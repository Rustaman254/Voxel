"use client";

import { motion } from "framer-motion";
import { Button } from "@/components/ui/Button";
import { Sparkles, Calendar, MapPin } from "lucide-react";
import Link from "next/link";

export function HeroSection() {
    return (
        <section className="relative min-h-screen flex items-center justify-center pt-20 overflow-hidden bg-background">
            {/* Background Blobs */}
            <div className="absolute top-0 left-0 w-full h-full -z-10">
                <motion.div
                    animate={{
                        scale: [1, 1.2, 1],
                        x: [0, 100, 0],
                        y: [0, -50, 0],
                    }}
                    transition={{ duration: 20, repeat: Infinity, ease: "linear" }}
                    className="absolute top-[-10%] left-[-10%] w-[50%] h-[50%] bg-primary/20 blur-[120px] rounded-full"
                />
                <motion.div
                    animate={{
                        scale: [1, 1.3, 1],
                        x: [0, -80, 0],
                        y: [0, 70, 0],
                    }}
                    transition={{ duration: 25, repeat: Infinity, ease: "linear" }}
                    className="absolute bottom-[-10%] right-[-10%] w-[60%] h-[60%] bg-secondary/20 blur-[120px] rounded-full"
                />
            </div>

            <div className="max-w-5xl mx-auto px-6 text-center">
                <motion.div
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ duration: 0.8 }}
                    className="inline-flex items-center gap-2 px-4 py-2 rounded-full glass border border-primary/20 mb-8"
                >
                    <Sparkles className="w-4 h-4 text-primary" />
                    <span className="text-sm font-semibold tracking-wide uppercase text-foreground/80">
                        Immersive Event Experiences
                    </span>
                </motion.div>

                <motion.h1
                    initial={{ opacity: 0, y: 30 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ duration: 0.8, delay: 0.2 }}
                    className="text-6xl md:text-8xl font-black tracking-tighter mb-8 leading-[0.9]"
                >
                    Beautiful events, <br />
                    <span className="gradient-text">made simple.</span>
                </motion.h1>

                <motion.p
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ duration: 0.8, delay: 0.4 }}
                    className="text-xl md:text-2xl text-foreground/60 max-w-2xl mx-auto mb-12 font-medium"
                >
                    Join 1M+ creators and organizations hosting unforgettable events.
                    From retreats to workshops, we've got you covered.
                </motion.p>

                <motion.div
                    initial={{ opacity: 0, scale: 0.9 }}
                    animate={{ opacity: 1, scale: 1 }}
                    transition={{ duration: 0.5, delay: 0.6 }}
                    className="flex flex-col sm:flex-row items-center justify-center gap-4"
                >
                    <Link href="/auth/signup">
                        <Button size="lg" className="px-10 h-16 text-lg">
                            Create an Event — it's free
                        </Button>
                    </Link>
                    <Link href="#events">
                        <Button variant="glass" size="lg" className="px-10 h-16 text-lg">
                            Explore Events
                        </Button>
                    </Link>
                </motion.div>

                {/* Feature Pills */}
                <motion.div
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    transition={{ duration: 1, delay: 1 }}
                    className="mt-20 flex flex-wrap justify-center gap-8 md:gap-16 opacity-40 hover:opacity-100 transition-opacity duration-500"
                >
                    <div className="flex items-center gap-3">
                        <Calendar className="w-6 h-6" />
                        <span className="font-bold uppercase tracking-widest text-xs">RSVP Tracking</span>
                    </div>
                    <div className="flex items-center gap-3">
                        <MapPin className="w-6 h-6" />
                        <span className="font-bold uppercase tracking-widest text-xs">Interactive Map</span>
                    </div>
                    <div className="flex items-center gap-3">
                        <Sparkles className="w-6 h-6" />
                        <span className="font-bold uppercase tracking-widest text-xs">Smart Invites</span>
                    </div>
                </motion.div>
            </div>
        </section>
    );
}
