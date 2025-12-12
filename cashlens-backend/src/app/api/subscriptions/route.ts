import { NextRequest, NextResponse } from 'next/server';
import { ObjectId } from 'mongodb';
import { getDatabase } from '@/lib/mongodb';

interface SubscriptionTransaction {
  id: string;
  amount: number;
  date: Date;
  accountName: string | null;
  accountMask: string | null;
}

interface DetectedSubscription {
  id: string;
  merchantName: string;
  amount: number;
  frequency: string;
  category: string | null;
  lastCharge: Date;
  nextExpected: Date | null;
  accountName: string | null;
  accountMask: string | null;
  logoUrl: string | null;
  transactionCount: number;
  confidence: number;
  transactions: SubscriptionTransaction[];
}

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const userId = searchParams.get('userId');
    const months = parseInt(searchParams.get('months') || '3');

    if (!userId) {
      return NextResponse.json(
        { error: 'userId is required' },
        { status: 400 }
      );
    }

    const db = await getDatabase();
    const userObjectId = new ObjectId(userId);

    // Get transactions from the last N months
    const startDate = new Date();
    startDate.setMonth(startDate.getMonth() - months);

    const transactions = await db
      .collection('transactions')
      .find({
        userId: userObjectId,
        date: { $gte: startDate },
        pending: false,
        isExcluded: { $ne: true },
        // Only consider outgoing transactions (positive amounts in Plaid = money out)
        amount: { $gt: 0 },
      })
      .sort({ date: -1 })
      .toArray();

    // Get account info
    const accountIds = [...new Set(transactions.map((t) => t.accountId?.toString()).filter(Boolean))];
    const accounts = await db
      .collection('accounts')
      .find({ _id: { $in: accountIds.map((id) => new ObjectId(id)) } })
      .toArray();
    const accountMap = new Map(
      accounts.map((a) => [a._id.toString(), { name: a.name, mask: a.mask }])
    );

    // Group transactions by merchant name (normalized)
    const merchantGroups = new Map<string, any[]>();

    for (const t of transactions) {
      // Use merchantName if available, otherwise use cleaned transaction name
      let merchant = t.merchantName || t.name || '';

      // Normalize merchant name: lowercase, trim, remove extra spaces
      merchant = merchant.toLowerCase().trim().replace(/\s+/g, ' ');

      // Skip if no valid merchant name
      if (!merchant || merchant.length < 2) continue;

      // Skip common non-subscription patterns
      const skipPatterns = [
        'transfer', 'payment', 'deposit', 'atm', 'withdrawal',
        'venmo', 'zelle', 'paypal', 'cash app', 'wire'
      ];
      if (skipPatterns.some(p => merchant.includes(p))) continue;

      if (!merchantGroups.has(merchant)) {
        merchantGroups.set(merchant, []);
      }
      merchantGroups.get(merchant)!.push(t);
    }

    // Analyze each merchant group for subscription patterns
    const subscriptions: DetectedSubscription[] = [];

    for (const [merchant, txns] of merchantGroups) {
      // Need at least 2 transactions to detect a pattern
      if (txns.length < 2) continue;

      // Sort by date (oldest first)
      txns.sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());

      // Calculate amount statistics
      const amounts = txns.map(t => t.amount);
      const avgAmount = amounts.reduce((a, b) => a + b, 0) / amounts.length;
      const minAmount = Math.min(...amounts);
      const maxAmount = Math.max(...amounts);

      // Check amount consistency (within 20% of average)
      const amountVariance = (maxAmount - minAmount) / avgAmount;
      if (amountVariance > 0.20) continue; // Too much variance, not a subscription

      // Calculate interval between transactions
      const intervals: number[] = [];
      for (let i = 1; i < txns.length; i++) {
        const prevDate = new Date(txns[i - 1].date);
        const currDate = new Date(txns[i].date);
        const daysDiff = Math.round((currDate.getTime() - prevDate.getTime()) / (1000 * 60 * 60 * 24));
        intervals.push(daysDiff);
      }

      // Determine frequency based on average interval
      const avgInterval = intervals.reduce((a, b) => a + b, 0) / intervals.length;
      let frequency: string;
      let expectedInterval: number;

      if (avgInterval >= 25 && avgInterval <= 35) {
        frequency = 'monthly';
        expectedInterval = 30;
      } else if (avgInterval >= 12 && avgInterval <= 16) {
        frequency = 'bi-weekly';
        expectedInterval = 14;
      } else if (avgInterval >= 5 && avgInterval <= 9) {
        frequency = 'weekly';
        expectedInterval = 7;
      } else if (avgInterval >= 355 && avgInterval <= 375) {
        frequency = 'yearly';
        expectedInterval = 365;
      } else if (avgInterval >= 85 && avgInterval <= 95) {
        frequency = 'quarterly';
        expectedInterval = 90;
      } else {
        // Not a recognized frequency pattern
        continue;
      }

      // Check interval consistency
      const intervalVariance = intervals.map(i => Math.abs(i - expectedInterval));
      const maxVariance = Math.max(...intervalVariance);
      if (maxVariance > 7) continue; // Too much variance in timing

      // Calculate confidence score (0-1)
      let confidence = 1.0;
      confidence -= amountVariance * 0.5; // Reduce for amount variance
      confidence -= (maxVariance / expectedInterval) * 0.3; // Reduce for timing variance
      confidence = Math.max(0.5, Math.min(1.0, confidence)); // Clamp between 0.5 and 1.0

      // Get the most recent transaction
      const lastTxn = txns[txns.length - 1];
      const lastChargeDate = new Date(lastTxn.date);

      // Calculate next expected charge
      const nextExpected = new Date(lastChargeDate);
      nextExpected.setDate(nextExpected.getDate() + expectedInterval);

      // Get account info
      const account = lastTxn.accountId ? accountMap.get(lastTxn.accountId.toString()) : null;

      // Get display name (capitalize first letter of each word)
      const displayName = (lastTxn.merchantName || lastTxn.name || merchant)
        .split(' ')
        .map((word: string) => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
        .join(' ');

      // Build transaction history (sorted by date, newest first)
      const transactionHistory: SubscriptionTransaction[] = txns
        .sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime())
        .map((t) => {
          const txnAccount = t.accountId ? accountMap.get(t.accountId.toString()) : null;
          return {
            id: t._id.toString(),
            amount: t.amount,
            date: new Date(t.date),
            accountName: txnAccount?.name || null,
            accountMask: txnAccount?.mask || null,
          };
        });

      subscriptions.push({
        id: `sub_${merchant.replace(/\s+/g, '_').substring(0, 20)}`,
        merchantName: displayName,
        amount: Math.round(avgAmount * 100) / 100,
        frequency,
        category: lastTxn.primaryCategory || lastTxn.category?.[0] || null,
        lastCharge: lastChargeDate,
        nextExpected: nextExpected > new Date() ? nextExpected : null,
        accountName: account?.name || null,
        accountMask: account?.mask || null,
        logoUrl: lastTxn.logoUrl || null,
        transactionCount: txns.length,
        confidence,
        transactions: transactionHistory,
      });
    }

    // Sort by last charge date (newest first)
    subscriptions.sort((a, b) => new Date(b.lastCharge).getTime() - new Date(a.lastCharge).getTime());

    // Calculate total monthly cost
    let totalMonthly = 0;
    for (const sub of subscriptions) {
      switch (sub.frequency) {
        case 'weekly':
          totalMonthly += sub.amount * 4.33;
          break;
        case 'bi-weekly':
          totalMonthly += sub.amount * 2.17;
          break;
        case 'monthly':
          totalMonthly += sub.amount;
          break;
        case 'quarterly':
          totalMonthly += sub.amount / 3;
          break;
        case 'yearly':
          totalMonthly += sub.amount / 12;
          break;
      }
    }

    return NextResponse.json({
      subscriptions,
      totalMonthly: Math.round(totalMonthly * 100) / 100,
      count: subscriptions.length,
    });
  } catch (error: any) {
    console.error('Error detecting subscriptions:', error);
    return NextResponse.json(
      { error: error.message || 'Failed to detect subscriptions' },
      { status: 500 }
    );
  }
}
