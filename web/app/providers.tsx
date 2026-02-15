"use client";

import React, { createContext, useContext, useEffect, useRef, useState } from "react";


interface UserPosition {
    userId: string;
    x: number;
    y: number;
    latitude: number;
    longitude: number;
    username?: string;
    color?: string;
    avatarUrl?: string;
}

interface VoxelEvent {
    id: string;
    title: string;
    description: string;
    x: number;
    y: number;
    latitude?: number;
    longitude?: number;
    creatorId: string;
    startTime: string;
    ticketPrice: number;
    hasTickets: boolean;
    voxelTheme: string;
    createdAt: string;
}

interface WebSocketContextType {
    isConnected: boolean;
    events: VoxelEvent[];
    userPositions: Record<string, UserPosition>;
    createEvent: (event: Omit<VoxelEvent, "id" | "createdAt" | "creatorId">) => void;
    updatePosition: (lat: number, lng: number) => void;
    userId: string | null;
    userProfile: { username: string; color: string } | null;
}

const WebSocketContext = createContext<WebSocketContextType | null>(null);

export function useWebSocket() {
    const context = useContext(WebSocketContext);
    if (!context) {
        throw new Error("useWebSocket must be used within a WebSocketProvider");
    }
    return context;
}

const GUEST_NAMES = [
    "Neon Rider", "Voxel Vanguard", "Cyber Drifter", "Pixel Paladin",
    "Glitch Hunter", "Net Runner", "Data Wraith", "Code Nomad",
    "Byte Walker", "Signal Seeker", "Poly Pilgrim", "Grid Surfer"
];

const GUEST_COLORS = [
    "#B452FF", // Luma Purple
    "#00D1FF", // Cyan
    "#FF52AF", // Hot Pink
    "#319795", // Teal
    "#F6E05E", // Yellow
    "#FF9F1C", // Orange
    "#FF4D4D", // Red
    "#8B5CF6", // Violet
];

export function WebSocketProvider({ children }: { children: React.ReactNode }) {
    const [isConnected, setIsConnected] = useState(false);
    const [events, setEvents] = useState<VoxelEvent[]>([]);
    const [userPositions, setUserPositions] = useState<Record<string, UserPosition>>({});
    const [userId, setUserId] = useState<string | null>(null);
    const [userProfile, setUserProfile] = useState<{ username: string; color: string } | null>(null);
    const ws = useRef<WebSocket | null>(null);

    // Initialize User Identity
    useEffect(() => {
        // 1. User ID
        let id = localStorage.getItem("voxel_user_id");
        if (!id) {
            id = "user_" + Math.random().toString(36).substr(2, 9);
            localStorage.setItem("voxel_user_id", id);
        }
        setUserId(id);

        // 2. User Profile (Name & Color)
        const storedProfile = localStorage.getItem("voxel_user_profile");
        if (storedProfile) {
            setUserProfile(JSON.parse(storedProfile));
        } else {
            const newProfile = {
                username: GUEST_NAMES[Math.floor(Math.random() * GUEST_NAMES.length)],
                color: GUEST_COLORS[Math.floor(Math.random() * GUEST_COLORS.length)]
            };
            localStorage.setItem("voxel_user_profile", JSON.stringify(newProfile));
            setUserProfile(newProfile);
        }
    }, []);

    useEffect(() => {
        if (!userId) return;

        const connect = () => {
            const socket = new WebSocket(`ws://localhost:8080/ws?userId=${userId}`);

            socket.onopen = () => {
                console.log("WebSocket Connected");
                setIsConnected(true);
            };

            socket.onmessage = (event) => {
                try {
                    const message = JSON.parse(event.data);
                    // console.log("WS Message:", message);

                    switch (message.type) {
                        case "events_list":
                            setEvents(message.payload || []);
                            break;
                        case "event_created":
                            setEvents((prev) => [...prev, message.payload]);
                            break;
                        case "move":
                            // Payload: {userId, x, y, latitude, longitude, username, color}
                            const pos = message.payload;
                            if (pos && pos.userId && pos.userId !== userId) {
                                setUserPositions((prev) => ({
                                    ...prev,
                                    [pos.userId]: pos
                                }));
                            }
                            break;
                        default:
                            break;
                    }
                } catch (error) {
                    console.error("Error parsing WS message:", error);
                }
            };

            socket.onclose = () => {
                console.log("WebSocket Disconnected");
                setIsConnected(false);
                // Reconnect after 3s
                setTimeout(connect, 3000);
            };

            ws.current = socket;
        };

        connect();

        return () => {
            ws.current?.close();
        };
    }, [userId]);

    const createEvent = (eventData: any) => {
        if (ws.current && ws.current.readyState === WebSocket.OPEN) {
            ws.current.send(JSON.stringify({
                type: "create_event",
                payload: {
                    ...eventData,
                    creatorId: userId
                }
            }));
        }
    };

    const updatePosition = (lat: number, lng: number) => {
        if (ws.current && ws.current.readyState === WebSocket.OPEN && userId && userProfile) {
            ws.current.send(JSON.stringify({
                type: "move",
                payload: {
                    userId,
                    latitude: lat,
                    longitude: lng,
                    x: 0, // Placeholder
                    y: 0,  // Placeholder
                    username: userProfile.username,
                    color: userProfile.color
                }
            }));
        }
    };

    return (
        <WebSocketContext.Provider value={{ isConnected, events, userPositions, createEvent, updatePosition, userId, userProfile }}>
            {children}
        </WebSocketContext.Provider>
    );
}
