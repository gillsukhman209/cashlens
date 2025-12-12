import { NextRequest, NextResponse } from 'next/server';
import { ObjectId } from 'mongodb';
import { getDatabase } from '@/lib/mongodb';

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const userId = searchParams.get('userId');
    const startDate = searchParams.get('startDate');
    const endDate = searchParams.get('endDate');
    const accountId = searchParams.get('accountId');
    const category = searchParams.get('category');
    const search = searchParams.get('search');
    const limit = parseInt(searchParams.get('limit') || '50');
    const offset = parseInt(searchParams.get('offset') || '0');
    const excludePending = searchParams.get('excludePending') === 'true';

    if (!userId) {
      return NextResponse.json(
        { error: 'userId is required' },
        { status: 400 }
      );
    }

    const db = await getDatabase();
    const userObjectId = new ObjectId(userId);

    // Debug: Count all transactions for this user to help diagnose issues
    const debugTotalForUser = await db.collection('transactions').countDocuments({ userId: userObjectId });
    const debugCSVCount = await db.collection('transactions').countDocuments({ userId: userObjectId, source: 'csv' });
    console.log(`[DEBUG] User ${userId}: Total transactions = ${debugTotalForUser}, CSV imported = ${debugCSVCount}`);

    // Build query - use $ne: true to include transactions where isExcluded is false, null, or missing
    const query: any = { userId: userObjectId, isExcluded: { $ne: true } };

    // Date range filter
    if (startDate || endDate) {
      query.date = {};
      if (startDate) {
        query.date.$gte = new Date(startDate);
      }
      if (endDate) {
        query.date.$lte = new Date(endDate);
      }
    }

    // Account filter
    if (accountId) {
      query.accountId = new ObjectId(accountId);
    }

    // Category filter
    if (category) {
      query.primaryCategory = category;
    }

    // Search filter (merchant name)
    if (search) {
      query.$or = [
        { name: { $regex: search, $options: 'i' } },
        { merchantName: { $regex: search, $options: 'i' } },
      ];
    }

    // Exclude pending transactions if requested
    if (excludePending) {
      query.pending = false;
    }

    // Get total count
    const total = await db.collection('transactions').countDocuments(query);

    // Get transactions
    const transactions = await db
      .collection('transactions')
      .find(query)
      .sort({ date: -1, createdAt: -1 })
      .skip(offset)
      .limit(limit)
      .toArray();

    // Get account info for transactions
    const accountIds = [...new Set(transactions.map((t) => t.accountId.toString()))];
    const accounts = await db
      .collection('accounts')
      .find({ _id: { $in: accountIds.map((id) => new ObjectId(id)) } })
      .toArray();
    const accountMap = new Map(
      accounts.map((a) => [
        a._id.toString(),
        { name: a.name, mask: a.mask, type: a.type, subtype: a.subtype },
      ])
    );

    // Format transactions
    const formattedTransactions = transactions.map((t) => {
      const account = accountMap.get(t.accountId.toString());
      return {
        id: t._id.toString(),
        plaidTransactionId: t.plaidTransactionId,
        amount: t.amount,
        isoCurrencyCode: t.isoCurrencyCode,
        date: t.date,
        name: t.name,
        merchantName: t.merchantName,
        category: t.primaryCategory || t.category?.[0] || 'Uncategorized',
        detailedCategory: t.detailedCategory,
        pending: t.pending,
        paymentChannel: t.paymentChannel,
        logoUrl: t.logoUrl,
        location: t.location,
        userNote: t.userNote,
        userCategory: t.userCategory,
        account: account
          ? {
              name: account.name,
              mask: account.mask,
              type: account.type,
              subtype: account.subtype,
            }
          : null,
      };
    });

    return NextResponse.json({
      transactions: formattedTransactions,
      total,
      limit,
      offset,
      hasMore: offset + transactions.length < total,
      // Debug info - remove after fixing
      _debug: {
        totalForUser: debugTotalForUser,
        csvCount: debugCSVCount,
        queryUserId: userId,
      },
    });
  } catch (error: any) {
    console.error('Error fetching transactions:', error);
    return NextResponse.json(
      { error: error.message || 'Failed to fetch transactions' },
      { status: 500 }
    );
  }
}
