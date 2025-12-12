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

export async function POST(request: NextRequest) {
  try {
    const formData = await request.formData();
    const file = formData.get('file') as File;
    const userId = formData.get('userId') as string;
    const accountId = formData.get('accountId') as string;
    const format = formData.get('format') as string;

    if (!file || !userId || !accountId || !format) {
      return NextResponse.json(
        { error: 'file, userId, accountId, and format are required' },
        { status: 400 }
      );
    }

    const db = await getDatabase();
    const userObjectId = new ObjectId(userId);
    const accountObjectId = new ObjectId(accountId);

    // Verify account exists and belongs to user
    const account = await db.collection('accounts').findOne({
      _id: accountObjectId,
      userId: userObjectId,
    });

    if (!account) {
      return NextResponse.json({ error: 'Account not found' }, { status: 404 });
    }

    // Parse CSV
    const csvText = await file.text();
    const rows = parseCSV(csvText);

    if (rows.length === 0) {
      return NextResponse.json(
        { error: 'No transactions found in CSV' },
        { status: 400 }
      );
    }

    // Transform based on format
    let transactions: any[] = [];

    if (format === 'apple_card') {
      transactions = rows.map((row) => {
        const amount = parseFloat(row['Amount (USD)'] || '0');
        const transactionDate = row['Transaction Date'];
        const description = row['Description'] || '';
        const merchant = row['Merchant'] || '';
        const category = row['Category'] || 'Other';
        const type = row['Type'] || 'Purchase';

        return {
          userId: userObjectId,
          accountId: accountObjectId,
          plaidTransactionId: null,
          source: 'csv',
          amount,
          isoCurrencyCode: 'USD',
          date: transactionDate ? parseDate(transactionDate) : new Date(),
          authorizedDate: null,
          name: description,
          merchantName: merchant,
          category: [category],
          primaryCategory: category,
          detailedCategory: null,
          pending: false,
          paymentChannel: 'online',
          logoUrl: null,
          website: null,
          location: null,
          userCategory: null,
          userNote: null,
          isExcluded: false,
          importedType: type, // Store original Apple Card type
          createdAt: new Date(),
          updatedAt: new Date(),
        };
      });
    } else {
      return NextResponse.json(
        { error: `Unsupported format: ${format}` },
        { status: 400 }
      );
    }

    // Filter out any invalid transactions
    transactions = transactions.filter(
      (t) => t.date && !isNaN(t.amount) && t.name
    );

    if (transactions.length === 0) {
      return NextResponse.json(
        { error: 'No valid transactions found in CSV' },
        { status: 400 }
      );
    }

    // Bulk insert transactions
    const result = await db.collection('transactions').insertMany(transactions);

    // Calculate and update account balance (sum of all transactions for this account)
    const allTransactions = await db
      .collection('transactions')
      .find({ accountId: accountObjectId })
      .toArray();

    const balance = allTransactions.reduce(
      (sum, t) => sum + (t.amount || 0),
      0
    );

    await db.collection('accounts').updateOne(
      { _id: accountObjectId },
      {
        $set: {
          currentBalance: balance,
          lastUpdatedAt: new Date(),
        },
      }
    );

    return NextResponse.json({
      success: true,
      imported: result.insertedCount,
      balance: Math.round(balance * 100) / 100,
    });
  } catch (error: any) {
    console.error('Error importing CSV:', error);
    return NextResponse.json(
      { error: error.message || 'Failed to import CSV' },
      { status: 500 }
    );
  }
}
