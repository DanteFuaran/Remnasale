import {
  CheckCircle,
  Lock,
  Infinity,
  Headphones,
  MonitorSmartphone,
  EyeOff,
} from 'lucide-react';

const ADVANTAGES = [
  {
    icon: <Infinity size={20} />,
    title: 'Без лимита трафика',
    desc: 'Смотрите, качайте и стримьте без ограничений.',
  },
  {
    icon: <CheckCircle size={20} />,
    title: 'Без рекламы',
    desc: 'YouTube, сайты и приложения без рекламных вставок.',
  },
  {
    icon: <Lock size={20} />,
    title: 'Шифрование данных',
    desc: 'Весь трафик защищен современными протоколами.',
  },
  {
    icon: <Headphones size={20} />,
    title: 'Техподдержка',
    desc: 'Поддержка через Telegram — ответим быстро.',
  },
  {
    icon: <MonitorSmartphone size={20} />,
    title: 'Все платформы',
    desc: 'Работает на Windows, macOS, Android и iOS.',
  },
  {
    icon: <EyeOff size={20} />,
    title: 'Без отслеживания',
    desc: 'Не храним логи вашей активности.',
  },
];

export default function Advantages() {
  return (
    <section className="section" id="advantages">
      <div className="section-header">
        <h2>Преимущества</h2>
        <p>Почему выбирают нас</p>
      </div>
      <div className="advantages">
        {ADVANTAGES.map((a, i) => (
          <div className="advantage-item" key={i}>
            <div className="advantage-icon">{a.icon}</div>
            <div>
              <h4>{a.title}</h4>
              <p>{a.desc}</p>
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}
