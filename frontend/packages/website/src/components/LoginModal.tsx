import { useEffect, useRef, useState } from 'react';

interface Props {
  onClose: () => void;
  onSuccess: (user: { name: string; telegram_id: number }) => void;
  oauthProviders?: { google: boolean; github: boolean };
}

type TgStep = 'idle' | 'waiting';

export default function LoginModal({ onClose, onSuccess, oauthProviders }: Props) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [tgStep, setTgStep] = useState<TgStep>('idle');
  const [tgBotLink, setTgBotLink] = useState('');
  const pollRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const expireRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const tgWindowRef = useRef<Window | null>(null);

  // Clean up polling on unmount
  useEffect(() => {
    return () => {
      if (pollRef.current) clearInterval(pollRef.current);
      if (expireRef.current) clearTimeout(expireRef.current);
      try { tgWindowRef.current?.close(); } catch {}
    };
  }, []);

  const stopPolling = () => {
    if (pollRef.current) { clearInterval(pollRef.current); pollRef.current = null; }
    if (expireRef.current) { clearTimeout(expireRef.current); expireRef.current = null; }
  };

  const closeTgWindow = () => {
    try { tgWindowRef.current?.close(); } catch {}
    tgWindowRef.current = null;
  };

  const startTgAuth = async () => {
    setLoading(true);
    setError('');
    try {
      const r = await fetch('/web/api/auth/tg-bot/start', {
        method: 'POST',
        credentials: 'include',
      });
      const d = await r.json();
      if (!r.ok) {
        setError(d.detail || 'Не удалось начать авторизацию');
        return;
      }

      setTgBotLink(d.bot_link);
      setTgStep('waiting');
      // Keep window reference so we can close it after auth completes
      tgWindowRef.current = window.open(d.bot_link, '_blank') || null;

      // Poll every 1.5s for confirmation
      pollRef.current = setInterval(async () => {
        try {
          const pr = await fetch(`/web/api/auth/tg-bot/poll/${d.token}`, {
            credentials: 'include',
          });
          if (pr.status === 404) {
            stopPolling();            closeTgWindow();            setTgStep('idle');
            setError('Время ожидания истекло. Попробуйте ещё раз.');
            return;
          }
          const pd = await pr.json();
          if (pd.status === 'ok') {
            stopPolling();
            closeTgWindow();
            const profileResp = await fetch('/web/api/user/data', { credentials: 'include' });
            const profile = profileResp.ok ? await profileResp.json() : null;
            onSuccess({
              name: profile?.user?.name || pd.name || 'Пользователь',
              telegram_id: pd.telegram_id,
            });
          }
        } catch {
          // network hiccup — keep polling
        }
      }, 1500);

      // Auto-expire after 5 minutes
      expireRef.current = setTimeout(() => {
        stopPolling();
        closeTgWindow();
        setTgStep('idle');
        setError('Время ожидания истекло. Попробуйте ещё раз.');
      }, 300_000);
    } catch {
      setError('Ошибка сети');
    } finally {
      setLoading(false);
    }
  };

  const cancelTgAuth = () => {
    stopPolling();
    closeTgWindow();
    setTgStep('idle');
    setTgBotLink('');
    setError('');
  };

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content" onClick={(e) => e.stopPropagation()}>
        <button className="modal-close" onClick={onClose} aria-label="Закрыть">×</button>
        <h2 className="modal-title">Войти в аккаунт</h2>
        <p className="modal-subtitle">Выберите способ входа</p>

        {error && <div className="modal-error">{error}</div>}

        <div className="login-options">
          {/* Telegram bot deeplink auth */}
          {tgStep === 'idle' ? (
            <button
              className="login-option-btn login-option-tg-bot"
              onClick={startTgAuth}
              disabled={loading}
            >
              <svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor" aria-hidden="true">
                <path d="M12 0C5.373 0 0 5.373 0 12s5.373 12 12 12 12-5.373 12-12S18.627 0 12 0zm5.894 8.221-1.97 9.28c-.145.658-.537.818-1.084.508l-3-2.21-1.447 1.394c-.16.16-.295.295-.605.295l.213-3.053 5.56-5.023c.242-.213-.054-.333-.373-.12l-6.871 4.326-2.962-.924c-.643-.204-.657-.643.136-.953l11.57-4.461c.537-.194 1.006.131.833.941z"/>
              </svg>
              Войти через Telegram
            </button>
          ) : (
            <div className="tg-waiting-block">
              <div className="tg-waiting-status">
                <div className="spinner" style={{ width: 20, height: 20, flexShrink: 0 }} />
                <span>Ожидаем подтверждения в Telegram...</span>
              </div>
              <a
                href={tgBotLink}
                target="_blank"
                rel="noopener noreferrer"
                className="login-option-btn login-option-tg-bot"
                style={{ textAlign: 'center' }}
              >
                Открыть Telegram ещё раз
              </a>
              <button className="tg-cancel-btn" onClick={cancelTgAuth}>
                Отмена
              </button>
            </div>
          )}

          {/* Google OAuth */}
          {oauthProviders?.google && (
            <a
              href="/web/api/auth/oauth/google"
              className="login-option-btn login-option-google"
            >
              <svg viewBox="0 0 24 24" width="20" height="20" aria-hidden="true">
                <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
                <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
                <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l3.66-2.84z"/>
                <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
              </svg>
              Войти через Google
            </a>
          )}

          {/* GitHub OAuth */}
          {oauthProviders?.github && (
            <a
              href="/web/api/auth/oauth/github"
              className="login-option-btn login-option-github"
            >
              <svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor" aria-hidden="true">
                <path d="M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12"/>
              </svg>
              Войти через GitHub
            </a>
          )}
        </div>

        {loading && (
          <div className="modal-loading">
            <div className="spinner" />
            <span>Подготавливаем вход...</span>
          </div>
        )}
      </div>
    </div>
  );
}

