import { Component } from 'react';

export default class ErrorBoundary extends Component {
  constructor(props) {
    super(props);
    this.state = { error: null };
  }

  static getDerivedStateFromError(error) {
    return { error };
  }

  componentDidCatch(error, info) {
    console.error('App crashed:', error, info);
  }

  render() {
    if (this.state.error) {
      return (
        <div style={{ minHeight: '100vh', background: '#020617', color: '#f1f5f9', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '1rem', fontFamily: 'system-ui, sans-serif' }}>
          <div style={{ maxWidth: 480, width: '100%', background: '#0f172a', border: '1px solid #334155', borderRadius: 16, padding: '1.5rem', textAlign: 'center' }}>
            <div style={{ fontSize: '2.5rem', marginBottom: '0.5rem' }}>⚠️</div>
            <h2 style={{ fontSize: '1.1rem', fontWeight: 700, margin: 0 }}>Something went wrong</h2>
            <p style={{ fontSize: '0.8rem', color: '#94a3b8', marginTop: '0.5rem', wordBreak: 'break-word' }}>
              {String(this.state.error?.message || this.state.error || 'Unknown error')}
            </p>
            <button
              onClick={() => window.location.reload()}
              style={{ marginTop: '1rem', background: '#059669', color: '#fff', border: 'none', borderRadius: 999, padding: '0.6rem 1.5rem', fontSize: '0.85rem', fontWeight: 600, cursor: 'pointer' }}
            >
              Reload App
            </button>
          </div>
        </div>
      );
    }
    return this.props.children;
  }
}
