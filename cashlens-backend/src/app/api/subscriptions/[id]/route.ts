import { NextRequest, NextResponse } from 'next/server';
import { ObjectId } from 'mongodb';
import { getDatabase } from '@/lib/mongodb';

const VALID_FREQUENCIES = ['weekly', 'bi-weekly', 'monthly', 'quarterly', 'yearly'];

// PATCH - Update subscription (name, amount, frequency)
export async function PATCH(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const body = await request.json();
    const { userId, customName, customAmount, customFrequency } = body;

    if (!userId) {
      return NextResponse.json(
        { error: 'userId is required' },
        { status: 400 }
      );
    }

    if (!id) {
      return NextResponse.json(
        { error: 'subscription id is required' },
        { status: 400 }
      );
    }

    // Validate frequency if provided
    if (customFrequency && !VALID_FREQUENCIES.includes(customFrequency)) {
      return NextResponse.json(
        { error: `Invalid frequency. Must be one of: ${VALID_FREQUENCIES.join(', ')}` },
        { status: 400 }
      );
    }

    const db = await getDatabase();
    const userObjectId = new ObjectId(userId);

    // The id is the normalized merchant name (subscriptionKey)
    // We need to decode it since it may have been URL encoded
    const subscriptionKey = decodeURIComponent(id).toLowerCase().trim().replace(/\s+/g, ' ');

    console.log(`[DEBUG] Subscription PATCH: userId=${userId}, subscriptionKey=${subscriptionKey}`);

    // Upsert the override
    const updateData: Record<string, any> = {
      userId: userObjectId,
      subscriptionKey,
      updatedAt: new Date(),
    };

    // Only set fields that are provided
    if (customName !== undefined) {
      updateData.customName = customName || null;
    }
    if (customAmount !== undefined) {
      updateData.customAmount = customAmount !== null ? Number(customAmount) : null;
    }
    if (customFrequency !== undefined) {
      updateData.customFrequency = customFrequency || null;
    }

    const result = await db.collection('subscription_user_overrides').updateOne(
      { userId: userObjectId, subscriptionKey },
      {
        $set: updateData,
        $setOnInsert: {
          isDeleted: false,
          createdAt: new Date(),
        },
      },
      { upsert: true }
    );

    console.log(`[DEBUG] Subscription PATCH: Updated override for ${subscriptionKey}, matched=${result.matchedCount}, modified=${result.modifiedCount}, upserted=${result.upsertedCount}`);

    return NextResponse.json({
      success: true,
      subscriptionKey,
      customName: customName || null,
      customAmount: customAmount !== null ? Number(customAmount) : null,
      customFrequency: customFrequency || null,
    });
  } catch (error: any) {
    console.error('Error updating subscription:', error);
    return NextResponse.json(
      { error: error.message || 'Failed to update subscription' },
      { status: 500 }
    );
  }
}

// DELETE - Mark subscription as deleted (soft delete via override)
export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const { searchParams } = new URL(request.url);
    const userId = searchParams.get('userId');

    if (!userId) {
      return NextResponse.json(
        { error: 'userId is required' },
        { status: 400 }
      );
    }

    if (!id) {
      return NextResponse.json(
        { error: 'subscription id is required' },
        { status: 400 }
      );
    }

    const db = await getDatabase();
    const userObjectId = new ObjectId(userId);

    // The id is the normalized merchant name (subscriptionKey)
    const subscriptionKey = decodeURIComponent(id).toLowerCase().trim().replace(/\s+/g, ' ');

    console.log(`[DEBUG] Subscription DELETE: userId=${userId}, subscriptionKey=${subscriptionKey}`);

    // Upsert the override with isDeleted = true
    const result = await db.collection('subscription_user_overrides').updateOne(
      { userId: userObjectId, subscriptionKey },
      {
        $set: {
          isDeleted: true,
          updatedAt: new Date(),
        },
        $setOnInsert: {
          userId: userObjectId,
          subscriptionKey,
          customName: null,
          customAmount: null,
          customFrequency: null,
          createdAt: new Date(),
        },
      },
      { upsert: true }
    );

    console.log(`[DEBUG] Subscription DELETE: Marked ${subscriptionKey} as deleted, matched=${result.matchedCount}, modified=${result.modifiedCount}, upserted=${result.upsertedCount}`);

    return NextResponse.json({
      success: true,
      subscriptionKey,
      deleted: true,
    });
  } catch (error: any) {
    console.error('Error deleting subscription:', error);
    return NextResponse.json(
      { error: error.message || 'Failed to delete subscription' },
      { status: 500 }
    );
  }
}
