"use client";

import { motion } from "framer-motion";
import { Landmark, Phone, ArrowRight } from "lucide-react";
import { VillageSilhouette } from "./village-silhouette";

const APP_URL = process.env.NEXT_PUBLIC_APP_URL || "http://localhost:8080";

export function Footer() {
  return (
    <footer id="cta" className="relative overflow-hidden border-t border-border/50 bg-secondary/50">
      {/* CTA Section */}
      <div className="mx-auto max-w-7xl px-6 py-24 lg:py-32">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-100px" }}
          transition={{ duration: 0.5 }}
          className="text-center"
        >
          <h2 className="text-balance font-serif text-3xl font-bold tracking-tight text-foreground sm:text-4xl">
            Apne Gaon Ko Badlein.
          </h2>
          <p className="mt-2 font-serif text-lg italic text-primary">
            Transform Your Village.
          </p>
          <p className="mx-auto mt-4 max-w-xl text-pretty text-muted-foreground">
            Join 50 lakh+ villagers who are making their panchayats more
            transparent, responsive, and accountable -- one report at a time.
          </p>

          {/* App store badges + SMS */}
          <div className="mt-10 flex flex-col items-center gap-6">
            <div className="flex flex-wrap items-center justify-center gap-4">
              <a
                href={APP_URL}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-3 rounded-xl bg-foreground px-6 py-3.5 text-background shadow-sm transition-opacity hover:opacity-90"
              >
                <svg
                  className="h-7 w-7"
                  viewBox="0 0 24 24"
                  fill="currentColor"
                >
                  <path d="M17.05 20.28c-.98.95-2.05.8-3.08.35-1.09-.46-2.09-.48-3.24 0-1.44.62-2.2.44-3.06-.35C2.79 15.25 3.51 7.59 9.05 7.31c1.35.07 2.29.74 3.08.8 1.18-.24 2.31-.93 3.57-.84 1.51.12 2.65.72 3.4 1.8-3.12 1.87-2.38 5.98.48 7.13-.57 1.5-1.31 2.99-2.54 4.09zM12.03 7.25c-.15-2.23 1.66-4.07 3.74-4.25.29 2.58-2.34 4.5-3.74 4.25z" />
                </svg>
                <div className="text-left">
                  <p className="text-[10px] leading-none text-background/70">
                    Download on the
                  </p>
                  <p className="text-sm font-semibold leading-tight text-background">
                    App Store
                  </p>
                </div>
              </a>
              <a
                href={APP_URL}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-3 rounded-xl bg-foreground px-6 py-3.5 text-background shadow-sm transition-opacity hover:opacity-90"
              >
                <svg
                  className="h-7 w-7"
                  viewBox="0 0 24 24"
                  fill="currentColor"
                >
                  <path d="M3.609 1.814L13.792 12 3.61 22.186a.996.996 0 01-.61-.92V2.734a1 1 0 01.609-.92zm10.89 10.893l2.302 2.302-10.937 6.333 8.635-8.635zm3.199-3.199l2.302 2.302a1 1 0 010 1.38l-2.302 2.302L15.103 12l2.595-2.492zM5.864 2.658L16.8 8.99l-2.302 2.302-8.635-8.635z" />
                </svg>
                <div className="text-left">
                  <p className="text-[10px] leading-none text-background/70">
                    Get it on
                  </p>
                  <p className="text-sm font-semibold leading-tight text-background">
                    Google Play
                  </p>
                </div>
              </a>
            </div>

            {/* Missed call / SMS option */}
            <div className="flex items-center gap-3 rounded-xl border border-border/60 bg-card/80 px-5 py-3 backdrop-blur-sm">
              <Phone className="h-5 w-5 text-primary" />
              <div className="text-left">
                <p className="text-xs text-muted-foreground">
                  No smartphone? Give a missed call to
                </p>
                <p className="text-sm font-bold text-foreground">
                  1800-XXX-XXXX (Toll Free)
                </p>
              </div>
            </div>
          </div>
        </motion.div>
      </div>

      {/* Village silhouette at bottom */}
      <VillageSilhouette className="w-full text-foreground" />

      {/* Bottom bar */}
      <div className="border-t border-border/50 bg-secondary/30">
        <div className="mx-auto flex max-w-7xl flex-col items-center justify-between gap-4 px-6 py-6 sm:flex-row">
          <div className="flex items-center gap-2.5">
            <div className="flex h-7 w-7 items-center justify-center rounded-md bg-primary">
              <Landmark className="h-4 w-4 text-primary-foreground" />
            </div>
            <div>
              <span className="text-sm font-semibold text-foreground">
                Praja Shakti
              </span>
              <span className="ml-1 text-[10px] text-muted-foreground">
                Gaon Ki Awaaz
              </span>
            </div>
          </div>

          <p className="text-xs text-muted-foreground">
            &copy; {new Date().getFullYear()} Praja Shakti. Ministry of
            Panchayati Raj, Government of India.
          </p>

          <div className="flex gap-6">
            <a
              href="#"
              className="text-xs text-muted-foreground transition-colors hover:text-foreground"
            >
              Privacy Policy
            </a>
            <a
              href="#"
              className="text-xs text-muted-foreground transition-colors hover:text-foreground"
            >
              RTI Information
            </a>
            <a
              href="#"
              className="text-xs text-muted-foreground transition-colors hover:text-foreground"
            >
              Accessibility
            </a>
          </div>
        </div>
      </div>
    </footer>
  );
}
