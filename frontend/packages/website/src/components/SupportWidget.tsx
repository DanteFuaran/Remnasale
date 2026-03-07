import { useState, useEffect, useRef, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';

interface TicketMessage {
  id: number;
  is_admin: boolean;
  text: string;
  created_at: string;
}

interface GuestTicket {
  id: number;
  subject: string;
  status: string;
  messages: TicketMessage[];
  admin_typing?: boolean;
}

type View = 'closed' | 'form' | 'chat';

interface Props {
  logoUrl?: string;
}

export default function SupportWidget({ logoUrl }: Props) {
  const navigate = useNavigate();
  const [authed, setAuthed] = useState(false);
  const [role, setRole] = useState<string | null>(null);
  const [unread, setUnread] = useState(0);

  // Panel state
  const [open, setOpen] = useState(false);
  const [view, setView] = useState<View>('form');
  const [ticket, setTicket] = useState<GuestTicket | null>(null);

  // Hint bubble
  const [showHint, setShowHint] = useState(false);

  // Form state
  const [guestName, setGuestName] = useState('');
  const [guestSubject, setGuestSubject] = useState('');
  const [guestText, setGuestText] = useState('');
  const [sending, setSending] = useState(false);
  const [error, setError] = useState('');

  // Reply state
  const [replyText, setReplyText] = useState('');
  const [replying, setReplying] = useState(false);
  const [uploadingImage, setUploadingImage] = useState(false);

  const chatEndRef = useRef<HTMLDivElement>(null);
  const wrapRef = useRef<HTMLDivElement>(null);
  const pollRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const typingTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const imageInputRef = useRef<HTMLInputElement>(null);

  // Check auth status
  useEffect(() => {
    fetch('/web/api/user/data', { credentials: 'include' })
      .then((r) => (r.ok ? r.json() : null))
      .then((d) => {
        if (d?.user) {
          setAuthed(true);
          setRole(d.user.role ?? null);
        }
      })
      .catch(() => {});
  }, []);

  const isStaff = role === 'DEV' || role === 'ADMIN';

  // Show hint bubble after 2s for guests (once per session)
  useEffect(() => {
    if (authed) return;
    const seen = sessionStorage.getItem('fab_hint_seen');
    if (seen) return;
    const t = setTimeout(() => {
      setShowHint(true);
      sessionStorage.setItem('fab_hint_seen', '1');
      setTimeout(() => setShowHint(false), 6000);
    }, 2000);
    return () => clearTimeout(t);
  }, [authed]);

  // Poll unread for authed users
  useEffect(() => {
    if (!authed) return;
    if (isStaff) {
      // Staff: poll admin unread tickets count
      const load = () =>
        fetch('/web/api/admin/tickets/unread-count', { credentials: 'include' })
          .then((r) => (r.ok ? r.json() : null))
          .then((d) => { if (d) setUnread(d.count ?? 0); })
          .catch(() => {});
      load();
      const id = setInterval(load, 15000);
      return () => clearInterval(id);
    }
    // Regular users: poll own unread tickets
    const load = () =>
      fetch('/web/api/tickets/unread-count', { credentials: 'include' })
        .then((r) => (r.ok ? r.json() : null))
        .then((d) => { if (d) setUnread(d.count ?? 0); })
        .catch(() => {});
    load();
    const id = setInterval(load, 30000);
    return () => clearInterval(id);
  }, [authed, isStaff]);

  // On mount: check if guest already has an active ticket
  useEffect(() => {
    if (authed) return;
    fetch('/web/api/public/tickets/guest/check', { credentials: 'include' })
      .then((r) => (r.ok ? r.json() : null))
      .then((d) => { if (d?.has_ticket) loadGuestTicket(); })
      .catch(() => {});
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [authed]);

  const loadGuestTicket = useCallback(async () => {
    try {
      const r = await fetch('/web/api/public/tickets/guest/me', { credentials: 'include' });
      if (r.ok) {
        const t = await r.json();
        // If ticket is closed — reset to form so guest can start a new chat
        if (t.status === 'CLOSED') {
          setTicket(null);
          setView('form');
          return;
        }
        setTicket(t);
        setView('chat');
      }
    } catch { /* ignore */ }
  }, []);

  // Poll messages when chat is open
  useEffect(() => {
    if (open && view === 'chat' && !authed) {
      pollRef.current = setInterval(loadGuestTicket, 8000);
    }
    return () => {
      if (pollRef.current) { clearInterval(pollRef.current); pollRef.current = null; }
    };
  }, [open, view, authed, loadGuestTicket]);

  // Scroll to bottom on new messages
  useEffect(() => {
    chatEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [ticket?.messages?.length]);

  // Close on outside click
  useEffect(() => {
    if (!open) return;
    const handle = (e: MouseEvent) => {
      if (wrapRef.current && !wrapRef.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', handle);
    return () => document.removeEventListener('mousedown', handle);
  }, [open]);

  const handleFabClick = () => {
    if (isStaff) { navigate('/system', { state: { section: 'support' } }); return; }
    if (authed) { navigate('/support'); return; }
    setShowHint(false);
    setOpen((v) => {
      if (!v && view === 'chat') loadGuestTicket();
      return !v;
    });
  };

  const lastGuestTypingSentRef = useRef(0);

  const sendTypingSignal = useCallback(() => {
    const now = Date.now();
    if (now - lastGuestTypingSentRef.current < 2000) return;
    lastGuestTypingSentRef.current = now;
    fetch('/web/api/public/tickets/guest/me/typing', {
      method: 'POST',
      credentials: 'include',
    }).catch(() => {});
  }, []);

  const handleReplyChange = (val: string) => {
    setReplyText(val);
    sendTypingSignal();
  };

  const handleGuestSubmit = async () => {
    if (!guestName.trim() || !guestSubject.trim() || !guestText.trim()) {
      setError('Заполните все поля'); return;
    }
    setSending(true);
    setError('');
    try {
      const r = await fetch('/web/api/public/tickets/guest', {
        method: 'POST',
        credentials: 'include',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: guestName.trim(), subject: guestSubject.trim(), text: guestText.trim() }),
      });
      if (r.ok) {
        const t = await r.json();
        setTicket(t);
        setView('chat');
        setGuestName(''); setGuestSubject(''); setGuestText('');
        // Immediately reload ticket to get fresh messages list
        // (backend may return empty messages due to session caching)
        loadGuestTicket();
      } else {
        const d = await r.json().catch(() => ({}));
        setError(d.detail || 'Ошибка отправки');
      }
    } catch { setError('Ошибка сети'); }
    finally { setSending(false); }
  };

  const handleReply = async () => {
    if (!replyText.trim()) return;
    setReplying(true);
    try {
      const r = await fetch('/web/api/public/tickets/guest/me/reply', {
        method: 'POST',
        credentials: 'include',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: replyText.trim() }),
      });
      if (r.ok) {
        const t = await r.json();
        setTicket(t);
        setReplyText('');
      }
    } catch { /* ignore */ }
    finally { setReplying(false); }
  };

  const handleImageUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploadingImage(true);
    try {
      const fd = new FormData();
      fd.append('file', file);
      const r = await fetch('/web/api/public/image-upload', { method: 'POST', credentials: 'include', body: fd });
      if (r.ok) {
        const { url } = await r.json();
        setReplyText((prev) => prev ? `${prev}\n[IMG]${url}` : `[IMG]${url}`);
      }
    } catch { /* ignore */ } finally {
      setUploadingImage(false);
      if (imageInputRef.current) imageInputRef.current.value = '';
    }
  };

  function renderMsgText(text: string) {
    const parts = text.split(/(\[IMG\][^\s\n]+)/g);
    return parts.map((part, i) => {
      if (part.startsWith('[IMG]')) {
        const url = part.slice(5);
        return <img key={i} src={url} alt="" className="chat-msg-image" onClick={() => window.open(url, '_blank')} />;
      }
      return part ? <span key={i} style={{ whiteSpace: 'pre-wrap', wordBreak: 'break-word' }}>{part}</span> : null;
    });
  }

  const isClosed = ticket?.status === 'CLOSED';

  return (
    <div className="support-fab-wrap" ref={wrapRef}>

      {/* Hint bubble */}
      {showHint && !open && (
        <div className="support-fab-hint">
          <span>Нужна помощь? Напишите нам! 👋</span>
          <button className="support-fab-hint-close" onClick={() => setShowHint(false)}>✕</button>
        </div>
      )}

      {open && !authed && (
        <div className="support-fab-panel">
          {/* Header */}
          <div className="support-fab-panel-header">
            <span>💬 Поддержка</span>
            <button className="support-fab-panel-close" onClick={() => setOpen(false)}>✕</button>
          </div>

          {/* Form view */}
          {view === 'form' && (
            <div className="support-fab-form">
              <input
                className="admin-input"
                placeholder="Ваше имя"
                maxLength={100}
                value={guestName}
                onChange={(e) => setGuestName(e.target.value)}
              />
              <input
                className="admin-input"
                placeholder="Тема обращения"
                maxLength={200}
                value={guestSubject}
                onChange={(e) => setGuestSubject(e.target.value)}
              />
              <textarea
                className="admin-input"
                placeholder="Опишите проблему..."
                rows={4}
                maxLength={2000}
                value={guestText}
                onChange={(e) => setGuestText(e.target.value)}
                onKeyDown={(e) => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); handleGuestSubmit(); } }}
              />
              {error && <span className="support-fab-error">{error}</span>}
              <button
                className="btn-primary"
                style={{ width: '100%' }}
                onClick={handleGuestSubmit}
                disabled={sending}
              >
                {sending ? 'Отправка...' : 'Начать чат'}
              </button>
            </div>
          )}

          {/* Chat view */}
          {view === 'chat' && ticket && (
            <div className="support-fab-chat">
              <div className="support-fab-chat-subject">{ticket.subject}</div>
              <div className="support-fab-messages">
                {ticket.messages.map((m) => (
                  <div key={m.id} className={`support-fab-msg ${m.is_admin ? 'from-admin' : 'from-user'}`}>
                    <div className="support-fab-msg-bubble">
                      <div className="support-fab-msg-text">{renderMsgText(m.text)}</div>
                      <span className="support-fab-msg-meta">
                        {m.is_admin ? <>{logoUrl ? <img src={logoUrl} alt="" className="support-msg-logo" /> : <svg className="support-msg-logo-svg" viewBox="0 0 24 24" fill="var(--cyan)" width="14" height="14"><path d="M12 2l7 4v6c0 5.25-3.15 10.13-7 11.38C8.15 22.13 5 17.25 5 12V6l7-4z"/></svg>} Поддержка</> : '👤 Вы'} · {m.created_at}
                      </span>
                    </div>
                  </div>
                ))}
                {ticket.messages.length === 1 && !ticket.admin_typing && (
                  <div className="support-fab-waiting">
                    <span>⏳ Ожидайте ответа от поддержки</span>
                  </div>
                )}
                {ticket.admin_typing && (
                  <div className="typing-indicator-subtle">
                    <span>Собеседник печатает...</span>
                  </div>
                )}
                <div ref={chatEndRef} />
              </div>

              {isClosed ? (
                <div className="support-fab-closed">Чат закрыт</div>
              ) : (
                <div className="support-fab-input chat-input-compact">
                  <input ref={imageInputRef} type="file" accept="image/*" style={{ display: 'none' }} onChange={handleImageUpload} />
                  <button className="chat-attach-inline" onClick={() => imageInputRef.current?.click()} disabled={uploadingImage} title="Прикрепить">
                    {uploadingImage ? (
                      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><circle cx="12" cy="12" r="10" strokeDasharray="31.4" strokeDashoffset="10"><animateTransform attributeName="transform" type="rotate" from="0 12 12" to="360 12 12" dur="1s" repeatCount="indefinite"/></circle></svg>
                    ) : (
                      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M21.44 11.05l-9.19 9.19a6 6 0 01-8.49-8.49l9.19-9.19a4 4 0 015.66 5.66l-9.2 9.19a2 2 0 01-2.83-2.83l8.49-8.48"/></svg>
                    )}
                  </button>
                  <textarea
                    className="admin-input"
                    placeholder="Сообщение..."
                    rows={1}
                    value={replyText}
                    onChange={(e) => handleReplyChange(e.target.value)}
                    onKeyDown={(e) => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); handleReply(); } }}
                  />
                  <button
                    className="chat-send-btn"
                    onClick={handleReply}
                    disabled={replying || !replyText.trim()}
                    title="Отправить"
                  >
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><path d="M2.01 21L23 12 2.01 3 2 10l15 2-15 2z"/></svg>
                  </button>
                </div>
              )}
            </div>
          )}
        </div>
      )}

      {/* FAB button */}
      <button
        className="support-fab"
        onClick={handleFabClick}
        aria-label="Поддержка"
        title="Поддержка"
      >
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" width="22" height="22">
          <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
        </svg>
        {unread > 0 && <span className="support-fab-badge">{unread}</span>}
      </button>

    </div>
  );
}
