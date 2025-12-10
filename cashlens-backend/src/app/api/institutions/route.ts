import { NextRequest, NextResponse } from 'next/server';
import { ObjectId } from 'mongodb';
import { getDatabase } from '@/lib/mongodb';

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const userId = searchParams.get('userId');

    if (!userId) {
      return NextResponse.json(
        { error: 'userId is required' },
        { status: 400 }
      );
    }

    const db = await getDatabase();
    const userObjectId = new ObjectId(userId);

    // Get all plaid items for user
    const plaidItems = await db
      .collection('plaid_items')
      .find({ userId: userObjectId })
      .sort({ createdAt: -1 })
      .toArray();

    // Get account counts for each institution
    const institutions = await Promise.all(
      plaidItems.map(async (item) => {
        const accountCount = await db
          .collection('accounts')
          .countDocuments({ plaidItemId: item._id, isHidden: false });

        return {
          id: item._id.toString(),
          itemId: item.itemId,
          institutionId: item.institutionId,
          name: item.institutionName,
          logo: item.institutionLogo,
          color: item.institutionColor,
          status: item.status,
          accountCount,
          lastSyncedAt: item.lastSyncedAt,
          createdAt: item.createdAt,
          error: item.error,
        };
      })
    );

    return NextResponse.json({
      institutions,
    });
  } catch (error: any) {
    console.error('Error fetching institutions:', error);
    return NextResponse.json(
      { error: error.message || 'Failed to fetch institutions' },
      { status: 500 }
    );
  }
}

export async function DELETE(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const userId = searchParams.get('userId');
    const itemId = searchParams.get('itemId');

    if (!userId || !itemId) {
      return NextResponse.json(
        { error: 'userId and itemId are required' },
        { status: 400 }
      );
    }

    const db = await getDatabase();
    const userObjectId = new ObjectId(userId);
    const plaidItemObjectId = new ObjectId(itemId);

    // Get the plaid item
    const plaidItem = await db.collection('plaid_items').findOne({
      _id: plaidItemObjectId,
      userId: userObjectId,
    });

    if (!plaidItem) {
      return NextResponse.json(
        { error: 'Institution not found' },
        { status: 404 }
      );
    }

    // Delete all transactions for accounts linked to this item
    const accounts = await db
      .collection('accounts')
      .find({ plaidItemId: plaidItemObjectId })
      .toArray();
    const accountIds = accounts.map((a) => a._id);

    if (accountIds.length > 0) {
      await db.collection('transactions').deleteMany({
        accountId: { $in: accountIds },
      });
    }

    // Delete all accounts linked to this item
    await db.collection('accounts').deleteMany({
      plaidItemId: plaidItemObjectId,
    });

    // Delete sync logs
    await db.collection('sync_logs').deleteMany({
      plaidItemId: plaidItemObjectId,
    });

    // Delete the plaid item
    await db.collection('plaid_items').deleteOne({
      _id: plaidItemObjectId,
    });

    return NextResponse.json({
      success: true,
      message: 'Institution unlinked successfully',
    });
  } catch (error: any) {
    console.error('Error unlinking institution:', error);
    return NextResponse.json(
      { error: error.message || 'Failed to unlink institution' },
      { status: 500 }
    );
  }
}
