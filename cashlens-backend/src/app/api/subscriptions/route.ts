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

    // First check for stored subscriptions (from CSV import)
    const storedSubscriptions = await db
      .collection('detected_subscriptions')
      .find({ userId: userObjectId })
      .sort({ lastCharge: -1 })
      .toArray();

    if (storedSubscriptions.length > 0) {
      console.log(`[DEBUG] Subscriptions: Found ${storedSubscriptions.length} stored subscriptions for user ${userId}`);

      // Calculate total monthly cost
      let totalMonthly = 0;
      const formattedSubs = storedSubscriptions.map((sub) => {
        let monthlyAmount = sub.amount;
        switch (sub.frequency) {
          case 'weekly':
            monthlyAmount = sub.amount * 4.33;
            break;
          case 'bi-weekly':
            monthlyAmount = sub.amount * 2.17;
            break;
          case 'quarterly':
            monthlyAmount = sub.amount / 3;
            break;
          case 'yearly':
            monthlyAmount = sub.amount / 12;
            break;
        }
        totalMonthly += monthlyAmount;

        return {
          id: sub._id.toString(),
          merchantName: sub.merchantName,
          amount: sub.amount,
          frequency: sub.frequency,
          category: sub.category,
          lastCharge: sub.lastCharge,
          nextExpected: sub.nextExpected,
          accountName: sub.accountName,
          accountMask: sub.accountMask,
          logoUrl: sub.logoUrl,
          transactionCount: sub.transactionCount,
          confidence: sub.confidence,
          transactions: [], // Stored subscriptions don't have transaction history
        };
      });

      return NextResponse.json({
        subscriptions: formattedSubs,
        totalMonthly: Math.round(totalMonthly * 100) / 100,
        count: formattedSubs.length,
        source: 'stored',
      });
    }

    // Fall back to detecting subscriptions from transactions
    // Get transactions from the last N months
    const startDate = new Date();
    startDate.setMonth(startDate.getMonth() - months);

    // Debug: Check total transactions for this user
    const totalUserTxns = await db.collection('transactions').countDocuments({ userId: userObjectId });
    const csvTxns = await db.collection('transactions').countDocuments({ userId: userObjectId, source: 'csv' });
    console.log(`[DEBUG] Subscriptions: User ${userId} has ${totalUserTxns} total transactions, ${csvTxns} from CSV (detecting from transactions)`);

    const transactions = await db
      .collection('transactions')
      .find({
        userId: userObjectId,
        date: { $gte: startDate },
        pending: { $ne: true }, // Changed to $ne: true to include null/undefined/false
        isExcluded: { $ne: true },
        // Only consider outgoing transactions (positive amounts in Plaid = money out)
        amount: { $gt: 0 },
      })
      .sort({ date: -1 })
      .toArray();

    console.log(`[DEBUG] Subscriptions: Found ${transactions.length} transactions after filtering (date >= ${startDate.toISOString()}, amount > 0)`);

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
    // This detection focuses on TIMING consistency, not amount consistency
    // Utility bills can vary significantly in amount but are still subscriptions
    const merchantGroups = new Map<string, any[]>();

    for (const t of transactions) {
      // Use merchantName if available, otherwise use cleaned transaction name
      let merchant = t.merchantName || t.name || '';

      // Normalize merchant name: lowercase, trim, remove extra spaces
      merchant = merchant.toLowerCase().trim().replace(/\s+/g, ' ');

      // Skip if no valid merchant name
      if (!merchant || merchant.length < 2) continue;

      // Skip common non-subscription patterns (transfers, not actual bills)
      const skipPatterns = [
        'transfer', 'deposit', 'atm', 'withdrawal',
        'venmo', 'zelle', 'cash app', 'wire',
        'interest', 'fee', 'refund', 'credit'
      ];
      if (skipPatterns.some(p => merchant.includes(p))) continue;

      if (!merchantGroups.has(merchant)) {
        merchantGroups.set(merchant, []);
      }
      merchantGroups.get(merchant)!.push(t);
    }

    // Debug: Show top merchant groups
    const topMerchants = Array.from(merchantGroups.entries())
      .sort((a, b) => b[1].length - a[1].length)
      .slice(0, 10);
    console.log(`[DEBUG] Subscriptions: Top merchants: ${topMerchants.map(([m, t]) => `${m}(${t.length})`).join(', ')}`);

    // Analyze each merchant group for subscription patterns
    const subscriptions: DetectedSubscription[] = [];

    for (const [merchant, txns] of merchantGroups) {
      // Need at least 2 transactions to detect a pattern
      if (txns.length < 2) continue;

      // Sort by date (oldest first)
      txns.sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());

      // Calculate amount statistics (for display, not filtering)
      const amounts = txns.map(t => t.amount);
      const avgAmount = amounts.reduce((a, b) => a + b, 0) / amounts.length;
      const minAmount = Math.min(...amounts);
      const maxAmount = Math.max(...amounts);
      const amountVariance = avgAmount > 0 ? (maxAmount - minAmount) / avgAmount : 0;

      // Calculate interval between transactions
      const intervals: number[] = [];
      for (let i = 1; i < txns.length; i++) {
        const prevDate = new Date(txns[i - 1].date);
        const currDate = new Date(txns[i].date);
        const daysDiff = Math.round((currDate.getTime() - prevDate.getTime()) / (1000 * 60 * 60 * 24));
        intervals.push(daysDiff);
      }

      // Determine frequency based on average interval (with wider tolerance)
      const avgInterval = intervals.reduce((a, b) => a + b, 0) / intervals.length;
      let frequency: string;
      let expectedInterval: number;
      let maxAllowedVariance: number;

      if (avgInterval >= 20 && avgInterval <= 40) {
        // Monthly - most common, allow more variance (bills can be 28-35 days apart)
        frequency = 'monthly';
        expectedInterval = 30;
        maxAllowedVariance = 12; // Allow up to 12 days variance for monthly
      } else if (avgInterval >= 10 && avgInterval <= 18) {
        frequency = 'bi-weekly';
        expectedInterval = 14;
        maxAllowedVariance = 5;
      } else if (avgInterval >= 4 && avgInterval <= 10) {
        frequency = 'weekly';
        expectedInterval = 7;
        maxAllowedVariance = 3;
      } else if (avgInterval >= 340 && avgInterval <= 390) {
        frequency = 'yearly';
        expectedInterval = 365;
        maxAllowedVariance = 30; // Allow a month variance for yearly
      } else if (avgInterval >= 75 && avgInterval <= 105) {
        frequency = 'quarterly';
        expectedInterval = 90;
        maxAllowedVariance = 15;
      } else {
        // Not a recognized frequency pattern
        continue;
      }

      // Check interval consistency (with more tolerance)
      const intervalVariances = intervals.map(i => Math.abs(i - expectedInterval));
      const maxVariance = Math.max(...intervalVariances);
      const avgVariance = intervalVariances.reduce((a, b) => a + b, 0) / intervalVariances.length;

      // Skip if timing is too inconsistent
      if (maxVariance > maxAllowedVariance) continue;

      // Calculate confidence score based on timing consistency (not amount)
      let confidence = 1.0;
      // Reduce confidence based on timing variance
      confidence -= (avgVariance / expectedInterval) * 0.4;
      // Slightly reduce confidence for variable amounts (but don't exclude)
      if (amountVariance > 0.5) {
        confidence -= 0.1; // Variable amount subscriptions get slightly lower confidence
      }
      confidence = Math.max(0.4, Math.min(1.0, confidence));

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
      // Debug info
      _debug: {
        totalUserTransactions: totalUserTxns,
        csvTransactions: csvTxns,
        filteredTransactions: transactions.length,
        merchantGroups: topMerchants.map(([m, t]) => ({ merchant: m, count: t.length })),
      },
    });
  } catch (error: any) {
    console.error('Error detecting subscriptions:', error);
    return NextResponse.json(
      { error: error.message || 'Failed to detect subscriptions' },
      { status: 500 }
    );
  }
}
