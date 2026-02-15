"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import { motion, AnimatePresence } from "framer-motion";
import { Menu, X, Rocket } from "lucide-react";
import { Button } from "@/components/ui/Button";
import { cn } from "@/lib/utils";

export function Navbar() {
    const [isScrolled, setIsScrolled] = useState(false);
    const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);

    useEffect(() => {
        const handleScroll = () => {
            setIsScrolled(window.scrollY > 20);
        };
        window.addEventListener("scroll", handleScroll);
        return () => window.removeEventListener("scroll", handleScroll);
    }, []);

    return (
        <nav
            className={cn(
                "fixed top-0 left-0 right-0 z-50 transition-all duration-500 px-6 py-4",
                isScrolled ? "glass m-4 rounded-3xl" : "bg-transparent"
            )}
        >
            <div className="max-w-7xl mx-auto flex items-center justify-between">
                <Link href="/" className="flex items-center gap-2 group">
                    <div className="w-10 h-10 bg-primary rounded-xl flex items-center justify-center group-hover:rotate-12 transition-transform">
                        <Rocket className="text-white w-6 h-6" />
                    </div>
                    <span className="text-2xl font-black tracking-tight text-foreground">
                        VOXEL
                    </span>
                </Link>

                {/* Desktop Menu */}
                <div className="hidden md:flex items-center gap-8">
                    <Link href="#features" className="text-foreground/70 hover:text-primary transition-colors font-medium text-sm">Features</Link>
                    <Link href="#events" className="text-foreground/70 hover:text-primary transition-colors font-medium text-sm">Discover</Link>
                    <Link href="#pricing" className="text-foreground/70 hover:text-primary transition-colors font-medium text-sm">Pricing</Link>
                    <div className="flex items-center gap-3">
                        <Link href="/auth/signin">
                            <Button variant="ghost" size="sm">Sign In</Button>
                        </Link>
                        <Link href="/auth/signup">
                            <Button size="sm">Sign Up</Button>
                        </Link>
                    </div>
                </div>

                {/* Mobile Toggle */}
                <button
                    className="md:hidden text-foreground p-2"
                    onClick={() => setIsMobileMenuOpen(!isMobileMenuOpen)}
                >
                    {isMobileMenuOpen ? <X /> : <Menu />}
                </button>
            </div>

            {/* Mobile Menu */}
            <AnimatePresence>
                {isMobileMenuOpen && (
                    <motion.div
                        initial={{ opacity: 0, y: -20 }}
                        animate={{ opacity: 1, y: 0 }}
                        exit={{ opacity: 0, y: -20 }}
                        className="absolute top-full left-0 right-0 mt-2 p-4 md:hidden"
                    >
                        <div className="glass rounded-3xl p-6 flex flex-col gap-4 shadow-xl">
                            <Link href="#features" onClick={() => setIsMobileMenuOpen(false)} className="text-lg font-medium p-2">Features</Link>
                            <Link href="#events" onClick={() => setIsMobileMenuOpen(false)} className="text-lg font-medium p-2">Discover</Link>
                            <Link href="#pricing" onClick={() => setIsMobileMenuOpen(false)} className="text-lg font-medium p-2">Pricing</Link>
                            <hr className="border-foreground/10" />
                            <Link href="/auth/signin" className="w-full">
                                <Button variant="ghost" className="w-full">Sign In</Button>
                            </Link>
                            <Link href="/auth/signup" className="w-full">
                                <Button className="w-full">Sign Up</Button>
                            </Link>
                        </div>
                    </motion.div>
                )}
            </AnimatePresence>
        </nav>
    );
}
