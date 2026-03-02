"use client";

import { motion } from "framer-motion";
import Image from "next/image";
import { ArrowRight, Users } from "lucide-react";
import { VillageSilhouette } from "./village-silhouette";

const APP_URL = process.env.NEXT_PUBLIC_APP_URL || "http://localhost:8080";

export function Hero() {
  return (
    <section className="relative overflow-hidden pt-28 pb-0 lg:pt-40">
      {/* Warm earthy background glow */}
      <div className="pointer-events-none absolute inset-0 -z-10">
        <div className="absolute top-0 left-1/4 h-[500px] w-[500px] rounded-full bg-primary/6 blur-3xl" />
        <div className="absolute right-0 bottom-0 h-[400px] w-[400px] rounded-full bg-accent/8 blur-3xl" />
      </div>

      <div className="mx-auto max-w-7xl px-6">
        <div className="grid items-center gap-12 lg:grid-cols-2 lg:gap-16">
          {/* Left: Text content */}
          <motion.div
            initial={{ opacity: 0, y: 30 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.7, ease: "easeOut" }}
          >
            <div className="mb-6 inline-flex items-center gap-2 rounded-full border border-primary/20 bg-primary/5 px-4 py-1.5 text-sm font-medium text-primary">
              <Users className="h-3.5 w-3.5" />
              Serving 5,000+ villages across India
            </div>

            <h1 className="text-balance font-serif text-4xl font-bold leading-tight tracking-tight text-foreground sm:text-5xl lg:text-6xl">
              Gaon Ki Awaaz,{" "}
              <span className="text-primary">Sarkar Tak Pahunche.</span>
            </h1>

            <p className="mt-6 max-w-xl text-pretty text-lg leading-relaxed text-muted-foreground">
              From broken hand pumps to unlit village roads, report problems in
              your gram panchayat, track them in real-time, and hold local
              authorities accountable. Your village, your voice.
            </p>

            {/* Trust badges */}
            <div className="mt-6 flex flex-wrap items-center gap-3 text-xs font-medium text-muted-foreground">
              <span className="inline-flex items-center gap-1.5 rounded-full bg-secondary px-3 py-1">
                <span className="h-1.5 w-1.5 rounded-full bg-chart-3" />
                Government Backed
              </span>
              <span className="inline-flex items-center gap-1.5 rounded-full bg-secondary px-3 py-1">
                <span className="h-1.5 w-1.5 rounded-full bg-primary" />
                Available in 12 Languages
              </span>
              <span className="inline-flex items-center gap-1.5 rounded-full bg-secondary px-3 py-1">
                <span className="h-1.5 w-1.5 rounded-full bg-accent" />
                Works Offline
              </span>
            </div>

            <div className="mt-10 flex flex-wrap items-center gap-4">
              <a
                href={APP_URL}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-2 rounded-lg bg-primary px-7 py-3.5 text-sm font-semibold text-primary-foreground shadow-md transition-all hover:opacity-90"
              >
                Report an Issue
                <ArrowRight className="h-4 w-4" />
              </a>
              <a
                href="#how-it-works"
                className="inline-flex items-center gap-2 rounded-lg border border-border px-7 py-3.5 text-sm font-semibold text-foreground transition-all hover:bg-secondary"
              >
                See How It Works
              </a>
            </div>
          </motion.div>

          {/* Right: Village illustration */}
          <motion.div
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ duration: 0.7, delay: 0.2, ease: "easeOut" }}
            className="relative"
          >
            <div className="relative overflow-hidden rounded-2xl border border-border/50 shadow-2xl shadow-primary/5">
              <div className="absolute -inset-px -z-10 rounded-2xl bg-gradient-to-br from-primary/15 via-transparent to-accent/15" />
              <Image
                src="/images/village-hero.jpg"
                alt="Indian village landscape with green fields, terracotta rooftops, and a banyan tree"
                width={640}
                height={400}
                className="h-auto w-full object-cover"
                priority
              />
              {/* Overlay info card */}
              <div className="absolute right-4 bottom-4 left-4 rounded-xl border border-border/30 bg-card/80 p-4 backdrop-blur-md sm:left-auto sm:w-56">
                <p className="text-xs font-semibold text-primary">Live Now</p>
                <p className="mt-1 text-sm font-bold text-foreground">
                  Broken Hand Pump
                </p>
                <p className="text-xs text-muted-foreground">
                  Ward 3, Rampur Village
                </p>
                <div className="mt-2 flex items-center gap-1.5">
                  <span className="h-2 w-2 animate-pulse rounded-full bg-accent" />
                  <span className="text-[10px] font-medium text-accent-foreground">
                    Being resolved
                  </span>
                </div>
              </div>
            </div>
          </motion.div>
        </div>
      </div>

      {/* Village silhouette divider */}
      <VillageSilhouette className="mt-16 w-full text-foreground lg:mt-24" />
    </section>
  );
}
