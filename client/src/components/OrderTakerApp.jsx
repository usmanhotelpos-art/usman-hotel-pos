import { useState, useEffect, useMemo, useRef } from 'react';

const API = '/api';

function fetchJson(url, opts = {}) {
  const headers = { 'Content-Type': 'application/json', ...opts.headers };
  if (opts.token) headers['Authorization'] = `Bearer ${opts.token}`;
  return fetch(url, { ...opts, headers }).then(async (r) => {
    const data = await r.json();
    if (!r.ok) throw new Error(data.error || 'Request failed');
    return data;
  });
}

const CATEGORY_ICONS = {
  'All': '🎯', 'Chicken': '🍗', 'Steak': '🥩', 'Fish': '🐟', 'Salad': '🥗', 'Juice': '🧃', 'Dessert': '🍰', 'Burger': '🍔',
  'Pizza': '🍕', 'Soup': '🍜', 'Biryani': '🍚', 'Mutton': '🐑', 'Beef': '🥩', 'BBQ': '🔥', 'Grill': '🥩', 'Chinese': '🥟',
  'Rice': '🍚', 'Roll': '🌯', 'Wrap': '🌯', 'Tea': '☕', 'Coffee': '☕', 'Breakfast': '🍳', 'Sandwich': '🥪', 'Pasta': '🍝',
  'Noodles': '🍜', 'Ice Cream': '🍨', 'Smoothie': '🥤', 'Combo': '🎯', 'Special': '⭐', 'Tikka': '🥘', 'Karhai': '🍲',
  'Drinks': '🥤', 'Beverage': '🥤', 'Shawarma': '🌯', 'Fries': '🍟', 'Mandi': '🍛', 'Handi': '🍲', 'Kebab': '🥙',
  'Nihari': '🍲', 'Haleem': '🥣', 'Dosa': '🥞', 'Curry': '🍛', 'Dal': '🥣', 'Paratha': '🫓', 'Roti': '🫓', 'Bread': '🍞',
  'Seafood': '🦐', 'Platter': '🍽️', 'Family': '👨‍👩‍👧‍👦', 'Deal': '💥', 'Addon': '➕', 'Extra': '➕', 'Dips': '🥫',
  'Sauce': '🥫', 'Topping': '🧀', 'Cheese': '🧀', 'Mashallah': '🌟', 'ناشتے کی آئٹمز': '🍳', 'چکن کڑاہی مینیو': '🍲',
  'سیخ کباب': '🥙', 'بوٹی آئٹمز': '🥩', 'چکن پیسز': '🍗', 'نان اور روٹی': '🫓', 'اسپیشل نان': '🫓',
  'Karahi': '🍲', 'Fast Food': '🍟', 'مَا شَاءَ ٱللَّٰهُ': '🌟'
};

function getCatIcon(name) {
  if (!name) return '📁';
  if (CATEGORY_ICONS[name]) return CATEGORY_ICONS[name];
  const lower = name.toLowerCase();
  for (const [key, icon] of Object.entries(CATEGORY_ICONS)) {
    if (key.toLowerCase() === lower) return icon;
  }
  for (const [key, icon] of Object.entries(CATEGORY_ICONS)) {
    if (lower.includes(key.toLowerCase()) || key.toLowerCase().includes(lower)) return icon;
  }
  return '📁';
}

const getTableLabel = (table) => String(table.label || table.name || table.number || `Table ${table.id}`);

const MASHALLAH_CATEGORY = 'مَا شَاءَ ٱللَّٰهُ';

export function OrderTakerApp() {
  const [token, setToken] = useState('');
  const [orderTaker, setOrderTaker] = useState(null);
  const [loginForm, setLoginForm] = useState({ email: '', password: '' });
  const [message, setMessage] = useState('');
  const [loading, setLoading] = useState(false);

  // POS data
  const [products, setProducts] = useState([]);
  const [categories, setCategories] = useState([]);
  const [tables, setTables] = useState([]);
  const [orders, setOrders] = useState([]);
  const [settings, setSettings] = useState({});
  const [mashallahSlots, setMashallahSlots] = useState([]);

  // POS state
  const [activeType, setActiveType] = useState('Dine-In');
  const [search, setSearch] = useState('');
  const [category, setCategory] = useState('All');
  const [cart, setCart] = useState([]);
  const [showCart, setShowCart] = useState(false);
  const [showDetails, setShowDetails] = useState(false);
  const [orderedItems, setOrderedItems] = useState({});
  const [showOrdersPopup, setShowOrdersPopup] = useState(false);

  // Order creation
  const [customerName, setCustomerName] = useState('');
  const [phone, setPhone] = useState('');
  const [tableNumber, setTableNumber] = useState('');
  const [notes, setNotes] = useState('');

  // Edit
  const [editOrder, setEditOrder] = useState(null);
  const [editCart, setEditCart] = useState([]);

  // Payment request photo
  const [requestOrderId, setRequestOrderId] = useState(null);
  const [previewImage, setPreviewImage] = useState(null);
  const fileInputRef = useRef(null);

  const apiBase = API;

  useEffect(() => {
    const saved = localStorage.getItem('orderTakerToken');
    const savedUser = localStorage.getItem('orderTakerUser');
    if (saved && savedUser) {
      setToken(saved);
      try { setOrderTaker(JSON.parse(savedUser)); } catch {}
    }
  }, []);

  useEffect(() => {
    if (!token || !orderTaker) return;
    loadData();
  }, [token, orderTaker]);

  async function loadData() {
    try {
      const [cats, prods, tbls, ords, sets, slots] = await Promise.all([
        fetchJson(`${apiBase}/pos/categories`, { token }).catch(() => null),
        fetchJson(`${apiBase}/pos/products`, { token }).catch(() => null),
        fetchJson(`${apiBase}/pos/tables`, { token }).catch(() => null),
        fetchJson(`${apiBase}/pos/orders`, { token }).catch(() => null),
        fetchJson(`${apiBase}/settings`).catch(() => null),
        fetchJson(`${apiBase}/pos/mashallah-slots`, { token }).catch(() => null),
      ]);
      if (Array.isArray(cats)) setCategories(cats);
      if (Array.isArray(prods)) setProducts(prods);
      if (Array.isArray(tbls)) setTables(tbls);
      if (Array.isArray(ords)) setOrders(ords);
      if (sets) setSettings(sets);
      if (Array.isArray(slots)) setMashallahSlots(slots);
    } catch (e) { setMessage(e.message); }
  }

  async function handleLogin(e) {
    e.preventDefault();
    setLoading(true);
    setMessage('');
    try {
      const data = await fetchJson(`${apiBase}/auth/login`, {
        method: 'POST',
        body: JSON.stringify(loginForm),
      });
      if (!data.user || !['Order Taker', 'Waiter', 'Helper'].includes(data.user.role)) {
        throw new Error('Invalid Order Taker credentials');
      }
      setToken(data.token);
      setOrderTaker(data.user);
      localStorage.setItem('orderTakerToken', data.token);
      localStorage.setItem('orderTakerUser', JSON.stringify(data.user));
      setMessage('');
    } catch (e) {
      setMessage(e.message);
    } finally {
      setLoading(false);
    }
  }

  function handleLogout() {
    setToken('');
    setOrderTaker(null);
    localStorage.removeItem('orderTakerToken');
    localStorage.removeItem('orderTakerUser');
    setCart([]);
    setEditOrder(null);
  }

  function addToCart(product) {
    setCart(prev => {
      const existing = prev.find(i => i.id === product.id);
      if (existing) return prev.map(i => i.id === product.id ? { ...i, quantity: i.quantity + 1 } : i);
      return [...prev, { ...product, quantity: 1, itemId: `${product.id}-${Date.now()}` }];
    });
    setOrderedItems(prev => ({ ...prev, [product.id]: true }));
    setTimeout(() => setOrderedItems(prev => ({ ...prev, [product.id]: false })), 600);
  }

  function updateCartQty(itemId, delta) {
    setCart(prev => prev.map(i => i.itemId === itemId ? { ...i, quantity: Math.max(0, i.quantity + delta) } : i).filter(i => i.quantity > 0));
  }

  function removeFromCart(itemId) {
    setCart(prev => prev.filter(i => i.itemId !== itemId));
  }

  const cartTotal = cart.reduce((s, i) => s + (Number(i.price) || 0) * i.quantity, 0);
  const cartCount = cart.reduce((s, i) => s + i.quantity, 0);

  const mashallahProducts = useMemo(() => {
    return (mashallahSlots || [])
      .map((slot) => {
        const product = products.find((item) => item.id === slot.productId);
        return product ? product : null;
      })
      .filter(Boolean);
  }, [mashallahSlots, products]);

  const filteredProducts = useMemo(() => {
    const searchTerm = search.toLowerCase().trim();
    const matchesSearch = (p) =>
      !searchTerm ||
      (p.name || '').toLowerCase().includes(searchTerm) ||
      (p.category || '').toLowerCase().includes(searchTerm) ||
      (p.code || '').toLowerCase().includes(searchTerm) ||
      (p.id || '').toLowerCase().includes(searchTerm);
    if (category === MASHALLAH_CATEGORY) {
      return mashallahProducts.filter(matchesSearch);
    }
    return products.filter(p => {
      if (category !== 'All' && p.category !== category) return false;
      return matchesSearch(p);
    });
  }, [products, category, search, mashallahProducts]);

  const allCategories = useMemo(() => {
    const names = (categories || []).map((c) => c.name).filter(Boolean);
    return ['All', MASHALLAH_CATEGORY, ...names];
  }, [categories]);

  // Tables data
  const tablesList = useMemo(() => {
    const occupiedTableNumbers = new Set(
      orders.filter(o => o.orderType === 'Dine-In' && !['completed', 'payment collected'].includes((o.status || '').toLowerCase())).map(o => o.tableNumber).filter(Boolean)
    );
    return { occupied: occupiedTableNumbers };
  }, [orders]);

  const availableDineInTables = useMemo(() => {
    return (tables || []).map(table => ({
      ...table,
      isOccupied: tablesList.occupied.has(getTableLabel(table)),
    }));
  }, [tables, tablesList]);

  // Orders by this order taker only
  const myOrders = useMemo(() => {
    const name = orderTaker?.name || '';
    const username = orderTaker?.username || '';
    return orders.filter(o => o.orderTaker === name || o.orderTaker === username || o.waiter === name || o.waiter === username);
  }, [orders, orderTaker]);

  async function createOrder() {
    if (!cart.length) { setMessage('Cart is empty'); return; }
    if (activeType === 'Dine-In' && !tableNumber) { setMessage('Please select a table or room'); return; }
    setLoading(true);
    try {
      const payload = {
        items: cart.map(i => ({ productId: i.id, name: i.name, price: i.price, quantity: i.quantity, code: i.code || '' })),
        orderType: 'Dine-In',
        customerName: customerName || '',
        phone,
        tableNumber,
        notes,
        orderTaker: orderTaker?.name || orderTaker?.username || '',
        waiter: orderTaker?.name || orderTaker?.username || '',
        status: 'Pending',
        paymentStatus: 'Pending',
        serviceType: '',
        deliveryFee: 0,
        discount: 0,
        taxPercent: 0,
        serviceCharge: 0,
        paymentMethod: 'Cash',
      };
      await fetchJson(`${apiBase}/pos/orders`, { method: 'POST', body: JSON.stringify(payload), token });
      setCart([]);
      setCustomerName('');
      setPhone('');
      setTableNumber('');
      setNotes('');
      setShowCart(false);
      setShowDetails(false);
      setMessage('Order created successfully');
      await loadData();
    } catch (e) { setMessage(e.message); } finally { setLoading(false); }
  }

  async function saveEditOrder() {
    if (!editOrder) return;
    setLoading(true);
    try {
      const payload = {
        items: editCart.map(i => ({ productId: i.id, name: i.name, price: i.price, quantity: i.quantity, code: i.code || '' })),
        customerName: editOrder.customerName || '',
        phone: editOrder.phone || '',
        tableNumber: editOrder.tableNumber || '',
        deliveryAgent: editOrder.deliveryAgent || '',
        serviceType: editOrder.serviceType || '',
        deliveryFee: editOrder.deliveryFee || 0,
        discount: editOrder.discount || 0,
        taxPercent: editOrder.taxPercent || 0,
        serviceCharge: editOrder.serviceCharge || 0,
        paymentMethod: editOrder.paymentMethod || 'Cash',
        paymentStatus: editOrder.paymentStatus || 'Pending',
        notes: editOrder.notes || '',
        status: editOrder.status || 'Pending',
        orderTaker: orderTaker?.name || orderTaker?.username || '',
      };
      await fetchJson(`${apiBase}/pos/orders/${editOrder.id}`, { method: 'PUT', body: JSON.stringify(payload), token });
      setEditOrder(null);
      setEditCart([]);
      setMessage('Order updated');
      await loadData();
    } catch (e) { setMessage(e.message); } finally { setLoading(false); }
  }

  function openEditOrder(order) {
    setEditOrder(order);
    setEditCart((order.items || []).map(i => ({ ...i, id: i.productId || i.id, itemId: `${i.productId || i.id}-edit` })));
  }

  function openRequestCamera(orderId) {
    setRequestOrderId(orderId);
    setTimeout(() => fileInputRef.current?.click(), 50);
  }

  function compressImage(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onerror = reject;
      reader.onload = () => {
        const img = new Image();
        img.onerror = reject;
        img.onload = () => {
          const maxDim = 900;
          let { width, height } = img;
          if (width > maxDim || height > maxDim) {
            const ratio = Math.min(maxDim / width, maxDim / height);
            width = Math.round(width * ratio);
            height = Math.round(height * ratio);
          }
          const canvas = document.createElement('canvas');
          canvas.width = width;
          canvas.height = height;
          canvas.getContext('2d').drawImage(img, 0, 0, width, height);
          resolve(canvas.toDataURL('image/jpeg', 0.72));
        };
        img.src = reader.result;
      };
      reader.readAsDataURL(file);
    });
  }

  async function handleRequestImage(e) {
    const file = e.target.files?.[0];
    e.target.value = '';
    if (!file || !requestOrderId) return;
    setLoading(true);
    try {
      const image = await compressImage(file);
      await fetchJson(`${apiBase}/pos/orders/${requestOrderId}`, {
        method: 'PUT',
        body: JSON.stringify({
          paymentRequestImage: image,
          paymentRequestedAt: new Date().toISOString(),
          orderTaker: orderTaker?.name || orderTaker?.username || '',
        }),
        token
      });
      setRequestOrderId(null);
      setMessage('Payment request sent with photo');
      await loadData();
    } catch (err) { setMessage(err.message); setRequestOrderId(null); } finally { setLoading(false); }
  }

  if (!token || !orderTaker) {
    return (
      <div className="min-h-screen bg-slate-950 text-slate-100 flex items-center justify-center p-4">
        <div className="w-full max-w-sm">
          <div className="text-center mb-6">
            <div className="text-5xl mb-2">📋</div>
            <h1 className="text-2xl font-bold text-white">Order Taker App</h1>
            <p className="text-sm text-slate-400 mt-1">Login to start taking orders</p>
          </div>
          <form onSubmit={handleLogin} className="space-y-4">
            <input type="text" value={loginForm.email} onChange={(e) => setLoginForm({ ...loginForm, email: e.target.value })} placeholder="Username" className="w-full rounded-xl border border-slate-700 bg-slate-900 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" required />
            <input type="password" value={loginForm.password} onChange={(e) => setLoginForm({ ...loginForm, password: e.target.value })} placeholder="Password" className="w-full rounded-xl border border-slate-700 bg-slate-900 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" required />
            {message && <p className="text-xs text-rose-400 text-center">{message}</p>}
            <button type="submit" disabled={loading || !loginForm.email || !loginForm.password} className="w-full rounded-xl bg-emerald-600 py-3 text-sm font-bold text-white hover:bg-emerald-500 disabled:opacity-50">
              {loading ? 'Logging in...' : 'Login'}
            </button>
          </form>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-white text-slate-900 pb-28">
      {/* Header */}
      <div className="sticky top-0 z-40 bg-white/95 backdrop-blur-xl border-b border-slate-200 px-3 py-2 flex items-center justify-between gap-2">
        <div className="flex items-center gap-2 min-w-0">
          <span className="text-lg">📋</span>
          <div className="min-w-0">
            <p className="text-xs font-bold text-emerald-600 truncate">{orderTaker?.name || orderTaker?.username}</p>
            <p className="text-[10px] text-slate-400">{orderTaker?.role || 'Order Taker'}</p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <button onClick={() => setShowOrdersPopup(true)} className="relative rounded-full bg-slate-100 px-3 py-1.5 text-xs font-semibold text-slate-700 hover:bg-slate-200">
            📋 Orders {myOrders.length > 0 && <span className="ml-1 text-emerald-600 font-bold">({myOrders.length})</span>}
          </button>
          <button onClick={handleLogout} className="rounded-full bg-rose-600 px-3 py-1.5 text-xs font-semibold text-white">Logout</button>
        </div>
      </div>

      {/* Search */}
      <div className="px-3 pb-2">
        <div className="relative">
          <input type="text" value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Search menu..." className="w-full rounded-full border border-slate-200 bg-white pl-4 pr-9 py-2 text-sm text-slate-900 placeholder-slate-400 outline-none focus:border-emerald-400 shadow-sm" />
          <div className="pointer-events-none absolute right-0 top-0 flex h-full w-8 items-center justify-center rounded-r-full text-xs text-slate-400">🔍</div>
        </div>
      </div>

      {/* Categories left + Products right */}
      <div className="flex gap-2 px-3">
        <div className="w-16 shrink-0 overflow-y-auto max-h-[70vh] space-y-1.5">
          {allCategories.map(cat => {
            const catObj = (categories || []).find((c) => c.name === cat);
            return (
              <button key={cat} onClick={() => setCategory(cat)}
                className={`flex flex-col items-center justify-center rounded-xl px-1 py-1.5 text-[9px] font-medium transition-all duration-200 min-h-[52px] w-full ${
                  category === cat
                    ? cat === MASHALLAH_CATEGORY ? 'bg-amber-600 text-white shadow-lg ring-2 ring-amber-400/50 scale-105' : 'bg-emerald-600 text-white shadow-lg ring-2 ring-emerald-400/50 scale-105'
                    : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
                }`}>
                {catObj?.icon ? (
                  <img src={catObj.icon} alt="" className="w-5 h-5 rounded-full object-cover mb-0.5 shadow-sm" />
                ) : (
                  <span className="text-xl mb-0.5">{getCatIcon(cat)}</span>
                )}
                <span className="leading-tight text-center font-semibold truncate w-full">{cat}</span>
              </button>
            );
          })}
        </div>
        <div className="flex-1 min-w-0">
          {filteredProducts.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-16 text-slate-400">
              <div className="text-4xl mb-2">🍽️</div>
              <p className="text-sm">No products found</p>
            </div>
          ) : (
            <div className="grid grid-cols-3 gap-1.5">
              {filteredProducts.map(product => (
                <button key={product.id} type="button" onClick={() => addToCart(product)}
                  className={`relative rounded-xl border p-1.5 shadow-soft transition active:scale-[0.97] ${
                    orderedItems[product.id] ? 'border-emerald-500 bg-emerald-50 scale-105' : 'border-slate-200 bg-white hover:border-emerald-300'
                  }`}>
                  <div className="flex flex-col items-center text-center mb-1">
                    {product.photo ? (
                      <img src={product.photo} alt={product.name} className="w-14 h-14 rounded-full object-cover mb-0.5 shadow-md" />
                    ) : (
                      <div className="w-14 h-14 rounded-full bg-gradient-to-br from-sky-100 to-indigo-100 flex items-center justify-center mb-0.5 text-slate-500 text-lg shadow-md">📦</div>
                    )}
                  </div>
                  <div className="text-sm font-black text-transparent bg-clip-text bg-gradient-to-r from-violet-600 via-fuchsia-500 to-rose-500 leading-tight line-clamp-2 mb-0.5" style={{textShadow: '0 0 12px rgba(168,85,247,0.4), 0 0 24px rgba(236,72,153,0.2)'}}>{product.name}</div>
                  <div className="text-xs font-extrabold text-emerald-500" style={{textShadow: '0 0 8px rgba(16,185,129,0.5)'}}>{Number(product.price) || 0} PKR</div>
                  {orderedItems[product.id] && (
                    <span className="absolute -top-1.5 -right-1.5 flex h-5 w-5 items-center justify-center rounded-full bg-emerald-500 text-[10px] font-bold text-white shadow-lg ring-2 ring-white">✓</span>
                  )}
                </button>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Floating cart button */}
      {cart.length > 0 && !showCart && !showDetails && (
        <button onClick={() => setShowDetails(true)}
          className="fixed right-4 z-[60] flex items-center gap-2 rounded-2xl bg-emerald-600 px-4 py-3 text-sm font-bold text-white shadow-[0_8px_32px_rgba(16,185,129,0.5)] active:scale-95 transition-all duration-200 hover:shadow-[0_8px_32px_rgba(16,185,129,0.7)]"
          style={{ bottom: 80 }}>
          <span className="flex h-7 w-7 items-center justify-center rounded-full bg-white/20 text-xs">🛒</span>
          <span>{cartCount} items · {cartTotal} PKR</span>
        </button>
      )}

      {/* Order details popup (customer name / notes / table selection) */}
      {showDetails && (
        <div className="fixed inset-0 z-[70] flex items-end sm:items-center justify-center bg-black/60" onClick={() => setShowDetails(false)}>
          <div className="w-full sm:max-w-md max-h-[85vh] rounded-t-3xl sm:rounded-3xl border border-slate-700 bg-slate-950 p-5 shadow-[0_35px_120px_-30px_rgba(0,0,0,0.8)] overflow-y-auto" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between">
              <div>
                <p className="text-xs uppercase tracking-[0.2em] text-slate-500">Order details</p>
                <h3 className="mt-2 text-xl font-semibold text-white">🍽️ Dine-In order</h3>
              </div>
              <button onClick={() => setShowDetails(false)} className="rounded-full border border-slate-700 bg-slate-900 px-3 py-2 text-sm text-slate-200 hover:bg-slate-800">✕</button>
            </div>
            <div className="mt-6 space-y-4">
              <div className="grid gap-3">
                <label className="text-sm text-slate-400">Table / Room</label>
                <select value={tableNumber} onChange={(e) => setTableNumber(e.target.value)} className="w-full rounded-3xl border border-slate-800 bg-slate-900 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500">
                  <option value="">Select table or room</option>
                  {availableDineInTables.length ? availableDineInTables.map((table) => (
                    <option key={table.id} value={getTableLabel(table)}>
                      {getTableLabel(table)}{table.isOccupied ? ' (Busy)' : ''}
                    </option>
                  )) : <option value="" disabled>No tables found</option>}
                </select>
                {!tableNumber && <p className="text-xs text-amber-400">Select a table to continue</p>}
              </div>
              <div className="grid gap-3">
                <label className="text-sm text-slate-400">Phone <span className="text-slate-500">(optional)</span></label>
                <input type="tel" value={phone} onChange={(e) => setPhone(e.target.value)} placeholder="Phone number" className="w-full rounded-3xl border border-slate-800 bg-slate-900 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" />
              </div>
              <div className="grid gap-3">
                <label className="text-sm text-slate-400">Notes <span className="text-slate-500">(optional)</span></label>
                <textarea value={notes} onChange={(e) => setNotes(e.target.value)} placeholder="Order notes" rows={3} className="w-full rounded-3xl border border-slate-800 bg-slate-900 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" />
              </div>
              <div className="flex justify-end gap-3 pt-2">
                <button onClick={() => setShowDetails(false)} className="rounded-3xl border border-slate-700 px-4 py-3 text-sm font-semibold text-slate-200 hover:bg-slate-800">Cancel</button>
                <button onClick={() => { setShowDetails(false); setShowCart(true); }} disabled={activeType === 'Dine-In' && !tableNumber}
                  className="rounded-3xl bg-emerald-600 px-5 py-3 text-sm font-semibold text-white hover:bg-emerald-500 disabled:opacity-50 disabled:cursor-not-allowed">
                  Save & Continue →
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Cart screen */}
      {showCart && (
        <div className="fixed inset-0 z-50 bg-white flex flex-col">
          <div className="flex items-center justify-between px-4 py-3 border-b border-slate-200">
            <h3 className="text-base font-bold text-slate-900">🛒 Cart ({cartCount} items)</h3>
            <div className="flex items-center gap-2">
              <button onClick={() => { setShowCart(false); setShowDetails(true); }} className="rounded-full bg-slate-100 px-3 py-1.5 text-xs font-semibold text-slate-600 hover:bg-slate-200">Edit Details</button>
              <button onClick={() => setShowCart(false)} className="rounded-full p-1.5 text-slate-500 hover:bg-slate-100">✕</button>
            </div>
          </div>
          <div className="px-4 py-2 border-b border-slate-100 text-xs text-slate-500 space-y-0.5">
            <p>🍽️ Dine-In {tableNumber && <span className="font-semibold text-slate-700">• Table: {tableNumber}</span>}</p>
            {phone && <p>📞 {phone}</p>}
            {notes && <p className="truncate">📝 {notes}</p>}
          </div>
          <div className="flex-1 overflow-y-auto px-4 py-3 space-y-2">
            {cart.map(item => (
              <div key={item.itemId} className="flex items-center justify-between rounded-xl border border-slate-200 bg-white p-3 shadow-sm">
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-semibold text-slate-900 truncate">{item.name}</p>
                  <p className="text-xs text-slate-400">{item.price} PKR each</p>
                </div>
                <div className="flex items-center gap-2 shrink-0">
                  <button onClick={() => updateCartQty(item.itemId, -1)} className="h-8 w-8 rounded-full bg-slate-100 text-slate-700 text-sm font-bold hover:bg-slate-200 active:scale-95">−</button>
                  <span className="w-6 text-center text-sm font-bold text-slate-900">{item.quantity}</span>
                  <button onClick={() => updateCartQty(item.itemId, 1)} className="h-8 w-8 rounded-full bg-emerald-600 text-white text-sm font-bold hover:bg-emerald-500 active:scale-95">+</button>
                  <button onClick={() => removeFromCart(item.itemId)} className="ml-1 h-8 w-8 rounded-full bg-rose-50 text-rose-500 text-xs font-bold hover:bg-rose-100">✕</button>
                </div>
              </div>
            ))}
            {cart.length === 0 && (
              <div className="flex flex-col items-center justify-center py-16 text-slate-400">
                <div className="text-4xl mb-2">🛒</div>
                <p className="text-sm">Cart is empty</p>
                <button onClick={() => setShowCart(false)} className="mt-3 rounded-full bg-emerald-600 px-4 py-2 text-xs font-bold text-white">Back to Menu</button>
              </div>
            )}
          </div>
          <div className="px-4 py-3 border-t border-slate-200 space-y-2">
            <div className="flex items-center justify-between">
              <span className="text-sm text-slate-500">Total</span>
              <span className="text-lg font-bold text-emerald-600">{cartTotal} PKR</span>
            </div>
            <button onClick={createOrder} disabled={loading || !cart.length} className="w-full rounded-xl bg-emerald-600 py-3 text-sm font-bold text-white hover:bg-emerald-500 disabled:opacity-50 active:scale-[0.99]">
              {loading ? 'Creating...' : 'Place 🍽️ Dine-In Order'}
            </button>
          </div>
        </div>
      )}

      {/* Orders popup */}
      {showOrdersPopup && (
        <div className="fixed inset-0 z-[60] bg-black/70 px-2 py-4 flex items-start justify-center pt-12" onClick={() => setShowOrdersPopup(false)}>
          <div className="relative w-full max-w-md max-h-[80vh] flex flex-col rounded-2xl bg-slate-950 border border-slate-800 overflow-hidden" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between p-4 border-b border-slate-800">
              <h3 className="text-base font-bold text-white">📋 My Orders ({myOrders.length})</h3>
              <button onClick={() => setShowOrdersPopup(false)} className="rounded-full p-1 text-slate-300 hover:bg-slate-800">✕</button>
            </div>
            <div className="flex-1 overflow-y-auto p-3 space-y-2">
              {myOrders.length === 0 && <p className="text-sm text-slate-500 text-center py-8">No orders yet</p>}
              {myOrders.sort((a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0)).map(order => (
                <div key={order.id} className="rounded-xl border border-slate-800 bg-slate-900 p-3">
                  <div className="flex items-center justify-between mb-1">
                    <span className="text-xs font-bold text-indigo-400">#{order.orderNumber || order.id}</span>
                    <span className="text-[10px] text-slate-400">{new Date(order.createdAt).toLocaleTimeString()}</span>
                  </div>
                  <div className="flex items-center gap-2 text-[10px] text-slate-400 mb-1">
                    <span className={`font-semibold ${order.orderType === 'Dine-In' ? 'text-emerald-400' : 'text-amber-400'}`}>{order.orderType}</span>
                    <span>•</span>
                    <span>{order.customerName || order.tableNumber || '-'}</span>
                    <span>•</span>
                    <span className={`font-semibold ${order.status === 'Completed' || order.status === 'Payment Collected' ? 'text-emerald-400' : 'text-amber-400'}`}>{order.status}</span>
                  </div>
                  <div className="mt-1 space-y-1 border-t border-slate-800 pt-1.5">
                    {(order.items || []).map((item, idx) => (
                      <div key={idx} className="flex items-center justify-between gap-2 text-[11px]">
                        <span className="text-slate-200 min-w-0"><span className="text-amber-400 font-bold">{item.quantity}x</span> <span className="truncate">{item.name}</span></span>
                        <span className="text-slate-400 shrink-0">{Number(item.price) || 0} × {item.quantity} = <span className="text-emerald-400 font-bold">{Number(item.total) || ((Number(item.price) || 0) * item.quantity)}</span></span>
                      </div>
                    ))}
                    {order.subtotal ? <div className="flex items-center justify-between border-t border-slate-800 pt-1 text-[11px]"><span className="text-slate-400">Total</span><span className="font-bold text-emerald-400">{order.total || order.amount || 0} PKR</span></div> : null}
                  </div>
                  {order.orderType === 'Dine-In' && (
                    <div className="mt-2 rounded-lg border border-slate-800 bg-slate-950 p-2">
                      {order.paymentRequestImage ? (
                        <div className="flex items-center gap-2">
                          <img src={order.paymentRequestImage} alt="Payment request" onClick={() => setPreviewImage(order.paymentRequestImage)} className="h-12 w-12 rounded-lg object-cover cursor-pointer border border-amber-600/50" />
                          <div className="flex-1 min-w-0">
                            <p className="text-[10px] font-bold text-amber-400">📷 Payment Request Sent</p>
                            <p className="text-[9px] text-slate-500 truncate">{order.paymentRequestedAt ? new Date(order.paymentRequestedAt).toLocaleString() : ''}</p>
                          </div>
                          <button onClick={() => openRequestCamera(order.id)} className="shrink-0 rounded-full bg-slate-800 px-2.5 py-1 text-[10px] font-semibold text-slate-200 hover:bg-slate-700">Retake</button>
                        </div>
                      ) : (
                        <button onClick={() => openRequestCamera(order.id)} disabled={loading}
                          className="w-full rounded-lg bg-amber-600 px-3 py-2 text-[11px] font-bold text-white hover:bg-amber-500 active:scale-[0.98] transition-all disabled:opacity-50 flex items-center justify-center gap-1.5">
                          📷 Request Payment (Take Photo)
                        </button>
                      )}
                    </div>
                  )}
                  <div className="flex items-center justify-between">
                    <span className="text-sm font-bold text-emerald-400">{order.total || order.amount || 0} PKR</span>
                    <div className="flex gap-1.5">
                      <button onClick={() => openEditOrder(order)} className="rounded-full bg-slate-800 px-2.5 py-1 text-[10px] font-semibold text-slate-200 hover:bg-slate-700">✏️ Edit</button>
                      <button onClick={() => window.print()} className="rounded-full bg-slate-800 px-2.5 py-1 text-[10px] font-semibold text-slate-200 hover:bg-slate-700">🖨️ Print</button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* Edit order modal */}
      {editOrder && (
        <div className="fixed inset-0 z-[70] bg-black/70 px-2 py-4 flex items-center justify-center" onClick={() => { setEditOrder(null); setEditCart([]); }}>
          <div className="relative w-full max-w-md max-h-[90vh] flex flex-col rounded-2xl bg-slate-950 border border-slate-800 overflow-hidden" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between p-4 border-b border-slate-800">
              <h3 className="text-base font-bold text-white">✏️ Edit Order #{editOrder.orderNumber || editOrder.id}</h3>
              <button onClick={() => { setEditOrder(null); setEditCart([]); }} className="rounded-full p-1 text-slate-300 hover:bg-slate-800">✕</button>
            </div>
            <div className="flex-1 overflow-y-auto p-3 space-y-2">
              <input type="text" value={editOrder.notes || ''} onChange={(e) => setEditOrder({ ...editOrder, notes: e.target.value })} placeholder="Notes" className="w-full rounded-xl border border-slate-700 bg-slate-900 px-3 py-2 text-sm text-slate-100 outline-none" />
              {editCart.map((item, idx) => (
                <div key={idx} className="flex items-center justify-between rounded-xl border border-slate-800 bg-slate-900 p-3">
                  <span className="text-sm text-slate-200 truncate flex-1">{item.name}</span>
                  <div className="flex items-center gap-2 shrink-0">
                    <button onClick={() => { const c = [...editCart]; c[idx].quantity = Math.max(0, c[idx].quantity - 1); if (c[idx].quantity === 0) c.splice(idx, 1); setEditCart(c); }} className="h-7 w-7 rounded-full bg-slate-800 text-white text-sm font-bold">−</button>
                    <span className="w-6 text-center text-sm font-bold text-white">{item.quantity}</span>
                    <button onClick={() => { const c = [...editCart]; c[idx].quantity += 1; setEditCart(c); }} className="h-7 w-7 rounded-full bg-slate-800 text-white text-sm font-bold">+</button>
                  </div>
                </div>
              ))}
            </div>
            <div className="px-4 py-3 border-t border-slate-800">
              <div className="flex items-center justify-between mb-3">
                <span className="text-sm text-slate-400">Total</span>
                <span className="text-lg font-bold text-emerald-400">{editCart.reduce((s, i) => s + (Number(i.price) || 0) * i.quantity, 0)} PKR</span>
              </div>
              <button onClick={saveEditOrder} disabled={loading} className="w-full rounded-xl bg-emerald-600 py-3 text-sm font-bold text-white hover:bg-emerald-500 disabled:opacity-50">
                {loading ? 'Saving...' : 'Save Changes'}
              </button>
            </div>
          </div>
        </div>
      )}

      <input ref={fileInputRef} type="file" accept="image/*" capture="environment" className="hidden" onChange={handleRequestImage} />

      {previewImage && (
        <div className="fixed inset-0 z-[90] bg-black/90 flex items-center justify-center p-4" onClick={() => setPreviewImage(null)}>
          <img src={previewImage} alt="Payment request" className="max-w-full max-h-full rounded-xl shadow-2xl" />
          <button onClick={() => setPreviewImage(null)} className="absolute top-4 right-4 rounded-full bg-white/10 px-4 py-2 text-sm font-bold text-white hover:bg-white/20">✕ Close</button>
        </div>
      )}

      {message && (
        <div className="fixed bottom-32 left-1/2 -translate-x-1/2 z-[80] rounded-full bg-slate-900 border border-slate-700 px-4 py-2 text-xs text-slate-200 shadow-xl">
          {message}
          <button onClick={() => setMessage('')} className="ml-2 text-slate-400">✕</button>
        </div>
      )}
    </div>
  );
}
