import { useState } from 'react';

interface FAQItem {
  q: string;
  a: string;
}

const DEFAULT_ITEMS: FAQItem[] = [
  {
    q: 'Как подключиться к VPN?',
    a: 'Откройте нашего Telegram-бота, выберите тарифный план, оплатите и получите ключ подключения. Весь процесс занимает менее минуты.',
  },
  {
    q: 'Какие устройства поддерживаются?',
    a: 'Windows, macOS, Linux, Android и iOS. Одна подписка может использоваться на нескольких устройствах одновременно (лимит зависит от тарифа).',
  },
  {
    q: 'Есть ли ограничения по трафику?',
    a: 'На большинстве тарифов трафик безлимитный. Подробности указаны в описании каждого тарифного плана.',
  },
  {
    q: 'Какие способы оплаты доступны?',
    a: 'Банковские карты, криптовалюта, Telegram Stars и другие способы оплаты через Telegram-бота.',
  },
  {
    q: 'Ведутся ли логи активности?',
    a: 'Нет. Мы не храним логи вашей интернет-активности. Ваша конфиденциальность — наш приоритет.',
  },
  {
    q: 'Можно ли попробовать бесплатно?',
    a: 'Да, мы предоставляем пробный период. Откройте бота и выберите пробную подписку.',
  },
  {
    q: 'Работает ли VPN с российскими сервисами?',
    a: 'Да! Наш VPN не блокирует доступ к российским сайтам и приложениям — ВКонтакте, Госуслуги, банки и другие сервисы работают без проблем.',
  },
];

interface Props {
  items?: { q: string; a: string; active: boolean }[];
}

export default function FAQ({ items }: Props) {
  const [openIdx, setOpenIdx] = useState<number | null>(null);

  const faqItems: FAQItem[] = (items && items.length > 0)
    ? items.filter(i => i.active).map(({ q, a }) => ({ q, a }))
    : DEFAULT_ITEMS;

  return (
    <section className="section" id="faq">
      <div className="section-title-row">
        <h2>Часто задаваемые вопросы</h2>
        <div className="section-title-line" />
      </div>
      <div className="faq-list">
        {faqItems.map((item, i) => {
          const isOpen = openIdx === i;
          return (
            <div className={`faq-item${isOpen ? ' open' : ''}`} key={i}>
              <button className="faq-question" onClick={() => setOpenIdx(isOpen ? null : i)}>
                <span>{item.q}</span>
                <svg
                  className={`faq-chevron${isOpen ? ' open' : ''}`}
                  viewBox="0 0 20 20"
                  fill="currentColor"
                  width="18"
                  height="18"
                >
                  <path
                    fillRule="evenodd"
                    d="M5.23 7.21a.75.75 0 0 1 1.06.02L10 11.17l3.71-3.94a.75.75 0 1 1 1.08 1.04l-4.25 4.5a.75.75 0 0 1-1.08 0l-4.25-4.5a.75.75 0 0 1 .02-1.06z"
                    clipRule="evenodd"
                  />
                </svg>
              </button>
              <div className="faq-answer-wrap" style={{ maxHeight: isOpen ? 300 : 0 }}>
                <div className="faq-answer">{item.a}</div>
              </div>
            </div>
          );
        })}
      </div>
    </section>
  );
}
