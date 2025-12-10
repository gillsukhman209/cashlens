import { ObjectId } from 'mongodb';

export interface User {
  _id?: ObjectId;
  email: string;
  name: string;
  image?: string;
  provider: 'apple' | 'google';
  providerId: string;
  createdAt: Date;
  updatedAt: Date;
  settings: {
    currency: string;
    notifications: boolean;
  };
}

export interface PlaidItem {
  _id?: ObjectId;
  userId: ObjectId;
  accessToken: string; // Encrypted
  itemId: string;
  institutionId: string;
  institutionName: string;
  institutionLogo?: string;
  institutionColor?: string;
  cursor?: string; // For transaction sync pagination
  status: 'active' | 'needs_reauth' | 'disconnected';
  lastSyncedAt?: Date;
  createdAt: Date;
  updatedAt: Date;
  error?: {
    code: string;
    message: string;
    occurredAt: Date;
  };
}

export interface Account {
  _id?: ObjectId;
  userId: ObjectId;
  plaidItemId: ObjectId;
  accountId: string; // Plaid account_id
  name: string;
  officialName?: string;
  type: string; // depository, credit, loan, investment
  subtype?: string; // checking, savings, credit card, etc.
  mask?: string; // Last 4 digits
  currentBalance: number;
  availableBalance?: number;
  creditLimit?: number;
  isoCurrencyCode: string;
  isHidden: boolean;
  lastUpdatedAt: Date;
  createdAt: Date;
}

export interface Transaction {
  _id?: ObjectId;
  userId: ObjectId;
  accountId: ObjectId;
  plaidTransactionId: string;
  amount: number; // Positive = outflow, Negative = inflow
  isoCurrencyCode: string;
  date: Date;
  authorizedDate?: Date;
  name: string;
  merchantName?: string;
  category?: string[];
  primaryCategory?: string;
  detailedCategory?: string;
  personalFinanceCategory?: {
    primary: string;
    detailed: string;
    confidenceLevel?: string | null;
  };
  pending: boolean;
  paymentChannel?: string; // online, in store, other
  location?: {
    address?: string;
    city?: string;
    region?: string;
    postalCode?: string;
    country?: string;
    lat?: number;
    lon?: number;
  };
  logoUrl?: string;
  website?: string;
  // User customizations
  userCategory?: string;
  userNote?: string;
  isExcluded: boolean;
  createdAt: Date;
  updatedAt: Date;
}

export interface SyncLog {
  _id?: ObjectId;
  userId: ObjectId;
  plaidItemId: ObjectId;
  syncType: 'initial' | 'incremental' | 'historical';
  status: 'success' | 'partial' | 'failed';
  transactionsAdded: number;
  transactionsModified: number;
  transactionsRemoved: number;
  errorDetails?: string;
  startedAt: Date;
  completedAt?: Date;
}
