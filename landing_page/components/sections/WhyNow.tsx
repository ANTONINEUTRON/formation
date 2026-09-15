import { Container } from "../layout/Container";

const securityFeatures = [
  {
    icon: "🔑",
    title: "Non-Custodial",
    description:
      "Your wallet holds your funds. Always. We never have access to your private keys.",
  },
  {
    icon: "✅",
    title: "You Approve Every Trade",
    description:
      "Each transaction requires your signature via mobile wallet. Or set autonomy limits you control.",
  },
  {
    icon: "🔐",
    title: "No Private Keys Shared",
    description:
      "Agent requests signatures via deep link to Phantom/Solflare. Your keys never leave your device.",
  },
  {
    icon: "⚡",
    title: "Built on Battle-Tested Infra",
    description:
      "Jupiter for swaps and perps, Drift for predictions. The most trusted DeFi protocols on Solana.",
  },
];

export function WhyNow() {
  return (
    <section className="py-20 md:py-32">
      <Container>
        <div className="text-center mb-16">
          <p className="text-sm font-medium text-primary mb-4 tracking-wide uppercase">
            Security First
          </p>
          <h2 className="text-3xl md:text-4xl font-bold text-text max-w-3xl mx-auto">
            Your Keys, Your Crypto, Your Control
          </h2>
          <p className="mt-4 text-text-secondary max-w-2xl mx-auto">
            Symbians is fully non-custodial. Your agent orchestrates trades — you approve them.
          </p>
        </div>

        <div className="grid md:grid-cols-2 gap-6">
          {securityFeatures.map((feature) => (
            <div
              key={feature.title}
              className="p-6 rounded-xl border border-border bg-surface"
            >
              <div className="flex items-start gap-4">
                <span className="text-3xl">{feature.icon}</span>
                <div>
                  <h3 className="text-lg font-semibold text-text mb-1">
                    {feature.title}
                  </h3>
                  <p className="text-text-secondary">{feature.description}</p>
                </div>
              </div>
            </div>
          ))}
        </div>

        {/* Powered by logos */}
        <div className="mt-16 text-center">
          <p className="text-sm text-text-muted mb-6">Powered by</p>
          <div className="flex items-center justify-center gap-8">
            <div className="flex items-center gap-2 text-text-secondary">
              <svg className="w-6 h-6" viewBox="0 0 24 24" fill="currentColor">
                <path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5" />
              </svg>
              <span className="font-medium">Jupiter</span>
            </div>
            <span className="text-text-muted">•</span>
            <div className="flex items-center gap-2 text-text-secondary">
              <svg className="w-6 h-6" viewBox="0 0 24 24" fill="currentColor">
                <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 17.93c-3.95-.49-7-3.85-7-7.93 0-.62.08-1.21.21-1.79L9 15v1c0 1.1.9 2 2 2v1.93zm6.9-2.54c-.26-.81-1-1.39-1.9-1.39h-1v-3c0-.55-.45-1-1-1H8v-2h2c.55 0 1-.45 1-1V7h2c1.1 0 2-.9 2-2v-.41c2.93 1.19 5 4.06 5 7.41 0 2.08-.8 3.97-2.1 5.39z" />
              </svg>
              <span className="font-medium">Solana</span>
            </div>
          </div>
        </div>
      </Container>
    </section>
  );
}
