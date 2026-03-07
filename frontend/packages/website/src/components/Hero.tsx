interface HeroProps {
  botUrl: string;
}

export default function Hero({ botUrl }: HeroProps) {
  return (
    <section className="hero">
      <div className="hero-badge">
        <span>✨</span>
        VPN без ограничений
      </div>
      <h1>Быстрый и надежный<br />VPN-сервис</h1>
      <p className="hero-subtitle">
        Безлимитный трафик, высокая скорость и доступ ко всем сервисам.
        Подключение за 30 секунд через Telegram-бот.
      </p>
      <div className="hero-actions">
        <a href={botUrl} target="_blank" rel="noopener noreferrer" className="btn-primary">
          Подключиться
        </a>
        <a href="#plans" className="btn-secondary">
          Тарифы
        </a>
      </div>
    </section>
  );
}
