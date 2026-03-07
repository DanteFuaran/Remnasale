import {
  Shield,
  Zap,
  Globe,
  CreditCard,
  Users,
  Smartphone,
} from 'lucide-react';

const FEATURES = [
  {
    icon: <Zap size={22} />,
    title: 'Высокая скорость',
    desc: 'Низкий пинг и стабильное соединение для комфортной работы и стриминга.',
  },
  {
    icon: <Globe size={22} />,
    title: 'Множество локаций',
    desc: 'Серверы в Европе, США, Азии и других регионах без ограничений по трафику.',
  },
  {
    icon: <Shield size={22} />,
    title: 'Безопасность',
    desc: 'Шифрование трафика и защита данных. Никаких логов вашей активности.',
  },
  {
    icon: <CreditCard size={22} />,
    title: 'Удобная оплата',
    desc: 'Банковские карты, криптовалюта, Telegram Stars и другие способы.',
  },
  {
    icon: <Users size={22} />,
    title: 'Реферальная система',
    desc: 'Приглашайте друзей и получайте бонусы на баланс или дополнительные дни.',
  },
  {
    icon: <Smartphone size={22} />,
    title: 'Все устройства',
    desc: 'Windows, macOS, Android, iOS — одна подписка для всех ваших устройств.',
  },
];

export default function Features() {
  return (
    <section className="section" id="features">
      <div className="section-header">
        <h2>Возможности</h2>
        <p>Всё что нужно для свободного интернета</p>
      </div>
      <div className="features-grid">
        {FEATURES.map((f, i) => (
          <div className="feature-card" key={i}>
            <div className="feature-icon">{f.icon}</div>
            <h3>{f.title}</h3>
            <p>{f.desc}</p>
          </div>
        ))}
      </div>
    </section>
  );
}
