"use client";

import { motion } from "framer-motion";
import {
  FileText,
  CheckCircle2,
  Clock,
  MapPin,
  TreePine,
} from "lucide-react";
import { VillageSilhouette } from "./village-silhouette";

const stats = [
  {
    icon: MapPin,
    value: "5,200+",
    label: "Villages Connected",
  },
  {
    icon: FileText,
    value: "1,84,000+",
    label: "Grievances Filed",
  },
  {
    icon: CheckCircle2,
    value: "1,42,000+",
    label: "Issues Resolved",
  },
  {
    icon: Clock,
    value: "72 Hrs",
    label: "Avg. Resolution Time",
  },
];

const containerVariants = {
  hidden: {},
  visible: {
    transition: {
      staggerChildren: 0.12,
    },
  },
};

const itemVariants = {
  hidden: { opacity: 0, scale: 0.9 },
  visible: {
    opacity: 1,
    scale: 1,
    transition: { duration: 0.5, ease: "easeOut" },
  },
};

export function Stats() {
  return (
    <section id="stats" className="relative py-24 lg:py-32">
      <div className="mx-auto max-w-7xl px-6">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-100px" }}
          transition={{ duration: 0.5 }}
          className="relative overflow-hidden rounded-3xl bg-primary p-12 shadow-2xl shadow-primary/20 lg:p-16"
        >
          {/* Village silhouette overlay at top */}
          <VillageSilhouette className="pointer-events-none absolute top-0 left-0 w-full text-primary-foreground opacity-30" />

          <div className="relative text-center">
            <div className="mx-auto mb-3 inline-flex items-center gap-2 rounded-full bg-primary-foreground/10 px-4 py-1.5 text-xs font-medium text-primary-foreground/80">
              <TreePine className="h-3.5 w-3.5" />
              Parivartan Ki Kahaani
            </div>
            <h2 className="text-balance font-serif text-3xl font-bold tracking-tight text-primary-foreground sm:text-4xl">
              Real Villages. Real Impact.
            </h2>
            <p className="mx-auto mt-3 max-w-lg text-sm text-primary-foreground/70">
              Numbers from the ground that show how villagers are reclaiming
              their right to better infrastructure.
            </p>
          </div>

          <motion.div
            variants={containerVariants}
            initial="hidden"
            whileInView="visible"
            viewport={{ once: true }}
            className="relative mt-12 grid gap-6 sm:grid-cols-2 lg:grid-cols-4"
          >
            {stats.map((stat) => (
              <motion.div
                key={stat.label}
                variants={itemVariants}
                className="flex flex-col items-center rounded-2xl bg-primary-foreground/10 px-6 py-8 backdrop-blur-sm"
              >
                <stat.icon className="mb-3 h-7 w-7 text-primary-foreground/70" />
                <span className="text-3xl font-extrabold tracking-tight text-primary-foreground lg:text-4xl">
                  {stat.value}
                </span>
                <span className="mt-2 text-xs font-medium text-primary-foreground/70">
                  {stat.label}
                </span>
              </motion.div>
            ))}
          </motion.div>
        </motion.div>
      </div>
    </section>
  );
}
