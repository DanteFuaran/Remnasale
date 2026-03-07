import { useEffect } from 'react';

declare global {
  interface Window {
    particlesJS?: (id: string, config: unknown) => void;
  }
}

const PARTICLES_CONFIG = {
  particles: {
    number: { value: 55, density: { enable: true, value_area: 900 } },
    color: { value: '#24C4F1' },
    shape: { type: 'circle' },
    opacity: { value: 0.12, random: true, anim: { enable: true, speed: 0.4, opacity_min: 0.04 } },
    size: { value: 2.5, random: true, anim: { enable: true, speed: 1, size_min: 0.5 } },
    line_linked: {
      enable: true,
      distance: 150,
      color: '#24C4F1',
      opacity: 0.06,
      width: 1,
    },
    move: {
      enable: true,
      speed: 0.7,
      direction: 'none',
      random: true,
      straight: false,
      out_mode: 'out',
      bounce: false,
    },
  },
  interactivity: {
    detect_on: 'canvas',
    events: {
      onhover: { enable: true, mode: 'grab' },
      onclick: { enable: true, mode: 'push' },
      resize: true,
    },
    modes: {
      grab: { distance: 140, line_linked: { opacity: 0.18 } },
      push: { particles_nb: 3 },
    },
  },
  retina_detect: true,
};

export default function ParticlesBackground() {
  useEffect(() => {
    const script = document.createElement('script');
    script.src = 'https://cdn.jsdelivr.net/particles.js/2.0.0/particles.min.js';
    script.async = true;
    script.onload = () => {
      if (window.particlesJS) {
        // Enable pointer events on the canvas for interactivity
        const el = document.getElementById('particles-js');
        if (el) el.style.pointerEvents = 'auto';
        window.particlesJS('particles-js', PARTICLES_CONFIG);
      }
    };
    document.head.appendChild(script);

    return () => {
      script.remove();
    };
  }, []);

  return null;
}
