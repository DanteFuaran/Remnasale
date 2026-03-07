export default function Loader() {
  return (
    <div className="page-loader">
      <div className="chip-loader">
        <svg viewBox="0 0 800 500" xmlns="http://www.w3.org/2000/svg" aria-label="Загрузка">
          <defs>
            <linearGradient id="chipGrad" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#1a1a2e" />
              <stop offset="100%" stopColor="#0a0a14" />
            </linearGradient>
            <linearGradient id="chipTextGrad" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#ffffff" />
              <stop offset="100%" stopColor="#24C4F1" />
            </linearGradient>
            <linearGradient id="pinGrad" x1="1" y1="0" x2="0" y2="0">
              <stop offset="0%" stopColor="#4a4a6a" />
              <stop offset="50%" stopColor="#2a2a4a" />
              <stop offset="100%" stopColor="#1a1a2e" />
            </linearGradient>
          </defs>

          {/* Traces left side */}
          <path d="M100 100 H200 V210 H326" className="trace-bg" />
          <path d="M100 100 H200 V210 H326" className="trace-flow cl-cyan" />

          <path d="M80 180 H180 V230 H326" className="trace-bg" />
          <path d="M80 180 H180 V230 H326" className="trace-flow cl-white" style={{ animationDelay: '0.4s' }} />

          <path d="M60 260 H150 V250 H326" className="trace-bg" />
          <path d="M60 260 H150 V250 H326" className="trace-flow cl-teal" style={{ animationDelay: '0.8s' }} />

          <path d="M100 350 H200 V270 H326" className="trace-bg" />
          <path d="M100 350 H200 V270 H326" className="trace-flow cl-green" style={{ animationDelay: '1.2s' }} />

          {/* Traces right side */}
          <path d="M700 90 H560 V210 H474" className="trace-bg" />
          <path d="M700 90 H560 V210 H474" className="trace-flow cl-white" style={{ animationDelay: '0.6s' }} />

          <path d="M740 160 H580 V230 H474" className="trace-bg" />
          <path d="M740 160 H580 V230 H474" className="trace-flow cl-cyan" style={{ animationDelay: '1.0s' }} />

          <path d="M720 250 H590 V250 H474" className="trace-bg" />
          <path d="M720 250 H590 V250 H474" className="trace-flow cl-teal" style={{ animationDelay: '0.2s' }} />

          <path d="M680 340 H570 V270 H474" className="trace-bg" />
          <path d="M680 340 H570 V270 H474" className="trace-flow cl-green" style={{ animationDelay: '1.4s' }} />

          {/* Chip body */}
          <rect x="330" y="190" width="140" height="100" rx="20" ry="20"
            fill="url(#chipGrad)" stroke="rgba(36,196,241,0.4)" strokeWidth="2"
            filter="drop-shadow(0 0 12px rgba(36,196,241,0.3))" />

          {/* Left pins */}
          <rect x="322" y="205" width="8" height="10" fill="url(#pinGrad)" rx="2" />
          <rect x="322" y="225" width="8" height="10" fill="url(#pinGrad)" rx="2" />
          <rect x="322" y="245" width="8" height="10" fill="url(#pinGrad)" rx="2" />
          <rect x="322" y="265" width="8" height="10" fill="url(#pinGrad)" rx="2" />

          {/* Right pins */}
          <rect x="470" y="205" width="8" height="10" fill="url(#pinGrad)" rx="2" />
          <rect x="470" y="225" width="8" height="10" fill="url(#pinGrad)" rx="2" />
          <rect x="470" y="245" width="8" height="10" fill="url(#pinGrad)" rx="2" />
          <rect x="470" y="265" width="8" height="10" fill="url(#pinGrad)" rx="2" />

          {/* Chip text */}
          <text x="400" y="238" fontFamily="Arial, sans-serif" fontSize="20"
            fill="url(#chipTextGrad)" textAnchor="middle" dominantBaseline="middle"
            fontWeight="bold" letterSpacing="1">
            Loading
          </text>
          <text x="400" y="262" fontFamily="Arial, sans-serif" fontSize="10"
            fill="rgba(36,196,241,0.5)" textAnchor="middle" dominantBaseline="middle"
            letterSpacing="2">
            REMNASALE
          </text>

          {/* Terminal dots left */}
          <circle cx="100" cy="100" r="5" fill="rgba(36,196,241,0.35)" />
          <circle cx="80" cy="180" r="5" fill="rgba(255,255,255,0.2)" />
          <circle cx="60" cy="260" r="5" fill="rgba(36,196,241,0.25)" />
          <circle cx="100" cy="350" r="5" fill="rgba(36,196,241,0.2)" />

          {/* Terminal dots right */}
          <circle cx="700" cy="90" r="5" fill="rgba(255,255,255,0.2)" />
          <circle cx="740" cy="160" r="5" fill="rgba(36,196,241,0.35)" />
          <circle cx="720" cy="250" r="5" fill="rgba(36,196,241,0.25)" />
          <circle cx="680" cy="340" r="5" fill="rgba(36,196,241,0.2)" />
        </svg>
      </div>
    </div>
  );
}
