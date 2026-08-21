import { useState, useEffect, useMemo, useRef } from 'react';

const API = '/api';

function fetchJson(url, opts = {}) {
  const headers = { 'Content-Type': 'application/json', ...opts.headers };
  const tk = opts.token;
  if (tk) headers['Authorization'] = `Bearer ${tk}`;
  return fetch(url, { ...opts, headers }).then(async (res) => {
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(data.error || 'Request failed');
    return data;
  });
}

async function refreshToken(stored) {
  if (!stored) return null;
  try {
    const res = await fetch(`${API}/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${stored}` }
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok || !data.token) return null;
    localStorage.setItem('activeOrdersToken', data.token);
    return data.token;
  } catch {
    return null;
  }
}

const ACTIVE_STATUSES_EXCLUDED = ['completed', 'payment collected', 'cancelled'];
const norm = (v) => String(v || '').trim().toLowerCase().replace(/\s+/g, ' ');

export function ActiveOrdersApp() {
  const [token, setToken] = useState(
    () =>
      localStorage.getItem('activeOrdersToken') ||
      localStorage.getItem('posToken') ||
      localStorage.getItem('orderTakerToken') ||
      ''
  );
  const [user, setUser] = useState(null);
  const [loginForm, setLoginForm] = useState({ email: '', password: '' });
  const [orders, setOrders] = useState([]);
  const [tables, setTables] = useState([]);
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState('');
  const [alertsEnabled, setAlertsEnabled] = useState(false);
  const [notifState, setNotifState] = useState(typeof Notification !== 'undefined' ? Notification.permission : 'unsupported');
  const [lastUpdated, setLastUpdated] = useState(null);
  const [viewOrder, setViewOrder] = useState(null);
  const [busyId, setBusyId] = useState(null);
  const [previewImage, setPreviewImage] = useState(null);
  const [refreshing, setRefreshing] = useState(false);

  const seenIdsRef = useRef(null);
  const audioCtxRef = useRef(null);
  const alertsRef = useRef(false);
  const keepAliveRef = useRef(null);
  const swRegRef = useRef(null);
  const tokenRef = useRef(token);
  tokenRef.current = token;

  useEffect(() => {
    document.title = 'Active Dine-In Orders';
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.register('/sw-active-orders.js').then((reg) => {
        swRegRef.current = reg;
      }).catch(() => {});
    }
    return () => stopKeepAlive();
  }, []);

  async function loadData(silent = true) {
    if (!tokenRef.current) return;
    try {
      let data;
      try {
        data = await fetchJson(`${API}/pos/orders`, { token: tokenRef.current });
      } catch (e) {
        const fresh = await refreshToken(tokenRef.current);
        if (fresh) {
          setToken(fresh);
          data = await fetchJson(`${API}/pos/orders`, { token: fresh });
        } else {
          throw e;
        }
      }
      const list = Array.isArray(data) ? data : [];
      setOrders(list);
      setLastUpdated(new Date());
      setMessage('');

      const tbls = await fetchJson(`${API}/pos/tables`, { token: tokenRef.current }).catch(() => []);
      setTables(Array.isArray(tbls) ? tbls : []);

      const active = list.filter((o) => o.orderType === 'Dine-In' && !ACTIVE_STATUSES_EXCLUDED.includes(norm(o.status)));
      const ids = new Set(active.map((o) => o.id));
      if (seenIdsRef.current === null) {
        seenIdsRef.current = ids;
        return;
      }
      const freshOnes = active.filter((o) => !seenIdsRef.current.has(o.id));
      seenIdsRef.current = ids;
      if (freshOnes.length > 0 && alertsRef.current) {
        fireAlerts(freshOnes);
      }
    } catch (e) {
      if (!silent) setMessage(e.message || 'Load failed');
      if (String(e.message).toLowerCase().includes('token') || String(e.message).toLowerCase().includes('auth')) {
        setToken('');
        setUser(null);
        localStorage.removeItem('activeOrdersToken');
      }
    }
  }

  useEffect(() => {
    if (token) loadData(true);
    const id = setInterval(() => loadData(true), 1000);
    return () => clearInterval(id);
  }, [token]);

  // Keep tab "playing audio" so Chrome does not throttle timers in background
  function startKeepAlive() {
    try {
      if (keepAliveRef.current) return;
      unlockAudio();
      const ctx = audioCtxRef.current;
      if (!ctx) return;
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'sine';
      osc.frequency.value = 55;
      gain.gain.value = 0.003;
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start();
      keepAliveRef.current = { ctx, osc, gain };
    } catch { /* ignore */ }
  }

  function stopKeepAlive() {
    try {
      if (keepAliveRef.current) {
        keepAliveRef.current.osc.stop();
        keepAliveRef.current = null;
      }
    } catch { /* ignore */ }
  }

  async function manualRefresh() {
    setRefreshing(true);
    await loadData(true);
    setTimeout(() => setRefreshing(false), 500);
  }

  function unlockAudio() {
    try {
      if (!audioCtxRef.current) {
        const Ctx = window.AudioContext || window.webkitAudioContext;
        audioCtxRef.current = new Ctx();
      }
      if (audioCtxRef.current.state === 'suspended') audioCtxRef.current.resume();
    } catch { /* ignore */ }
  }

  function playLoudAlert() {
    try {
      unlockAudio();
      const ctx = audioCtxRef.current;
      if (!ctx) return;
      const t0 = ctx.currentTime + 0.05;
      for (let i = 0; i < 10; i++) {
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        osc.type = 'square';
        osc.frequency.setValueAtTime(i % 2 ? 1400 : 900, t0 + i * 0.26);
        gain.gain.setValueAtTime(1.0, t0 + i * 0.26);
        gain.gain.exponentialRampToValueAtTime(0.01, t0 + i * 0.26 + 0.22);
        osc.connect(gain);
        gain.connect(ctx.destination);
        osc.start(t0 + i * 0.26);
        osc.stop(t0 + i * 0.26 + 0.24);
      }
    } catch { /* ignore */ }
  }

  function showNotifications(list) {
    const body = list
      .slice(0, 3)
      .map((o) => `Table ${o.tableNumber || '-'} · #${o.orderNumber || o.id} · ${(o.items || []).length} items · ${Number(o.total || o.amount || 0)} Rs`)
      .join('\n');
    // 1st: service worker notification (works in background, WhatsApp-style heads-up + vibration)
    try {
      if (swRegRef.current?.active) {
        swRegRef.current.active.postMessage({ type: 'notify', orders: list, tag: 'ao-' + Date.now() });
        return;
      }
    } catch { /* ignore */ }
    // Fallback: page notification
    if (typeof Notification === 'undefined' || Notification.permission !== 'granted') return;
    const title = list.length > 1 ? `🆕 ${list.length} New Dine-In Orders` : '🆕 New Dine-In Order';
    try {
      const n = new Notification(title, { body, tag: 'active-orders', renotify: true });
      setTimeout(() => n.close(), 15000);
    } catch {
      try {
        navigator.serviceWorker?.ready
          ?.then((reg) => reg.showNotification(title, { body, tag: 'active-orders' }))
          .catch(() => {});
      } catch { /* ignore */ }
    }
  }

  function fireAlerts(freshOnes) {
    playLoudAlert();
    setTimeout(playLoudAlert, 3200);
    try {
      navigator.vibrate?.([800, 200, 800, 200, 800]);
    } catch { /* ignore */ }
    showNotifications(freshOnes);
  }

  async function enableAlerts() {
    unlockAudio();
    let perm = typeof Notification !== 'undefined' ? Notification.permission : 'unsupported';
    if (perm === 'default') {
      try {
        perm = await Notification.requestPermission();
      } catch { perm = 'denied'; }
    }
    setNotifState(perm);
    alertsRef.current = true;
    setAlertsEnabled(true);
    startKeepAlive();
    playLoudAlert();
    setMessage('Alerts enabled - sound + vibration even with screen off ✅');
    setTimeout(() => setMessage(''), 4000);
  }

  async function handleLogin(e) {
    e.preventDefault();
    setLoading(true);
    setMessage('');
    try {
      const data = await fetchJson(`${API}/auth/login`, {
        method: 'POST',
        body: JSON.stringify(loginForm)
      });
      if (!data.user || !data.token) throw new Error('Login failed');
      localStorage.setItem('activeOrdersToken', data.token);
      setToken(data.token);
      setUser(data.user);
    } catch (e) {
      setMessage(e.message);
    } finally {
      setLoading(false);
    }
  }

  const activeOrders = useMemo(
    () =>
      orders
        .filter((o) => o.orderType === 'Dine-In' && !ACTIVE_STATUSES_EXCLUDED.includes(norm(o.status)))
        .sort((a, b) => new Date(b.createdAt || b.date || 0) - new Date(a.createdAt || a.date || 0)),
    [orders]
  );

  const tableStatusFor = (label) => {
    const t = tables.find((x) => String(x.label || x.name || x.number || '') === String(label || ''));
    return t ? String(t.status || '') : '';
  };

  function fmt(dt) {
    if (!dt) return '-';
    return new Date(dt).toLocaleString('en-US', { year: 'numeric', month: '2-digit', day: '2-digit', hour: 'numeric', minute: '2-digit', hour12: true });
  }

  function fmtTime(dt) {
    if (!dt) return '';
    return new Date(dt).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true });
  }

  async function markPaid(order) {
    if (!confirm(`Mark order #${order.orderNumber || order.id} as PAID?`)) return;
    setBusyId(order.id);
    try {
      await fetchJson(`${API}/pos/orders/${order.id}`, {
        method: 'PUT',
        token: tokenRef.current,
        body: JSON.stringify({
          status: 'Payment Collected',
          paymentStatus: 'Paid',
          items: order.items || [],
          customerName: order.customerName || '',
          phone: order.phone || '',
          address: order.address || '',
          tableNumber: order.tableNumber || '',
          deliveryAgent: order.deliveryAgent || '',
          serviceType: order.serviceType || '',
          deliveryFee: order.deliveryFee || 0,
          discount: order.discount || 0,
          taxPercent: order.taxPercent || 0,
          serviceCharge: order.serviceCharge || 0,
          paymentMethod: order.paymentMethod || 'Cash',
          notes: order.notes || ''
        })
      });
      const amount = Number(order.total || order.amount || 0);
      if (amount) {
        await fetchJson(`${API}/pos/payments`, {
          method: 'POST',
          token: tokenRef.current,
          body: JSON.stringify({
            orderId: order.id,
            amount,
            paymentMethod: order.paymentMethod || 'Cash',
            status: 'Completed',
            description: `Payment collected for order ${order.orderNumber || order.id}`
          })
        }).catch(() => {});
      }
      if (order.tableNumber) {
        const table = tables.find((t) => String(t.label || t.name || t.number || '') === String(order.tableNumber));
        if (table) {
          await fetchJson(`${API}/pos/tables/${table.id}`, {
            method: 'PUT',
            token: tokenRef.current,
            body: JSON.stringify({ status: 'available' })
          }).catch(() => {});
        }
      }
      setMessage(`Order #${order.orderNumber || order.id} marked paid ✅`);
      await loadData(true);
    } catch (e) {
      setMessage(e.message);
    } finally {
      setBusyId(null);
    }
  }

  async function markServed(order) {
    setBusyId(order.id);
    try {
      await fetchJson(`${API}/pos/orders/${order.id}`, {
        method: 'PUT',
        token: tokenRef.current,
        body: JSON.stringify({ status: 'Served', servedAt: new Date().toISOString() })
      });
      setMessage(`Order #${order.orderNumber || order.id} marked served 🍽️`);
      await loadData(true);
    } catch (e) {
      setMessage(e.message);
    } finally {
      setBusyId(null);
    }
  }

  async function deleteOrder(order) {
    if (!confirm(`DELETE order #${order.orderNumber || order.id}? This cannot be undone.`)) return;
    setBusyId(order.id);
    try {
      await fetchJson(`${API}/pos/orders/${order.id}`, { method: 'DELETE', token: tokenRef.current });
      setMessage(`Order #${order.orderNumber || order.id} deleted 🗑️`);
      await loadData(true);
    } catch (e) {
      setMessage(e.message);
    } finally {
      setBusyId(null);
    }
  }

  function printOrder(order) {
    const win = window.open('', '_blank', 'width=380,height=600');
    if (!win) return;
    const rows = (order.items || [])
      .map((it) => `<tr><td>${it.quantity}x</td><td>${it.name}</td><td style="text-align:right">${(Number(it.price) || 0) * (Number(it.quantity) || 0)}</td></tr>`)
      .join('');
    win.document.write(`<!doctype html><html><head><title>#${order.orderNumber || order.id}</title>
      <style>body{font-family:'Courier New',monospace;font-size:12px;padding:8px}h2{text-align:center;margin:4px 0}
      table{width:100%;border-collapse:collapse;margin-top:6px}td{padding:2px 0}.tot{font-weight:bold;border-top:1px dashed #000;margin-top:6px;padding-top:4px;display:flex;justify-content:space-between}</style></head><body>
      <h2>ACTIVE ORDER TICKET</h2>
      <div style="text-align:center">#${order.orderNumber || order.id} · TABLE ${order.tableNumber || '-'}</div><hr/>
      <div>Taker: ${order.orderTaker || order.waiter || '-'}</div>
      <div>Customer: ${order.customerName || '-'}</div>
      <div>Placed: ${fmt(order.createdAt)}</div><hr/>
      <table>${rows}</table>
      <div class="tot"><span>TOTAL</span><span>${Number(order.total || order.amount || 0)} Rs</span></div>
      <div style="text-align:center;margin-top:10px">Status: ${order.status || '-'}</div>
      </body></html>`);
    win.document.close();
    win.focus();
    win.print();
  }

  if (!token) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-slate-950 p-4 text-slate-100">
        <form onSubmit={handleLogin} className="w-full max-w-sm space-y-4 rounded-3xl border border-slate-800 bg-slate-900 p-6 shadow-xl">
          <div className="text-center">
            <div className="text-4xl">🆕</div>
            <h1 className="mt-2 text-xl font-bold">Active Orders Monitor</h1>
            <p className="mt-1 text-xs text-slate-400">Login to see live dine-in orders</p>
          </div>
          <input type="email" required value={loginForm.email} onChange={(e) => setLoginForm((p) => ({ ...p, email: e.target.value }))} placeholder="Email or username" className="w-full rounded-xl border border-slate-700 bg-slate-950 px-4 py-3 text-sm outline-none focus:border-emerald-500" />
          <input type="password" required value={loginForm.password} onChange={(e) => setLoginForm((p) => ({ ...p, password: e.target.value }))} placeholder="Password" className="w-full rounded-xl border border-slate-700 bg-slate-950 px-4 py-3 text-sm outline-none focus:border-emerald-500" />
          {message && <p className="rounded-lg bg-rose-950/60 px-3 py-2 text-xs text-rose-300">{message}</p>}
          <button type="submit" disabled={loading} className="w-full rounded-xl bg-emerald-600 py-3 text-sm font-bold text-white hover:bg-emerald-500 disabled:opacity-50">
            {loading ? 'Signing in...' : 'Sign In'}
          </button>
        </form>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-slate-950 pb-24 text-slate-100">
      {/* Header */}
      <div className="sticky top-0 z-40 border-b border-slate-800 bg-slate-950/95 backdrop-blur">
        <div className="mx-auto flex max-w-3xl flex-wrap items-center justify-between gap-2 px-3 py-2.5">
          <div className="flex items-center gap-2">
            <span className="text-xl">🆕</span>
            <div>
              <h1 className="text-base font-bold leading-tight">Active Dine-In Orders</h1>
              <p className="text-[10px] text-slate-400">
                {lastUpdated ? `Updated ${fmtTime(lastUpdated)} · auto-refresh 1s` : 'Loading...'}
              </p>
            </div>
            <span className={`ml-1 flex h-7 min-w-7 items-center justify-center rounded-full px-2 text-xs font-black ${activeOrders.length ? 'bg-emerald-600 text-white' : 'bg-slate-800 text-slate-400'}`}>
              {activeOrders.length}
            </span>
          </div>
          <div className="flex items-center gap-1.5">
            <button onClick={manualRefresh} title="Refresh orders" className="flex h-9 w-9 items-center justify-center rounded-full bg-slate-800 text-base text-emerald-400 transition-all active:scale-90 hover:bg-slate-700">
              <span className={`inline-block ${refreshing ? 'animate-spin' : ''}`}>🔄</span>
            </button>
            <button
              onClick={enableAlerts}
              className={`rounded-full px-3 py-2 text-xs font-bold transition-all active:scale-95 ${
                alertsEnabled ? 'bg-emerald-600 text-white shadow-[0_0_16px_rgba(16,185,129,0.6)]' : 'animate-pulse bg-gradient-to-r from-fuchsia-600 to-violet-600 text-white'
              }`}
            >
              {alertsEnabled ? '🔔 Alerts ON' : '🔔 Enable Sound + Alerts'}
            </button>
          </div>
        </div>
        {message && <div className="mx-auto max-w-3xl px-3 pb-2"><p className="rounded-lg bg-emerald-950/70 px-3 py-1.5 text-xs font-semibold text-emerald-300">{message}</p></div>}
        {notifState === 'denied' && (
          <div className="mx-auto max-w-3xl px-3 pb-2">
            <p className="rounded-lg bg-amber-950/60 px-3 py-1.5 text-[11px] text-amber-300">
              ⚠️ Notification permission blocked - allow it in browser site settings for popups. Loud sound still works.
            </p>
          </div>
        )}
      </div>

      {/* Orders */}
      <div className="mx-auto max-w-3xl space-y-3 px-3 pt-3">
        {activeOrders.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-24 text-slate-500">
            <div className="text-5xl">🎉</div>
            <p className="mt-2 text-sm font-semibold">No active dine-in orders</p>
            <p className="text-xs">New orders will appear here with a loud alert</p>
          </div>
        ) : (
          activeOrders.map((order) => {
            const isNew = Date.now() - new Date(order.createdAt || 0).getTime() < 5 * 60 * 1000;
            const served = norm(order.status) === 'served';
            return (
              <div
                key={order.id}
                className={`rounded-3xl border p-3 shadow-lg ${isNew && !served ? 'border-fuchsia-500/60 bg-gradient-to-br from-fuchsia-950/40 to-slate-900' : served ? 'border-amber-600/50 bg-slate-900' : 'border-emerald-700/50 bg-slate-900'}`}
              >
                <div className="flex items-start justify-between gap-2">
                  <div className="flex items-center gap-2">
                    <span className="flex h-12 min-w-12 flex-col items-center justify-center rounded-2xl bg-gradient-to-br from-emerald-500 to-emerald-700 px-2 text-white shadow-md">
                      <span className="text-[8px] font-bold uppercase opacity-80">Table</span>
                      <span className="text-sm font-black leading-none">{String(order.tableNumber || '-').replace(/table/i, '').trim() || '-'}</span>
                    </span>
                    <div>
                      <div className="text-sm font-black text-white">#{order.orderNumber || order.id}</div>
                      <div className="text-[11px] font-bold text-cyan-300">{fmtTime(order.createdAt)}</div>
                    </div>
                  </div>
                  <div className="text-right">
                    <div className="text-lg font-black text-emerald-400">{Number(order.total || order.amount || 0)}<span className="ml-0.5 text-[10px]">Rs</span></div>
                    <span className={`inline-flex rounded-full px-2 py-0.5 text-[9px] font-black uppercase ${served ? 'bg-amber-500 text-slate-950' : 'bg-violet-600 text-white'}`}>
                      {isNew && !served ? '🔥 NEW' : order.status}
                    </span>
                  </div>
                </div>

                <div className="mt-2 space-y-0.5 text-[11px] text-slate-300">
                  <p>👤 {order.customerName || 'Walk-in'} {order.phone ? `· 📞 ${order.phone}` : ''}</p>
                  <p className="font-bold text-violet-300">🧑‍💼 Taker: {order.orderTaker || order.waiter || '-'}</p>
                  <p className="line-clamp-2 text-slate-400">
                    {(order.items || []).map((it, idx) => `${it.quantity}x ${it.name}`).join(', ')}
                  </p>
                </div>
                {String(order.notes || '').trim() && (
                  <p className="mt-1 rounded-lg bg-slate-800/80 px-2 py-1 text-[10px] text-amber-200">📝 {order.notes}</p>
                )}
                {order.paymentRequestImage && (
                  <button onClick={() => setPreviewImage(order.paymentRequestImage)} className="mt-2 flex w-full items-center gap-2 rounded-xl border border-amber-600/40 bg-slate-950/70 p-2 text-left transition active:scale-[0.98]">
                    <img src={order.paymentRequestImage} alt="Payment proof" className="h-12 w-12 rounded-lg border border-amber-500/50 object-cover" />
                    <span className="min-w-0 flex-1">
                      <span className="block text-[10px] font-bold text-amber-400">📷 Payment photo attached</span>
                      {order.paymentRequestedAt && (
                        <span className="block text-[9px] text-slate-500">{fmt(order.paymentRequestedAt)}</span>
                      )}
                      {order.paymentRequestStatus === 'owner-request' && (
                        <span className="block text-[9px] font-bold text-violet-400">✅ Request sent to owner{order.paymentMethod ? ` (${order.paymentMethod})` : ''}</span>
                      )}
                    </span>
                    <span className="shrink-0 text-slate-500">🔍</span>
                  </button>
                )}

                <div className="mt-2.5 grid grid-cols-5 gap-1.5">
                  <button onClick={() => markPaid(order)} disabled={busyId === order.id} className="flex flex-col items-center justify-center gap-0.5 rounded-2xl bg-gradient-to-b from-emerald-500 to-emerald-700 py-2.5 text-white shadow transition-all active:scale-90 disabled:opacity-50">
                    <span className="text-lg leading-none">✅</span>
                    <span className="text-[9px] font-black">PAID</span>
                  </button>
                  <button onClick={() => markServed(order)} disabled={busyId === order.id || served} className="flex flex-col items-center justify-center gap-0.5 rounded-2xl bg-gradient-to-b from-amber-400 to-amber-600 py-2.5 text-slate-950 shadow transition-all active:scale-90 disabled:opacity-50">
                    <span className="text-lg leading-none">🍽️</span>
                    <span className="text-[9px] font-black">{served ? 'SERVED' : 'SERVE'}</span>
                  </button>
                  <button onClick={() => printOrder(order)} className="flex flex-col items-center justify-center gap-0.5 rounded-2xl bg-gradient-to-b from-sky-500 to-sky-700 py-2.5 text-white shadow transition-all active:scale-90">
                    <span className="text-lg leading-none">🖨️</span>
                    <span className="text-[9px] font-black">PRINT</span>
                  </button>
                  <button onClick={() => setViewOrder(order)} className="flex flex-col items-center justify-center gap-0.5 rounded-2xl bg-gradient-to-b from-indigo-500 to-indigo-700 py-2.5 text-white shadow transition-all active:scale-90">
                    <span className="text-lg leading-none">👁️</span>
                    <span className="text-[9px] font-black">VIEW</span>
                  </button>
                  <button onClick={() => deleteOrder(order)} disabled={busyId === order.id} className="flex flex-col items-center justify-center gap-0.5 rounded-2xl bg-gradient-to-b from-rose-500 to-rose-700 py-2.5 text-white shadow transition-all active:scale-90 disabled:opacity-50">
                    <span className="text-lg leading-none">🗑️</span>
                    <span className="text-[9px] font-black">DEL</span>
                  </button>
                </div>
              </div>
            );
          })
        )}
      </div>

      {/* Fullscreen payment photo preview */}
      {previewImage && (
        <div className="fixed inset-0 z-[70] flex items-center justify-center bg-black/95 p-3" onClick={() => setPreviewImage(null)}>
          <button onClick={() => setPreviewImage(null)} className="absolute right-4 top-4 z-10 rounded-full bg-slate-800 px-4 py-2 text-sm font-bold text-white">✕ Close</button>
          <img src={previewImage} alt="Payment proof" className="max-h-full max-w-full rounded-2xl object-contain" />
        </div>
      )}

      {/* View modal */}
      {viewOrder && (
        <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/75 sm:items-center" onClick={() => setViewOrder(null)}>
          <div className="max-h-[85vh] w-full max-w-md overflow-y-auto rounded-t-3xl border border-slate-700 bg-slate-900 p-5 sm:rounded-3xl" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-start justify-between">
              <div>
                <h3 className="text-lg font-black text-white">#{viewOrder.orderNumber || viewOrder.id}</h3>
                <p className="text-xs text-slate-400">Table {viewOrder.tableNumber || '-'} · {fmt(viewOrder.createdAt)}</p>
              </div>
              <button onClick={() => setViewOrder(null)} className="rounded-full border border-slate-700 bg-slate-800 px-3 py-1.5 text-sm text-slate-200">✕</button>
            </div>
            <div className="mt-3 space-y-1 text-xs text-slate-300">
              <p>👤 Customer: {viewOrder.customerName || 'Walk-in'} {viewOrder.phone ? `· 📞 ${viewOrder.phone}` : ''}</p>
              <p className="font-bold text-violet-300">🧑‍💼 Order Taker: {viewOrder.orderTaker || viewOrder.waiter || '-'}</p>
              <p>💳 Payment: {viewOrder.paymentMethod || '-'} · {viewOrder.paymentStatus || '-'}</p>
              <p>📍 Status: {viewOrder.status || '-'}</p>
              {viewOrder.notes && <p>📝 {viewOrder.notes}</p>}
            </div>
            <div className="mt-3 rounded-2xl border border-slate-800 bg-slate-950 p-3">
              {(viewOrder.items || []).map((it, idx) => (
                <div key={idx} className="flex items-center justify-between border-b border-slate-800/70 py-1.5 text-xs last:border-0">
                  <span className="text-slate-200">{it.quantity}x {it.name}</span>
                  <span className="font-semibold text-slate-300">{(Number(it.price) || 0) * (Number(it.quantity) || 0)} Rs</span>
                </div>
              ))}
              <div className="mt-2 flex items-center justify-between text-sm font-black text-emerald-400">
                <span>TOTAL</span>
                <span>{Number(viewOrder.total || viewOrder.amount || 0)} Rs</span>
              </div>
            </div>
            {viewOrder.paymentRequestImage && (
              <button onClick={() => setPreviewImage(viewOrder.paymentRequestImage)} className="mt-3 flex w-full items-center gap-3 rounded-2xl border border-amber-600/40 bg-slate-950 p-3 text-left transition active:scale-[0.98]">
                <img src={viewOrder.paymentRequestImage} alt="Payment proof" className="h-14 w-14 rounded-xl border border-amber-500/50 object-cover" />
                <span className="min-w-0 flex-1">
                  <span className="block text-xs font-bold text-amber-400">📷 Payment photo attached</span>
                  <span className="block text-[10px] text-slate-500">Tap to view full image</span>
                </span>
                <span className="shrink-0 text-slate-500">🔍</span>
              </button>
            )}
            <div className="mt-3 grid grid-cols-4 gap-1.5">
              <button onClick={() => { markPaid(viewOrder); setViewOrder(null); }} className="rounded-xl bg-emerald-600 py-2 text-[11px] font-black text-white">✅ PAID</button>
              <button onClick={() => { printOrder(viewOrder); }} className="rounded-xl bg-sky-600 py-2 text-[11px] font-black text-white">🖨️ PRINT</button>
              <button onClick={() => { deleteOrder(viewOrder); setViewOrder(null); }} className="rounded-xl bg-rose-600 py-2 text-[11px] font-black text-white">🗑️ DEL</button>
              <button onClick={() => setViewOrder(null)} className="rounded-xl bg-slate-700 py-2 text-[11px] font-black text-white">CLOSE</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
