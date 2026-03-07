import { useEffect, useState, useRef, useCallback } from 'react';
import type { ReactNode } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import Navbar from '../components/Navbar';
import {
  UsersIcon, BroadcastIcon, PlansIcon, GatewaysIcon, FeaturesIcon,
  StatsIcon, LogsIcon, BotIcon, BrandingIcon, DatabaseIcon, SupportIcon,
} from '../components/AdminIcons';
import {
  Zap, Globe, Shield, CreditCard, Users, Smartphone,
  Infinity as InfinityIcon, CheckCircle, EyeOff, Headphones,
  Lock, Wifi, Cloud, Server, Activity, Award, Bell, Bookmark, Box, Briefcase,
  Camera, Clock, Cpu, Database, Download, Film, Gift, Heart, Home, Key,
  Layers, Map, Monitor, Music, Package, Percent, Phone, Play, Power, Radio,
  RefreshCw, Scissors, Search, Send as SendIcon, Settings, Share2, ShoppingCart, Star, Sun, Thermometer,
  Truck, Umbrella, Upload, Video, Volume2, Watch, Wrench, X as XIcon, Crosshair, Rocket,
} from 'lucide-react';
import type { PublicConfig } from '../App';

const ICON_MAP: Record<string, React.ReactNode> = {
  Zap: <Zap size={20} />, Globe: <Globe size={20} />, Shield: <Shield size={20} />,
  CreditCard: <CreditCard size={20} />, Users: <Users size={20} />, Smartphone: <Smartphone size={20} />,
  Infinity: <InfinityIcon size={20} />, CheckCircle: <CheckCircle size={20} />, EyeOff: <EyeOff size={20} />,
  Headphones: <Headphones size={20} />, Lock: <Lock size={20} />, Wifi: <Wifi size={20} />,
  Cloud: <Cloud size={20} />, Server: <Server size={20} />, Activity: <Activity size={20} />,
  Award: <Award size={20} />, Bell: <Bell size={20} />, Bookmark: <Bookmark size={20} />,
  Box: <Box size={20} />, Briefcase: <Briefcase size={20} />, Camera: <Camera size={20} />,
  Clock: <Clock size={20} />, Cpu: <Cpu size={20} />, Database: <Database size={20} />,
  Download: <Download size={20} />, Film: <Film size={20} />, Gift: <Gift size={20} />,
  Heart: <Heart size={20} />, Home: <Home size={20} />, Key: <Key size={20} />,
  Layers: <Layers size={20} />, Map: <Map size={20} />, Monitor: <Monitor size={20} />,
  Music: <Music size={20} />, Package: <Package size={20} />, Percent: <Percent size={20} />,
  Phone: <Phone size={20} />, Play: <Play size={20} />, Power: <Power size={20} />,
  Radio: <Radio size={20} />, RefreshCw: <RefreshCw size={20} />, Scissors: <Scissors size={20} />,
  Search: <Search size={20} />, Send: <SendIcon size={20} />, Settings: <Settings size={20} />,
  Share2: <Share2 size={20} />, ShoppingCart: <ShoppingCart size={20} />, Star: <Star size={20} />,
  Sun: <Sun size={20} />, Thermometer: <Thermometer size={20} />, Truck: <Truck size={20} />,
  Umbrella: <Umbrella size={20} />, Upload: <Upload size={20} />, Video: <Video size={20} />,
  Volume2: <Volume2 size={20} />, Watch: <Watch size={20} />, Wrench: <Wrench size={20} />,
  X: <XIcon size={20} />, Crosshair: <Crosshair size={20} />, Rocket: <Rocket size={20} />,
};

const DEFAULT_ADVANTAGES: AdvantageItem[] = [
  { icon: 'Zap',          title: 'Высокая скорость',    desc: 'Низкий пинг и стабильное соединение для комфортной работы и стриминга.', active: true },
  { icon: 'Globe',        title: 'Множество локаций',   desc: 'Серверы в Европе, США, Азии и других регионах без ограничений по трафику.', active: true },
  { icon: 'Shield',       title: 'Безопасность',        desc: 'Шифрование трафика и защита данных. Никаких логов вашей активности.', active: true },
  { icon: 'CreditCard',   title: 'Удобная оплата',      desc: 'Банковские карты, криптовалюта, Telegram Stars и другие способы.', active: true },
  { icon: 'Users',        title: 'Реферальная система', desc: 'Приглашайте друзей и получайте бонусы на баланс или дополнительные дни.', active: true },
  { icon: 'Smartphone',   title: 'Все устройства',      desc: 'Windows, macOS, Android, iOS — одна подписка для всех устройств.', active: true },
  { icon: 'Infinity',     title: 'Без лимита трафика',  desc: 'Смотрите, качайте и стримьте без ограничений.', active: true },
  { icon: 'CheckCircle',  title: 'Без рекламы',         desc: 'YouTube, сайты и приложения без рекламных вставок.', active: true },
  { icon: 'EyeOff',       title: 'Без отслеживания',    desc: 'Не храним логи вашей интернет-активности.', active: true },
  { icon: 'Headphones',   title: 'Техподдержка 24/7',   desc: 'Поддержка через Telegram — ответим быстро.', active: true },
];

const DEFAULT_FAQ_ITEMS: FAQItem[] = [
  { q: 'Как подключиться к VPN?', a: 'Откройте нашего Telegram-бота, выберите тарифный план, оплатите и получите ключ подключения. Весь процесс занимает менее минуты.', active: true },
  { q: 'Какие устройства поддерживаются?', a: 'Windows, macOS, Linux, Android и iOS. Одна подписка может использоваться на нескольких устройствах одновременно (лимит зависит от тарифа).', active: true },
  { q: 'Есть ли ограничения по трафику?', a: 'На большинстве тарифов трафик безлимитный. Подробности указаны в описании каждого тарифного плана.', active: true },
  { q: 'Какие способы оплаты доступны?', a: 'Банковские карты, криптовалюта, Telegram Stars и другие способы оплаты через Telegram-бота.', active: true },
  { q: 'Ведутся ли логи активности?', a: 'Нет. Мы не храним логи вашей интернет-активности. Ваша конфиденциальность — наш приоритет.', active: true },
  { q: 'Можно ли попробовать бесплатно?', a: 'Да, мы предоставляем пробный период. Откройте бота и выберите пробную подписку.', active: true },
  { q: 'Работает ли VPN с российскими сервисами?', a: 'Да! Наш VPN не блокирует доступ к российским сайтам — ВКонтакте, Госуслуги, банки работают без проблем.', active: true },
] as FAQItem[];

interface Props {
  config: PublicConfig;
}

type Section = 'users' | 'broadcast' | 'plans' | 'gateways' | 'features' | 'stats' | 'logs' | 'bot' | 'branding' | 'database' | 'support';

interface BrandForm {
  name: string;
  logo: string;
  slogan: string;
  badge: string;
  title: string;
  subtitle: string;
  timezone: string;
  advantages: AdvantageItem[];
  faq: FAQItem[];
}

interface AdvantageItem {
  icon: string;
  title: string;
  desc: string;
  active: boolean;
}

interface FAQItem {
  q: string;
  a: string;
  active: boolean;
}

type BrandTab = 'branding' | 'homepage' | 'advantages' | 'faq' | 'site-settings';

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
  user_telegram_id: number;
  user_name?: string;
  is_read_by_admin: boolean;
  created_at: string;
  updated_at: string;
  messages: TicketMessage[];
  guest_typing?: boolean;
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

/* ~50 icon options for advantages */
const ICON_OPTIONS = [
  'Zap','Globe','Shield','CreditCard','Users','Smartphone','Infinity','CheckCircle','EyeOff','Headphones',
  'Lock','Wifi','Cloud','Server','Activity','Award','Bell','Bookmark','Box','Briefcase',
  'Camera','Clock','Cpu','Database','Download','Film','Gift','Heart','Home','Key',
  'Layers','Map','Monitor','Music','Package','Percent','Phone','Play','Power','Radio',
  'RefreshCw','Scissors','Search','Send','Settings','Share2','ShoppingCart','Star','Sun','Thermometer',
  'Truck','Umbrella','Upload','Video','Volume2','Watch','Wrench','X','Crosshair','Rocket',
];

function getStatusLabel(status: string, isReadByAdmin: boolean) {
  if (status === 'OPEN' && !isReadByAdmin) return 'Новое';
  return STATUS_LABELS[status] || status;
}
function getStatusColor(status: string, isReadByAdmin: boolean) {
  if (status === 'OPEN' && !isReadByAdmin) return '#F59E0B';
  return STATUS_COLORS[status] || '#888';
}

function formatTicketTime(dateStr: string, tz: string): string {
  try {
    if (!dateStr) return '';
    // Normalise to UTC: replace space separator with T, append Z if no offset present
    let s = dateStr.trim();
    if (!s.includes('T') && s.includes(' ')) s = s.replace(' ', 'T');
    if (!s.includes('+') && !s.toLowerCase().includes('z')) s += 'Z';
    const d = new Date(s);
    if (isNaN(d.getTime())) return dateStr;
    return d.toLocaleString('ru-RU', { timeZone: tz, day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' });
  } catch { return dateStr; }
}

const TIMEZONE_OPTIONS = [
  'Europe/Moscow','Europe/Kaliningrad','Europe/Samara','Asia/Yekaterinburg','Asia/Omsk',
  'Asia/Krasnoyarsk','Asia/Irkutsk','Asia/Yakutsk','Asia/Vladivostok','Asia/Magadan',
  'Asia/Kamchatka','UTC','Europe/London','Europe/Berlin','Europe/Paris',
  'America/New_York','America/Chicago','America/Denver','America/Los_Angeles',
  'Asia/Dubai','Asia/Shanghai','Asia/Tokyo','Asia/Kolkata','Australia/Sydney',
];

export default function AdminPage({ config }: Props) {
  const navigate = useNavigate();
  const location = useLocation();
  const [checking, setChecking] = useState(true);
  const [section, setSection] = useState<Section>(() => {
    const st = (location.state as { section?: string } | null)?.section;
    return (st as Section) ?? 'users';
  });
  const [form, setForm] = useState<BrandForm>({ name: '', logo: '', slogan: '', badge: '', title: '', subtitle: '', timezone: 'Europe/Moscow', advantages: DEFAULT_ADVANTAGES, faq: DEFAULT_FAQ_ITEMS });
  const [saving, setSaving] = useState(false);
  const [saveMsg, setSaveMsg] = useState<{ ok: boolean; text: string } | null>(null);
  const [brandTab, setBrandTab] = useState<BrandTab>('branding');
  const [confirmDeleteId, setConfirmDeleteId] = useState<number | null>(null);
  const [advDragIdx, setAdvDragIdx] = useState<number | null>(null);
  const [advDragOver, setAdvDragOver] = useState<number | null>(null);
  const [advModal, setAdvModal] = useState<{ idx: number } | null>(null);
  const [advDraft, setAdvDraft] = useState<AdvantageItem | null>(null);
  const [faqDraft, setFaqDraft] = useState<FAQItem | null>(null);
  const [lightboxUrl, setLightboxUrl] = useState<string | null>(null);
  const [faqDragIdx, setFaqDragIdx] = useState<number | null>(null);
  const [faqDragOver, setFaqDragOver] = useState<number | null>(null);
  const [editFaqIdx, setEditFaqIdx] = useState<number | null>(null);
  const [clockTick, setClockTick] = useState(0);

  // Support state
  const [tickets, setTickets] = useState<Ticket[]>([]);
  const [activeTicket, setActiveTicket] = useState<Ticket | null>(null);
  const [replyText, setReplyText] = useState('');
  const [sendingReply, setSendingReply] = useState(false);
  const [unreadCount, setUnreadCount] = useState(0);
  const [uploadingImage, setUploadingImage] = useState(false);
  const chatEndRef = useRef<HTMLDivElement>(null);
  const adminTypingTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const activeTicketPollRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const imageInputRef = useRef<HTMLInputElement>(null);

  // Clock tick every second for timezone preview
  useEffect(() => {
    const id = setInterval(() => setClockTick((n) => n + 1), 1000);
    return () => clearInterval(id);
  }, []);

  // Guard: only DEV can access
  useEffect(() => {
    fetch('/web/api/user/data', { credentials: 'include' })
      .then((r) => (r.ok ? r.json() : null))
      .then((d) => {
        if (!d?.user || d.user.role !== 'DEV') {
          navigate('/', { replace: true });
        } else {
          setChecking(false);
        }
      })
      .catch(() => navigate('/', { replace: true }));
  }, [navigate]);

  // Load current brand settings
  useEffect(() => {
    if (checking) return;
    fetch('/web/api/settings/brand')
      .then((r) => (r.ok ? r.json() : null))
      .then((d) => {
        if (d) setForm({ name: d.name ?? '', logo: d.logo ?? '', slogan: d.slogan ?? '', badge: d.badge ?? '', title: d.title ?? '', subtitle: d.subtitle ?? '', timezone: d.timezone ?? 'Europe/Moscow', advantages: d.advantages?.length ? d.advantages : DEFAULT_ADVANTAGES, faq: d.faq?.length ? d.faq : DEFAULT_FAQ_ITEMS });
      })
      .catch(() => {});
  }, [checking]);

  // Support: load tickets
  const loadTickets = useCallback(async () => {
    try {
      const r = await fetch('/web/api/admin/tickets', { credentials: 'include' });
      if (r.ok) setTickets(await r.json());
    } catch { /* ignore */ }
  }, []);

  const loadUnreadCount = useCallback(async () => {
    try {
      const r = await fetch('/web/api/admin/tickets/unread-count', { credentials: 'include' });
      if (r.ok) { const d = await r.json(); setUnreadCount(d.count ?? 0); }
    } catch { /* ignore */ }
  }, []);

  useEffect(() => {
    if (checking) return;
    loadUnreadCount();
  }, [checking, loadUnreadCount]);

  useEffect(() => {
    if (section === 'support' && !checking) loadTickets();
  }, [section, checking, loadTickets]);

  // Poll active ticket every 5 s for real-time message updates
  const refreshActiveTicket = useCallback(async () => {
    if (!activeTicket) return;
    try {
      const r = await fetch(`/web/api/admin/tickets/${activeTicket.id}?silent=true`, { credentials: 'include' });
      if (r.ok) setActiveTicket(await r.json());
    } catch { /* ignore */ }
  }, [activeTicket]);

  useEffect(() => {
    if (activeTicket && section === 'support') {
      activeTicketPollRef.current = setInterval(refreshActiveTicket, 5000);
    }
    return () => {
      if (activeTicketPollRef.current) { clearInterval(activeTicketPollRef.current); activeTicketPollRef.current = null; }
    };
  }, [activeTicket?.id, section, refreshActiveTicket]);

  // Poll unread count every 30 s
  useEffect(() => {
    if (checking) return;
    const id = setInterval(loadUnreadCount, 30000);
    return () => clearInterval(id);
  }, [checking, loadUnreadCount]);

  useEffect(() => {
    chatEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [activeTicket?.messages?.length]);

  const openAdminTicket = async (id: number) => {
    try {
      const r = await fetch(`/web/api/admin/tickets/${id}`, { credentials: 'include' });
      if (r.ok) {
        const t = await r.json();
        setActiveTicket(t);
        setTickets((prev) => prev.map((tt) => tt.id === id ? { ...tt, is_read_by_admin: true } : tt));
        loadUnreadCount();
      }
    } catch { /* ignore */ }
  };

  const handleAdminReply = async () => {
    if (!replyText.trim() || !activeTicket) return;
    setSendingReply(true);
    try {
      const r = await fetch(`/web/api/admin/tickets/${activeTicket.id}/reply`, {
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
    finally { setSendingReply(false); }
  };

  const handleAdminImageUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
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

  const lastTypingSentRef = useRef(0);

  const sendAdminTyping = useCallback(() => {
    if (!activeTicket) return;
    const now = Date.now();
    if (now - lastTypingSentRef.current < 2000) return;
    lastTypingSentRef.current = now;
    fetch(`/web/api/admin/tickets/${activeTicket.id}/typing`, {
      method: 'POST',
      credentials: 'include',
    }).catch(() => {});
  }, [activeTicket]);

  const handleAdminReplyChange = (val: string) => {
    setReplyText(val);
    sendAdminTyping();
  };

  const handleAdminClose = async () => {
    if (!activeTicket) return;
    try {
      const r = await fetch(`/web/api/admin/tickets/${activeTicket.id}/close`, {
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

  const handleAdminDelete = async (id: number) => {
    setConfirmDeleteId(null);
    try {
      const r = await fetch(`/web/api/admin/tickets/${id}`, {
        method: 'DELETE',
        credentials: 'include',
      });
      if (r.ok) {
        if (activeTicket?.id === id) setActiveTicket(null);
        loadTickets();
        loadUnreadCount();
      }
    } catch { /* ignore */ }
  };

  const handleSave = async () => {
    setSaving(true);
    setSaveMsg(null);
    try {
      const r = await fetch('/web/api/settings/brand', {
        method: 'POST',
        credentials: 'include',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(form),
      });
      if (r.ok) {
        setSaveMsg({ ok: true, text: 'Настройки сохранены!' });
        // Refresh public config so landing page picks up changes on navigation
        try {
          const cr = await fetch('/web/api/public/config');
          if (cr.ok) {
            const newCfg = await cr.json();
            Object.assign(config, newCfg);
          }
        } catch { /* ignore */ }
      } else {
        const err = await r.json().catch(() => ({}));
        setSaveMsg({ ok: false, text: err.detail ?? 'Ошибка сохранения' });
      }
    } catch {
      setSaveMsg({ ok: false, text: 'Ошибка сети' });
    } finally {
      setSaving(false);
    }
  };

  if (checking) return null;

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

  const logoForNav = form.logo || config.brand?.logo;
  const nameForNav = form.name || config.brand?.name;

  const SECTION_TITLES: Record<Section, string> = {
    users: 'Управление пользователями',
    broadcast: 'Рассылка сообщений',
    plans: 'Тарифные планы',
    gateways: 'Платежные системы',
    features: 'Дополнительные функции',
    stats: 'Статистика',
    logs: 'Журнал',
    bot: 'Управление ботом',
    branding: 'Внешний вид',
    database: 'Управление БД',
    support: 'Поддержка',
  };

  const NavItem = ({ id, icon, label, badge }: { id: Section; icon: ReactNode; label: string; badge?: number }) => (
    <button
      className={`admin-nav-item${section === id ? ' active' : ''}`}
      onClick={() => setSection(id)}
      title={label}
    >
      <span className="admin-nav-icon" style={{ position: 'relative' }}>
        {icon}
        {badge ? <span className="admin-nav-badge">{badge}</span> : null}
      </span>
      <span className="admin-nav-label">{label}</span>
    </button>
  );

  return (
    <>
      <Navbar
        botUrl={config.bot_url}
        oauthProviders={config.oauth_providers}
        brand={{ ...config.brand, logo: logoForNav ?? '', name: nameForNav ?? '' }}
      />
      <div className="admin-layout">
        {/* Sidebar */}
        <aside className="admin-sidebar">
          <nav className="admin-sidebar-nav">
            <NavItem id="users" icon={<UsersIcon />} label="Пользователи" />
            <NavItem id="broadcast" icon={<BroadcastIcon />} label="Рассылка" />
            <div className="admin-nav-divider" />
            <NavItem id="plans" icon={<PlansIcon />} label="Тарифы" />
            <NavItem id="gateways" icon={<GatewaysIcon />} label="Платежные системы" />
            <div className="admin-nav-divider" />
            <NavItem id="features" icon={<FeaturesIcon />} label="Доп. функции" />
            <div className="admin-nav-divider" />
            <NavItem id="stats" icon={<StatsIcon />} label="Статистика" />
            <NavItem id="logs" icon={<LogsIcon />} label="Журнал" />
            <div className="admin-nav-divider" />
            <NavItem id="bot" icon={<BotIcon />} label="Управление ботом" />
            <NavItem id="branding" icon={<BrandingIcon />} label="Внешний вид" />
            <div className="admin-nav-divider" />
            <NavItem id="support" icon={<SupportIcon />} label="Поддержка" badge={unreadCount || undefined} />
            <div className="admin-nav-divider" />
            <NavItem id="database" icon={<DatabaseIcon />} label="Управление БД" />
          </nav>
        </aside>

        {/* Content */}
        <main className={`admin-content${section === 'support' ? ' admin-content--fill' : ''}`}>
          {section !== 'branding' && section !== 'support' && (
            <div className="db-card">
              <p style={{ color: 'var(--text2)', fontSize: '.92rem', lineHeight: 1.6 }}>
                Раздел в разработке.
              </p>
            </div>
          )}

          {section === 'support' && (
            <div className="support-admin-layout">
              {/* Ticket list */}
              <div className="support-admin-list">
                <div className="support-sidebar-header">
                  <h3>Все обращения</h3>
                  {unreadCount > 0 && <span className="support-badge">{unreadCount}</span>}
                </div>
                <div className="support-ticket-list">
                  {tickets.length === 0 && (
                    <p className="support-empty">Нет обращений</p>
                  )}
                  {tickets.map((t) => (
                    <div key={t.id} className={`support-ticket-item${activeTicket?.id === t.id ? ' active' : ''}${!t.is_read_by_admin ? ' unread' : ''}`}>
                      <button
                        className="support-ticket-item-btn"
                        onClick={() => openAdminTicket(t.id)}
                      >
                        <div className="support-ticket-item-top">
                          <span className="support-ticket-user">От: {t.user_name ?? (t.user_telegram_id === 0 ? 'Гость' : `TG ${t.user_telegram_id}`)}</span>
                          <span className="support-ticket-status" style={{ color: getStatusColor(t.status, t.is_read_by_admin) }}>
                            {getStatusLabel(t.status, t.is_read_by_admin)}
                          </span>
                        </div>
                        <div className="support-ticket-item-mid">
                          <span className="support-ticket-subject">Тема: {t.subject}</span>
                        </div>
                        <div className="support-ticket-item-bottom">
                          <span className="support-ticket-date">{formatTicketTime(t.updated_at, form.timezone)}</span>
                          {!t.is_read_by_admin && <span className="support-unread-dot" />}
                        </div>
                      </button>
                      <button className="support-delete-btn" onClick={() => setConfirmDeleteId(t.id)} title="Удалить">&times;</button>
                    </div>
                  ))}
                </div>
              </div>

              {/* Chat area */}
              <div className="support-admin-chat">
                {activeTicket ? (
                  <div className="support-chat-card">
                    <div className="support-chat-header">
                      <div>
                        <div className="support-chat-user">От: {activeTicket.user_name ?? (activeTicket.user_telegram_id === 0 ? 'Гость' : `TG ${activeTicket.user_telegram_id}`)}</div>
                        <h2 className="support-chat-subject">Тема: {activeTicket.subject}</h2>
                        <span className="support-ticket-status" style={{ color: getStatusColor(activeTicket.status, activeTicket.is_read_by_admin) }}>
                          {getStatusLabel(activeTicket.status, activeTicket.is_read_by_admin)}
                        </span>
                        <span className="support-chat-date">Создано: {formatTicketTime(activeTicket.created_at, form.timezone)}</span>
                      </div>
                      {activeTicket.status !== 'CLOSED' && (
                        <button className="support-close-btn" onClick={handleAdminClose}>Закрыть тикет</button>
                      )}
                    </div>
                    <div className="support-chat-messages">
                      {activeTicket.messages.map((m) => (
                        <div key={m.id} className={`support-msg ${m.is_admin ? 'admin' : 'user'}`}>
                          <div className="support-msg-bubble">
                            <span className="support-msg-sender">{m.is_admin ? <>{logoForNav ? <img src={logoForNav} alt="" className="support-msg-logo" /> : <svg className="support-msg-logo-svg" viewBox="0 0 24 24" fill="var(--cyan)" width="14" height="14"><path d="M12 2l7 4v6c0 5.25-3.15 10.13-7 11.38C8.15 22.13 5 17.25 5 12V6l7-4z"/></svg>} Вы (поддержка)</> : '👤 Пользователь'}</span>
                            <div className="support-msg-text">{renderMsgText(m.text)}</div>
                            <span className="support-msg-time">{formatTicketTime(m.created_at, form.timezone)}</span>
                          </div>
                        </div>
                      ))}
                      {activeTicket.guest_typing && (
                        <div className="typing-indicator-subtle">
                          <span>Собеседник печатает...</span>
                        </div>
                      )}
                      <div ref={chatEndRef} />
                    </div>
                    {activeTicket.status !== 'CLOSED' && (
                      <div className="support-chat-input chat-input-compact">
                        <input ref={imageInputRef} type="file" accept="image/*" style={{ display: 'none' }} onChange={handleAdminImageUpload} />
                        <button className="chat-attach-inline" onClick={() => imageInputRef.current?.click()} disabled={uploadingImage} title="Прикрепить изображение">
                          {uploadingImage ? (
                            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><circle cx="12" cy="12" r="10" strokeDasharray="31.4" strokeDashoffset="10"><animateTransform attributeName="transform" type="rotate" from="0 12 12" to="360 12 12" dur="1s" repeatCount="indefinite"/></circle></svg>
                          ) : (
                            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M21.44 11.05l-9.19 9.19a6 6 0 01-8.49-8.49l9.19-9.19a4 4 0 015.66 5.66l-9.2 9.19a2 2 0 01-2.83-2.83l8.49-8.48"/></svg>
                          )}
                        </button>
                        <textarea
                          className="admin-input"
                          placeholder="Сообщение..."
                          rows={1}
                          value={replyText}
                          onChange={(e) => handleAdminReplyChange(e.target.value)}
                          onKeyDown={(e) => {
                            if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); handleAdminReply(); }
                          }}
                        />
                        <button className="chat-send-btn" onClick={handleAdminReply} disabled={sendingReply || !replyText.trim()} title="Отправить">
                          <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor"><path d="M2.01 21L23 12 2.01 3 2 10l15 2-15 2z"/></svg>
                        </button>
                      </div>
                    )}
                  </div>
                ) : (
                  <div className="support-empty-state">
                    <div className="support-empty-icon">🎫</div>
                    <h3>Выберите обращение</h3>
                    <p>Выберите тикет из списка слева для просмотра и ответа</p>
                  </div>
                )}
              </div>
            </div>
          )}

          {section === 'branding' && (
            <div className="db-card">

              {/* Sub-tabs */}
              <div className="admin-subtabs">
                {([['branding','Брендирование'],['homepage','Главная страница'],['advantages','Преимущества'],['faq','Часто задаваемые вопросы'],['site-settings','Настройки сайта']] as [BrandTab,string][]).map(([k,v]) => (
                  <button key={k} className={`admin-subtab${brandTab === k ? ' active' : ''}`} onClick={() => setBrandTab(k)}>{v}</button>
                ))}
              </div>

              <div className="admin-form">

                {/* ── Брендирование ── */}
                {brandTab === 'branding' && (<>
                  <div className="admin-field">
                    <label className="admin-label">Логотип (URL изображения)</label>
                    <div className="admin-logo-row">
                      {form.logo && (
                        <img src={form.logo} alt="Превью" className="admin-logo-preview"
                          onError={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }}
                          onLoad={(e) => { (e.target as HTMLImageElement).style.display = 'block'; }}
                        />
                      )}
                      <input type="url" className="admin-input" placeholder="https://example.com/logo.png" value={form.logo} onChange={(e) => setForm({ ...form, logo: e.target.value })} />
                    </div>
                    <span className="admin-hint">Будет в шапке сайта, закладках браузера и как аватар поддержки в чате. Рекомендуемый размер: 64×64 px.</span>
                  </div>
                  <div className="admin-field">
                    <label className="admin-label">Название сервиса</label>
                    <input type="text" className="admin-input" placeholder="VPN Shop" maxLength={64} value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
                    <span className="admin-hint">Отображается в шапке сайта рядом с логотипом.</span>
                  </div>
                </>)}

                {/* ── Главная страница ── */}
                {brandTab === 'homepage' && (<>
                  <div className="admin-field">
                    <label className="admin-label">Бейдж (✨ плашка)</label>
                    <input type="text" className="admin-input" placeholder="VPN без ограничений" maxLength={64} value={form.badge} onChange={(e) => setForm({ ...form, badge: e.target.value })} />
                    <span className="admin-hint">Голубая плашка над заголовком. По умолчанию: «VPN без ограничений»</span>
                  </div>
                  <div className="admin-field">
                    <label className="admin-label">Крупный заголовок (H1)</label>
                    <input type="text" className="admin-input" placeholder="Быстрый и надежный VPN-сервис" maxLength={128} value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} />
                    <span className="admin-hint">Главный заголовок на первом экране.</span>
                  </div>
                  <div className="admin-field">
                    <label className="admin-label">Подзаголовок (лозунг)</label>
                    <textarea className="admin-input admin-textarea" placeholder="Безлимитный трафик, высокая скорость и доступ ко всем сервисам." maxLength={256} rows={3} value={form.subtitle || form.slogan} onChange={(e) => setForm({ ...form, subtitle: e.target.value })} />
                    <span className="admin-hint">Текст под заголовком.</span>
                  </div>
                </>)}

                {/* ── Преимущества ── */}
                {brandTab === 'advantages' && (
                  <>
                    <p style={{ color: 'var(--text2)', fontSize: '.85rem', marginBottom: '8px' }}>Перетаскивайте карточки для изменения порядка. Кликните на карточку для редактирования.</p>
                    <div className="admin-adv-grid">
                      {form.advantages.map((adv, i) => (
                        <div
                          key={i}
                          className={`admin-adv-card${!adv.active ? ' admin-adv-card--inactive' : ''}${advDragOver === i ? ' admin-adv-card--dragover' : ''}`}
                          draggable
                          onDragStart={(e) => { e.dataTransfer.effectAllowed = 'move'; setAdvDragIdx(i); }}
                          onDragOver={(e) => { e.preventDefault(); setAdvDragOver(i); }}
                          onDrop={(e) => { e.preventDefault(); if (advDragIdx === null || advDragIdx === i) { setAdvDragOver(null); return; } const arr = [...form.advantages]; const [moved] = arr.splice(advDragIdx, 1); arr.splice(i, 0, moved); setForm({ ...form, advantages: arr }); setAdvDragIdx(null); setAdvDragOver(null); }}
                          onDragEnd={() => { setAdvDragIdx(null); setAdvDragOver(null); }}
                          onClick={() => { setAdvDraft({ ...adv }); setAdvModal({ idx: i }); }}
                        >
                          <div className="admin-adv-card-controls">
                            <label className="admin-toggle admin-toggle-sm" onClick={(e) => e.stopPropagation()}>
                              <input type="checkbox" checked={adv.active} onChange={(e) => { const a = [...form.advantages]; a[i] = { ...a[i], active: e.target.checked }; setForm({ ...form, advantages: a }); }} />
                              <span className="admin-toggle-slider" />
                            </label>
                            <button className="admin-remove-btn" onClick={(e) => { e.stopPropagation(); const a = form.advantages.filter((_, j) => j !== i); setForm({ ...form, advantages: a }); if (advModal?.idx === i) setAdvModal(null); }} title="Удалить"><svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14H6L5 6"/><path d="M10 11v6M14 11v6"/><path d="M9 6V4h6v2"/></svg></button>
                          </div>
                          <div className="feature-icon" style={{ opacity: adv.active ? 1 : 0.4 }}>{ICON_MAP[adv.icon] ?? <Zap size={20} />}</div>
                          <h3 style={{ opacity: adv.active ? 1 : 0.4 }}>{adv.title || '(без заголовка)'}</h3>
                          <p style={{ opacity: adv.active ? 1 : 0.4 }}>{adv.desc || '(нет описания)'}</p>
                        </div>
                      ))}
                      <button
                        className="admin-adv-card admin-adv-add-card"
                        onClick={() => { const newAdv: AdvantageItem = { icon: 'Zap', title: '', desc: '', active: true }; const newList = [...form.advantages, newAdv]; setForm({ ...form, advantages: newList }); setAdvDraft({ ...newAdv }); setAdvModal({ idx: newList.length - 1 }); }}
                      >
                        <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"><path d="M12 5v14M5 12h14" /></svg>
                        <span>Добавить</span>
                      </button>
                    </div>
                  </>
                )}

                {/* ── Часто задаваемые вопросы ── */}
                {brandTab === 'faq' && (<>
                  <p style={{ color: 'var(--text2)', fontSize: '.85rem', marginBottom: '4px' }}>Перетаскивайте для изменения порядка. Кликните на вопрос для редактирования.</p>
                  {form.faq.map((item, i) => (
                    <div
                      key={i}
                      className={`admin-faq-card${!item.active ? ' admin-faq-card--inactive' : ''}${faqDragOver === i ? ' admin-faq-card--dragover' : ''}`}
                      draggable
                      onDragStart={(e) => { e.dataTransfer.effectAllowed = 'move'; setFaqDragIdx(i); }}
                      onDragOver={(e) => { e.preventDefault(); setFaqDragOver(i); }}
                      onDrop={(e) => { e.preventDefault(); if (faqDragIdx === null || faqDragIdx === i) { setFaqDragOver(null); return; } const arr = [...form.faq]; const [moved] = arr.splice(faqDragIdx, 1); arr.splice(i, 0, moved); setForm({ ...form, faq: arr }); setFaqDragIdx(null); setFaqDragOver(null); }}
                      onDragEnd={() => { setFaqDragIdx(null); setFaqDragOver(null); }}
                      onClick={() => { setFaqDraft({ ...item }); setEditFaqIdx(editFaqIdx === i ? null : i); }}
                    >
                      <div className="admin-faq-card-top">
                        <span className="admin-faq-card-q">{item.q || '(без вопроса)'}</span>
                        <div className="admin-faq-card-controls" onClick={(e) => e.stopPropagation()}>
                          <label className="admin-toggle admin-toggle-sm">
                            <input type="checkbox" checked={item.active} onChange={(e) => { const f = [...form.faq]; f[i] = { ...f[i], active: e.target.checked }; setForm({ ...form, faq: f }); }} />
                            <span className="admin-toggle-slider" />
                          </label>
                          <button className="admin-remove-btn" onClick={(e) => { e.stopPropagation(); const f = form.faq.filter((_, j) => j !== i); setForm({ ...form, faq: f }); if (editFaqIdx === i) setEditFaqIdx(null); }} title="Удалить"><svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14H6L5 6"/><path d="M10 11v6M14 11v6"/><path d="M9 6V4h6v2"/></svg></button>
                        </div>
                      </div>
                      <span className="admin-faq-card-a">{item.a || '(нет ответа)'}</span>
                    </div>
                  ))}
                  <button className="admin-adv-card admin-adv-add-card admin-faq-add-card" onClick={() => { const newFaq: FAQItem = { q: '', a: '', active: true }; const newList = [...form.faq, newFaq]; setForm({ ...form, faq: newList }); setEditFaqIdx(newList.length - 1); }}>
                    <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"><path d="M12 5v14M5 12h14" /></svg>
                    <span>Добавить вопрос</span>
                  </button>
                    {editFaqIdx !== null && form.faq[editFaqIdx] && (
                    <div className="admin-confirm-overlay" onClick={() => { if (faqDraft) { const f = [...form.faq]; f[editFaqIdx] = { ...faqDraft }; setForm({ ...form, faq: f }); } setEditFaqIdx(null); setFaqDraft(null); }}>
                      <div className="admin-adv-modal" onClick={(e) => e.stopPropagation()}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
                          <span style={{ color: 'var(--text)', fontWeight: 600, fontSize: '.95rem' }}>Редактирование вопроса</span>
                          <button className="admin-remove-btn" onClick={() => { if (faqDraft) { const f = [...form.faq]; f[editFaqIdx] = { ...faqDraft }; setForm({ ...form, faq: f }); } setEditFaqIdx(null); setFaqDraft(null); }}>✕</button>
                        </div>
                        <label className="admin-label">Вопрос</label>
                        <input type="text" className="admin-input" placeholder="Вопрос" maxLength={200} value={form.faq[editFaqIdx].q} onChange={(e) => { const f = [...form.faq]; f[editFaqIdx] = { ...f[editFaqIdx], q: e.target.value }; setForm({ ...form, faq: f }); }} />
                        <label className="admin-label" style={{ marginTop: 10 }}>Ответ</label>
                        <textarea className="admin-input admin-faq-auto-textarea" placeholder="Ответ" maxLength={1000} value={form.faq[editFaqIdx].a} onChange={(e) => { const f = [...form.faq]; f[editFaqIdx] = { ...f[editFaqIdx], a: e.target.value }; setForm({ ...form, faq: f }); const t = e.target; t.style.height = 'auto'; t.style.height = t.scrollHeight + 'px'; }} onFocus={(e) => { const t = e.target; t.style.height = 'auto'; t.style.height = t.scrollHeight + 'px'; }} rows={3} />
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8, marginTop: 16 }}>
                          <button className="admin-confirm-cancel" style={{ flex: 1 }} onClick={() => { if (faqDraft) { const f = [...form.faq]; f[editFaqIdx] = { ...faqDraft }; setForm({ ...form, faq: f }); } setEditFaqIdx(null); setFaqDraft(null); }}>Отмена</button>
                          <button className="admin-confirm-ok" style={{ flex: 1 }} onClick={() => { setEditFaqIdx(null); setFaqDraft(null); }}>Принять</button>
                        </div>
                      </div>
                    </div>
                  )}
                </>)}

                {/* ── Настройки сайта ── */}
                {brandTab === 'site-settings' && (<>
                  <div className="admin-field">
                    <label className="admin-label">Часовой пояс</label>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                      <select className="admin-input" style={{ flex: 1 }} value={form.timezone} onChange={(e) => setForm({ ...form, timezone: e.target.value })}>
                        {TIMEZONE_OPTIONS.map(tz => <option key={tz} value={tz}>{tz}</option>)}
                      </select>
                      <span style={{ color: 'var(--cyan)', fontVariantNumeric: 'tabular-nums', fontSize: '.92rem', fontWeight: 600, whiteSpace: 'nowrap', background: 'var(--bg-card)', border: '1px solid var(--border-accent)', borderRadius: 8, padding: '6px 12px', flexShrink: 0 }}>
                        {(() => { void clockTick; try { return new Date().toLocaleTimeString('ru-RU', { timeZone: form.timezone, hour: '2-digit', minute: '2-digit', second: '2-digit' }); } catch { return '--:--:--'; } })()}
                      </span>
                    </div>
                    <span className="admin-hint">Используется для отображения времени в тикетах поддержки.</span>
                  </div>
                </>)}

                {saveMsg && (
                  <div className={`admin-save-msg ${saveMsg.ok ? 'ok' : 'err'}`}>
                    {saveMsg.text}
                  </div>
                )}

                <button className="btn-primary admin-save-btn" style={{ alignSelf: 'center' }} onClick={handleSave} disabled={saving}>
                  {saving ? 'Сохранение...' : 'Сохранить изменения'}
                </button>
              </div>
            </div>
          )}
        </main>
      </div>

      {/* ── Delete confirmation modal ── */}
      {confirmDeleteId !== null && (
        <div className="admin-confirm-overlay" onClick={() => setConfirmDeleteId(null)}>
          <div className="admin-confirm-dialog" onClick={(e) => e.stopPropagation()}>
            <h3>Удалить обращение?</h3>
            <p>Это действие необратимо. Обращение и все сообщения будут удалены навсегда.</p>
            <div className="admin-confirm-btns">
              <button className="admin-confirm-cancel" onClick={() => setConfirmDeleteId(null)}>Отмена</button>
              <button className="admin-confirm-ok" onClick={() => handleAdminDelete(confirmDeleteId)}>Удалить</button>
            </div>
          </div>
        </div>
      )}

      {/* ── Advantage edit modal ── */}
      {advModal !== null && advDraft !== null && form.advantages[advModal.idx] && (
        <div className="admin-confirm-overlay" onClick={() => { const a = [...form.advantages]; a[advModal.idx] = advDraft; setForm({ ...form, advantages: a }); setAdvModal(null); setAdvDraft(null); }}>
          <div className="admin-adv-modal" onClick={(e) => e.stopPropagation()}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
              <span style={{ color: 'var(--text)', fontWeight: 600, fontSize: '.95rem' }}>Редактирование преимущества</span>
              <button className="admin-remove-btn" onClick={() => { const a = [...form.advantages]; a[advModal.idx] = advDraft; setForm({ ...form, advantages: a }); setAdvModal(null); setAdvDraft(null); }}>✕</button>
            </div>
            <label className="admin-label">Иконка</label>
            <div className="admin-icon-grid">
              {ICON_OPTIONS.map((ic) => (
                <button
                  key={ic}
                  className={`admin-icon-btn${form.advantages[advModal.idx].icon === ic ? ' active' : ''}`}
                  title={ic}
                  onClick={() => { const a = [...form.advantages]; a[advModal.idx] = { ...a[advModal.idx], icon: ic }; setForm({ ...form, advantages: a }); }}
                >
                  {ICON_MAP[ic] ?? <Zap size={16} />}
                </button>
              ))}
            </div>
            <input
              type="text" className="admin-input" placeholder="Заголовок" maxLength={80}
              value={form.advantages[advModal.idx].title}
              onChange={(e) => { const a = [...form.advantages]; a[advModal.idx] = { ...a[advModal.idx], title: e.target.value }; setForm({ ...form, advantages: a }); }}
              style={{ marginTop: 10 }}
            />
            <textarea
              className="admin-input admin-faq-auto-textarea" placeholder="Описание" maxLength={300}
              value={form.advantages[advModal.idx].desc}
              onChange={(e) => { const a = [...form.advantages]; a[advModal.idx] = { ...a[advModal.idx], desc: e.target.value }; setForm({ ...form, advantages: a }); const t = e.target; t.style.height = 'auto'; t.style.height = t.scrollHeight + 'px'; }}
              onFocus={(e) => { const t = e.target; t.style.height = 'auto'; t.style.height = t.scrollHeight + 'px'; }}
              rows={2}
              style={{ marginTop: 8 }}
            />
            <div style={{ display: 'flex', gap: 10, marginTop: 16, justifyContent: 'flex-end' }}>
              <button
                className="admin-confirm-cancel"
                onClick={() => { const a = [...form.advantages]; a[advModal.idx] = advDraft; setForm({ ...form, advantages: a }); setAdvModal(null); setAdvDraft(null); }}
              >Отмена</button>
              <button
                className="btn-primary"
                style={{ padding: '8px 22px', fontSize: '.87rem' }}
                onClick={() => { setAdvModal(null); setAdvDraft(null); }}
              >Принять</button>
            </div>
          </div>
        </div>
      )}

      {/* ── Image lightbox ── */}
      {lightboxUrl && (
        <div className="lightbox-overlay" onClick={() => setLightboxUrl(null)}>
          <button className="lightbox-close" onClick={() => setLightboxUrl(null)}>✕</button>
          <img src={lightboxUrl} alt="" className="lightbox-img" onClick={(e) => e.stopPropagation()} />
        </div>
      )}
    </>
  );
}
