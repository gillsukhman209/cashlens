import { NextRequest, NextResponse } from 'next/server';
import { ObjectId } from 'mongodb';
import { plaidClient, encryptToken } from '@/lib/plaid';
import { getDatabase } from '@/lib/mongodb';
import { PlaidItem, Account } from '@/types/models';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { publicToken, userId, institutionId, institutionName } = body;

    if (!publicToken || !userId) {
      return NextResponse.json(
        { error: 'publicToken and userId are required' },
        { status: 400 }
      );
    }

    // Exchange public token for access token
    const exchangeResponse = await plaidClient.itemPublicTokenExchange({
      public_token: publicToken,
    });

    const accessToken = exchangeResponse.data.access_token;
    const itemId = exchangeResponse.data.item_id;

    // Get institution details if not provided
    let instName = institutionName;
    let instId = institutionId;
    let instLogo: string | undefined;
    let instColor: string | undefined;

    if (institutionId) {
      try {
        const instResponse = await plaidClient.institutionsGetById({
          institution_id: institutionId,
          country_codes: ['US' as any],
          options: {
            include_optional_metadata: true,
          },
        });
        const inst = instResponse.data.institution;
        instName = inst.name;
        instLogo = inst.logo || undefined;
        instColor = inst.primary_color || undefined;
      } catch (e) {
        // Use provided name if institution lookup fails
      }
    }

    // Encrypt the access token before storing
    const encryptedToken = encryptToken(accessToken);

    const db = await getDatabase();
    const userObjectId = new ObjectId(userId);

    // Store the Plaid item
    const plaidItem: PlaidItem = {
      userId: userObjectId,
      accessToken: encryptedToken,
      itemId,
      institutionId: instId || '',
      institutionName: instName || 'Unknown Bank',
      institutionLogo: instLogo,
      institutionColor: instColor,
      status: 'active',
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    const itemResult = await db.collection('plaid_items').insertOne(plaidItem);
    const plaidItemId = itemResult.insertedId;

    // Fetch accounts
    const accountsResponse = await plaidClient.accountsGet({
      access_token: accessToken,
    });

    const accounts: Account[] = accountsResponse.data.accounts.map((acc) => ({
      userId: userObjectId,
      plaidItemId,
      accountId: acc.account_id,
      name: acc.name,
      officialName: acc.official_name || undefined,
      type: acc.type,
      subtype: acc.subtype || undefined,
      mask: acc.mask || undefined,
      currentBalance: acc.balances.current || 0,
      availableBalance: acc.balances.available || undefined,
      creditLimit: acc.balances.limit || undefined,
      isoCurrencyCode: acc.balances.iso_currency_code || 'USD',
      isHidden: false,
      lastUpdatedAt: new Date(),
      createdAt: new Date(),
    }));

    // Insert accounts
    if (accounts.length > 0) {
      await db.collection('accounts').insertMany(accounts);
    }

    return NextResponse.json({
      success: true,
      itemId,
      plaidItemId: plaidItemId.toString(),
      accounts: accounts.map((acc) => ({
        id: acc.accountId,
        name: acc.name,
        type: acc.type,
        subtype: acc.subtype,
        mask: acc.mask,
        currentBalance: acc.currentBalance,
        availableBalance: acc.availableBalance,
      })),
      institution: {
        id: instId,
        name: instName,
        logo: instLogo,
        color: instColor,
      },
    });
  } catch (error: any) {
    console.error('Error exchanging token:', error);
    return NextResponse.json(
      { error: error.message || 'Failed to exchange token' },
      { status: 500 }
    );
  }
}
