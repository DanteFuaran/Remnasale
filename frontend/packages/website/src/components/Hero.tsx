interface HeroProps {
  botUrl: string;
  slogan?: string;
  badge?: string;
  title?: string;
  subtitle?: string;
}

const DEFAULT_BADGE = 'Интернет без ограничений';
const DEFAULT_TITLE = 'Быстрый и надежный VPN-сервис';
const DEFAULT_SUBTITLE = 'Стабильный сервис, для свободного интернета.\nБесплатный пробный период без привязки карт.';

export default function Hero({ botUrl, slogan, badge, title, subtitle }: HeroProps) {
  const displayBadge = badge || DEFAULT_BADGE;
  const displayTitle = title || DEFAULT_TITLE;
  const displaySubtitle = subtitle || slogan || DEFAULT_SUBTITLE;
  return (
    <section className="hero">
      <div className="hero-badge">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10"/><line x1="2" y1="12" x2="22" y2="12"/><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/></svg>
        {displayBadge}
      </div>
      <h1>{displayTitle.split('\n').map((line, i, arr) => (
        <span key={i}>{line}{i < arr.length - 1 && <br />}</span>
      ))}</h1>
      <p className="hero-subtitle">
        {displaySubtitle.split('\n').map((line, i, arr) => (
          <span key={i}>{line}{i < arr.length - 1 && <br />}</span>
        ))}
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
