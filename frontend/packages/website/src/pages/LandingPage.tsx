import { useState, useEffect } from 'react';
import ParticlesBackground from '../components/ParticlesBackground';
import Navbar from '../components/Navbar';
import Hero from '../components/Hero';
import Features from '../components/Features';
import CompatibleServices from '../components/CompatibleServices';
import Plans from '../components/Plans';
import FAQ from '../components/FAQ';
import Footer from '../components/Footer';
import SupportWidget from '../components/SupportWidget';
import type { PublicConfig } from '../App';

interface Props {
  config: PublicConfig;
}

export default function LandingPage({ config }: Props) {
  return (
    <>
      <ParticlesBackground />
      <Navbar botUrl={config.bot_url} oauthProviders={config.oauth_providers} brand={config.brand} />
      <Hero
        botUrl={config.bot_url}
        slogan={config.brand?.slogan}
        badge={config.brand?.badge}
        title={config.brand?.title}
        subtitle={config.brand?.subtitle}
      />
      <Features advantages={config.brand?.advantages} />
      <CompatibleServices />
      <Plans botUrl={config.bot_url} />
      <FAQ items={config.brand?.faq} />

      <div className="cta-banner">
        <h2>Готовы начать?</h2>
        <p>Подключитесь к VPN за 30 секунд через Telegram</p>
        {config.bot_url && (
          <a href={config.bot_url} target="_blank" rel="noopener noreferrer" className="btn-primary">
            Подключиться
          </a>
        )}
      </div>

      <Footer />
      <SupportWidget logoUrl={config.brand?.logo} />
    </>
  );
}
