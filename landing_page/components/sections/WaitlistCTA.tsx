import { Container } from "../layout/Container";
import { Button } from "../ui/Button";

const WAITLIST_FORM_URL = "https://forms.gle/eZYFLTdifqEfZd7aA";

export function WaitlistCTA() {
  return (
    <section className="py-20 md:py-32 bg-surface/50">
      <Container size="md">
        <div className="text-center">
          <p className="text-sm font-medium text-primary mb-4 tracking-wide uppercase">
            Early Access
          </p>
          <h2 className="text-3xl md:text-4xl font-bold text-text">
            Join Traders on the Waitlist
          </h2>
          <p className="mt-4 text-text-secondary max-w-xl mx-auto">
            Be first to automate your Solana trading with AI. Get early access when we launch.
          </p>

          <div className="mt-8 flex flex-col sm:flex-row items-center justify-center gap-4">
            <a
              href={WAITLIST_FORM_URL}
              target="_blank"
              rel="noopener noreferrer"
            >
              <Button size="lg">
                Join the Waitlist
                <svg
                  className="w-5 h-5"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M13 7l5 5m0 0l-5 5m5-5H6"
                  />
                </svg>
              </Button>
            </a>
          </div>
        </div>
      </Container>
    </section>
  );
}
