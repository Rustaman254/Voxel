"use client";

import { MapContainer, TileLayer, Marker, Popup, useMap } from "react-leaflet";
import L from "leaflet";
import { useEffect, useState, useRef } from "react";
import { Avatar } from "@/components/ui/Avatar";
import { renderToStaticMarkup } from "react-dom/server";
import { Calendar, MapPin, Navigation, X, Locate } from "lucide-react";
import { cn } from "@/lib/utils";
import { useWebSocket } from "@/app/providers";
import { Button } from "@/components/ui/Button";
import { motion, AnimatePresence } from "framer-motion";

// Fix Leaflet icon issue
const DefaultIcon = L.icon({
    iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
    shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
    iconSize: [25, 41],
    iconAnchor: [12, 41],
});
L.Marker.prototype.options.icon = DefaultIcon;

interface MapViewProps {
    center: [number, number];
    zoom: number;
    markers?: any[]; // Keep for backward compatibility if needed, but we use hook now
}

export default function MapView({ center, zoom }: MapViewProps) {
    const [isMounted, setIsMounted] = useState(false);
    const { events, userPositions, updatePosition, userId, userProfile } = useWebSocket();
    const [myPosition, setMyPosition] = useState<[number, number] | null>(null);
    const [selectedItem, setSelectedItem] = useState<any | null>(null);
    const [locationError, setLocationError] = useState<string | null>(null);

    useEffect(() => {
        setIsMounted(true);

        if (!navigator.geolocation) {
            setLocationError("Geolocation is not supported by your browser");
            return;
        }

        // High Accuracy Tracking (Uber-like)
        const watchId = navigator.geolocation.watchPosition(
            (position) => {
                const { latitude, longitude } = position.coords;
                setMyPosition([latitude, longitude]);
                updatePosition(latitude, longitude);
                setLocationError(null);
            },
            (error) => {
                console.error("Location error:", error);
                if (error.code === 1) { // PERMISSION_DENIED
                    setLocationError("Please enable location services to use the map.");
                }
            },
            {
                enableHighAccuracy: true,
                timeout: 5000,
                maximumAge: 0
            }
        );

        return () => navigator.geolocation.clearWatch(watchId);
    }, [updatePosition]);

    if (!isMounted) return <div className="w-full h-full bg-slate-100 animate-pulse" />;

    const allMarkers = [
        // Events
        ...events.map(e => ({
            id: e.id,
            lat: e.latitude || e.y,
            lng: e.longitude || e.x,
            type: "event" as const,
            data: e
        })),
        // Users
        ...Object.values(userPositions).map(u => ({
            id: u.userId,
            lat: u.latitude || u.y,
            lng: u.longitude || u.x,
            type: "user" as const,
            data: {
                name: u.username || "Unknown",
                color: u.color || "#ccc",
                userId: u.userId,
                isMe: false
            }
        })),
        // Me
        ...(myPosition && userProfile ? [{
            id: "me",
            lat: myPosition[0],
            lng: myPosition[1],
            type: "user" as const,
            data: {
                name: userProfile.username,
                color: userProfile.color,
                userId: userId,
                isMe: true
            }
        }] : [])
    ];

    return (
        <div className="relative w-full h-full flex overflow-hidden">
            {/* Map Container */}
            <div className="flex-1 relative z-0">
                <MapContainer
                    center={myPosition || center}
                    zoom={zoom}
                    scrollWheelZoom={true}
                    className="w-full h-full"
                    zoomControl={false}
                >
                    <TileLayer
                        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
                        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
                    />

                    <MapController center={myPosition} selectedItem={selectedItem} />

                    {allMarkers.map((marker, i) => (
                        <CustomMarker
                            key={`${marker.type}-${marker.id}-${i}`}
                            marker={marker}
                            isMe={marker.type === 'user' && (marker.data as any).isMe}
                            onClick={() => setSelectedItem(marker)}
                        />
                    ))}
                </MapContainer>

                {/* Location Error Overlay */}
                {locationError && (
                    <div className="absolute top-4 left-1/2 -translate-x-1/2 z-[1000] bg-red-500 text-white px-4 py-2 rounded-full shadow-lg text-sm font-bold flex items-center gap-2">
                        <Locate className="w-4 h-4" />
                        {locationError}
                    </div>
                )}
            </div>

            {/* Airbnb-style Side Panel / Mobile Drawer */}
            <AnimatePresence>
                {selectedItem && (
                    <motion.div
                        initial={{ x: "100%", opacity: 0 }}
                        animate={{ x: 0, opacity: 1 }}
                        exit={{ x: "100%", opacity: 0 }}
                        transition={{ type: "spring", stiffness: 300, damping: 30 }}
                        className="absolute top-0 right-0 h-full w-full md:w-[400px] bg-background/80 backdrop-blur-xl border-l border-white/20 shadow-2xl z-[500] p-6 flex flex-col"
                    >
                        <button
                            onClick={() => setSelectedItem(null)}
                            className="absolute top-6 right-6 p-2 bg-foreground/5 hover:bg-foreground/10 rounded-full transition-colors"
                        >
                            <X className="w-5 h-5" />
                        </button>

                        <div className="mt-8 flex-1 overflow-y-auto no-scrollbar">
                            {selectedItem.type === "event" ? (
                                <div className="space-y-6">
                                    <div
                                        className="aspect-video rounded-3xl w-full bg-gradient-to-br shadow-inner flex items-center justify-center"
                                        style={{
                                            background: `linear-gradient(135deg, ${selectedItem.data.voxelTheme}66, ${selectedItem.data.voxelTheme}22)`
                                        }}
                                    >
                                        <Calendar className="w-16 h-16 text-white/60" />
                                    </div>

                                    <div>
                                        <h2 className="text-3xl font-black tracking-tight mb-2 leading-tight">{selectedItem.data.title}</h2>
                                        <div className="flex items-center gap-2 text-foreground/60 font-medium">
                                            <MapPin className="w-4 h-4" />
                                            <span>{selectedItem.data.latitude?.toFixed(4)}, {selectedItem.data.longitude?.toFixed(4)}</span>
                                        </div>
                                    </div>

                                    <div className="p-4 glass rounded-2xl border border-white/10">
                                        <p className="text-sm text-foreground/80 leading-relaxed">
                                            {selectedItem.data.description || "No description provided for this event."}
                                        </p>
                                    </div>

                                    <div className="flex items-center justify-between py-4 border-t border-white/10">
                                        <div>
                                            <p className="text-xs uppercase font-bold text-foreground/40 mb-1">Date</p>
                                            <p className="font-bold">{new Date(selectedItem.data.startTime).toLocaleDateString()}</p>
                                        </div>
                                        <div className="text-right">
                                            <p className="text-xs uppercase font-bold text-foreground/40 mb-1">Time</p>
                                            <p className="font-bold">{new Date(selectedItem.data.startTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</p>
                                        </div>
                                    </div>

                                    <Button className="w-full h-14 text-lg rounded-2xl shadow-lg shadow-primary/20">
                                        Join Event
                                    </Button>
                                </div>
                            ) : (
                                <div className="flex flex-col items-center text-center space-y-6 mt-10">
                                    <div className="relative">
                                        <Avatar
                                            name={selectedItem.data.name}
                                            color={selectedItem.data.color}
                                            size={120}
                                            isTalking={false}
                                        />
                                        {selectedItem.data.isMe && (
                                            <div className="absolute -bottom-2 px-3 py-1 bg-primary text-white text-xs font-bold rounded-full border-2 border-background">
                                                YOU
                                            </div>
                                        )}
                                    </div>

                                    <div>
                                        <h2 className="text-3xl font-black tracking-tight mb-1">{selectedItem.data.name}</h2>
                                        <p className="text-foreground/50 font-medium">@{selectedItem.data.userId?.substring(0, 8)}...</p>
                                    </div>

                                    <div className="grid grid-cols-3 gap-3 w-full">
                                        <div className="glass p-3 rounded-2xl flex flex-col items-center">
                                            <span className="text-xl font-black">12</span>
                                            <span className="text-[10px] uppercase font-bold text-foreground/40">Events</span>
                                        </div>
                                        <div className="glass p-3 rounded-2xl flex flex-col items-center">
                                            <span className="text-xl font-black">450</span>
                                            <span className="text-[10px] uppercase font-bold text-foreground/40">Followers</span>
                                        </div>
                                        <div className="glass p-3 rounded-2xl flex flex-col items-center">
                                            <span className="text-xl font-black">89</span>
                                            <span className="text-[10px] uppercase font-bold text-foreground/40">Following</span>
                                        </div>
                                    </div>

                                    <div className="w-full space-y-3">
                                        <Button className="w-full h-12 rounded-xl" variant="glass">
                                            Message
                                        </Button>
                                        <Button className="w-full h-12 rounded-xl border border-foreground/10" variant="outline">
                                            View Profile
                                        </Button>
                                    </div>
                                </div>
                            )}
                        </div>
                    </motion.div>
                )}
            </AnimatePresence>
        </div>
    );
}

// Helper to control map view
function MapController({ center, selectedItem }: { center: [number, number] | null, selectedItem: any }) {
    const map = useMap();
    useEffect(() => {
        // If an item is selected, fly to it
        if (selectedItem) {
            map.flyTo([selectedItem.lat, selectedItem.lng], 16, {
                duration: 1.5,
                easeLinearity: 0.25
            });
        }
        // Otherwise if we have a user position and no selection, keep centered (optional, maybe distracting)
        else if (center && !selectedItem) {
            // map.flyTo(center, 15); 
        }
    }, [center, selectedItem, map]);
    return null;
}

function CustomMarker({ marker, isMe, onClick }: { marker: any, isMe?: boolean, onClick: () => void }) {
    const createAvatarIcon = (name: string, color: string) => {
        const html = renderToStaticMarkup(
            <div className="relative flex flex-col items-center transition-transform hover:scale-110">
                <div
                    className={cn(
                        "w-12 h-12 rounded-full border-[3px] shadow-xl flex items-center justify-center overflow-hidden bg-white transition-all duration-500",
                        isMe && "ring-4 ring-primary/30 animate-pulse-soft"
                    )}
                    style={{ borderColor: color }}
                >
                    {/* Ensure we generate initials safely */}
                    <span className="font-black text-xs" style={{ color }}>
                        {name ? name.substring(0, 2).toUpperCase() : "??"}
                    </span>
                </div>
                {!isMe && (
                    <div className="glass px-2 py-0.5 rounded-full mt-1 border border-black/5 shadow-sm">
                        <span className="text-[8px] font-black tracking-wide" style={{ color }}>{name}</span>
                    </div>
                )}
            </div>
        );
        return L.divIcon({
            html,
            className: "custom-div-icon",
            iconSize: [48, 70],
            iconAnchor: [24, 60],
        });
    };

    const createEventIcon = (color: string) => {
        const html = renderToStaticMarkup(
            <div className="relative flex flex-col items-center group cursor-pointer">
                <div className="w-14 h-14 bg-white rounded-2xl shadow-2xl flex items-center justify-center border border-black/5 rotate-45 group-hover:scale-110 group-hover:rotate-0 transition-all duration-300">
                    <div className="-rotate-45 group-hover:rotate-0 transition-transform duration-300">
                        <Calendar className="w-7 h-7" style={{ color }} />
                    </div>
                </div>
                <div className="w-2 h-2 bg-black/20 rounded-full mt-4 blur-[2px]" />
            </div>
        );
        return L.divIcon({
            html,
            className: "custom-div-icon",
            iconSize: [56, 80],
            iconAnchor: [28, 40],
        });
    };

    const icon = marker.type === "user"
        ? createAvatarIcon(marker.data.name || "User", marker.data.color || "#B452FF")
        : createEventIcon(marker.data.voxelTheme || "#B452FF");

    return (
        <Marker
            position={[marker.lat, marker.lng]}
            icon={icon}
            eventHandlers={{
                click: onClick,
            }}
        />
    );
}
