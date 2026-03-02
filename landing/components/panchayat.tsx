"use client";

import { motion } from "framer-motion";
import { Building2, ShieldCheck, BarChart3, Users } from "lucide-react";

const benefits = [
  {
    icon: Building2,
    title: "Digital Gram Panchayat",
    description:
      "All grievances are tracked digitally. No more lost paperwork or forgotten complaints. Every sarpanch gets a dashboard.",
  },
  {
    icon: ShieldCheck,
    title: "Government Partnership",
    description:
      "Officially backed by the Ministry of Panchayati Raj and integrated with the PFMS system for transparent fund allocation.",
  },
  {
    icon: BarChart3,
    title: "Data-Driven Decisions",
    description:
      "Ward-level analytics help panchayats prioritize spending. Water issues in Ward 5? Road damage in Ward 2? Data tells the story.",
  },
  {
    icon: Users,
    title: "Gram Sabha Empowerment",
    description:
      "Villagers see real-time data before gram sabha meetings. Informed citizens lead to better governance and accountability.",
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

const cardVariants = {
  hidden: { opacity: 0, y: 20 },
  visible: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.45, ease: "easeOut" },
  },
};

export function Panchayat() {
  return (
    <section id="panchayat" className="relative bg-secondary/40 py-24 lg:py-32">
      <div className="mx-auto max-w-7xl px-6">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-100px" }}
          transition={{ duration: 0.5 }}
          className="text-center"
        >
          <p className="text-sm font-semibold uppercase tracking-widest text-primary">
            Panchayati Raj
          </p>
          <h2 className="mt-3 text-balance font-serif text-3xl font-bold tracking-tight text-foreground sm:text-4xl">
            Strengthening Grassroots Governance
          </h2>
          <p className="mx-auto mt-4 max-w-2xl text-pretty text-muted-foreground">
            Designed in partnership with district administrations to bring
            digital transparency to the last mile of Indian governance.
          </p>
        </motion.div>

        <motion.div
          variants={containerVariants}
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true, margin: "-100px" }}
          className="mt-16 grid gap-6 sm:grid-cols-2"
        >
          {benefits.map((benefit) => (
            <motion.div
              key={benefit.title}
              variants={cardVariants}
              className="flex gap-5 rounded-2xl border border-border/50 bg-card/80 p-7 shadow-sm backdrop-blur-sm transition-all hover:border-primary/25 hover:shadow-md"
            >
              <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-primary">
                <benefit.icon className="h-6 w-6" />
              </div>
              <div>
                <h3 className="text-lg font-semibold text-foreground">
                  {benefit.title}
                </h3>
                <p className="mt-2 text-sm leading-relaxed text-muted-foreground">
                  {benefit.description}
                </p>
              </div>
            </motion.div>
          ))}
        </motion.div>
      </div>
    </section>
  );
}
