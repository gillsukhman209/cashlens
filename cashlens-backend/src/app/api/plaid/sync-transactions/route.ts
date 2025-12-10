import { NextRequest, NextResponse } from 'next/server';
import { ObjectId } from 'mongodb';
import { plaidClient, decryptToken } from '@/lib/plaid';
import { getDatabase } from '@/lib/mongodb';
import { Transaction, SyncLog } from '@/types/models';
import { RemovedTransaction, TransactionsSyncRequest } from 'plaid';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { userId, plaidItemId } = body;

    if (!userId) {
      return NextResponse.json(
        { error: 'userId is required' },
        { status: 400 }
      );
    }

    const db = await getDatabase();
    const userObjectId = new ObjectId(userId);

    // Build query - sync specific item or all items for user
    const itemQuery: any = { userId: userObjectId, status: 'active' };
    if (plaidItemId) {
      itemQuery._id = new ObjectId(plaidItemId);
    }

    const plaidItems = await db.collection('plaid_items').find(itemQuery).toArray();

    if (plaidItems.length === 0) {
      return NextResponse.json(
        { error: 'No linked accounts found' },
        { status: 404 }
      );
    }

    let totalAdded = 0;
    let totalModified = 0;
    let totalRemoved = 0;
    const updatedAccounts: any[] = [];

    for (const item of plaidItems) {
      const accessToken = decryptToken(item.accessToken);
      let cursor = item.cursor || undefined;
      let hasMore = true;

      const syncLog: SyncLog = {
        userId: userObjectId,
        plaidItemId: item._id,
        syncType: cursor ? 'incremental' : 'initial',
        status: 'success',
        transactionsAdded: 0,
        transactionsModified: 0,
        transactionsRemoved: 0,
        startedAt: new Date(),
      };

      try {
        while (hasMore) {
          const syncRequest: TransactionsSyncRequest = {
            access_token: accessToken,
            cursor: cursor,
            count: 500,
          };

          const response = await plaidClient.transactionsSync(syncRequest);
          const { added, modified, removed, next_cursor, has_more } = response.data;

          // Process added transactions
          if (added.length > 0) {
            // Get account ObjectIds mapping
            const accountIds = [...new Set(added.map((t) => t.account_id))];
            const accounts = await db
              .collection('accounts')
              .find({ accountId: { $in: accountIds } })
              .toArray();
            const accountMap = new Map(accounts.map((a) => [a.accountId, a._id]));

            const transactions: Transaction[] = added.map((t) => ({
              userId: userObjectId,
              accountId: accountMap.get(t.account_id) || new ObjectId(),
              plaidTransactionId: t.transaction_id,
              amount: t.amount,
              isoCurrencyCode: t.iso_currency_code || 'USD',
              date: new Date(t.date),
              authorizedDate: t.authorized_date ? new Date(t.authorized_date) : undefined,
              name: t.name,
              merchantName: t.merchant_name || undefined,
              category: t.category || undefined,
              primaryCategory: t.personal_finance_category?.primary || t.category?.[0],
              detailedCategory: t.personal_finance_category?.detailed,
              personalFinanceCategory: t.personal_finance_category
                ? {
                    primary: t.personal_finance_category.primary,
                    detailed: t.personal_finance_category.detailed,
                    confidenceLevel: t.personal_finance_category.confidence_level,
                  }
                : undefined,
              pending: t.pending,
              paymentChannel: t.payment_channel,
              location: t.location
                ? {
                    address: t.location.address || undefined,
                    city: t.location.city || undefined,
                    region: t.location.region || undefined,
                    postalCode: t.location.postal_code || undefined,
                    country: t.location.country || undefined,
                    lat: t.location.lat || undefined,
                    lon: t.location.lon || undefined,
                  }
                : undefined,
              logoUrl: t.logo_url || undefined,
              website: t.website || undefined,
              isExcluded: false,
              createdAt: new Date(),
              updatedAt: new Date(),
            }));

            await db.collection('transactions').insertMany(transactions);
            syncLog.transactionsAdded += added.length;
            totalAdded += added.length;
          }

          // Process modified transactions
          if (modified.length > 0) {
            for (const t of modified) {
              await db.collection('transactions').updateOne(
                { plaidTransactionId: t.transaction_id },
                {
                  $set: {
                    amount: t.amount,
                    date: new Date(t.date),
                    name: t.name,
                    merchantName: t.merchant_name || undefined,
                    category: t.category || undefined,
                    primaryCategory: t.personal_finance_category?.primary || t.category?.[0],
                    pending: t.pending,
                    updatedAt: new Date(),
                  },
                }
              );
            }
            syncLog.transactionsModified += modified.length;
            totalModified += modified.length;
          }

          // Process removed transactions
          if (removed.length > 0) {
            const removedIds = removed.map((r: RemovedTransaction) => r.transaction_id);
            await db.collection('transactions').deleteMany({
              plaidTransactionId: { $in: removedIds },
            });
            syncLog.transactionsRemoved += removed.length;
            totalRemoved += removed.length;
          }

          cursor = next_cursor;
          hasMore = has_more;
        }

        // Update cursor in plaid_items
        await db.collection('plaid_items').updateOne(
          { _id: item._id },
          {
            $set: {
              cursor,
              lastSyncedAt: new Date(),
              updatedAt: new Date(),
            },
          }
        );

        // Fetch updated account balances
        const balancesResponse = await plaidClient.accountsGet({
          access_token: accessToken,
        });

        for (const acc of balancesResponse.data.accounts) {
          await db.collection('accounts').updateOne(
            { accountId: acc.account_id },
            {
              $set: {
                currentBalance: acc.balances.current || 0,
                availableBalance: acc.balances.available || undefined,
                lastUpdatedAt: new Date(),
              },
            }
          );

          updatedAccounts.push({
            accountId: acc.account_id,
            name: acc.name,
            currentBalance: acc.balances.current,
            availableBalance: acc.balances.available,
          });
        }

        syncLog.completedAt = new Date();
        await db.collection('sync_logs').insertOne(syncLog);
      } catch (error: any) {
        console.error(`Error syncing item ${item._id}:`, error);
        syncLog.status = 'failed';
        syncLog.errorDetails = error.message;
        syncLog.completedAt = new Date();
        await db.collection('sync_logs').insertOne(syncLog);

        // Mark item as needing reauth if appropriate
        if (error.response?.data?.error_code === 'ITEM_LOGIN_REQUIRED') {
          await db.collection('plaid_items').updateOne(
            { _id: item._id },
            { $set: { status: 'needs_reauth', updatedAt: new Date() } }
          );
        }
      }
    }

    return NextResponse.json({
      success: true,
      added: totalAdded,
      modified: totalModified,
      removed: totalRemoved,
      accounts: updatedAccounts,
    });
  } catch (error: any) {
    console.error('Error syncing transactions:', error);
    return NextResponse.json(
      { error: error.message || 'Failed to sync transactions' },
      { status: 500 }
    );
  }
}
