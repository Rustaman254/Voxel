import { Navbar } from "@/components/landing/Navbar";
import { HeroSection } from "@/components/landing/HeroSection";

export default function LandingPage() {
  return (
    <main className="min-h-screen relative">
      <Navbar />
      <HeroSection />

      {/* Target IDs for navigation */}
      <section id="features" className="py-20 bg-background/50">
        <div className="max-w-7xl mx-auto px-6">
          <h2 className="text-4xl font-bold mb-12 text-center">Engineered for experience.</h2>
          {/* Feature grid will go here */}
          <div className="grid md:grid-cols-3 gap-8">
            {[1, 2, 3].map((i) => (
              <div key={i} className="glass p-8 rounded-[40px] aspect-square flex flex-col justify-end">
                <div className="w-12 h-12 bg-primary/20 rounded-2xl mb-4" />
                <h3 className="text-2xl font-bold mb-2">Feature {i}</h3>
                <p className="text-foreground/60">Luma-inspired feature description with smooth glassmorphism effects.</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section id="events" className="py-20">
        <div className="max-w-7xl mx-auto px-6">
          <div className="flex justify-between items-end mb-12">
            <div>
              <h2 className="text-4xl font-bold mb-4">Discover upcoming events.</h2>
              <p className="text-foreground/60">Find what's happening in your local community.</p>
            </div>
          </div>
          {/* Event cards will go here */}
          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
            {[1, 2, 3].map((i) => (
              <div key={i} className="group relative glass p-4 rounded-[32px] overflow-hidden cursor-pointer hover:shadow-luma-hover transition-all">
                <div className="aspect-video bg-foreground/5 rounded-2xl mb-4 overflow-hidden">
                  <div className="w-full h-full bg-gradient-to-br from-primary/20 to-secondary/20 animate-pulse" />
                </div>
                <h3 className="text-xl font-bold mb-1">Epic Workshop {i}</h3>
                <p className="text-sm text-foreground/60 mb-4">San Francisco, CA</p>
                <div className="flex items-center justify-between">
                  <span className="text-xs font-bold uppercase tracking-wider text-primary">Feb 24, 2024</span>
                  <div className="flex -space-x-2">
                    {[1, 2, 3].map((j) => (
                      <div key={j} className="w-8 h-8 rounded-full border-2 border-background bg-foreground/10" />
                    ))}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      <footer className="py-12 border-t border-foreground/5">
        <div className="max-w-7xl mx-auto px-6 text-center text-foreground/40 text-sm font-medium">
          © {new Date().getFullYear()} Voxel (GameForge). Inspired by Luma.
        </div>
      </footer>
    </main>
  );
}
