import { NextRequest, NextResponse } from "next/server";

// In-memory store for demo purposes
// In production, use a proper database (Vercel Postgres, Supabase, etc.)
const waitlist: Map<string, {
  email: string;
  referralCode: string;
  referredBy?: string;
  referralCount: number;
  position: number;
  createdAt: Date;
}> = new Map();

function generateReferralCode(): string {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  let code = "";
  for (let i = 0; i < 8; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const { email, referredBy } = body;

    // Validate email
    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return NextResponse.json(
        { error: "Invalid email address" },
        { status: 400 }
      );
    }

    const normalizedEmail = email.toLowerCase().trim();

    // Check if already registered
    if (waitlist.has(normalizedEmail)) {
      const existing = waitlist.get(normalizedEmail)!;
      return NextResponse.json(
        { error: "Already registered", position: existing.position },
        { status: 409 }
      );
    }

    // Calculate position
    const position = waitlist.size + 1;

    // Generate referral code
    const referralCode = generateReferralCode();

    // Create entry
    const entry = {
      email: normalizedEmail,
      referralCode,
      referredBy: referredBy || undefined,
      referralCount: 0,
      position,
      createdAt: new Date(),
    };

    waitlist.set(normalizedEmail, entry);

    // Update referrer's count (in a real app, adjust their position too)
    if (referredBy) {
      for (const [, user] of waitlist) {
        if (user.referralCode === referredBy) {
          user.referralCount += 1;
          break;
        }
      }
    }

    // In production, send confirmation email here
    // await sendConfirmationEmail(email, referralCode);

    return NextResponse.json({
      position,
      referralCode,
      totalWaitlist: waitlist.size,
    });
  } catch (error) {
    console.error("Waitlist error:", error);
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    );
  }
}

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const code = searchParams.get("code");

  if (!code) {
    return NextResponse.json(
      { error: "Referral code required" },
      { status: 400 }
    );
  }

  for (const [, user] of waitlist) {
    if (user.referralCode === code) {
      return NextResponse.json({
        position: user.position,
        referralCount: user.referralCount,
      });
    }
  }

  return NextResponse.json(
    { error: "Code not found" },
    { status: 404 }
  );
}
