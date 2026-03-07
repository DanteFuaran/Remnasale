import { useState, useEffect } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import LandingPage from './pages/LandingPage';
import DashboardPage from './pages/DashboardPage';
import AdminPage from './pages/AdminPage';
import SupportPage from './pages/SupportPage';
import Loader from './components/Loader';

export interface BrandConfig {
  name: string;
  logo: string;
  slogan: string;
  badge: string;
  title: string;
  subtitle: string;
  timezone?: string;
  advantages?: { icon: string; title: string; desc: string; active: boolean }[];
  faq?: { q: string; a: string; active: boolean }[];
}

export interface PublicConfig {
  bot_url: string;
  bot_username: string;
  oauth_providers: { google: boolean; github: boolean };
  brand: BrandConfig;
}

export default function App() {
  const [config, setConfig] = useState<PublicConfig | null>(null);

  const _defaultConfig = {
    bot_url: '', bot_username: '', oauth_providers: { google: false, github: false },
    brand: { name: 'VPN Shop', logo: '', slogan: '', badge: '', title: '', subtitle: '' },
  };

  useEffect(() => {
    const t0 = Date.now();
    fetch('/web/api/public/config')
      .then((r) => r.ok ? r.json() : null)
      .then((d) => {
        const remaining = Math.max(0, 2000 - (Date.now() - t0));
        setTimeout(() => setConfig(d ?? _defaultConfig), remaining);
      })
      .catch(() => {
        const remaining = Math.max(0, 2000 - (Date.now() - t0));
        setTimeout(() => setConfig(_defaultConfig), remaining);
      });
  }, []);

  if (!config) return <Loader />;

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<LandingPage config={config} />} />
        <Route path="/dashboard" element={<DashboardPage config={config} />} />
        <Route path="/support" element={<SupportPage config={config} />} />
        <Route path="/system" element={<AdminPage config={config} />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
