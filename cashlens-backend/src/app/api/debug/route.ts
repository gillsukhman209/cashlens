import { NextRequest, NextResponse } from 'next/server';
import { ObjectId } from 'mongodb';
import { getDatabase } from '@/lib/mongodb';

// Debug endpoint to help diagnose transaction issues
// DELETE THIS FILE after fixing the issue
export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const userId = searchParams.get('userId');

    const db = await getDatabase();

    // If no userId provided, show global stats
    if (!userId) {
      const allUsers = await db.collection('users').find({}).toArray();
      const allTransactionCount = await db.collection('transactions').countDocuments({});
      const allAccountsCount = await db.collection('accounts').countDocuments({});
      const csvTransactionCount = await db.collection('transactions').countDocuments({ source: 'csv' });

      // Get sample of recent transactions
      const recentTransactions = await db.collection('transactions')
        .find({})
        .sort({ createdAt: -1 })
        .limit(10)
        .toArray();

      return NextResponse.json({
        message: 'No userId provided - showing global stats',
        users: allUsers.map(u => ({
          id: u._id.toString(),
          email: u.email,
          name: u.name,
        })),
        counts: {
          users: allUsers.length,
          transactions: allTransactionCount,
          csvTransactions: csvTransactionCount,
          accounts: allAccountsCount,
        },
        recentTransactions: recentTransactions.map(t => ({
          id: t._id.toString(),
          userId: t.userId?.toString(),
          accountId: t.accountId?.toString(),
          source: t.source,
          name: t.name?.substring(0, 50),
          amount: t.amount,
          date: t.date,
          isExcluded: t.isExcluded,
        })),
      });
    }

    const userObjectId = new ObjectId(userId);

    // Get counts
    const totalTransactions = await db.collection('transactions').countDocuments({ userId: userObjectId });
    const csvTransactions = await db.collection('transactions').countDocuments({ userId: userObjectId, source: 'csv' });
    const plaidTransactions = await db.collection('transactions').countDocuments({ userId: userObjectId, source: { $ne: 'csv' } });

    // Get all accounts for this user
    const accounts = await db.collection('accounts').find({ userId: userObjectId }).toArray();

    // Get all plaid items for this user
    const plaidItems = await db.collection('plaid_items').find({ userId: userObjectId }).toArray();

    // Get sample transactions (first 5)
    const sampleTransactions = await db
      .collection('transactions')
      .find({ userId: userObjectId })
      .limit(5)
      .toArray();

    // Check if there are any transactions at all in the DB
    const globalTransactionCount = await db.collection('transactions').countDocuments({});

    // Get all unique userIds in transactions (to check for mismatches)
    const uniqueUserIds = await db.collection('transactions').distinct('userId');

    return NextResponse.json({
      queryUserId: userId,
      userIdAsObjectId: userObjectId.toString(),
      counts: {
        totalTransactions,
        csvTransactions,
        plaidTransactions,
        globalTransactionCount,
      },
      accounts: accounts.map(a => ({
        id: a._id.toString(),
        name: a.name,
        type: a.type,
        currentBalance: a.currentBalance,
        plaidItemId: a.plaidItemId?.toString(),
      })),
      plaidItems: plaidItems.map(p => ({
        id: p._id.toString(),
        itemId: p.itemId,
        institutionName: p.institutionName,
        status: p.status,
      })),
      sampleTransactions: sampleTransactions.map(t => ({
        id: t._id.toString(),
        userId: t.userId?.toString(),
        accountId: t.accountId?.toString(),
        source: t.source,
        name: t.name,
        amount: t.amount,
        date: t.date,
        isExcluded: t.isExcluded,
      })),
      uniqueUserIdsInTransactions: uniqueUserIds.map((id: any) => id?.toString()),
    });
  } catch (error: any) {
    console.error('Debug error:', error);
    return NextResponse.json(
      { error: error.message || 'Debug failed' },
      { status: 500 }
    );
  }
}
