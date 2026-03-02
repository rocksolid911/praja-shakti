export function VillageSilhouette({ className = "" }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 1440 200"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={className}
      preserveAspectRatio="none"
      aria-hidden="true"
    >
      {/* Hut 1 */}
      <polygon points="80,200 80,140 120,110 160,140 160,200" fill="currentColor" opacity="0.08" />
      {/* Temple */}
      <polygon points="260,200 260,100 290,60 320,100 320,200" fill="currentColor" opacity="0.06" />
      <rect x="280" y="55" width="20" height="10" rx="2" fill="currentColor" opacity="0.06" />
      {/* Tree 1 - Banyan */}
      <ellipse cx="420" cy="120" rx="50" ry="45" fill="currentColor" opacity="0.05" />
      <rect x="415" y="120" width="10" height="80" fill="currentColor" opacity="0.05" />
      {/* Hut 2 */}
      <polygon points="550,200 550,150 580,125 610,150 610,200" fill="currentColor" opacity="0.07" />
      {/* Well */}
      <rect x="700" y="170" width="40" height="30" rx="3" fill="currentColor" opacity="0.06" />
      <line x1="710" y1="170" x2="710" y2="155" stroke="currentColor" strokeWidth="3" opacity="0.06" />
      <line x1="730" y1="170" x2="730" y2="155" stroke="currentColor" strokeWidth="3" opacity="0.06" />
      <line x1="705" y1="155" x2="735" y2="155" stroke="currentColor" strokeWidth="3" opacity="0.06" />
      {/* Tree 2 - Palm */}
      <rect x="870" y="100" width="6" height="100" fill="currentColor" opacity="0.05" />
      <ellipse cx="873" cy="95" rx="30" ry="18" fill="currentColor" opacity="0.05" />
      {/* Panchayat building */}
      <rect x="980" y="140" width="80" height="60" rx="2" fill="currentColor" opacity="0.07" />
      <polygon points="970,140 1020,115 1070,140" fill="currentColor" opacity="0.06" />
      <rect x="1010" y="165" width="20" height="35" fill="currentColor" opacity="0.04" />
      {/* Flag on panchayat */}
      <line x1="1020" y1="115" x2="1020" y2="90" stroke="currentColor" strokeWidth="2" opacity="0.06" />
      <rect x="1020" y="90" width="15" height="10" rx="1" fill="currentColor" opacity="0.08" />
      {/* Hut 3 */}
      <polygon points="1200,200 1200,155 1225,130 1250,155 1250,200" fill="currentColor" opacity="0.06" />
      {/* Tree 3 */}
      <ellipse cx="1350" cy="140" rx="35" ry="30" fill="currentColor" opacity="0.04" />
      <rect x="1347" y="140" width="6" height="60" fill="currentColor" opacity="0.04" />
      {/* Ground line */}
      <rect x="0" y="195" width="1440" height="5" fill="currentColor" opacity="0.03" />
    </svg>
  );
}
