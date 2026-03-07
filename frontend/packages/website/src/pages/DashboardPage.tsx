import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import Navbar from '../components/Navbar';
import SupportWidget from '../components/SupportWidget';
import type { PublicConfig } from '../App';

interface Props {
  config: PublicConfig;
}

interface UserData {
  user: {
    telegram_id: number;
    name: string;
    username: string | null;
    balance: number;
    referral_balance: number;
    referral_code: string;
    role: string;
  };
  subscription: {
    status: string;
    plan_name: string | null;
    expire_at: string | null;
    url: string | null;
    traffic_used_gb: number | null;
    traffic_limit_gb: number | null;
    is_unlimited_traffic: boolean;
    device_limit: number | null;
    is_unlimited_devices: boolean;
  } | null;
  ref_link: string;
  bot_username: string;
  support_url: string | null;
  trial_available: boolean;
  ticket_unread: number;
  features: {
    balance_enabled: boolean;
    referral_enabled: boolean;
    trial_enabled: boolean;
  };
}

const STATUS_LABELS: Record<string, { label: string; className: string }> = {
  active: { label: 'Активна', className: 'status-active' },
  expired: { label: 'Истекла', className: 'status-expired' },
  disabled: { label: 'Отключена', className: 'status-expired' },
  none: { label: 'Нет подписки', className: 'status-none' },
};

function formatDate(iso: string | null): string {
  if (!iso) return '—';
  return new Date(iso).toLocaleDateString('ru-RU', { day: '2-digit', month: '2-digit', year: 'numeric' });
}

function formatGB(gb: number | null): string {
  if (gb === null) return '—';
  return gb >= 1 ? `${gb.toFixed(1)} ГБ` : `${(gb * 1024).toFixed(0)} МБ`;
}

export default function DashboardPage({ config }: Props) {
  const [data, setData] = useState<UserData | null>(null);
  const [loading, setLoading] = useState(true);
  const [copied, setCopied] = useState(false);
  const navigate = useNavigate();

  useEffect(() => {
    fetch('/web/api/user/data', { credentials: 'include' })
      .then((r) => {
        if (r.status === 401) {
          navigate('/');
          return null;
        }
        return r.ok ? r.json() : null;
      })
      .then((d) => {
        if (d) setData(d);
      })
      .catch(() => navigate('/'))
      .finally(() => setLoading(false));
  }, [navigate]);

  const handleLogout = async () => {
    await fetch('/web/api/auth/logout', { method: 'POST', credentials: 'include' });
    navigate('/');
  };

  const copyRefLink = () => {
    if (!data?.ref_link) return;
    navigator.clipboard.writeText(data.ref_link).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    });
  };

  if (loading) {
    return (
      <div className="dashboard-loading">
        <div className="spinner" />
        <p>Загрузка...</p>
      </div>
    );
  }

  if (!data) return null;

  const { user, subscription, ref_link, features, trial_available, support_url, ticket_unread } = data;
  const subStatus = subscription?.status || 'none';
  const statusInfo = STATUS_LABELS[subStatus] || { label: subStatus, className: 'status-none' };

  return (
    <div className="dashboard">
      <Navbar botUrl={config.bot_url} oauthProviders={config.oauth_providers} brand={config.brand} />

      <div className="dashboard-body">

        {/* Subscription card */}
        <div className="db-card">
          <div className="db-card-head">
            <span className="db-card-title">Подписка</span>
            <span className={`db-status ${statusInfo.className}`}>{statusInfo.label}</span>
          </div>

          {subscription ? (
            <div className="db-sub-details">
              {subscription.plan_name && (
                <div className="db-row">
                  <span className="db-label">Тариф</span>
                  <span className="db-value">{subscription.plan_name}</span>
                </div>
              )}
              <div className="db-row">
                <span className="db-label">Истекает</span>
                <span className="db-value">{formatDate(subscription.expire_at)}</span>
              </div>
              {!subscription.is_unlimited_traffic && (
                <div className="db-row">
                  <span className="db-label">Трафик</span>
                  <span className="db-value">
                    {formatGB(subscription.traffic_used_gb)} / {formatGB(subscription.traffic_limit_gb)}
                  </span>
                </div>
              )}
              {subscription.is_unlimited_traffic && (
                <div className="db-row">
                  <span className="db-label">Трафик</span>
                  <span className="db-value db-unlim">∞ Безлимит</span>
                </div>
              )}
              <div className="db-row">
                <span className="db-label">Устройства</span>
                <span className="db-value">
                  {subscription.is_unlimited_devices ? '∞ Безлимит' : subscription.device_limit}
                </span>
              </div>
              {subscription.url && (
                <a href={subscription.url} className="btn-primary db-sub-btn" target="_blank" rel="noopener noreferrer">
                  Подключить устройство
                </a>
              )}
            </div>
          ) : (
            <div className="db-empty-sub">
              <p>У вас пока нет активной подписки.</p>
              {trial_available && (
                <a href={config.bot_url || `https://t.me/${data.bot_username}`} target="_blank" rel="noopener noreferrer" className="btn-primary">
                  Попробовать бесплатно
                </a>
              )}
              {!trial_available && (
                <a href={config.bot_url || `https://t.me/${data.bot_username}`} target="_blank" rel="noopener noreferrer" className="btn-primary">
                  Подключиться
                </a>
              )}
            </div>
          )}
        </div>

        <div className="db-grid-2">
          {/* Balance card */}
          {features.balance_enabled && (
            <div className="db-card">
              <div className="db-card-head">
                <span className="db-card-title">Баланс</span>
              </div>
              <div className="db-balance-amount">{user.balance} ₽</div>
              {features.referral_enabled && user.referral_balance > 0 && (
                <div className="db-row" style={{ marginTop: 8 }}>
                  <span className="db-label">Реферальный</span>
                  <span className="db-value db-green">+{user.referral_balance} ₽</span>
                </div>
              )}
              <a
                href={config.bot_url || `https://t.me/${data.bot_username}`}
                target="_blank"
                rel="noopener noreferrer"
                className="db-link-btn"
              >
                Пополнить →
              </a>
            </div>
          )}

          {/* Referral card */}
          {features.referral_enabled && (
            <div className="db-card">
              <div className="db-card-head">
                <span className="db-card-title">Реферальная программа</span>
              </div>
              <p className="db-ref-hint">Приглашайте друзей и получайте бонусы</p>
              <div className="db-ref-link-row">
                <input
                  type="text"
                  value={ref_link}
                  readOnly
                  className="db-ref-input"
                  onClick={(e) => (e.target as HTMLInputElement).select()}
                />
                <button className="db-copy-btn" onClick={copyRefLink}>
                  {copied ? '✓' : '⎘'}
                </button>
              </div>
            </div>
          )}
        </div>

        {/* Bottom actions */}
        <div className="db-actions">
          <a
            href={config.bot_url || `https://t.me/${data.bot_username}`}
            target="_blank"
            rel="noopener noreferrer"
            className="db-action-btn"
          >
            <span>🤖</span> Открыть бота
          </a>
          {support_url && (
            <a href={support_url} target="_blank" rel="noopener noreferrer" className="db-action-btn">
              <span>💬</span> Поддержка
              {ticket_unread > 0 && <span className="db-badge">{ticket_unread}</span>}
            </a>
          )}
          <button className="db-action-btn db-action-logout" onClick={handleLogout}>
            <span>🚪</span> Выйти
          </button>
        </div>

      </div>
      <SupportWidget logoUrl={config.brand?.logo} />
    </div>
  );
}
