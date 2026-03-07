import { useState, useEffect, useRef } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import LoginModal from './LoginModal';

import type { BrandConfig } from '../App';

interface NavbarProps {
  botUrl: string;
  oauthProviders?: { google: boolean; github: boolean };
  brand?: BrandConfig;
}

interface AuthUser {
  name: string;
  telegram_id: number;
  balance?: number;
  referral_balance?: number;
  balance_mode?: string; // "unified" or "separate"
  role?: string;
}

const DEFAULT_LOGO = 'https://i.ibb.co/Xxn6D4vD/small-logo.png';
const DEFAULT_NAME = 'Remnasale';

export default function Navbar({ botUrl, oauthProviders, brand }: NavbarProps) {
  const logoSrc = brand?.logo || DEFAULT_LOGO;
  const siteName = brand?.name || DEFAULT_NAME;
  const [authUser, setAuthUser] = useState<AuthUser | null>(null);
  const [showModal, setShowModal] = useState(false);
  const [showMenu, setShowMenu] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);
  const navigate = useNavigate();
  const location = useLocation();

  useEffect(() => {
    fetch('/web/api/user/data', { credentials: 'include' })
      .then((r) => (r.ok ? r.json() : null))
      .then((d) => {
        if (d?.user) setAuthUser({
          name: d.user.name,
          telegram_id: d.user.telegram_id,
          balance: d.user.balance ?? 0,
          referral_balance: d.user.referral_balance ?? 0,
          balance_mode: d.features?.balance_mode ?? 'separate',
          role: d.user.role,
        });
      })
      .catch(() => {});
  }, [location.pathname]);

  // Close menu on outside click
  useEffect(() => {
    const handleClick = (e: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        setShowMenu(false);
      }
    };
    if (showMenu) document.addEventListener('mousedown', handleClick);
    return () => document.removeEventListener('mousedown', handleClick);
  }, [showMenu]);

  const handleLogout = async () => {
    await fetch('/web/api/auth/logout', { method: 'POST', credentials: 'include' });
    setAuthUser(null);
    setShowMenu(false);
    navigate('/');
  };

  return (
    <>
      <nav className="navbar">
        <div className="navbar-inner">
          <a className="navbar-brand" href="/" onClick={(e) => { e.preventDefault(); navigate('/'); }}>
            <img src={logoSrc} alt="Logo" className="navbar-logo-img" />
            {siteName}
          </a>
          <div className="navbar-nav">
            <a href="/" onClick={(e) => { e.preventDefault(); navigate('/'); window.scrollTo({ top: 0, behavior: 'smooth' }); }}>Главная</a>
            <a href="/#features">Преимущества</a>
            <a href="/#plans">Тарифы</a>
            {botUrl && (
              <a href={botUrl} target="_blank" rel="noopener noreferrer">
                Подключиться
              </a>
            )}
          </div>
          <div className="navbar-right">
            {authUser ? (
              <div className="navbar-user-wrap" ref={menuRef}>
                <div className="navbar-balance-info">
                  <span className="navbar-balance-main">{authUser.balance ?? 0} ₽</span>
                  {authUser.balance_mode !== 'unified' && (authUser.referral_balance ?? 0) > 0 && (
                    <span className="navbar-balance-bonus">+{authUser.referral_balance} ₽</span>
                  )}
                </div>
                <button
                  className="navbar-user-btn"
                  onClick={() => setShowMenu(!showMenu)}
                >
                  <div className="navbar-avatar">{authUser.name.charAt(0).toUpperCase()}</div>
                  <span className="navbar-username">{authUser.name}</span>
                  <svg className={`navbar-chevron${showMenu ? ' open' : ''}`} viewBox="0 0 20 20" fill="currentColor" width="14" height="14"><path fillRule="evenodd" d="M5.23 7.21a.75.75 0 0 1 1.06.02L10 11.17l3.71-3.94a.75.75 0 1 1 1.08 1.04l-4.25 4.5a.75.75 0 0 1-1.08 0l-4.25-4.5a.75.75 0 0 1 .02-1.06z" clipRule="evenodd" /></svg>
                </button>
                {showMenu && (
                  <div className="navbar-dropdown">
                    <button className="navbar-dd-item" onClick={() => { setShowMenu(false); navigate('/dashboard'); }}>
                      <span>📊</span> Личный кабинет
                    </button>
                    <a className="navbar-dd-item" href={botUrl} target="_blank" rel="noopener noreferrer" onClick={() => setShowMenu(false)}>
                      <span>💳</span> Пополнения
                    </a>
                    <a className="navbar-dd-item" href={botUrl} target="_blank" rel="noopener noreferrer" onClick={() => setShowMenu(false)}>
                      <span>📥</span> Скачать
                    </a>
                    <a className="navbar-dd-item" href={botUrl} target="_blank" rel="noopener noreferrer" onClick={() => setShowMenu(false)}>
                      <span>🔌</span> Подключиться
                    </a>
                    <div className="navbar-dd-divider" />
                    <button className="navbar-dd-item" onClick={() => { setShowMenu(false); navigate('/support'); }}>
                      <span>💬</span> Поддержка
                    </button>
                    {authUser.role === 'DEV' && (
                      <>
                        <div className="navbar-dd-divider" />
                        <button className="navbar-dd-item" onClick={() => { setShowMenu(false); navigate('/system'); }}>
                          <span>⚙️</span> Администрирование
                        </button>
                      </>
                    )}
                    <div className="navbar-dd-divider" />
                    <button className="navbar-dd-item navbar-dd-logout" onClick={handleLogout}>
                      <span>🚪</span> Выход
                    </button>
                  </div>
                )}
              </div>
            ) : (
              <button className="navbar-login-btn" onClick={() => setShowModal(true)}>
                Вход
              </button>
            )}
          </div>
        </div>
      </nav>

      {showModal && (
        <LoginModal
          onClose={() => setShowModal(false)}
          onSuccess={(user) => {
            setAuthUser({ ...user, balance: 0, referral_balance: 0 });
            setShowModal(false);
            navigate('/dashboard');
          }}
          oauthProviders={oauthProviders}
        />
      )}
    </>
  );
}
