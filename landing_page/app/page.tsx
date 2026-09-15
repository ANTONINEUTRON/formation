import { Header, Footer } from "@/components/layout";
import { Hero, HowItWorks, Features, WhyNow, WaitlistCTA } from "@/components/sections";

export default function Home() {
  return (
    <>
      <Header />
      <main className="flex-1">
        <Hero />
        <Features />
        <WhyNow />
        <HowItWorks />
        <WaitlistCTA />
      </main>
      <Footer />
    </>
  );
}
