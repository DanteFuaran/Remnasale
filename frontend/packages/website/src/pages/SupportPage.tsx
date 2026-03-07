import { useState, useEffect, useRef, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import Navbar from '../components/Navbar';
import type { PublicConfig } from '../App';

function formatMsgTime(dateStr: string, tz: string): string {
  try {
    if (!dateStr) return '';
    let s = dateStr.trim();
    if (!s.includes('T') && s.includes(' ')) s = s.replace(' ', 'T');
    if (!s.includes('+') && !s.toLowerCase().includes('z')) s += 'Z';
    const d = new Date(s);
    if (isNaN(d.getTime())) return dateStr;
    return d.toLocaleString('ru-RU', { timeZone: tz, day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' });
  } catch { return dateStr; }
}

interface Props {
  config: PublicConfig;
}

interface TicketMessage {
  id: number;
  is_admin: boolean;
  text: string;
  created_at: string;
}

interface Ticket {
  id: number;
  subject: string;
  status: string;
  is_read_by_user: boolean;
  created_at: string;
  updated_at: string;
  messages: TicketMessage[];
}

const STATUS_LABELS: Record<string, string> = {
  OPEN: 'Открыт',
  ANSWERED: 'Отвечен',
  CLOSED: 'Закрыт',
};
const STATUS_COLORS: Record<string, string> = {
  OPEN: '#24C4F1',
  ANSWERED: '#4ADE80',
  CLOSED: '#888',
};

export default function SupportPage({ config }: Props) {
  const navigate = useNavigate();
  const [authed, setAuthed] = useState(false);
  const [checking, setChecking] = useState(true);
  const [tickets, setTickets] = useState<Ticket[]>([]);
  const [activeTicket, setActiveTicket] = useState<Ticket | null>(null);
  const [showNew, setShowNew] = useState(false);
  const [newSubject, setNewSubject] = useState('');
  const [newText, setNewText] = useState('');
  const [replyText, setReplyText] = useState('');
  const [sending, setSending] = useState(false);
  const [error, setError] = useState('');
  const chatEndRef = useRef<HTMLDivElement>(null);
  const [lightboxUrl, setLightboxUrl] = useState<string | null>(null);

  function renderMsgText(text: string) {
    const parts = text.split(/(\[IMG\][^\s\n]+)/g);
    return parts.map((part, i) => {
      if (part.startsWith('[IMG]')) {
        const url = part.slice(5);
        return <img key={i} src={url} alt="" className="chat-msg-image" onClick={() => setLightboxUrl(url)} />;
      }
      return part ? <span key={i} style={{ whiteSpace: 'pre-wrap', wordBreak: 'break-word' }}>{part}</span> : null;
    });
  }

  useEffect(() => {
    fetch('/web/api/user/data', { credentials: 'include' })
      .then((r) => (r.ok ? r.json() : null))
      .then((d) => {
        if (d?.user) {
          setAuthed(true);
        } else {
          navigate('/', { replace: true });
        }
      })
      .catch(() => navigate('/', { replace: true }))
      .finally(() => setChecking(false));
  }, [navigate]);

  const loadTickets = useCallback(async () => {
    try {
      const r = await fetch('/web/api/tickets', { credentials: 'include' });
      if (r.ok) {
        const data = await r.json();
        setTickets(data);
      }
    } catch { /* ignore */ }
  }, []);

  useEffect(() => {
    if (authed) loadTickets();
  }, [authed, loadTickets]);

  useEffect(() => {
    chatEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [activeTicket?.messages?.length]);

  const openTicket = async (id: number) => {
    try {
      const r = await fetch(`/web/api/tickets/${id}`, { credentials: 'include' });
      if (r.ok) {
        const t = await r.json();
        setActiveTicket(t);
        setShowNew(false);
        // Update read status in list
        setTickets((prev) => prev.map((tt) => tt.id === id ? { ...tt, is_read_by_user: true } : tt));
      }
    } catch { /* ignore */ }
  };

  const handleCreate = async () => {
    if (!newSubject.trim() || !newText.trim()) {
      setError('Заполните тему и сообщение');
      return;
    }
    setSending(true);
    setError('');
    try {
      const r = await fetch('/web/api/tickets', {
        method: 'POST',
        credentials: 'include',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ subject: newSubject.trim(), text: newText.trim() }),
      });
      if (r.ok) {
        const t = await r.json();
        setActiveTicket(t);
        setShowNew(false);
        setNewSubject('');
        setNewText('');
        loadTickets();
      } else {
        const err = await r.json().catch(() => ({}));
        setError(err.detail || 'Ошибка создания');
      }
    } catch {
      setError('Ошибка сети');
    } finally {
      setSending(false);
    }
  };

  const handleReply = async () => {
    if (!replyText.trim() || !activeTicket) return;
    setSending(true);
    try {
      const r = await fetch(`/web/api/tickets/${activeTicket.id}/reply`, {
        method: 'POST',
        credentials: 'include',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: replyText.trim() }),
      });
      if (r.ok) {
        const t = await r.json();
        setActiveTicket(t);
        setReplyText('');
        loadTickets();
      }
    } catch { /* ignore */ }
    finally { setSending(false); }
  };

  const handleClose = async () => {
    if (!activeTicket) return;
    try {
      const r = await fetch(`/web/api/tickets/${activeTicket.id}/close`, {
        method: 'POST',
        credentials: 'include',
      });
      if (r.ok) {
        const t = await r.json();
        setActiveTicket(t);
        loadTickets();
      }
    } catch { /* ignore */ }
  };

  if (checking) return null;

  return (
    <>
      <Navbar botUrl={config.bot_url} oauthProviders={config.oauth_providers} brand={config.brand} />
      <div className="support-layout">
        {/* Sidebar — ticket list */}
        <aside className="support-sidebar">
          <div className="support-sidebar-header">
            <h3>Обращения</h3>
            <button className="btn-primary support-new-btn" onClick={() => { setShowNew(true); setActiveTicket(null); }}>
              + Новое
            </button>
          </div>
          <div className="support-ticket-list">
            {tickets.length === 0 && (
              <p className="support-empty">Нет обращений</p>
            )}
            {tickets.map((t) => (
              <button
                key={t.id}
                className={`support-ticket-item${activeTicket?.id === t.id ? ' active' : ''}${!t.is_read_by_user ? ' unread' : ''}`}
                onClick={() => openTicket(t.id)}
              >
                <div className="support-ticket-item-top">
                  <span className="support-ticket-subject">{t.subject}</span>
                  <span
                    className="support-ticket-status"
                    style={{ color: STATUS_COLORS[t.status] || '#888' }}
                  >
                    {STATUS_LABELS[t.status] || t.status}
                  </span>
                </div>
                <div className="support-ticket-item-bottom">
                  <span className="support-ticket-date">{formatMsgTime(t.updated_at, config.brand.timezone ?? 'Europe/Moscow')}</span>
                  {!t.is_read_by_user && <span className="support-unread-dot" />}
                </div>
              </button>
            ))}
          </div>
        </aside>

        {/* Main content */}
        <main className="support-main">
          {/* New ticket form */}
          {showNew && (
            <div className="db-card">
              <div className="db-card-header">
                <h2 className="db-card-title">Новое обращение</h2>
              </div>
              <div className="admin-form">
                <div className="admin-field">
                  <label className="admin-label">Тема</label>
                  <input
                    type="text"
                    className="admin-input"
                    placeholder="Кратко опишите проблему"
                    maxLength={200}
                    value={newSubject}
                    onChange={(e) => setNewSubject(e.target.value)}
                  />
                </div>
                <div className="admin-field">
                  <label className="admin-label">Сообщение</label>
                  <textarea
                    className="admin-input admin-textarea"
                    placeholder="Подробно опишите вашу проблему..."
                    rows={5}
                    value={newText}
                    onChange={(e) => setNewText(e.target.value)}
                  />
                </div>
                {error && <div className="admin-save-msg err">{error}</div>}
                <button className="btn-primary admin-save-btn" onClick={handleCreate} disabled={sending}>
                  {sending ? 'Отправка...' : 'Отправить'}
                </button>
              </div>
            </div>
          )}

          {/* Active ticket chat */}
          {activeTicket && !showNew && (
            <div className="support-chat-card">
              <div className="support-chat-header">
                <div>
                  <h2 className="support-chat-subject">{activeTicket.subject}</h2>
                  <span
                    className="support-ticket-status"
                    style={{ color: STATUS_COLORS[activeTicket.status] || '#888' }}
                  >
                    {STATUS_LABELS[activeTicket.status] || activeTicket.status}
                  </span>
                  <span className="support-chat-date">Создан: {formatMsgTime(activeTicket.created_at, config.brand.timezone ?? 'Europe/Moscow')}</span>
                </div>
                {activeTicket.status !== 'CLOSED' && (
                  <button className="support-close-btn" onClick={handleClose} title="Закрыть тикет">
                    Закрыть тикет
                  </button>
                )}
              </div>

              <div className="support-chat-messages">
                {activeTicket.messages.map((m) => (
                  <div key={m.id} className={`support-msg ${m.is_admin ? 'admin' : 'user'}`}>
                    <div className="support-msg-bubble">
                      <span className="support-msg-sender">{m.is_admin ? '🛡️ Поддержка' : '👤 Вы'}</span>
                      <p className="support-msg-text">{renderMsgText(m.text)}</p>
                      <span className="support-msg-time">{formatMsgTime(m.created_at, config.brand.timezone ?? 'Europe/Moscow')}</span>
                    </div>
                  </div>
                ))}
                <div ref={chatEndRef} />
              </div>

              {activeTicket.status !== 'CLOSED' && (
                <div className="support-chat-input">
                  <textarea
                    className="admin-input"
                    placeholder="Введите сообщение..."
                    rows={2}
                    value={replyText}
                    onChange={(e) => setReplyText(e.target.value)}
                    onKeyDown={(e) => {
                      if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); handleReply(); }
                    }}
                  />
                  <button className="btn-primary" onClick={handleReply} disabled={sending || !replyText.trim()}>
                    {sending ? '...' : 'Отправить'}
                  </button>
                </div>
              )}
            </div>
          )}

          {/* Empty state */}
          {!showNew && !activeTicket && (
            <div className="support-empty-state">
              <div className="support-empty-icon">💬</div>
              <h3>Выберите обращение или создайте новое</h3>
              <p>Мы готовы помочь вам с любым вопросом</p>
            </div>
          )}
        </main>
      </div>

      {/* Image lightbox */}
      {lightboxUrl && (
        <div className="lightbox-overlay" onClick={() => setLightboxUrl(null)}>
          <button className="lightbox-close" onClick={() => setLightboxUrl(null)}>✕</button>
          <img src={lightboxUrl} alt="" className="lightbox-img" onClick={(e) => e.stopPropagation()} />
        </div>
      )}
    </>
  );
}
