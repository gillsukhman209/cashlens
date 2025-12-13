import { NextRequest, NextResponse } from 'next/server';
import { ObjectId } from 'mongodb';
import { plaidClient, decryptToken } from '@/lib/plaid';
import { getDatabase } from '@/lib/mongodb';
import { Transaction, SyncLog } from '@/types/models';
import { RemovedTransaction, TransactionsSyncRequest } from 'plaid';

// Plaid webhook types
type WebhookType = 'TRANSACTIONS' | 'ITEM' | 'ASSETS' | 'LIABILITIES';
type TransactionsWebhookCode =
  | 'INITIAL_UPDATE'
  | 'HISTORICAL_UPDATE'
  | 'DEFAULT_UPDATE'
  | 'TRANSACTIONS_REMOVED'
  | 'SYNC_UPDATES_AVAILABLE';
type ItemWebhookCode =
  | 'ERROR'
  | 'NEW_ACCOUNTS_AVAILABLE'
  | 'PENDING_EXPIRATION'
  | 'USER_PERMISSION_REVOKED'
  | 'WEBHOOK_UPDATE_ACKNOWLEDGED';

interface PlaidWebhookPayload {
  webhook_type: WebhookType;
  webhook_code: TransactionsWebhookCode | ItemWebhookCode;
  item_id: string;
  error?: {
    error_code: string;
    error_message: string;
  };
  new_transactions?: number;
  removed_transactions?: string[];
}

export async function POST(request: NextRequest) {
  try {
    const payload: PlaidWebhookPayload = await request.json();

    console.log('[Webhook] Received:', {
      type: payload.webhook_type,
      code: payload.webhook_code,
      itemId: payload.item_id,
    });

    const db = await getDatabase();

    // Find the Plaid item by itemId
    const plaidItem = await db.collection('plaid_items').findOne({
      itemId: payload.item_id,
    });

    if (!plaidItem) {
      console.log('[Webhook] Item not found:', payload.item_id);
      // Return 200 to acknowledge receipt (Plaid will retry on non-200)
      return NextResponse.json({ received: true, status: 'item_not_found' });
    }

    // Handle different webhook types
    switch (payload.webhook_type) {
      case 'TRANSACTIONS':
        await handleTransactionsWebhook(db, plaidItem, payload);
        break;

      case 'ITEM':
        await handleItemWebhook(db, plaidItem, payload);
        break;

      default:
        console.log('[Webhook] Unhandled webhook type:', payload.webhook_type);
    }

    return NextResponse.json({ received: true, status: 'processed' });
  } catch (error: any) {
    console.error('[Webhook] Error processing webhook:', error);
    // Return 200 anyway to prevent Plaid from retrying indefinitely
    return NextResponse.json({ received: true, status: 'error', error: error.message });
  }
}

async function handleTransactionsWebhook(
  db: any,
  plaidItem: any,
  payload: PlaidWebhookPayload
) {
  const code = payload.webhook_code as TransactionsWebhookCode;

  switch (code) {
    case 'SYNC_UPDATES_AVAILABLE':
    case 'DEFAULT_UPDATE':
    case 'INITIAL_UPDATE':
    case 'HISTORICAL_UPDATE':
      // New transactions available - sync them
      console.log(`[Webhook] ${code}: Syncing transactions for item ${plaidItem._id}`);
      await syncTransactionsForItem(db, plaidItem);
      break;

    case 'TRANSACTIONS_REMOVED':
      // Transactions were removed - sync to update
      console.log('[Webhook] Transactions removed, syncing...');
      await syncTransactionsForItem(db, plaidItem);
      break;

    default:
      console.log('[Webhook] Unhandled transactions webhook code:', code);
  }
}

async function handleItemWebhook(
  db: any,
  plaidItem: any,
  payload: PlaidWebhookPayload
) {
  const code = payload.webhook_code as ItemWebhookCode;

  switch (code) {
    case 'ERROR':
      // Item has an error - update status
      console.log('[Webhook] Item error:', payload.error);
      await db.collection('plaid_items').updateOne(
        { _id: plaidItem._id },
        {
          $set: {
            status: 'needs_reauth',
            error: {
              code: payload.error?.error_code,
              message: payload.error?.error_message,
              occurredAt: new Date(),
            },
            updatedAt: new Date(),
          },
        }
      );
      break;

    case 'PENDING_EXPIRATION':
      // Consent is about to expire
      console.log('[Webhook] Item pending expiration');
      await db.collection('plaid_items').updateOne(
        { _id: plaidItem._id },
        {
          $set: {
            status: 'needs_reauth',
            updatedAt: new Date(),
          },
        }
      );
      break;

    case 'USER_PERMISSION_REVOKED':
      // User revoked access
      console.log('[Webhook] User permission revoked');
      await db.collection('plaid_items').updateOne(
        { _id: plaidItem._id },
        {
          $set: {
            status: 'disconnected',
            updatedAt: new Date(),
          },
        }
      );
      break;

    default:
      console.log('[Webhook] Unhandled item webhook code:', code);
  }
}

async function syncTransactionsForItem(db: any, item: any) {
  const accessToken = decryptToken(item.accessToken);
  let cursor = item.cursor || undefined;
  let hasMore = true;

  const syncLog: SyncLog = {
    userId: item.userId,
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
        const accountIds = [...new Set(added.map((t) => t.account_id))];
        const accounts = await db
          .collection('accounts')
          .find({ accountId: { $in: accountIds } })
          .toArray();
        const accountMap = new Map(accounts.map((a: any) => [a.accountId, a._id]));

        const transactions = added.map((t) => ({
          userId: item.userId,
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
      }

      // Process removed transactions
      if (removed.length > 0) {
        const removedIds = removed.map((r: RemovedTransaction) => r.transaction_id);
        await db.collection('transactions').deleteMany({
          plaidTransactionId: { $in: removedIds },
        });
        syncLog.transactionsRemoved += removed.length;
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
    }

    syncLog.completedAt = new Date();
    await db.collection('sync_logs').insertOne(syncLog);

    console.log(`[Webhook] Sync complete: +${syncLog.transactionsAdded} ~${syncLog.transactionsModified} -${syncLog.transactionsRemoved}`);
  } catch (error: any) {
    console.error(`[Webhook] Error syncing item ${item._id}:`, error);
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
