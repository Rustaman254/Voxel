"use client";

import { motion } from "framer-motion";
import { Navbar } from "@/components/landing/Navbar";
import { Button } from "@/components/ui/Button";
import { Search, Filter, Map as MapIcon, Grid, List as ListIcon, Calendar, MapPin, Users } from "lucide-react";
import Link from "next/link";
import { cn } from "@/lib/utils";
import { useWebSocket } from "@/app/providers";

export default function DiscoveryPage() {
    const { events, createEvent } = useWebSocket();

    const handleCreateEvent = () => {
        // Mock event creation for demo - using Nairobi coordinates
        const lat = -1.286389 + (Math.random() - 0.5) * 0.01;
        const lng = 36.817223 + (Math.random() - 0.5) * 0.01;

        createEvent({
            title: "New Voxel Event",
            description: "An amazing event created from the web!",
            x: lng, // X maps to longitude
            y: lat, // Y maps to latitude
            latitude: lat,
            longitude: lng,
            ticketPrice: 0,
            hasTickets: false,
            voxelTheme: "#B452FF",
            startTime: new Date().toISOString(),
        });
    };

    return (
        <main className="min-h-screen bg-background">
            <Navbar />

            <div className="pt-32 pb-20 max-w-7xl mx-auto px-6">
                <div className="flex flex-col md:flex-row md:items-end justify-between gap-8 mb-12">
                    <div>
                        <h1 className="text-5xl font-black tracking-tight mb-2">Discovery.</h1>
                        <p className="text-foreground/60 text-lg">Explore what's happening around you.</p>
                    </div>

                    <div className="flex items-center gap-3">
                        <Link href="/map">
                            <Button variant="glass" className="h-12 rounded-2xl gap-2">
                                <MapIcon className="w-5 h-5" />
                                <span>Map View</span>
                            </Button>
                        </Link>
                        <Button className="h-12 rounded-2xl gap-2" onClick={handleCreateEvent}>
                            <Calendar className="w-5 h-5" />
                            <span>Create Event</span>
                        </Button>
                    </div>
                </div>

                {/* Search & Filters */}
                <div className="flex flex-wrap items-center gap-4 mb-12">
                    <div className="flex-1 relative min-w-[300px]">
                        <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-foreground/30" />
                        <input
                            type="text"
                            placeholder="Search events, cities, creators..."
                            className="w-full h-14 glass border-none rounded-2xl pl-12 pr-4 focus:ring-2 focus:ring-primary transition-all font-medium"
                        />
                    </div>
                    <Button variant="glass" className="h-14 w-14 rounded-2xl p-0">
                        <Filter className="w-5 h-5" />
                    </Button>
                    <div className="flex bg-foreground/5 rounded-2xl p-1">
                        <button className="p-3 bg-white shadow-sm rounded-xl">
                            <Grid className="w-5 h-5" />
                        </button>
                        <button className="p-3 text-foreground/40">
                            <ListIcon className="w-5 h-5" />
                        </button>
                    </div>
                </div>

                {/* Category Pills */}
                <div className="flex gap-3 overflow-x-auto pb-4 no-scrollbar mb-12">
                    {["All", "Tech", "Design", "Business", "Community", "Music", "Social"].map((cat) => (
                        <button
                            key={cat}
                            className={cn(
                                "px-6 py-3 rounded-full font-bold text-sm transition-all whitespace-nowrap",
                                cat === "All" ? "bg-primary text-white" : "glass hover:bg-white/40"
                            )}
                        >
                            {cat}
                        </button>
                    ))}
                </div>

                {/* Event Grid */}
                {events.length === 0 ? (
                    <div className="text-center py-20 opacity-50">
                        <p>No events found. Create one!</p>
                    </div>
                ) : (
                    <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-8">
                        {events.map((event) => (
                            <motion.div
                                key={event.id}
                                whileHover={{ y: -8 }}
                                className="group glass p-6 rounded-[40px] border border-foreground/5 hover:border-primary/20 transition-all cursor-pointer"
                            >
                                <div className={cn("aspect-[4/3] rounded-[32px] mb-6 overflow-hidden bg-gradient-to-br shadow-inner shadow-black/5")} style={{
                                    background: `linear-gradient(135deg, ${event.voxelTheme}33, ${event.voxelTheme}11)`
                                }}>
                                    <div className="w-full h-full bg-white/10 flex items-center justify-center">
                                        <Calendar className="w-12 h-12 text-white/50" />
                                    </div>
                                </div>

                                <div className="flex items-start justify-between gap-4 mb-4">
                                    <div>
                                        <h3 className="text-2xl font-black tracking-tight group-hover:text-primary transition-colors">{event.title}</h3>
                                        <div className="flex items-center gap-2 text-foreground/50 mt-1 font-medium">
                                            <MapPin className="w-4 h-4" />
                                            <span className="text-sm">
                                                {event.latitude ? `${event.latitude.toFixed(2)}, ${event.longitude?.toFixed(2)}` : "Online"}
                                            </span>
                                        </div>
                                    </div>
                                    <div className="text-right">
                                        <span className="block text-primary font-black text-sm uppercase tracking-wider">
                                            {new Date(event.startTime).toLocaleDateString()}
                                        </span>
                                        <span className="text-xs font-bold text-foreground/40">
                                            {new Date(event.startTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                                        </span>
                                    </div>
                                </div>

                                <div className="flex items-center justify-between pt-4 border-t border-foreground/5">
                                    <div className="flex items-center gap-2">
                                        <div className="flex -space-x-3">
                                            {[1, 2, 3].map((j) => (
                                                <div key={j} className="w-8 h-8 rounded-full border-4 border-background bg-slate-200" />
                                            ))}
                                        </div>
                                        <span className="text-xs font-bold text-foreground/40">+12 going</span>
                                    </div>
                                    <Users className="w-5 h-5 text-foreground/20" />
                                </div>
                            </motion.div>
                        ))}
                    </div>
                )}
            </div>
        </main>
    );
}
