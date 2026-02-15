"use client";

import { motion } from "framer-motion";
import { Button } from "@/components/ui/Button";
import Link from "next/link";
import { Rocket, Mail, Lock, ArrowLeft } from "lucide-react";
import { useState } from "react";
import { useRouter } from "next/navigation";

export default function SignInPage() {
    const router = useRouter();
    const [email, setEmail] = useState("");
    const [password, setPassword] = useState("");
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState("");

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setError("");
        setLoading(true);

        try {
            const response = await fetch("https://voxel-nxjg.onrender.com/api/auth/login", {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                },
                body: JSON.stringify({
                    email,
                    password,
                }),
            });

            const data = await response.json();

            if (!response.ok) {
                throw new Error(data.error || "Login failed");
            }

            // Store auth token
            localStorage.setItem("authToken", data.token);
            localStorage.setItem("userId", data.userId);

            // Redirect to discover page
            router.push("/discover");
        } catch (err: any) {
            setError(err.message || "An error occurred during login");
        } finally {
            setLoading(false);
        }
    };

    return (
        <main className="min-h-screen flex items-center justify-center bg-background p-6">
            <Link href="/" className="absolute top-8 left-8 flex items-center gap-2 text-foreground/60 hover:text-primary transition-colors">
                <ArrowLeft className="w-4 h-4" />
                <span className="font-medium">Back to Home</span>
            </Link>

            <motion.div
                initial={{ opacity: 0, scale: 0.95 }}
                animate={{ opacity: 1, scale: 1 }}
                className="w-full max-w-md"
            >
                <div className="text-center mb-8">
                    <div className="inline-flex items-center justify-center w-16 h-16 bg-primary rounded-3xl mb-6 shadow-luma">
                        <Rocket className="text-white w-8 h-8" />
                    </div>
                    <h1 className="text-3xl font-black tracking-tight mb-2">Welcome Back.</h1>
                    <p className="text-foreground/60">Enter your details to sign in.</p>
                </div>

                <div className="glass p-8 rounded-[40px] shadow-2xl border border-primary/10">
                    {error && (
                        <div className="mb-4 p-3 bg-red-500/10 border border-red-500/20 rounded-2xl text-red-500 text-sm text-center">
                            {error}
                        </div>
                    )}

                    <form className="space-y-6" onSubmit={handleSubmit}>
                        <div className="space-y-2">
                            <label className="text-sm font-bold tracking-wide uppercase text-foreground/50 ml-2">Email Address</label>
                            <div className="relative">
                                <Mail className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-foreground/30" />
                                <input
                                    type="email"
                                    placeholder="name@company.com"
                                    value={email}
                                    onChange={(e) => setEmail(e.target.value)}
                                    required
                                    className="w-full h-14 bg-foreground/5 border-none rounded-2xl pl-12 pr-4 focus:ring-2 focus:ring-primary transition-all font-medium"
                                />
                            </div>
                        </div>

                        <div className="space-y-2">
                            <div className="flex justify-between items-center ml-2">
                                <label className="text-sm font-bold tracking-wide uppercase text-foreground/50">Password</label>
                                <Link href="#" className="text-xs font-bold text-primary">Forgot?</Link>
                            </div>
                            <div className="relative">
                                <Lock className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-foreground/30" />
                                <input
                                    type="password"
                                    placeholder="••••••••"
                                    value={password}
                                    onChange={(e) => setPassword(e.target.value)}
                                    required
                                    className="w-full h-14 bg-foreground/5 border-none rounded-2xl pl-12 pr-4 focus:ring-2 focus:ring-primary transition-all font-medium"
                                />
                            </div>
                        </div>

                        <Button className="w-full h-14 text-lg" type="submit" disabled={loading}>
                            {loading ? "Signing In..." : "Sign In"}
                        </Button>
                    </form>

                    <div className="mt-8 text-center text-sm font-medium text-foreground/40">
                        Don't have an account?{" "}
                        <Link href="/auth/signup" className="text-primary font-bold">Sign Up</Link>
                    </div>
                </div>
            </motion.div>
        </main>
    );
}
