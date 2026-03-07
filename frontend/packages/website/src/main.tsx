import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import './styles/global.css';

class ErrorBoundary extends React.Component<
  { children: React.ReactNode },
  { error: Error | null }
> {
  constructor(props: { children: React.ReactNode }) {
    super(props);
    this.state = { error: null };
  }
  static getDerivedStateFromError(error: Error) {
    return { error };
  }
  render() {
    if (this.state.error) {
      return (
        <div style={{
          padding: '40px',
          color: '#e74c3c',
          fontFamily: 'monospace',
          background: '#080C14',
          minHeight: '100vh',
        }}>
          <h2 style={{ color: '#fff', marginBottom: '16px' }}>Ошибка рендеринга</h2>
          <pre style={{ whiteSpace: 'pre-wrap', color: '#e74c3c', fontSize: '13px' }}>
            {this.state.error.message}
            {'\n\n'}
            {this.state.error.stack}
          </pre>
        </div>
      );
    }
    return this.props.children;
  }
}

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <ErrorBoundary>
      <App />
    </ErrorBoundary>
  </React.StrictMode>,
);
