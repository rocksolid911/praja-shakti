"use client";

import { motion } from "framer-motion";
import {
  Camera,
  MapPin,
  ThumbsUp,
  WifiOff,
  Languages,
  Bell,
} from "lucide-react";

const features = [
  {
    icon: Camera,
    title: "Photo Reporting",
    description:
      "Snap a photo of the broken road, dry borewell, or clogged drain. The app tags your GPS location automatically -- no paperwork needed.",
  },
  {
    icon: MapPin,
    title: "Live Tracking",
    description:
      "Watch your complaint travel from the gram panchayat to the block office. Every status update is transparent -- no more running to the sarpanch.",
  },
  {
    icon: ThumbsUp,
    title: "Community Upvotes",
    description:
      "Rally your village. When more people upvote an issue, it climbs higher in priority for the authorities. Collective voice, faster action.",
  },
  {
    icon: WifiOff,
    title: "Offline Mode",
    description:
      "Poor network in your area? No problem. Report issues offline and the app syncs automatically when connectivity returns.",
  },
  {
    icon: Languages,
    title: "Multi-Language",
    description:
      "Use the app in Hindi, Tamil, Telugu, Kannada, Bengali, Marathi, and 6 more regional languages. Your language, your comfort.",
  },
  {
    icon: Bell,
    title: "SMS Alerts",
    description:
      "Don't have a smartphone? Receive status updates via SMS on your basic phone. Every villager stays informed.",
  },
];

const containerVariants = {
  hidden: {},
  visible: {
    transition: {
      staggerChildren: 0.1,
    },
  },
};

const cardVariants = {
  hidden: { opacity: 0, y: 30 },
  visible: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.5, ease: "easeOut" },
  },
};

export function Features() {
  return (
    <section id="features" className="relative py-24 lg:py-32">
      <div className="mx-auto max-w-7xl px-6">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-100px" }}
          transition={{ duration: 0.5 }}
          className="text-center"
        >
          <p className="text-sm font-semibold uppercase tracking-widest text-primary">
            Suvidhaayein
          </p>
          <h2 className="mt-3 text-balance font-serif text-3xl font-bold tracking-tight text-foreground sm:text-4xl">
            Built for Villages, Powered by People
          </h2>
          <p className="mx-auto mt-4 max-w-2xl text-pretty text-muted-foreground">
            Simple tools designed for every villager -- from the farmer in the
            field to the teacher in the school. No technical skills needed.
          </p>
        </motion.div>

        <motion.div
          variants={containerVariants}
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true, margin: "-100px" }}
          className="mt-16 grid gap-6 sm:grid-cols-2 lg:grid-cols-3"
        >
          {features.map((feature) => (
            <motion.div
              key={feature.title}
              variants={cardVariants}
              className="group relative rounded-2xl border border-border/50 bg-card/70 p-7 shadow-sm backdrop-blur-sm transition-all hover:border-primary/30 hover:shadow-lg hover:shadow-primary/5"
            >
              <div className="mb-5 inline-flex h-12 w-12 items-center justify-center rounded-xl bg-primary/10 text-primary transition-colors group-hover:bg-primary group-hover:text-primary-foreground">
                <feature.icon className="h-6 w-6" />
              </div>
              <h3 className="text-lg font-semibold text-foreground">
                {feature.title}
              </h3>
              <p className="mt-2 text-sm leading-relaxed text-muted-foreground">
                {feature.description}
              </p>
            </motion.div>
          ))}
        </motion.div>
      </div>
    </section>
  );
}
