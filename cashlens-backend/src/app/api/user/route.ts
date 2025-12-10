import { NextRequest, NextResponse } from 'next/server';
import { ObjectId } from 'mongodb';
import { getDatabase } from '@/lib/mongodb';
import { User } from '@/types/models';

// GET - Get user by ID or email
export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const userId = searchParams.get('userId');
    const email = searchParams.get('email');

    if (!userId && !email) {
      return NextResponse.json(
        { error: 'userId or email is required' },
        { status: 400 }
      );
    }

    const db = await getDatabase();

    let user;
    if (userId) {
      user = await db.collection('users').findOne({ _id: new ObjectId(userId) });
    } else {
      user = await db.collection('users').findOne({ email });
    }

    if (!user) {
      return NextResponse.json(
        { error: 'User not found' },
        { status: 404 }
      );
    }

    return NextResponse.json({
      user: {
        id: user._id.toString(),
        email: user.email,
        name: user.name,
        image: user.image,
        provider: user.provider,
        createdAt: user.createdAt,
        settings: user.settings,
      },
    });
  } catch (error: any) {
    console.error('Error fetching user:', error);
    return NextResponse.json(
      { error: error.message || 'Failed to fetch user' },
      { status: 500 }
    );
  }
}

// POST - Create a new user (for testing, will be replaced by NextAuth)
export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { email, name, provider = 'apple', providerId } = body;

    if (!email || !name) {
      return NextResponse.json(
        { error: 'email and name are required' },
        { status: 400 }
      );
    }

    const db = await getDatabase();

    // Check if user exists
    const existingUser = await db.collection('users').findOne({ email });
    if (existingUser) {
      return NextResponse.json({
        user: {
          id: existingUser._id.toString(),
          email: existingUser.email,
          name: existingUser.name,
          image: existingUser.image,
          provider: existingUser.provider,
          createdAt: existingUser.createdAt,
          settings: existingUser.settings,
        },
        message: 'User already exists',
      });
    }

    const user: User = {
      email,
      name,
      provider,
      providerId: providerId || `test_${Date.now()}`,
      createdAt: new Date(),
      updatedAt: new Date(),
      settings: {
        currency: 'USD',
        notifications: true,
      },
    };

    const result = await db.collection('users').insertOne(user);

    return NextResponse.json({
      user: {
        id: result.insertedId.toString(),
        email: user.email,
        name: user.name,
        provider: user.provider,
        createdAt: user.createdAt,
        settings: user.settings,
      },
      message: 'User created successfully',
    });
  } catch (error: any) {
    console.error('Error creating user:', error);
    return NextResponse.json(
      { error: error.message || 'Failed to create user' },
      { status: 500 }
    );
  }
}
