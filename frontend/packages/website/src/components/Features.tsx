import {
  Shield,
  Zap,
  Globe,
  CreditCard,
  Users,
  Smartphone,
  CheckCircle,
  Lock,
  Infinity,
  Headphones,
  MonitorSmartphone,
  EyeOff,
  Wifi, Cloud, Server, Activity, Award, Bell, Bookmark, Box, Briefcase,
  Camera, Clock, Cpu, Database, Download, Film, Gift, Heart, Home, Key,
  Layers, Map, Monitor, Music, Package, Percent, Phone, Play, Power, Radio,
  RefreshCw, Scissors, Search, Send, Settings, Share2, ShoppingCart, Star, Sun, Thermometer,
  Truck, Umbrella, Upload, Video, Volume2, Watch, Wrench, X, Crosshair, Rocket,
} from 'lucide-react';

const ICON_MAP: Record<string, React.ReactNode> = {
  Zap: <Zap size={22} />, Globe: <Globe size={22} />, Shield: <Shield size={22} />,
  CreditCard: <CreditCard size={22} />, Users: <Users size={22} />, Smartphone: <Smartphone size={22} />,
  Infinity: <Infinity size={22} />, CheckCircle: <CheckCircle size={22} />, EyeOff: <EyeOff size={22} />,
  Headphones: <Headphones size={22} />, Lock: <Lock size={22} />, Wifi: <Wifi size={22} />,
  Cloud: <Cloud size={22} />, Server: <Server size={22} />, Activity: <Activity size={22} />,
  Award: <Award size={22} />, Bell: <Bell size={22} />, Bookmark: <Bookmark size={22} />,
  Box: <Box size={22} />, Briefcase: <Briefcase size={22} />, Camera: <Camera size={22} />,
  Clock: <Clock size={22} />, Cpu: <Cpu size={22} />, Database: <Database size={22} />,
  Download: <Download size={22} />, Film: <Film size={22} />, Gift: <Gift size={22} />,
  Heart: <Heart size={22} />, Home: <Home size={22} />, Key: <Key size={22} />,
  Layers: <Layers size={22} />, Map: <Map size={22} />, Monitor: <Monitor size={22} />,
  Music: <Music size={22} />, Package: <Package size={22} />, Percent: <Percent size={22} />,
  Phone: <Phone size={22} />, Play: <Play size={22} />, Power: <Power size={22} />,
  Radio: <Radio size={22} />, RefreshCw: <RefreshCw size={22} />, Scissors: <Scissors size={22} />,
  Search: <Search size={22} />, Send: <Send size={22} />, Settings: <Settings size={22} />,
  Share2: <Share2 size={22} />, ShoppingCart: <ShoppingCart size={22} />, Star: <Star size={22} />,
  Sun: <Sun size={22} />, Thermometer: <Thermometer size={22} />, Truck: <Truck size={22} />,
  Umbrella: <Umbrella size={22} />, Upload: <Upload size={22} />, Video: <Video size={22} />,
  Volume2: <Volume2 size={22} />, Watch: <Watch size={22} />, Wrench: <Wrench size={22} />,
  X: <X size={22} />, Crosshair: <Crosshair size={22} />, Rocket: <Rocket size={22} />,
  MonitorSmartphone: <MonitorSmartphone size={22} />,
};

const DEFAULT_FEATURES = [
  { icon: 'Zap', title: 'Высокая скорость', desc: 'Низкий пинг и стабильное соединение для комфортной работы и стриминга.' },
  { icon: 'Globe', title: 'Множество локаций', desc: 'Серверы в Европе, США, Азии и других регионах без ограничений по трафику.' },
  { icon: 'Shield', title: 'Безопасность', desc: 'Шифрование трафика и защита данных. Никаких логов вашей активности.' },
  { icon: 'CreditCard', title: 'Удобная оплата', desc: 'Банковские карты, криптовалюта, Telegram Stars и другие способы.' },
  { icon: 'Users', title: 'Реферальная система', desc: 'Приглашайте друзей и получайте бонусы на баланс или дополнительные дни.' },
  { icon: 'Smartphone', title: 'Все устройства', desc: 'Windows, macOS, Android, iOS — одна подписка для всех ваших устройств.' },
  { icon: 'Infinity', title: 'Без лимита трафика', desc: 'Смотрите, качайте и стримьте без ограничений.' },
  { icon: 'CheckCircle', title: 'Без рекламы', desc: 'YouTube, сайты и приложения без рекламных вставок.' },
  { icon: 'EyeOff', title: 'Без отслеживания', desc: 'Не храним логи вашей активности.' },
  { icon: 'Headphones', title: 'Техподдержка 24/7', desc: 'Поддержка через Telegram — ответим быстро.' },
];

interface Props {
  advantages?: { icon: string; title: string; desc: string; active: boolean }[];
}

export default function Features({ advantages }: Props) {
  const items = (advantages && advantages.length > 0)
    ? advantages.filter(a => a.active)
    : DEFAULT_FEATURES;

  return (
    <section className="section" id="features">
      <div className="section-title-row">
        <h2>Преимущества</h2>
        <div className="section-title-line" />
      </div>
      <div className="features-grid">
        {items.map((f, i) => (
          <div className="feature-card" key={i}>
            <div className="feature-icon">{ICON_MAP[f.icon] || <Zap size={22} />}</div>
            <h3>{f.title}</h3>
            <p>{f.desc}</p>
          </div>
        ))}
      </div>
    </section>
  );
}
