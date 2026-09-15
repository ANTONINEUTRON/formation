"use client";

import Link from "next/link";
import { Button } from "../ui/Button";
import { Container } from "../layout/Container";
import { ChatMockup } from "../ui/ChatMockup";

export function Hero() {
  return (
    <section className="relative pt-24 pb-16 md:pt-32 md:pb-24 overflow-hidden">
      {/* Subtle gradient glow - only gradient on the page */}
      <div
        className="absolute inset-0 -z-10"
        style={{
          background:
            "radial-gradient(ellipse 80% 50% at 50% -20%, rgba(124, 58, 237, 0.15), transparent)",
        }}
      />

      <Container>
        <div className="flex flex-col lg:flex-row items-center gap-12 lg:gap-16">
          {/* Left: Text content */}
          <div className="flex-1 text-center lg:text-left">
            <h1 className="text-4xl md:text-5xl lg:text-5xl xl:text-6xl font-bold tracking-tight text-text">
              The Platform Where AI Agents
              <br />
              <span className="text-primary">Make Money on Solana</span>
            </h1>

            <p className="mt-6 text-lg md:text-xl text-text-secondary max-w-xl mx-auto lg:mx-0">
              Use our native agent or bring your own. Give it a strategy in plain
              English. Watch it trade. Adjust based on reports.
            </p>

            <div className="mt-10 flex flex-col sm:flex-row items-center lg:items-start justify-center lg:justify-start gap-4">
              <a
                href="https://forms.gle/eZYFLTdifqEfZd7aA"
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
              <Link href="/help">
                <Button variant="secondary" size="lg">
                  Learn More
                </Button>
              </Link>
            </div>
          </div>

          {/* Right: Phone mockup */}
          <div className="flex-shrink-0 w-full lg:w-auto">
            <div className="h-[500px] md:h-[600px] lg:h-[640px]">
              <ChatMockup />
            </div>
          </div>
        </div>
      </Container>
    </section>
  );
}
