import { Container } from "../layout/Container";
import { Card, CardContent } from "../ui/Card";

const features = [
  {
    title: "Plain English",
    description:
      "Just tell your agent what to do. No coding required. \"Buy SOL on 5% dips\" is all you need.",
    icon: "💬",
  },
  {
    title: "Auto-Trade",
    description:
      "Agent executes swaps, limit orders, and perps while you sleep. 24/7 market coverage.",
    icon: "⚡",
  },
  {
    title: "Daily Reports",
    description:
      "Get push notifications with PnL, insights, and strategy suggestions. Stay informed, not glued.",
    icon: "📊",
  },
  {
    title: "Leverage Trading",
    description:
      "Long or short with up to 10x via Jupiter Perps. Set take-profit and stop-loss automatically.",
    icon: "📈",
  },
  {
    title: "Predictions",
    description:
      "Let your agent bet on prediction markets based on your thesis. Research-backed positions.",
    icon: "🎯",
  },
  {
    title: "Your Keys",
    description:
      "Non-custodial. You approve trades via mobile wallet. Agent orchestrates, you control.",
    icon: "🔒",
  },
];

export function Features() {
  return (
    <section className="py-20 md:py-32">
      <Container>
        <div className="text-center mb-16">
          <h2 className="text-3xl md:text-4xl font-bold text-text">
            Features
          </h2>
          <p className="mt-4 text-text-secondary max-w-2xl mx-auto">
            Everything you need to automate your trading strategy on Solana
          </p>
        </div>

        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
          {features.map((feature) => (
            <Card key={feature.title} hover className="text-center">
              <CardContent>
                <div className="inline-flex items-center justify-center w-14 h-14 rounded-lg bg-primary/10 text-3xl mb-4">
                  {feature.icon}
                </div>
                <h3 className="text-xl font-semibold text-text mb-2">
                  {feature.title}
                </h3>
                <p className="text-text-secondary">{feature.description}</p>
              </CardContent>
            </Card>
          ))}
        </div>
      </Container>
    </section>
  );
}
