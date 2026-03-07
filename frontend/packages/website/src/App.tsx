import ParticlesBackground from './components/ParticlesBackground';
import Navbar from './components/Navbar';
import Hero from './components/Hero';
import Features from './components/Features';
import Plans from './components/Plans';
import Advantages from './components/Advantages';
import Footer from './components/Footer';

const BOT_URL = 'https://t.me/remnasale_bot';

export default function App() {
  return (
    <>
      <ParticlesBackground />
      <Navbar botUrl={BOT_URL} />
      <Hero botUrl={BOT_URL} />
      <Features />
      <Plans botUrl={BOT_URL} />
      <Advantages />

      <div className="cta-banner">
        <h2>Готовы начать?</h2>
        <p>Подключитесь к VPN за 30 секунд через Telegram</p>
        <a href={BOT_URL} target="_blank" rel="noopener noreferrer" className="btn-primary">
          Подключиться
        </a>
      </div>

      <Footer />
    </>
  );
}
