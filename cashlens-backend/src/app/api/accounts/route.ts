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

    // Get all plaid items for user (for institution info)
    const plaidItems = await db
      .collection('plaid_items')
      .find({ userId: userObjectId, status: 'active' })
      .toArray();

    const plaidItemMap = new Map(
      plaidItems.map((item) => [
        item._id.toString(),
        {
          institutionName: item.institutionName,
          institutionLogo: item.institutionLogo,
          institutionColor: item.institutionColor,
          lastSyncedAt: item.lastSyncedAt,
        },
      ])
    );

    // Get all accounts for user
    const accounts = await db
      .collection('accounts')
      .find({ userId: userObjectId, isHidden: false })
      .sort({ type: 1, name: 1 })
      .toArray();

    // Enrich accounts with institution info
    const enrichedAccounts = accounts.map((acc) => {
      const institution = plaidItemMap.get(acc.plaidItemId.toString());
      return {
        id: acc._id.toString(),
        accountId: acc.accountId,
        name: acc.name,
        officialName: acc.officialName,
        type: acc.type,
        subtype: acc.subtype,
        mask: acc.mask,
        currentBalance: acc.currentBalance,
        availableBalance: acc.availableBalance,
        creditLimit: acc.creditLimit,
        isoCurrencyCode: acc.isoCurrencyCode,
        institution: institution
          ? {
              name: institution.institutionName,
              logo: institution.institutionLogo,
              color: institution.institutionColor,
            }
          : null,
        lastUpdatedAt: acc.lastUpdatedAt,
      };
    });

    // Calculate totals by type
    const totals = {
      checking: 0,
      savings: 0,
      credit: 0,
      investment: 0,
      other: 0,
    };

    for (const acc of accounts) {
      const balance = acc.currentBalance || 0;
      if (acc.type === 'depository') {
        if (acc.subtype === 'checking') {
          totals.checking += balance;
        } else if (acc.subtype === 'savings') {
          totals.savings += balance;
        } else {
          totals.other += balance;
        }
      } else if (acc.type === 'credit') {
        totals.credit += balance;
      } else if (acc.type === 'investment') {
        totals.investment += balance;
      } else {
        totals.other += balance;
      }
    }

    const netWorth = totals.checking + totals.savings + totals.investment - totals.credit + totals.other;

    return NextResponse.json({
      accounts: enrichedAccounts,
      totals,
      netWorth,
    });
  } catch (error: any) {
    console.error('Error fetching accounts:', error);
    return NextResponse.json(
      { error: error.message || 'Failed to fetch accounts' },
      { status: 500 }
    );
  }
}

export async function PATCH(request: NextRequest) {
  try {
    const body = await request.json();
    const { userId, accountId, isHidden } = body;

    if (!userId || !accountId || typeof isHidden !== 'boolean') {
      return NextResponse.json(
        { error: 'userId, accountId, and isHidden are required' },
        { status: 400 }
      );
    }

    const db = await getDatabase();
    const userObjectId = new ObjectId(userId);
    const accountObjectId = new ObjectId(accountId);

    // Update the account's isHidden status
    const result = await db.collection('accounts').updateOne(
      { _id: accountObjectId, userId: userObjectId },
      { $set: { isHidden, updatedAt: new Date() } }
    );

    if (result.matchedCount === 0) {
      return NextResponse.json(
        { error: 'Account not found' },
        { status: 404 }
      );
    }

    return NextResponse.json({
      success: true,
      accountId,
      isHidden,
    });
  } catch (error: any) {
    console.error('Error updating account visibility:', error);
    return NextResponse.json(
      { error: error.message || 'Failed to update account' },
      { status: 500 }
    );
  }
}
