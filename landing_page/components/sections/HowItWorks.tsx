import { Container } from "../layout/Container";

const steps = [
  {
    number: "1",
    title: "Connect Wallet",
    description: "Link Phantom or Solflare. Deep link for seamless mobile experience.",
    icon: (
      <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M21 12a2.25 2.25 0 00-2.25-2.25H15a3 3 0 11-6 0H5.25A2.25 2.25 0 003 12m18 0v6a2.25 2.25 0 01-2.25 2.25H5.25A2.25 2.25 0 013 18v-6m18 0V9M3 12V9m18 0a2.25 2.25 0 00-2.25-2.25H5.25A2.25 2.25 0 003 9m18 0V6a2.25 2.25 0 00-2.25-2.25H5.25A2.25 2.25 0 003 6v3" />
      </svg>
    ),
  },
  {
    number: "2",
    title: "Create Your Agent",
    description: "Name it, set risk tolerance and autonomy level",
    icon: (
      <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9.75 3.104v5.714a2.25 2.25 0 01-.659 1.591L5 14.5M9.75 3.104c-.251.023-.501.05-.75.082m.75-.082a24.301 24.301 0 014.5 0m0 0v5.714c0 .597.237 1.17.659 1.591L19.8 15.3M14.25 3.104c.251.023.501.05.75.082M19.8 15.3l-1.57.393A9.065 9.065 0 0112 15a9.065 9.065 0 00-6.23.693L5 14.5m14.8.8l1.402 1.402c1.232 1.232.65 3.318-1.067 3.611A48.309 48.309 0 0112 21c-2.773 0-5.491-.235-8.135-.687-1.718-.293-2.3-2.379-1.067-3.61L5 14.5" />
      </svg>
    ),
  },
  {
    number: "3",
    title: "Set Your Strategy",
    description: "\"Buy SOL on 5% dips, $500 max, stop loss 3%\"",
    icon: (
      <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M7.5 8.25h9m-9 3H12m-9.75 1.51c0 1.6 1.123 2.994 2.707 3.227 1.129.166 2.27.293 3.423.379.35.026.67.21.865.501L12 21l2.755-4.133a1.14 1.14 0 01.865-.501 48.172 48.172 0 003.423-.379c1.584-.233 2.707-1.626 2.707-3.228V6.741c0-1.602-1.123-2.995-2.707-3.228A48.394 48.394 0 0012 3c-2.392 0-4.744.175-7.043.513C3.373 3.746 2.25 5.14 2.25 6.741v6.018z" />
      </svg>
    ),
  },
  {
    number: "4",
    title: "Watch It Work",
    description: "Push notifications for trades, daily PnL reports",
    icon: (
      <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75zM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V8.625zM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V4.125z" />
      </svg>
    ),
  },
];

export function HowItWorks() {
  return (
    <section className="py-20 md:py-32 bg-surface/50">
      <Container>
        <div className="text-center mb-16">
          <h2 className="text-3xl md:text-4xl font-bold text-text">
            How It Works
          </h2>
          <p className="mt-4 text-text-secondary max-w-2xl mx-auto">
            Four steps to deploy your AI trading agent
          </p>
        </div>

        {/* Desktop: Horizontal */}
        <div className="hidden md:flex items-start justify-between gap-4">
          {steps.map((step, index) => (
            <div key={step.number} className="flex-1 relative">
              {/* Connector line */}
              {index < steps.length - 1 && (
                <div className="absolute top-6 left-1/2 w-full h-px bg-border" />
              )}

              <div className="relative flex flex-col items-center text-center">
                {/* Number circle */}
                <div className="w-12 h-12 rounded-full bg-surface border-2 border-primary flex items-center justify-center text-primary font-bold z-10">
                  {step.number}
                </div>

                {/* Icon */}
                <div className="mt-4 text-text-secondary">{step.icon}</div>

                {/* Content */}
                <h3 className="mt-3 font-semibold text-text">{step.title}</h3>
                <p className="mt-1 text-sm text-text-muted max-w-[160px]">
                  {step.description}
                </p>
              </div>
            </div>
          ))}
        </div>

        {/* Mobile: Vertical */}
        <div className="md:hidden space-y-8">
          {steps.map((step, index) => (
            <div key={step.number} className="flex gap-4">
              {/* Number and line */}
              <div className="flex flex-col items-center">
                <div className="w-10 h-10 rounded-full bg-surface border-2 border-primary flex items-center justify-center text-primary font-bold">
                  {step.number}
                </div>
                {index < steps.length - 1 && (
                  <div className="w-px h-full min-h-[40px] bg-border mt-2" />
                )}
              </div>

              {/* Content */}
              <div className="pb-4">
                <div className="text-text-secondary mb-2">{step.icon}</div>
                <h3 className="font-semibold text-text">{step.title}</h3>
                <p className="text-sm text-text-muted">{step.description}</p>
              </div>
            </div>
          ))}
        </div>
      </Container>
    </section>
  );
}
