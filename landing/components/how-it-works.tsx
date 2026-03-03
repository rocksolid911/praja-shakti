"use client";

import { motion } from "framer-motion";
import Image from "next/image";
import { Camera, Building2, CheckCircle, ArrowDown } from "lucide-react";

const steps = [
  {
    icon: Camera,
    number: "01",
    title: "Report",
    hindi: "Shikayat Darj Karein",
    description:
      "Spot a problem in your village? Open the app, take a photo, and tap submit. The GPS auto-tags the exact location for the authorities.",
  },
  {
    icon: Building2,
    number: "02",
    title: "Route to Panchayat",
    hindi: "Panchayat Tak Pahunche",
    description:
      "The complaint is automatically categorized (water, road, electricity) and routed to the concerned gram panchayat office or block official.",
  },
  {
    icon: CheckCircle,
    number: "03",
    title: "Resolve & Verify",
    hindi: "Samasya Ka Samadhan",
    description:
      "The official resolves the issue and uploads proof. You verify and mark it complete. The entire village can see the progress transparently.",
  },
];

const containerVariants = {
  hidden: {},
  visible: {
    transition: {
      staggerChildren: 0.2,
    },
  },
};

const stepVariants = {
  hidden: { opacity: 0, y: 30 },
  visible: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.5, ease: "easeOut" },
  },
};

export function HowItWorks() {
  return (
    <section id="how-it-works" className="relative py-24 lg:py-32">
      {/* Subtle warm glow */}
      <div className="pointer-events-none absolute inset-0 -z-10">
        <div className="absolute top-1/2 left-1/2 h-[500px] w-[500px] -translate-x-1/2 -translate-y-1/2 rounded-full bg-accent/5 blur-3xl" />
      </div>

      <div className="mx-auto max-w-7xl px-6">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-100px" }}
          transition={{ duration: 0.5 }}
          className="text-center"
        >
          <p className="text-sm font-semibold uppercase tracking-widest text-primary">
            Kaise Kaam Karta Hai
          </p>
          <h2 className="mt-3 text-balance font-serif text-3xl font-bold tracking-tight text-foreground sm:text-4xl">
            Three Steps to a Better Village
          </h2>
          <p className="mx-auto mt-4 max-w-2xl text-pretty text-muted-foreground">
            From spotting a broken road to seeing it repaired -- a simple process
            that puts the power back in the hands of the gram sabha.
          </p>
        </motion.div>

        <div className="mt-16 grid items-center gap-12 lg:grid-cols-2 lg:gap-16">
          {/* Left: Steps */}
          <motion.div
            variants={containerVariants}
            initial="hidden"
            whileInView="visible"
            viewport={{ once: true, margin: "-100px" }}
            className="flex flex-col gap-2"
          >
            {steps.map((step, index) => (
              <div key={step.number}>
                <motion.div
                  variants={stepVariants}
                  className="flex gap-5 rounded-2xl border border-border/50 bg-card/60 p-6 backdrop-blur-sm"
                >
                  <div className="flex flex-col items-center">
                    <div className="flex h-14 w-14 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-primary">
                      <step.icon className="h-7 w-7" />
                    </div>
                  </div>
                  <div>
                    <div className="flex items-center gap-2">
                      <span className="text-xs font-bold uppercase tracking-widest text-primary">
                        Step {step.number}
                      </span>
                    </div>
                    <h3 className="mt-1 text-lg font-bold text-foreground">
                      {step.title}
                    </h3>
                    <p className="text-xs italic text-muted-foreground">
                      {step.hindi}
                    </p>
                    <p className="mt-2 text-sm leading-relaxed text-muted-foreground">
                      {step.description}
                    </p>
                  </div>
                </motion.div>
                {index < steps.length - 1 && (
                  <div className="flex justify-center py-1">
                    <ArrowDown className="h-5 w-5 text-border" />
                  </div>
                )}
              </div>
            ))}
          </motion.div>

          {/* Right: Village scene image */}
          <motion.div
            initial={{ opacity: 0, scale: 0.95 }}
            whileInView={{ opacity: 1, scale: 1 }}
            viewport={{ once: true, margin: "-100px" }}
            transition={{ duration: 0.6, delay: 0.2 }}
            className="relative"
          >
            <div className="overflow-hidden rounded-2xl border border-border/50 shadow-xl shadow-primary/5">
              <Image
                src="/images/village-scene.jpg"
                alt="Indian village panchayat building with solar streetlight and paved road"
                width={640}
                height={420}
                className="h-auto w-full object-cover"
              />
            </div>
            {/* Floating stat card */}
            <div className="absolute -bottom-6 -left-4 rounded-xl border border-border/50 bg-card/90 px-5 py-4 shadow-lg backdrop-blur-md">
              <p className="text-2xl font-extrabold text-primary">92%</p>
              <p className="text-xs font-medium text-muted-foreground">
                Village satisfaction rate
              </p>
            </div>
          </motion.div>
        </div>
      </div>
    </section>
  );
}
