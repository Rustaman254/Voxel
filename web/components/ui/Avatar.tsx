"use client";

import { cn } from "@/lib/utils";
import { User as UserIcon } from "lucide-react";

interface AvatarProps {
    name?: string;
    src?: string;
    size?: number;
    color?: string;
    isTalking?: boolean;
    className?: string;
}

export function Avatar({
    name = "User",
    src,
    size = 40,
    color = "#B452FF",
    isTalking = false,
    className,
}: AvatarProps) {
    const initials = name
        .split(" ")
        .map((n) => n[0])
        .join("")
        .toUpperCase()
        .slice(0, 2);

    return (
        <div className={cn("relative flex flex-col items-center gap-2", className)}>
            <div
                className={cn(
                    "relative rounded-full transition-all duration-300",
                    isTalking && "ring-4 ring-green-500 ring-offset-2 animate-pulse"
                )}
                style={{
                    width: size,
                    height: size,
                    border: `3px solid ${color}`,
                    boxShadow: `0 0 15px ${color}4D`,
                }}
            >
                <div className="w-full h-full rounded-full overflow-hidden bg-foreground/5 flex items-center justify-center">
                    {src ? (
                        <img src={src} alt={name} className="w-full h-full object-cover" />
                    ) : (
                        <span
                            className="font-bold text-center"
                            style={{ fontSize: size * 0.35, color: color }}
                        >
                            {initials || <UserIcon size={size * 0.5} />}
                        </span>
                    )}
                </div>

                {isTalking && (
                    <div className="absolute bottom-0 right-0 bg-green-500 rounded-full p-1 border-2 border-background">
                        <div className="w-2 h-2 bg-white rounded-full" />
                    </div>
                )}
            </div>

            {name && (
                <div className="glass px-3 py-1 rounded-full border border-foreground/10">
                    <span className="text-[10px] font-black tracking-tight whitespace-nowrap" style={{ color: color }}>
                        {name}
                    </span>
                </div>
            )}
        </div>
    );
}
