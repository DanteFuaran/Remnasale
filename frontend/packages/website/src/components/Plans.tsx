import { useEffect, useState } from 'react';
import type { Plan } from '@dfc/shared';
import { formatPrice, pluralRu } from '@dfc/shared';

interface PlansProps {
  botUrl: string;
}

function formatDuration(days: number): string {
  if (days === 30) return '1 месяц';
  if (days === 90) return '3 месяца';
  if (days === 180) return '6 месяцев';
  if (days === 365) return '1 год';
  return `${days} ${pluralRu(days, 'день', 'дня', 'дней')}`;
}

function getPerMonth(amount: string, days: number): string {
  const n = parseFloat(amount);
  if (isNaN(n) || days <= 0) return '';
  const monthly = (n / days) * 30;
  return formatPrice(Math.round(monthly));
}

function computeSavings(durations: Plan['durations']): Map<number, number> {
  const map = new Map<number, number>();
  if (durations.length < 2) return map;
  // Find the shortest duration as baseline
  const sorted = [...durations].sort((a, b) => a.days - b.days);
  const basePPD =
    parseFloat(sorted[0].prices[0]?.amount ?? '0') / sorted[0].days;
  if (basePPD <= 0) return map;

  for (let i = 1; i < sorted.length; i++) {
    const ppd = parseFloat(sorted[i].prices[0]?.amount ?? '0') / sorted[i].days;
    const pct = Math.round(((basePPD - ppd) / basePPD) * 100);
    if (pct > 0) map.set(sorted[i].days, pct);
  }
  return map;
}

const CURRENCY_SYMBOLS: Record<string, string> = {
  USD: '$',
  EUR: '€',
  XTR: '★',
  RUB: '₽',
};

/** Pick the best price to display: prefer RUB, skip XTR, fallback to first */
function pickPrice(prices: { currency: string; amount: string }[]) {
  if (!prices.length) return null;
  const rub = prices.find((p) => p.currency === 'RUB');
  if (rub) return rub;
  const nonStars = prices.find((p) => p.currency !== 'XTR');
  return nonStars ?? prices[0];
}

export default function Plans({ botUrl }: PlansProps) {
  const [plans, setPlans] = useState<Plan[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Fetch plans from public API
    fetch('/web/api/public/plans')
      .then((r) => {
        if (!r.ok) throw new Error('not available');
        return r.json();
      })
      .then((data: Plan[]) => {
        setPlans(data);
        setLoading(false);
      })
      .catch(() => {
        setLoading(false);
      });
  }, []);

  return (
    <section className="section plans-section" id="plans">
      <div className="section-title-row">
        <h2>Тарифы</h2>
        <div className="section-title-line" />
      </div>

      {loading ? (
        <div className="loading-plans">
          <div className="spinner" />
          <p>Загрузка тарифов...</p>
        </div>
      ) : plans.length === 0 ? (
        <div className="loading-plans">
          <p style={{ fontSize: '1.05rem', color: 'var(--text2)' }}>
            Для просмотра тарифов перейдите в бот
          </p>
          <div style={{ marginTop: 20 }}>
            <a href={botUrl} target="_blank" rel="noopener noreferrer" className="btn-primary">
              Открыть бот
            </a>
          </div>
        </div>
      ) : (
        <div className="plans-grid">
          {plans.map((plan, idx) => {
            const savings = computeSavings(plan.durations);
            const isFeatured = idx === Math.min(1, plans.length - 1) && plans.length > 1;

            return (
              <div className={`plan-card${isFeatured ? ' featured' : ''}`} key={plan.id}>
                {isFeatured && <div className="plan-badge">Популярный</div>}
                <div className="plan-name">{plan.name}</div>
                <div className="plan-desc">{plan.description || '\u00A0'}</div>

                <div className="plan-meta">
                  {(plan as any).is_unlimited_traffic ? (
                    <span className="plan-meta-item">📊 Безлимит</span>
                  ) : plan.traffic_limit != null && plan.traffic_limit > 0 ? (
                    <span className="plan-meta-item">📊 {plan.traffic_limit} ГБ</span>
                  ) : null}
                  {(plan as any).is_unlimited_devices ? (
                    <span className="plan-meta-item">📱 Безлимит устройств</span>
                  ) : plan.device_limit != null && plan.device_limit > 0 ? (
                    <span className="plan-meta-item">
                      📱 {plan.device_limit} {pluralRu(plan.device_limit, 'устройство', 'устройства', 'устройств')}
                    </span>
                  ) : null}
                </div>

                <div className="plan-durations">
                  {plan.durations.map((dur) => {
                    const price = pickPrice(dur.prices);
                    if (!price) return null;
                    const sym = CURRENCY_SYMBOLS[price.currency] ?? price.currency;
                    const savPct = savings.get(dur.days);

                    return (
                      <div className="plan-dur" key={dur.days}>
                        <span className="plan-dur-period">{formatDuration(dur.days)}</span>
                        <span className="plan-dur-price">
                          {formatPrice(price.amount)} {sym}
                          {dur.days > 30 && (
                            <span style={{ fontSize: '.72rem', color: 'var(--text3)', marginLeft: 6, fontWeight: 500 }}>
                              ~{getPerMonth(price.amount, dur.days)} {sym}/мес
                            </span>
                          )}
                        </span>
                        {savPct && <span className="plan-dur-savings">-{savPct}%</span>}
                      </div>
                    );
                  })}
                </div>

                <a href={botUrl} target="_blank" rel="noopener noreferrer" className="plan-cta">
                  Подключить
                </a>
              </div>
            );
          })}
        </div>
      )}
    </section>
  );
}
