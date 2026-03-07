// Minimalist line-art SVG icons in cyan accent style (matching logo aesthetic)
// All icons are 24×24 viewBox, stroke-based, currentColor

interface IconProps {
  className?: string;
}

export const UsersIcon = ({ className }: IconProps) => (
  <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" width="24" height="24">
    <circle cx="9" cy="7" r="3.5" />
    <path d="M2 20v-1a5 5 0 0 1 5-5h4a5 5 0 0 1 5 5v1" />
    <circle cx="18" cy="8" r="2.5" />
    <path d="M18 13.5a4 4 0 0 1 4 4V20" />
  </svg>
);

export const BroadcastIcon = ({ className }: IconProps) => (
  <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" width="24" height="24">
    <path d="M3 11l18-7v18l-18-7v-4z" />
    <path d="M11 15v4a2 2 0 0 0 2 2h0a2 2 0 0 0 2-2v-3" />
  </svg>
);

export const PlansIcon = ({ className }: IconProps) => (
  <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" width="24" height="24">
    <rect x="3" y="3" width="18" height="18" rx="3" />
    <path d="M7 8h10M7 12h6M7 16h8" />
  </svg>
);

export const GatewaysIcon = ({ className }: IconProps) => (
  <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" width="24" height="24">
    <rect x="2" y="5" width="20" height="14" rx="3" />
    <path d="M2 10h20" />
    <path d="M6 15h4" />
  </svg>
);

export const FeaturesIcon = ({ className }: IconProps) => (
  <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" width="24" height="24">
    <rect x="3" y="3" width="7" height="7" rx="1.5" />
    <rect x="14" y="3" width="7" height="7" rx="1.5" />
    <rect x="3" y="14" width="7" height="7" rx="1.5" />
    <circle cx="17.5" cy="17.5" r="3.5" />
  </svg>
);

export const StatsIcon = ({ className }: IconProps) => (
  <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" width="24" height="24">
    <path d="M3 20h18" />
    <rect x="5" y="10" width="3" height="10" rx="1" />
    <rect x="10.5" y="4" width="3" height="16" rx="1" />
    <rect x="16" y="8" width="3" height="12" rx="1" />
  </svg>
);

export const LogsIcon = ({ className }: IconProps) => (
  <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" width="24" height="24">
    <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8l-6-6z" />
    <path d="M14 2v6h6" />
    <path d="M8 13h8M8 17h5" />
  </svg>
);

export const BotIcon = ({ className }: IconProps) => (
  <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" width="24" height="24">
    <rect x="4" y="8" width="16" height="12" rx="3" />
    <circle cx="9" cy="14" r="1.5" />
    <circle cx="15" cy="14" r="1.5" />
    <path d="M12 2v4" />
    <circle cx="12" cy="2" r="1" />
    <path d="M4 14H2M22 14h-2" />
  </svg>
);

export const BrandingIcon = ({ className }: IconProps) => (
  <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" width="24" height="24">
    <circle cx="12" cy="12" r="3" />
    <circle cx="19" cy="7" r="2" />
    <circle cx="5" cy="7" r="2" />
    <circle cx="5" cy="17" r="2" />
    <circle cx="19" cy="17" r="2" />
    <path d="M14.5 10.2L17.2 8M9.5 10.2L6.8 8M9.5 13.8L6.8 16M14.5 13.8l2.7 2.2" />
  </svg>
);

export const DatabaseIcon = ({ className }: IconProps) => (
  <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" width="24" height="24">
    <ellipse cx="12" cy="5" rx="8" ry="3" />
    <path d="M20 5v6c0 1.66-3.58 3-8 3S4 12.66 4 11V5" />
    <path d="M20 11v6c0 1.66-3.58 3-8 3s-8-1.34-8-3v-6" />
  </svg>
);

export const SupportIcon = ({ className }: IconProps) => (
  <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" width="24" height="24">
    <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
    <path d="M8 10h8M8 14h5" />
  </svg>
);
