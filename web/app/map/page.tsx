"use client";

import dynamic from "next/dynamic";
import { Navbar } from "@/components/landing/Navbar";
import { ArrowLeft, Map as MapIcon, Layers, Navigation } from "lucide-react";
import Link from "next/link";
import { useState } from "react";
import { Button } from "@/components/ui/Button";
import { useWebSocket } from "@/app/providers";

// Import Map component dynamically to avoid SSR issues with Leaflet
const MapView = dynamic(() => import("@/components/map/MapView"), {
    ssr: false,
    loading: () => <div className="w-full h-full bg-slate-100 animate-pulse flex items-center justify-center text-foreground/20 font-bold">Initializing Map...</div>,
});

export default function MapPage() {
    const { events, userPositions, isConnected } = useWebSocket();

    // Calculate active count (users + events)
    const activeCount = events.length + Object.keys(userPositions).length;

    return (
        <main className="h-screen w-screen overflow-hidden flex flex-col relative">
            <div className="absolute top-6 left-6 z-10 flex items-center gap-4">
                <Link href="/discover">
                    <Button variant="glass" className="h-12 w-12 rounded-2xl p-0">
                        <ArrowLeft className="w-5 h-5" />
                    </Button>
                </Link>
                <div className="glass px-6 h-12 rounded-2xl flex items-center gap-3">
                    <MapIcon className="w-5 h-5 text-primary" />
                    <span className="font-black tracking-tight text-sm uppercase">World View</span>
                    {isConnected && <div className="w-2 h-2 rounded-full bg-green-500 animate-pulse" />}
                </div>
            </div>

            <div className="absolute top-6 right-6 z-10 flex flex-col gap-3">
                <Button variant="glass" className="h-12 w-12 rounded-2xl p-0">
                    <Layers className="w-5 h-5" />
                </Button>
                <Button variant="glass" className="h-12 w-12 rounded-2xl p-0">
                    <Navigation className="w-5 h-5" />
                </Button>
            </div>

            <div className="flex-1 w-full relative">
                <MapView center={[-1.286389, 36.817223]} zoom={14} />
            </div>

            <div className="absolute bottom-10 left-1/2 -translate-x-1/2 z-10 w-full max-w-sm px-6">
                <div className="glass p-6 rounded-[40px] shadow-2xl border border-black/5 animate-in slide-in-from-bottom duration-700">
                    <div className="flex items-center justify-between mb-4">
                        <h4 className="font-black text-lg tracking-tight">Around You</h4>
                        <span className="text-[10px] font-bold bg-primary/10 text-primary px-2 py-0.5 rounded-full uppercase">
                            {activeCount} Active
                        </span>
                    </div>
                    <p className="text-xs text-foreground/50 font-medium mb-6">
                        Explore {events.length} events and see {Object.keys(userPositions).length} people nearby.
                    </p>
                    <Button className="w-full rounded-2xl h-12">Search in this Area</Button>
                </div>
            </div>
        </main>
    );
}
