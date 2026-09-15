import { Metadata } from "next";
import { Header, Footer, Container } from "@/components/layout";

export const metadata: Metadata = {
  title: "Privacy Policy",
  description: "How Symbians collects, uses, and protects your data.",
};

export default function PrivacyPage() {
  return (
    <>
      <Header />
      <main className="flex-1 pt-24 pb-16">
        <Container size="md">
          <article className="prose prose-invert max-w-none">
            <h1 className="text-4xl font-bold text-text mb-2">Privacy Policy</h1>
            <p className="text-text-muted mb-8">Last updated: April 15, 2026</p>

            <div className="space-y-8 text-text-secondary">
              <section>
                <h2 className="text-2xl font-semibold text-text mb-4">1. Introduction</h2>
                <p>
                  Symbians ("we", "our", "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, and safeguard your information when you use our platform.
                </p>
              </section>

              <section>
                <h2 className="text-2xl font-semibold text-text mb-4">2. Information We Collect</h2>
                
                <h3 className="text-xl font-medium text-text mt-4 mb-2">Wallet Information</h3>
                <p>
                  When you connect your Solana wallet, we collect your public wallet address. This is necessary to identify you on the platform and process blockchain transactions. We never have access to your private keys.
                </p>

                <h3 className="text-xl font-medium text-text mt-4 mb-2">Email (Optional)</h3>
                <p>
                  If you join our waitlist or contact support, we collect your email address. This is used solely for communication purposes and is never sold to third parties.
                </p>

                <h3 className="text-xl font-medium text-text mt-4 mb-2">Usage Data</h3>
                <p>
                  We automatically collect certain information about how you interact with the Platform, including:
                </p>
                <ul className="list-disc list-inside mt-2 space-y-1">
                  <li>Pages visited and features used</li>
                  <li>Device type and browser information</li>
                  <li>IP address (anonymized for analytics)</li>
                  <li>Referral sources</li>
                </ul>

                <h3 className="text-xl font-medium text-text mt-4 mb-2">Blockchain Data</h3>
                <p>
                  All blockchain transactions are public by nature. This includes your wallet address, transaction history, NFT ownership, and wager activity. This data is stored on the Solana blockchain and is not controlled by us.
                </p>
              </section>

              <section>
                <h2 className="text-2xl font-semibold text-text mb-4">3. How We Use Your Information</h2>
                <p>We use collected information to:</p>
                <ul className="list-disc list-inside mt-2 space-y-1">
                  <li>Provide and improve the Platform</li>
                  <li>Process transactions and manage your account</li>
                  <li>Send important updates (if you've provided an email)</li>
                  <li>Respond to support requests</li>
                  <li>Analyze usage patterns to improve user experience</li>
                  <li>Detect and prevent fraud or abuse</li>
                  <li>Comply with legal obligations</li>
                </ul>
              </section>

              <section>
                <h2 className="text-2xl font-semibold text-text mb-4">4. Third-Party Services</h2>
                <p>We use the following third-party services:</p>
                <ul className="list-disc list-inside mt-2 space-y-1">
                  <li><strong className="text-text">Solana Blockchain:</strong> For NFT minting, ownership, and transactions</li>
                  <li><strong className="text-text">Wallet Providers:</strong> Phantom, Solflare, and other Solana wallets for authentication</li>
                  <li><strong className="text-text">Analytics:</strong> Vercel Analytics and PostHog for anonymized usage data</li>
                  <li><strong className="text-text">Email:</strong> Resend for transactional emails</li>
                  <li><strong className="text-text">Hosting:</strong> Vercel for platform hosting</li>
                </ul>
                <p className="mt-2">
                  Each of these services has their own privacy policies. We encourage you to review them.
                </p>
              </section>

              <section>
                <h2 className="text-2xl font-semibold text-text mb-4">5. Data Retention</h2>
                <p>
                  We retain your data for as long as your account is active or as needed to provide services. If you request account deletion, we will remove your email and off-chain data within 30 days. Blockchain data cannot be deleted due to the immutable nature of the technology.
                </p>
              </section>

              <section>
                <h2 className="text-2xl font-semibold text-text mb-4">6. Data Security</h2>
                <p>
                  We implement industry-standard security measures to protect your information:
                </p>
                <ul className="list-disc list-inside mt-2 space-y-1">
                  <li>Encrypted connections (HTTPS) for all communications</li>
                  <li>Secure database storage with access controls</li>
                  <li>Regular security audits and updates</li>
                  <li>No storage of private keys or wallet passwords</li>
                </ul>
                <p className="mt-2">
                  However, no system is 100% secure. You are responsible for maintaining the security of your wallet and credentials.
                </p>
              </section>

              <section>
                <h2 className="text-2xl font-semibold text-text mb-4">7. Your Rights</h2>
                <p>Depending on your jurisdiction, you may have the right to:</p>
                <ul className="list-disc list-inside mt-2 space-y-1">
                  <li>Access the personal data we hold about you</li>
                  <li>Request correction of inaccurate data</li>
                  <li>Request deletion of your data (where applicable)</li>
                  <li>Object to certain processing of your data</li>
                  <li>Export your data in a portable format</li>
                </ul>
                <p className="mt-2">
                  To exercise these rights, contact us at{" "}
                  <a href="mailto:privacy@symbians.app" className="text-primary hover:underline">
                    privacy@symbians.app
                  </a>
                  .
                </p>
              </section>

              <section>
                <h2 className="text-2xl font-semibold text-text mb-4">8. Cookies</h2>
                <p>
                  We use essential cookies to maintain your session and preferences. Analytics cookies are used to understand how visitors interact with the Platform. You can control cookie settings in your browser.
                </p>
              </section>

              <section>
                <h2 className="text-2xl font-semibold text-text mb-4">9. Children's Privacy</h2>
                <p>
                  The Platform is not intended for users under 18 years of age. We do not knowingly collect information from children. If we discover that a child has provided us with personal information, we will delete it.
                </p>
              </section>

              <section>
                <h2 className="text-2xl font-semibold text-text mb-4">10. International Transfers</h2>
                <p>
                  Your information may be transferred to and processed in countries other than your own. By using the Platform, you consent to such transfers. We ensure appropriate safeguards are in place for international data transfers.
                </p>
              </section>

              <section>
                <h2 className="text-2xl font-semibold text-text mb-4">11. Changes to This Policy</h2>
                <p>
                  We may update this Privacy Policy from time to time. Changes will be posted on this page with an updated date. Significant changes will be communicated via email (if provided) or platform notification.
                </p>
              </section>

              <section>
                <h2 className="text-2xl font-semibold text-text mb-4">12. Contact Us</h2>
                <p>
                  If you have questions about this Privacy Policy or our data practices, contact us at:
                </p>
                <ul className="list-none mt-2 space-y-1">
                  <li>
                    Email:{" "}
                    <a href="mailto:privacy@symbians.app" className="text-primary hover:underline">
                      privacy@symbians.app
                    </a>
                  </li>
                  <li>X: @symbians_sol</li>
                  <li>Discord: discord.gg/symbians</li>
                </ul>
              </section>
            </div>
          </article>
        </Container>
      </main>
      <Footer />
    </>
  );
}
