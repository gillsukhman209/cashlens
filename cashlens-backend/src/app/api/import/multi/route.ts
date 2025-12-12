import { NextRequest, NextResponse } from 'next/server';
import { ObjectId } from 'mongodb';
import { getDatabase } from '@/lib/mongodb';

// Parse a single CSV line handling quoted fields
function parseCSVLine(line: string): string[] {
  const result: string[] = [];
  let current = '';
  let inQuotes = false;

  for (const char of line) {
    if (char === '"') {
      inQuotes = !inQuotes;
    } else if (char === ',' && !inQuotes) {
      result.push(current.trim());
      current = '';
    } else {
      current += char;
    }
  }
  result.push(current.trim());
  return result;
}

// Parse full CSV text into array of objects
function parseCSV(text: string): Record<string, string>[] {
  const lines = text.split('\n').filter((line) => line.trim());
  if (lines.length === 0) return [];

  const headers = parseCSVLine(lines[0]);
  return lines.slice(1).map((line) => {
    const values = parseCSVLine(line);
    const obj: Record<string, string> = {};
    headers.forEach((header, i) => {
      obj[header] = values[i] || '';
    });
    return obj;
  });
}

// Parse MM/DD/YYYY date format
function parseDate(dateStr: string): Date {
  const [month, day, year] = dateStr.split('/').map(Number);
  return new Date(year, month - 1, day);
}

interface ParsedTransaction {
  amount: number;
  date: Date;
  name: string;
  merchantName: string;
  category: string[];
  primaryCategory: string;
  type: string;
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
  transactions: {
    id: string;
    amount: number;
    date: Date;
    accountName: string | null;
    accountMask: string | null;
  }[];
}

// Detect subscriptions from a list of transactions
function detectSubscriptions(transactions: ParsedTransaction[], accountName: string | null): DetectedSubscription[] {
  // Group transactions by merchant name (normalized)
  const merchantGroups = new Map<string, ParsedTransaction[]>();

  for (const t of transactions) {
    let merchant = t.merchantName || t.name || '';
    merchant = merchant.toLowerCase().trim().replace(/\s+/g, ' ');

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

  const subscriptions: DetectedSubscription[] = [];

  for (const [merchant, txns] of merchantGroups) {
    if (txns.length < 2) continue;

    // Sort by date (oldest first)
    txns.sort((a, b) => a.date.getTime() - b.date.getTime());

    // Calculate amount statistics
    const amounts = txns.map(t => t.amount);
    const avgAmount = amounts.reduce((a, b) => a + b, 0) / amounts.length;
    const minAmount = Math.min(...amounts);
    const maxAmount = Math.max(...amounts);

    // Check amount consistency (within 20% of average)
    const amountVariance = (maxAmount - minAmount) / avgAmount;
    if (amountVariance > 0.20) continue;

    // Calculate interval between transactions
    const intervals: number[] = [];
    for (let i = 1; i < txns.length; i++) {
      const daysDiff = Math.round((txns[i].date.getTime() - txns[i - 1].date.getTime()) / (1000 * 60 * 60 * 24));
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
      continue;
    }

    // Check interval consistency
    const intervalVariance = intervals.map(i => Math.abs(i - expectedInterval));
    const maxVariance = Math.max(...intervalVariance);
    if (maxVariance > 7) continue;

    // Calculate confidence score
    let confidence = 1.0;
    confidence -= amountVariance * 0.5;
    confidence -= (maxVariance / expectedInterval) * 0.3;
    confidence = Math.max(0.5, Math.min(1.0, confidence));

    const lastTxn = txns[txns.length - 1];
    const lastChargeDate = lastTxn.date;

    const nextExpected = new Date(lastChargeDate);
    nextExpected.setDate(nextExpected.getDate() + expectedInterval);

    const displayName = (lastTxn.merchantName || lastTxn.name || merchant)
      .split(' ')
      .map((word: string) => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
      .join(' ');

    const transactionHistory = txns
      .sort((a, b) => b.date.getTime() - a.date.getTime())
      .map((t, index) => ({
        id: `temp_${index}`,
        amount: t.amount,
        date: t.date,
        accountName: accountName,
        accountMask: null,
      }));

    subscriptions.push({
      id: `sub_${merchant.replace(/\s+/g, '_').substring(0, 20)}`,
      merchantName: displayName,
      amount: Math.round(avgAmount * 100) / 100,
      frequency,
      category: lastTxn.primaryCategory || lastTxn.category?.[0] || null,
      lastCharge: lastChargeDate,
      nextExpected: nextExpected > new Date() ? nextExpected : null,
      accountName: accountName,
      accountMask: null,
      logoUrl: null,
      transactionCount: txns.length,
      confidence,
      transactions: transactionHistory,
    });
  }

  subscriptions.sort((a, b) => b.lastCharge.getTime() - a.lastCharge.getTime());
  return subscriptions;
}

export async function POST(request: NextRequest) {
  try {
    let formData;
    try {
      formData = await request.formData();
    } catch (formError: any) {
      console.error('[ERROR] Failed to parse form data:', formError);
      return NextResponse.json(
        { error: `Failed to parse form data: ${formError.message}` },
        { status: 400 }
      );
    }

    const userId = formData.get('userId') as string;
    const mode = formData.get('mode') as string; // 'subscriptions_only' or 'full'
    const accountName = formData.get('accountName') as string;
    const format = formData.get('format') as string;
    const files = formData.getAll('files') as File[];

    console.log(`[DEBUG] Multi-import: userId=${userId}, mode=${mode}, files=${files.length}, format=${format}, accountName=${accountName}`);

    if (!userId || !mode || !accountName || !format) {
      return NextResponse.json(
        { error: 'userId, mode, accountName, and format are required' },
        { status: 400 }
      );
    }

    if (files.length < 3) {
      return NextResponse.json(
        { error: `At least 3 CSV files are required for subscription detection (received ${files.length} files)` },
        { status: 400 }
      );
    }

    if (files.length > 10) {
      return NextResponse.json(
        { error: 'Maximum 10 CSV files allowed' },
        { status: 400 }
      );
    }

    const db = await getDatabase();
    const userObjectId = new ObjectId(userId);

    // Parse all CSV files
    const allTransactions: ParsedTransaction[] = [];

    for (const file of files) {
      const csvText = await file.text();
      const rows = parseCSV(csvText);
      console.log(`[DEBUG] Multi-import: Parsed ${rows.length} rows from ${file.name}`);

      if (format === 'apple_card') {
        for (const row of rows) {
          const amount = parseFloat(row['Amount (USD)'] || '0');
          const transactionDate = row['Transaction Date'];
          const description = row['Description'] || '';
          const merchant = row['Merchant'] || '';
          const category = row['Category'] || 'Other';
          const type = row['Type'] || 'Purchase';

          if (!transactionDate || isNaN(amount) || !description) continue;

          allTransactions.push({
            amount,
            date: parseDate(transactionDate),
            name: description,
            merchantName: merchant,
            category: [category],
            primaryCategory: category,
            type,
          });
        }
      } else {
        return NextResponse.json(
          { error: `Unsupported format: ${format}` },
          { status: 400 }
        );
      }
    }

    console.log(`[DEBUG] Multi-import: Total parsed transactions = ${allTransactions.length}`);

    // Detect subscriptions from combined transactions
    const subscriptions = detectSubscriptions(allTransactions, accountName);
    console.log(`[DEBUG] Multi-import: Detected ${subscriptions.length} subscriptions`);

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

    let accountId: string | null = null;
    let balance: number | null = null;

    // For full import mode, store transactions in database
    if (mode === 'full') {
      // Create or find manual account
      let account = await db.collection('accounts').findOne({
        userId: userObjectId,
        name: accountName,
        source: 'manual',
      });

      if (!account) {
        // Create plaid_items entry for manual account
        const plaidItemResult = await db.collection('plaid_items').insertOne({
          userId: userObjectId,
          itemId: `manual_${new ObjectId().toString()}`,
          accessToken: null,
          institutionId: 'manual',
          institutionName: accountName,
          status: 'manual',
          createdAt: new Date(),
          updatedAt: new Date(),
        });

        // Create account
        const accountResult = await db.collection('accounts').insertOne({
          userId: userObjectId,
          plaidItemId: plaidItemResult.insertedId,
          accountId: `manual_${new ObjectId().toString()}`,
          name: accountName,
          officialName: accountName,
          type: 'credit',
          subtype: 'credit card',
          mask: null,
          currentBalance: 0,
          availableBalance: null,
          creditLimit: null,
          isoCurrencyCode: 'USD',
          source: 'manual',
          isHidden: false,
          lastUpdatedAt: new Date(),
          createdAt: new Date(),
        });

        account = await db.collection('accounts').findOne({ _id: accountResult.insertedId });
      }

      accountId = account!._id.toString();

      // Transform and insert transactions
      const dbTransactions = allTransactions.map((t) => ({
        userId: userObjectId,
        accountId: account!._id,
        plaidTransactionId: null,
        source: 'csv',
        amount: t.amount,
        isoCurrencyCode: 'USD',
        date: t.date,
        authorizedDate: null,
        name: t.name,
        merchantName: t.merchantName,
        category: t.category,
        primaryCategory: t.primaryCategory,
        detailedCategory: null,
        pending: false,
        paymentChannel: 'online',
        logoUrl: null,
        website: null,
        location: null,
        userCategory: null,
        userNote: null,
        isExcluded: false,
        importedType: t.type,
        createdAt: new Date(),
        updatedAt: new Date(),
      }));

      await db.collection('transactions').insertMany(dbTransactions);

      // Calculate balance
      const allAccountTxns = await db
        .collection('transactions')
        .find({ accountId: account!._id })
        .toArray();

      balance = allAccountTxns.reduce((sum, t) => sum + (t.amount || 0), 0);
      balance = Math.round(balance * 100) / 100;

      await db.collection('accounts').updateOne(
        { _id: account!._id },
        {
          $set: {
            currentBalance: balance,
            lastUpdatedAt: new Date(),
          },
        }
      );

      console.log(`[DEBUG] Multi-import: Full import complete. AccountId=${accountId}, Balance=${balance}`);
    }

    // Store detected subscriptions in database (for both modes)
    if (subscriptions.length > 0) {
      // Remove old detected subscriptions for this user
      await db.collection('detected_subscriptions').deleteMany({ userId: userObjectId });

      // Insert new detected subscriptions
      const subscriptionDocs = subscriptions.map((sub) => ({
        userId: userObjectId,
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
        source: 'csv_import',
        createdAt: new Date(),
        updatedAt: new Date(),
      }));

      await db.collection('detected_subscriptions').insertMany(subscriptionDocs);
      console.log(`[DEBUG] Multi-import: Stored ${subscriptionDocs.length} subscriptions in database`);
    }

    return NextResponse.json({
      success: true,
      mode,
      filesProcessed: files.length,
      totalTransactions: allTransactions.length,
      subscriptionsDetected: subscriptions.length,
      subscriptions,
      totalMonthly: Math.round(totalMonthly * 100) / 100,
      accountId,
      balance,
    });
  } catch (error: any) {
    console.error('Error in multi-file import:', error);
    return NextResponse.json(
      { error: error.message || 'Failed to import CSV files' },
      { status: 500 }
    );
  }
}
