import { useState, useEffect, useMemo } from 'react';

const API = typeof window !== 'undefined' ? `${window.location.protocol}//${window.location.hostname}:4000/api` : '/api';

function fetchJson(url, opts = {}) {
  const headers = { 'Content-Type': 'application/json', ...opts.headers };
  if (opts.token) headers['Authorization'] = `Bearer ${opts.token}`;
  return fetch(url, { ...opts, headers }).then(async (r) => {
    const data = await r.json();
    if (!r.ok) throw new Error(data.error || 'Request failed');
    return data;
  });
}

export function OrderTakerApp() {
  const [token, setToken] = useState('');
  const [orderTaker, setOrderTaker] = useState(null);
  const [loginForm, setLoginForm] = useState({ username: '', password: '' });
  const [message, setMessage] = useState('');
  const [loading, setLoading] = useState(false);

  // POS data
  const [products, setProducts] = useState([]);
  const [categories, setCategories] = useState([]);
  const [orders, setOrders] = useState([]);
  const [settings, setSettings] = useState({});

  // POS state
  const [activeType, setActiveType] = useState('Dine-In');
  const [search, setSearch] = useState('');
  const [category, setCategory] = useState('All');
  const [cart, setCart] = useState([]);
  const [showCart, setShowCart] = useState(false);
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
      const [cats, prods, ords, sets] = await Promise.all([
        fetchJson(`${apiBase}/pos/categories`),
        fetchJson(`${apiBase}/pos/products`),
        fetchJson(`${apiBase}/pos/orders`, { token }),
        fetchJson(`${apiBase}/settings`),
      ]);
      setCategories(Array.isArray(cats) ? cats : []);
      setProducts(Array.isArray(prods) ? prods : []);
      setOrders(Array.isArray(ords) ? ords : []);
      setSettings(sets || {});
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
      if (!data.user || data.user.role !== 'Order Taker') {
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

  const filteredProducts = useMemo(() => {
    const searchTerm = search.toLowerCase().trim();
    return products.filter(p => {
      if (category !== 'All' && p.category !== category) return false;
      if (searchTerm && !(p.name || '').toLowerCase().includes(searchTerm) && !(p.code || '').toLowerCase().includes(searchTerm)) return false;
      return true;
    });
  }, [products, category, search]);

  const allCategories = useMemo(() => {
    const cats = [...new Set(products.map(p => p.category).filter(Boolean))];
    return ['All', ...cats];
  }, [products]);

  // Tables data
  const tablesList = useMemo(() => {
    const occupiedTableNumbers = new Set(
      orders.filter(o => o.orderType === 'Dine-In' && !['Completed', 'Payment Collected', 'Delivered'].includes(o.status)).map(o => o.tableNumber).filter(Boolean)
    );
    return { occupied: occupiedTableNumbers };
  }, [orders]);

  // Orders by this order taker only
  const myOrders = useMemo(() => {
    const name = orderTaker?.name || '';
    const username = orderTaker?.username || '';
    return orders.filter(o => o.orderTaker === name || o.orderTaker === username || o.waiter === name || o.waiter === username);
  }, [orders, orderTaker]);

  async function createOrder() {
    if (!cart.length) { setMessage('Cart is empty'); return; }
    setLoading(true);
    try {
      const payload = {
        items: cart.map(i => ({ productId: i.id, name: i.name, price: i.price, quantity: i.quantity, code: i.code || '' })),
        orderType: activeType,
        customerName: customerName || (activeType === 'Takeaway' ? 'Takeaway' : ''),
        phone,
        tableNumber: activeType === 'Dine-In' ? tableNumber : '',
        notes,
        orderTaker: orderTaker?.name || orderTaker?.username || '',
        waiter: orderTaker?.name || orderTaker?.username || '',
        status: activeType === 'Takeaway' ? 'Pay Later' : 'Pending',
        paymentStatus: activeType === 'Takeaway' ? 'Due' : 'Pending',
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
            <input type="text" value={loginForm.username} onChange={(e) => setLoginForm({ ...loginForm, username: e.target.value })} placeholder="Username" className="w-full rounded-xl border border-slate-700 bg-slate-900 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" required />
            <input type="password" value={loginForm.password} onChange={(e) => setLoginForm({ ...loginForm, password: e.target.value })} placeholder="Password" className="w-full rounded-xl border border-slate-700 bg-slate-900 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" required />
            {message && <p className="text-xs text-rose-400 text-center">{message}</p>}
            <button type="submit" disabled={loading || !loginForm.username || !loginForm.password} className="w-full rounded-xl bg-emerald-600 py-3 text-sm font-bold text-white hover:bg-emerald-500 disabled:opacity-50">
              {loading ? 'Logging in...' : 'Login'}
            </button>
          </form>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 pb-24">
      {/* Header */}
      <div className="sticky top-0 z-40 bg-slate-950/95 backdrop-blur-xl border-b border-slate-800 px-3 py-2 flex items-center justify-between gap-2">
        <div className="flex items-center gap-2 min-w-0">
          <span className="text-lg">📋</span>
          <div className="min-w-0">
            <p className="text-xs font-bold text-emerald-400 truncate">{orderTaker?.name || orderTaker?.username}</p>
            <p className="text-[10px] text-slate-400">Order Taker</p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <button onClick={() => setShowOrdersPopup(true)} className="relative rounded-full bg-slate-900 px-3 py-1.5 text-xs font-semibold text-slate-200 hover:bg-slate-800">
            📋 Orders {myOrders.length > 0 && <span className="ml-1 text-emerald-400">({myOrders.length})</span>}
          </button>
          <button onClick={handleLogout} className="rounded-full bg-rose-600 px-3 py-1.5 text-xs font-semibold text-white">Logout</button>
        </div>
      </div>

      {/* Order type tabs */}
      <div className="grid grid-cols-2 gap-2 px-3 py-3">
        {['Dine-In', 'Takeaway'].map(type => (
          <button key={type} onClick={() => setActiveType(type)}
            className={`rounded-xl py-3 text-sm font-bold text-center transition-all active:scale-95 ${
              activeType === type
                ? type === 'Dine-In' ? 'bg-gradient-to-r from-emerald-500 to-emerald-600 text-white shadow-lg' : 'bg-gradient-to-r from-amber-500 to-orange-500 text-white shadow-lg'
                : 'bg-slate-900 text-slate-400'
            }`}>
            {type === 'Dine-In' ? '🍽️ Dine In' : '🛍️ Take Away'}
          </button>
        ))}
      </div>

      {/* Dine-In: Table input */}
      {activeType === 'Dine-In' && (
        <div className="px-3 pb-2">
          <input type="text" value={tableNumber} onChange={(e) => setTableNumber(e.target.value)} placeholder="Table / Room number" className="w-full rounded-xl border border-slate-700 bg-slate-900 px-4 py-2.5 text-sm text-slate-100 outline-none focus:border-emerald-500" />
        </div>
      )}

      {/* Search */}
      <div className="px-3 pb-2">
        <input type="text" value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Search products..." className="w-full rounded-xl border border-slate-700 bg-slate-900 px-4 py-2.5 text-sm text-slate-100 outline-none focus:border-emerald-500" />
      </div>

      {/* Categories */}
      <div className="px-3 pb-2 overflow-x-auto">
        <div className="flex gap-1.5 min-w-max">
          {allCategories.map(cat => (
            <button key={cat} onClick={() => setCategory(cat)}
              className={`rounded-full px-3 py-1.5 text-xs font-semibold whitespace-nowrap transition ${category === cat ? 'bg-emerald-600 text-white' : 'bg-slate-900 text-slate-300 hover:bg-slate-800'}`}>
              {cat}
            </button>
          ))}
        </div>
      </div>

      {/* Products grid */}
      <div className="grid grid-cols-3 gap-2 px-3">
        {filteredProducts.map(product => (
          <button key={product.id} onClick={() => addToCart(product)}
            className={`relative rounded-xl border p-2.5 text-center transition-all active:scale-95 ${
              orderedItems[product.id] ? 'border-emerald-500 bg-emerald-900/40 scale-105' : 'border-slate-800 bg-slate-900 hover:border-slate-600'
            }`}>
            {product.photo && <img src={product.photo} alt="" className="mx-auto h-10 w-10 rounded-lg object-cover mb-1" />}
            <p className="text-[10px] font-semibold text-slate-200 leading-tight line-clamp-2">{product.name}</p>
            <p className="mt-0.5 text-[10px] font-bold text-emerald-400">{product.price} PKR</p>
          </button>
        ))}
      </div>

      {/* Floating cart button */}
      {cart.length > 0 && !showCart && (
        <button onClick={() => setShowCart(true)}
          className="fixed bottom-4 right-4 z-50 flex items-center gap-2 rounded-full bg-emerald-600 px-4 py-3 text-sm font-bold text-white shadow-xl active:scale-95">
          <span>🛒</span>
          <span>{cartCount} items · {cartTotal} PKR</span>
        </button>
      )}

      {/* Cart overlay */}
      {showCart && (
        <div className="fixed inset-0 z-50 bg-slate-950/95 flex flex-col">
          <div className="flex items-center justify-between px-4 py-3 border-b border-slate-800">
            <h3 className="text-base font-bold text-white">🛒 Cart ({cartCount} items)</h3>
            <button onClick={() => setShowCart(false)} className="rounded-full p-1.5 text-slate-300 hover:bg-slate-800">✕</button>
          </div>
          {/* Customer info */}
          <div className="px-4 py-3 border-b border-slate-800 space-y-2">
            {activeType === 'Takeaway' && (
              <input type="text" value={customerName} onChange={(e) => setCustomerName(e.target.value)} placeholder="Customer name" className="w-full rounded-xl border border-slate-700 bg-slate-900 px-3 py-2 text-sm text-slate-100 outline-none" />
            )}
            <input type="tel" value={phone} onChange={(e) => setPhone(e.target.value)} placeholder="Phone (optional)" className="w-full rounded-xl border border-slate-700 bg-slate-900 px-3 py-2 text-sm text-slate-100 outline-none" />
            <textarea value={notes} onChange={(e) => setNotes(e.target.value)} placeholder="Order notes" rows={2} className="w-full rounded-xl border border-slate-700 bg-slate-900 px-3 py-2 text-sm text-slate-100 outline-none" />
          </div>
          <div className="flex-1 overflow-y-auto px-4 py-3 space-y-2">
            {cart.map(item => (
              <div key={item.itemId} className="flex items-center justify-between rounded-xl border border-slate-800 bg-slate-900 p-3">
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-semibold text-white truncate">{item.name}</p>
                  <p className="text-xs text-slate-400">{item.price} PKR each</p>
                </div>
                <div className="flex items-center gap-2 shrink-0">
                  <button onClick={() => updateCartQty(item.itemId, -1)} className="h-7 w-7 rounded-full bg-slate-800 text-white text-sm font-bold">−</button>
                  <span className="w-6 text-center text-sm font-bold text-white">{item.quantity}</span>
                  <button onClick={() => updateCartQty(item.itemId, 1)} className="h-7 w-7 rounded-full bg-slate-800 text-white text-sm font-bold">+</button>
                  <button onClick={() => removeFromCart(item.itemId)} className="ml-1 text-xs text-rose-400">✕</button>
                </div>
              </div>
            ))}
          </div>
          <div className="px-4 py-3 border-t border-slate-800">
            <div className="flex items-center justify-between mb-3">
              <span className="text-sm text-slate-400">Total</span>
              <span className="text-lg font-bold text-emerald-400">{cartTotal} PKR</span>
            </div>
            <button onClick={createOrder} disabled={loading || !cart.length} className="w-full rounded-xl bg-emerald-600 py-3 text-sm font-bold text-white hover:bg-emerald-500 disabled:opacity-50">
              {loading ? 'Creating...' : `Place ${activeType === 'Dine-In' ? '🍽️ Dine-In' : '🛍️ Takeaway'} Order`}
            </button>
          </div>
        </div>
      )}

      {/* Orders popup */}
      {showOrdersPopup && (
        <div className="fixed inset-0 z-50 bg-black/70 px-2 py-4 flex items-start justify-center pt-12" onClick={() => setShowOrdersPopup(false)}>
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
                  <div className="text-[10px] text-slate-400 mb-2 line-clamp-2">
                    {(order.items || []).map((item, idx) => (
                      <span key={idx}><span className="text-amber-400 font-semibold">{item.quantity}x</span> {item.name}{idx < (order.items||[]).length - 1 ? ', ' : ''}</span>
                    ))}
                  </div>
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
        <div className="fixed inset-0 z-[60] bg-black/70 px-2 py-4 flex items-center justify-center" onClick={() => { setEditOrder(null); setEditCart([]); }}>
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

      {message && (
        <div className="fixed bottom-20 left-1/2 -translate-x-1/2 z-[70] rounded-full bg-slate-900 border border-slate-700 px-4 py-2 text-xs text-slate-200 shadow-xl">
          {message}
          <button onClick={() => setMessage('')} className="ml-2 text-slate-400">✕</button>
        </div>
      )}
    </div>
  );
}
