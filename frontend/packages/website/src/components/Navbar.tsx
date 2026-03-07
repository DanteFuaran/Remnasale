interface NavbarProps {
  botUrl: string;
}

export default function Navbar({ botUrl }: NavbarProps) {
  return (
    <nav className="navbar">
      <div className="navbar-brand">
        <div className="navbar-logo">🚀</div>
        Remnasale
      </div>
      <div className="navbar-links">
        <a href="#features">Возможности</a>
        <a href="#plans">Тарифы</a>
        <a href="#advantages">Преимущества</a>
        <a href={botUrl} target="_blank" rel="noopener noreferrer" className="navbar-cta">
          Подключиться
        </a>
      </div>
    </nav>
  );
}
