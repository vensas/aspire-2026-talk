import { useState, useEffect, useRef } from 'react';
import './App.css';

function CookieJarSvg({ level }: { level: number }) {
  const fillHeight = (level / 100) * 120;
  const fillY = 160 - fillHeight;

  return (
    <svg viewBox="0 0 120 200" className="cookie-jar-svg" aria-label={`Cookie jar: ${level} cookies`}>
      {/* jar body clip */}
      <defs>
        <clipPath id="jar-clip">
          <rect x="15" y="40" width="90" height="130" rx="8" />
        </clipPath>
      </defs>
      {/* fill */}
      <rect
        x="15" y={fillY} width="90" height={fillHeight + 10}
        fill={level > 30 ? '#f59e0b' : '#ef4444'}
        clipPath="url(#jar-clip)"
        className="jar-fill"
      />
      {/* jar outline */}
      <rect x="15" y="40" width="90" height="130" rx="8" fill="none" stroke="#6b7280" strokeWidth="3" />
      {/* lid */}
      <rect x="10" y="28" width="100" height="16" rx="4" fill="#9ca3af" stroke="#6b7280" strokeWidth="2" />
      <rect x="35" y="18" width="50" height="14" rx="4" fill="#9ca3af" stroke="#6b7280" strokeWidth="2" />
      {/* cookies visible when level > 0 */}
      {level > 10 && <circle cx="45" cy="140" r="12" fill="#92400e" opacity="0.8" />}
      {level > 25 && <circle cx="75" cy="135" r="12" fill="#92400e" opacity="0.8" />}
      {level > 50 && <circle cx="55" cy="115" r="12" fill="#92400e" opacity="0.8" />}
      {level > 70 && <circle cx="40" cy="100" r="10" fill="#92400e" opacity="0.7" />}
      {level > 85 && <circle cx="72" cy="95" r="10" fill="#92400e" opacity="0.7" />}
    </svg>
  );
}

export default function App() {
  const [level, setLevel] = useState<number | null>(null);
  const [refilling, setRefilling] = useState(false);
  const eventSourceRef = useRef<EventSource | null>(null);

  useEffect(() => {
    const es = new EventSource('/api/cookiejar/level/stream');
    eventSourceRef.current = es;

    es.onmessage = (e) => setLevel(Number(e.data));
    es.onerror = () => console.error('SSE connection lost');

    return () => es.close();
  }, []);

  const refill = async () => {
    setRefilling(true);
    try {
      await fetch('/api/cookiejar/refill', { method: 'POST' });
    } finally {
      setRefilling(false);
    }
  };

  return (
    <div className="app-container">
      <header className="app-header">
        <h1 className="app-title">🍪 Keksdose</h1>
        <p className="app-subtitle">Büro-Cookie-Tracker</p>
      </header>

      <main className="main-content">
        <div className="card">
          {level === null ? (
            <p className="loading">Verbinde...</p>
          ) : (
            <>
              <div className="jar-wrapper">
                <CookieJarSvg level={level} />
              </div>

              <div className="level-display">
                <span className="level-emoji">
                  {level === 0 ? '😢' : level <= 20 ? '😨' : ''}
                </span>
                <span className="level-value">{level}</span>
                <span className="level-label">
                  {level === 0 ? 'Leer!' : level <= 20 ? 'Fast leer' : level <= 50 ? 'Halbvoll' : 'Gut gefüllt'}
                </span>
              </div>

              <button
                className="refill-button"
                onClick={refill}
                disabled={refilling || level === 100}
                type="button"
              >
                {refilling ? 'Wird aufgefüllt...' : 'Keksdose auffüllen'}
              </button>
            </>
          )}
        </div>
      </main>
    </div>
  );
}
