"use client";

import { motion } from "framer-motion";
import { cn } from "@/lib/utils";
import { LucideIcon } from "lucide-react";

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
    variant?: "primary" | "secondary" | "outline" | "ghost" | "glass";
    size?: "sm" | "md" | "lg";
    icon?: LucideIcon;
    isLoading?: boolean;
}

export function Button({
    className,
    variant = "primary",
    size = "md",
    icon: Icon,
    isLoading,
    children,
    ...props
}: ButtonProps) {
    const variants = {
        primary: "bg-primary text-white hover:bg-primary-dark shadow-luma hover:shadow-luma-hover",
        secondary: "bg-secondary text-white hover:opacity-90",
        outline: "border-2 border-primary text-primary hover:bg-primary/5",
        ghost: "text-foreground hover:bg-foreground/5",
        glass: "glass text-foreground hover:bg-white/40",
    };

    const sizes = {
        sm: "px-4 py-2 text-sm rounded-full",
        md: "px-6 py-3 text-base rounded-full font-medium",
        lg: "px-8 py-4 text-lg rounded-full font-bold",
    };

    return (
        <motion.button
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            className={cn(
                "inline-flex items-center justify-center transition-all duration-300 disabled:opacity-50 disabled:cursor-not-allowed",
                variants[variant],
                sizes[size],
                className
            )}
            {...props}
        >
            {isLoading ? (
                <div className="mr-2 h-4 w-4 animate-spin rounded-full border-2 border-current border-t-transparent" />
            ) : Icon && (
                <Icon className="mr-2 h-5 w-5" />
            )}
            {children}
        </motion.button>
    );
}
