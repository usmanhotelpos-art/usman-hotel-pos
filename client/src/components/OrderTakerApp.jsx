import { useState, useEffect, useMemo, useRef } from 'react';
import { buildEscposReceipt, renderReceiptToCanvas, canvasToEscposRaster, CMD } from '../utils/escpos.js';
import { requestBluetoothPrinter, printToBluetooth, getSavedPrinterInfo, clearPrinterInfo, autoConnectSavedPrinter, disconnectDevice } from '../utils/btPrint.js';

const API = '/api';

async function refreshOrderTakerToken() {
  const stored = typeof window !== 'undefined' ? localStorage.getItem('orderTakerToken') : null;
  if (!stored) return null;
  try {
    const res = await fetch(`${API}/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${stored}` }
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok || !data.token) return null;
    localStorage.setItem('orderTakerToken', data.token);
    window.dispatchEvent(new CustomEvent('orderTakerTokenRefreshed', { detail: data.token }));
    return data.token;
  } catch { return null; }
}

function getTokenExpiry(tok) {
  try {
    const payload = JSON.parse(atob(tok.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')));
    return payload.exp ? payload.exp * 1000 : 0;
  } catch { return 0; }
}

async function fetchJson(url, opts = {}) {
  const headers = { 'Content-Type': 'application/json', ...opts.headers };
  const tk = opts.token;
  if (tk) headers['Authorization'] = `Bearer ${tk}`;
  const res = await fetch(url, { ...opts, headers });
  if (res.status === 401 && tk && !opts.retried && !url.includes('/auth/refresh')) {
    const newToken = await refreshOrderTakerToken();
    if (newToken) {
      return fetchJson(url, { ...opts, token: newToken, retried: true });
    }
  }
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error || 'Request failed');
  return data;
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

  // Variant / flavor selection popup
  const [variantProduct, setVariantProduct] = useState(null);
  const [variantFlavor, setVariantFlavor] = useState(null);
  const [variantStep, setVariantStep] = useState('flavors');

  // Order creation
  const [customerName, setCustomerName] = useState('');
  const [phone, setPhone] = useState('');
  const [tableNumber, setTableNumber] = useState('');
  const [notes, setNotes] = useState('');
  const [showPaymentPopup, setShowPaymentPopup] = useState(false);
  const [paymentMethod, setPaymentMethod] = useState('Cash');

  // Edit
  const [editOrder, setEditOrder] = useState(null);
  const [editCart, setEditCart] = useState([]);

  // Payment request photo
  const [requestOrderId, setRequestOrderId] = useState(null);
  const [previewImage, setPreviewImage] = useState(null);
  const fileInputRef = useRef(null);

  // Orders list UX
  const [expandedOrderId, setExpandedOrderId] = useState(null);
  const [ordersTab, setOrdersTab] = useState('new');
  const [popupRefreshing, setPopupRefreshing] = useState(false);
  const [now, setNow] = useState(() => Date.now());
  const [paymentMethodOrder, setPaymentMethodOrder] = useState(null);
  const [editAddSearch, setEditAddSearch] = useState('');

  // Bluetooth printer
  const [btDevice, setBtDevice] = useState(null);
  const [btConnected, setBtConnected] = useState(false);
  const [btInfo, setBtInfo] = useState(null);
  const [btConnecting, setBtConnecting] = useState(false);

  const apiBase = API;

  useEffect(() => {
    const saved = localStorage.getItem('orderTakerToken');
    const savedUser = localStorage.getItem('orderTakerUser');
    if (saved && savedUser) {
      setToken(saved);
      try { setOrderTaker(JSON.parse(savedUser)); } catch {}
      // Proactively renew token before it expires (6h window)
      const exp = getTokenExpiry(saved);
      if (exp && exp < Date.now() + 30 * 60 * 1000) {
        refreshOrderTakerToken();
      }
    }
  }, []);

  useEffect(() => {
    const onRefresh = (e) => { if (e.detail) setToken(e.detail); };
    window.addEventListener('orderTakerTokenRefreshed', onRefresh);
    return () => window.removeEventListener('orderTakerTokenRefreshed', onRefresh);
  }, []);

  useEffect(() => {
    if (!token || !orderTaker) return;
    loadData();
    const id = setInterval(() => loadData(true), 20000);
    return () => clearInterval(id);
  }, [token, orderTaker]);

  useEffect(() => {
    const id = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(id);
  }, []);

  async function loadData(silent = false) {
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
      if (sets) {
        const recFmt = sets.receiptDateTimeFormat || 'DD/MM/YYYY hh:mm A';
        setSettings({
          ...sets,
          receiptDateTimeFormat: recFmt.includes('HH') ? `${recFmt.replace('HH', 'hh')} A` : (recFmt.includes('hh') && !recFmt.includes('A') ? `${recFmt} A` : recFmt)
        });
      }
      if (Array.isArray(slots)) setMashallahSlots(slots);
      if (!silent && tbls === null) setMessage('Could not load tables from server - check connection or re-login');
    } catch (e) { if (!silent) setMessage(e.message); }
  }

  async function refreshOrdersOnly(showSpin = false) {
    if (showSpin) setPopupRefreshing(true);
    try {
      const ords = await fetchJson(`${apiBase}/pos/orders`, { token });
      if (Array.isArray(ords)) setOrders(ords);
    } catch (e) {
      if (!showSpin) setMessage(e.message);
    } finally {
      if (showSpin) setTimeout(() => setPopupRefreshing(false), 500);
    }
  }

  // Auto-refresh popup orders every 2s while open
  useEffect(() => {
    if (!showOrdersPopup || !token) return;
    refreshOrdersOnly();
    const id = setInterval(() => refreshOrdersOnly(), 2000);
    return () => clearInterval(id);
  }, [showOrdersPopup, token]);

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

  async function handleBtConnect() {
    if (btConnected && btDevice) {
      await disconnectDevice(btDevice);
      setBtDevice(null);
      setBtConnected(false);
      setBtInfo(null);
      clearPrinterInfo();
      return;
    }
    setBtConnecting(true);
    try {
      let device, info;
      const savedPrinter = getSavedPrinterInfo();
      if (savedPrinter?.id) {
        try {
          const result = await autoConnectSavedPrinter();
          device = result.device;
          info = result.info;
        } catch (err) {
          console.warn('Auto-reconnect failed, showing manual pairing:', err.message);
          const result = await requestBluetoothPrinter();
          device = result.device;
          info = result.info;
        }
      } else {
        const result = await requestBluetoothPrinter();
        device = result.device;
        info = result.info;
      }
      setBtDevice(device);
      setBtInfo(info);
      setBtConnected(true);
      setMessage(`Bluetooth printer connected: ${info.name}`);
    } catch (err) {
      console.warn('Bluetooth connection failed:', err.message);
      setMessage(err.message);
    } finally {
      setBtConnecting(false);
    }
  }

  async function printOrderBT(order) {
    let device = btDevice;

    if (!btConnected || !device) {
      try {
        const result = await autoConnectSavedPrinter();
        device = result.device;
        setBtDevice(device);
        setBtConnected(true);
      } catch (err) {
        console.warn('Auto-reconnect failed, requesting printer pairing:', err.message);
        try {
          const result = await requestBluetoothPrinter();
          device = result.device;
          setBtDevice(device);
          setBtConnected(true);
          setBtInfo(result.info);
        } catch (pairErr) {
          console.warn('Printer pairing cancelled or failed:', pairErr.message);
          return null;
        }
      }
    }

    if (!device) return null;

    const doPrint = async (data) => {
      await printToBluetooth(device, data);
    };

    const doBitmapPrint = async () => {
      const canvas = renderReceiptToCanvas(order, settings);
      const rasterData = canvasToEscposRaster(canvas);
      const cutCmd = new Uint8Array(CMD.CUT);
      const feedCmd = new Uint8Array(CMD.FEED_LINES(8));
      const finalData = new Uint8Array(rasterData.length + feedCmd.length + cutCmd.length);
      let offset = 0;
      finalData.set(rasterData, offset); offset += rasterData.length;
      finalData.set(feedCmd, offset); offset += feedCmd.length;
      finalData.set(cutCmd, offset);
      await printToBluetooth(device, finalData);
    };

    const attemptPrint = async () => {
      if (settings.btEncoding === 'bmp') {
        await doBitmapPrint();
      } else {
        try {
          const escposData = buildEscposReceipt(order, settings);
          await doPrint(escposData);
        } catch (textErr) {
          console.warn('Text BT print failed, trying bitmap:', textErr.message);
          await doBitmapPrint();
        }
      }

      const shouldPrintTokenSlip = settings.tokenSlipEnabled && (
        (order.orderType === 'Dine-In' && settings.btTokenSlipDineIn !== false) ||
        (order.orderType === 'Takeaway' && settings.btTokenSlipTakeaway !== false) ||
        (order.orderType === 'Delivery' && settings.btTokenSlipDelivery !== false) ||
        (!order.orderType && settings.btTokenSlipDineIn !== false)
      );
      if (shouldPrintTokenSlip) {
        const tokenOrder = { ...order, items: [] };
        await new Promise((r) => setTimeout(r, 500));
        if (settings.btEncoding === 'bmp') {
          const tokenCanvas = renderReceiptToCanvas(tokenOrder, { ...settings, _tokenOnly: true });
          const tokenRaster = canvasToEscposRaster(tokenCanvas);
          const tokenFeed = new Uint8Array(CMD.FEED_LINES(8));
          const tokenCut = new Uint8Array(CMD.CUT);
          const tokenFinal = new Uint8Array(tokenRaster.length + tokenFeed.length + tokenCut.length);
          let to = 0;
          tokenFinal.set(tokenRaster, to); to += tokenRaster.length;
          tokenFinal.set(tokenFeed, to); to += tokenFeed.length;
          tokenFinal.set(tokenCut, to);
          await printToBluetooth(device, tokenFinal);
        } else {
          const tokenData = buildEscposReceipt(tokenOrder, { ...settings, _tokenOnly: true });
          await printToBluetooth(device, tokenData);
        }
      }
    };

    try {
      await attemptPrint();
      return true;
    } catch (err) {
      console.warn('BT print attempt failed, reconnecting and retrying:', err.message);
      try { await disconnectDevice(device); } catch {}
      try {
        const result = await autoConnectSavedPrinter();
        device = result.device;
        setBtDevice(device);
        setBtConnected(true);
      } catch {
        try {
          const result = await requestBluetoothPrinter();
          device = result.device;
          setBtDevice(device);
          setBtConnected(true);
          setBtInfo(result.info);
        } catch {
          throw err;
        }
      }
      await attemptPrint();
      return true;
    }
  }

  function addToCart(product) {
    // Show flavor/variant popup if product has variants
    if (product.flavors && product.flavors.length > 0) {
      setVariantProduct(product);
      setVariantFlavor(null);
      setVariantStep('flavors');
      return;
    }
    addPlainToCart(product);
  }

  function addPlainToCart(product) {
    setCart(prev => {
      const existing = prev.find(i => i.id === product.id && !i.flavor && !i.weight);
      if (existing) return prev.map(i => i.id === product.id && !i.flavor && !i.weight ? { ...i, quantity: i.quantity + 1 } : i);
      return [...prev, { ...product, quantity: 1, price: Number(product.price) || 0, weight: '', flavor: '', itemId: `${product.id}-base-${Date.now()}` }];
    });
    setOrderedItems(prev => ({ ...prev, [product.id]: true }));
    setTimeout(() => setOrderedItems(prev => ({ ...prev, [product.id]: false })), 600);
  }

  function selectVariantFlavor(flavor) {
    if (flavor.variants && flavor.variants.length > 0) {
      setVariantFlavor(flavor);
      setVariantStep('variants');
      return;
    }
    // No variants - add with flavor only
    addVariantToCart(variantProduct, flavor, null);
  }

  function selectVariantSize(variant) {
    addVariantToCart(variantProduct, variantFlavor, variant);
  }

  function addVariantToCart(product, flavor, variant) {
    if (!product) return;
    const price = Number(variant?.price ?? product.price) || 0;
    setCart(prev => {
      const existing = prev.find(i => i.id === product.id && (i.flavor || '') === (flavor?.label || '') && (i.weight || '') === (variant?.label || ''));
      if (existing) return prev.map(i => i.id === product.id && (i.flavor || '') === (flavor?.label || '') && (i.weight || '') === (variant?.label || '') ? { ...i, quantity: i.quantity + 1 } : i);
      return [...prev, {
        ...product,
        quantity: 1,
        price,
        weight: variant?.label || '',
        flavor: flavor?.label || '',
        itemId: `${product.id}-${variant?.label || 'base'}-${flavor?.label || 'noflavor'}-${Date.now()}`
      }];
    });
    setOrderedItems(prev => ({ ...prev, [product.id]: true }));
    setTimeout(() => setOrderedItems(prev => ({ ...prev, [product.id]: false })), 600);
    setVariantProduct(null);
    setVariantFlavor(null);
    setVariantStep('flavors');
  }

  function updateCartQty(itemId, delta) {
    setCart(prev => prev.map(i => i.itemId === itemId ? { ...i, quantity: Math.max(0, i.quantity + delta) } : i).filter(i => i.quantity > 0));
  }

  function removeFromCart(itemId) {
    setCart(prev => prev.filter(i => i.itemId !== itemId));
  }

  const pressTimerRef = useRef(null);
  const pressFiredRef = useRef(false);

  function removeProductFromCart(product) {
    const line = cart.find(i => i.id === product.id);
    if (line) removeFromCart(line.itemId);
  }

  function handleProductPressStart(product) {
    pressFiredRef.current = false;
    pressTimerRef.current = setTimeout(() => {
      pressFiredRef.current = true;
      pressTimerRef.current = null;
      removeProductFromCart(product);
    }, 2000);
  }

  function handleProductPressEnd() {
    if (pressTimerRef.current) {
      clearTimeout(pressTimerRef.current);
      pressTimerRef.current = null;
    }
  }

  function handleProductClick(product) {
    if (pressFiredRef.current) {
      pressFiredRef.current = false;
      return;
    }
    addToCart(product);
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

  // Tables data - occupancy decided by active dine-in orders only (stale table.status ignored)
  const tablesList = useMemo(() => {
    const norm = (value) => String(value || '').trim().toLowerCase().replace(/\s+/g, ' ');
    const occupiedTableNumbers = new Set(
      orders
        .filter(o => o.orderType === 'Dine-In' && !['completed', 'payment collected', 'cancelled'].includes(norm(o.status)))
        .map(o => norm(o.tableNumber))
        .filter(Boolean)
    );
    return { occupied: occupiedTableNumbers, norm };
  }, [orders]);

  const availableDineInTables = useMemo(() => {
    return (tables || []).map(table => ({
      ...table,
      isOccupied: tablesList.occupied.has(tablesList.norm(getTableLabel(table))) || ['reserved'].includes((table.status || '').toLowerCase()),
    }));
  }, [tables, tablesList]);

  // Free tables only, grouped by section: Floor first, then Outside
  const freeTablesBySection = useMemo(() => {
    const free = availableDineInTables.filter((table) => !table.isOccupied);
    return {
      floor: free.filter((table) => (table.section || 'Floor') === 'Floor'),
      outside: free.filter((table) => (table.section || 'Floor') === 'Outside'),
    };
  }, [availableDineInTables]);

  // Only this order taker's dine-in orders split into New / Served / Cancelled tabs
  const isMyOrder = (order) => {
    const mine = [orderTaker?.name, orderTaker?.username, orderTaker?.email]
      .map((v) => String(v || '').trim().toLowerCase())
      .filter(Boolean);
    const theirs = [order.orderTaker, order.waiter].map((v) => String(v || '').trim().toLowerCase());
    return theirs.some((t) => t && mine.includes(t));
  };

  const isServedOrder = (order) => {
    const s = (order.status || '').toLowerCase();
    return s === 'served' || Boolean(order.servedAt);
  };

  const isCancelledOrder = (order) => {
    const s = (order.status || '').toLowerCase();
    return s === 'cancelled' || Boolean(order.cancelledAt);
  };

  const isPaidOrDone = (order) => {
    const s = (order.status || '').toLowerCase();
    const p = (order.paymentStatus || '').toLowerCase();
    return s === 'completed' || s === 'payment collected' || p === 'paid';
  };

  const myNewOrders = useMemo(() => (orders || []).filter(o =>
    (o.orderType === 'Dine-In' || o.orderType === 'Takeaway') && isMyOrder(o) && !isServedOrder(o) && !isCancelledOrder(o) && !isPaidOrDone(o)
  ), [orders, orderTaker]);

  const myServedOrders = useMemo(() => (orders || []).filter(o =>
    (o.orderType === 'Dine-In' || o.orderType === 'Takeaway') && isMyOrder(o) && isServedOrder(o)
  ), [orders, orderTaker]);

  const myCancelledOrders = useMemo(() => (orders || []).filter(o =>
    (o.orderType === 'Dine-In' || o.orderType === 'Takeaway') && isMyOrder(o) && isCancelledOrder(o)
  ), [orders, orderTaker]);

  const allTypeOrders = useMemo(() => ((orders || [])
    .filter(o => o.orderType === 'Dine-In' || o.orderType === 'Takeaway'))
    .slice()
    .sort((a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0))
  , [orders]);

  const popupOrders = ordersTab === 'new' ? myNewOrders : ordersTab === 'served' ? myServedOrders : ordersTab === 'cancelled' ? myCancelledOrders : allTypeOrders;

  async function createOrder(orderStatus = 'Pending', paymentOpts = {}) {
    if (!cart.length) { setMessage('Cart is empty'); return; }
    if (activeType === 'Dine-In' && !tableNumber) { setMessage('Please select a table or room'); return; }
    const isTakeaway = activeType === 'Take Away';
    setLoading(true);
    try {
      const payload = {
        items: cart.map(i => ({ productId: i.id, name: i.name, price: i.price, quantity: i.quantity, code: i.code || '', weight: i.weight || '', flavor: i.flavor || '' })),
        orderType: isTakeaway ? 'Takeaway' : 'Dine-In',
        customerName: isTakeaway ? (customerName || 'Pickup') : (customerName || ''),
        phone,
        tableNumber: isTakeaway ? '' : tableNumber,
        notes,
        orderTaker: orderTaker?.name || orderTaker?.username || '',
        waiter: orderTaker?.name || orderTaker?.username || '',
        status: orderStatus,
        paymentStatus: paymentOpts.paid ? 'Paid' : 'Pending',
        serviceType: '',
        deliveryFee: 0,
        discount: 0,
        taxPercent: 0,
        serviceCharge: 0,
        paymentMethod: isTakeaway ? (paymentOpts.paymentMethod || 'Cash') : '',
      };
      const createdOrder = await fetchJson(`${apiBase}/pos/orders`, { method: 'POST', body: JSON.stringify(payload), token });
      if (paymentOpts.paid) {
        await fetchJson(`${apiBase}/pos/payments`, {
          method: 'POST',
          body: JSON.stringify({
            orderId: createdOrder.id,
            amount: createdOrder.total,
            paymentMethod: paymentOpts.paymentMethod || 'Cash',
            status: 'Completed',
            description: `Payment for order ${createdOrder.orderNumber || createdOrder.id}`
          }),
          token
        });
      }
      setCart([]);
      setCustomerName('');
      setPhone('');
      setTableNumber('');
      setNotes('');
      setShowCart(false);
      setShowDetails(false);
      setShowPaymentPopup(false);
      setMessage(paymentOpts.paid ? 'Order created & payment completed ✅' : isTakeaway ? 'Takeaway order created 🛍️' : 'Order created successfully ✅');
      if (btConnected || btInfo || settings.btPrintEnabled) {
        const printOrder = { ...createdOrder, date: createdOrder.createdAt || new Date().toISOString() };
        printOrderBT(printOrder)
          .then((ok) => {
            if (ok) setMessage('Order created & printed via Bluetooth');
          })
          .catch((err) => setMessage(`Order created but Bluetooth print failed: ${err.message}`));
      }
      await loadData();
    } catch (e) { setMessage(e.message); } finally { setLoading(false); }
  }

  async function saveEditOrder() {
    if (!editOrder) return;
    if (!editCart.length) {
      setMessage('Order must have at least one item.');
      return;
    }
    if (!editOrder.tableNumber) {
      setMessage('Please select a table or room for Dine-In orders.');
      return;
    }
    setLoading(true);
    try {
      const subtotal = editCart.reduce((sum, item) => sum + (Number(item.price) || 0) * (Number(item.quantity) || 1), 0);
      const discountValue = Number(editOrder.discount) || 0;
      const taxValue = ((subtotal - discountValue) * (Number(editOrder.taxPercent) || 0)) / 100;
      const serviceValue = Number(editOrder.serviceCharge) || 0;
      const total = Math.max(0, subtotal - discountValue + taxValue + serviceValue);
      const payload = {
        items: editCart,
        orderType: 'Dine-In',
        customerName: editOrder.customerName || '',
        phone: editOrder.phone || '',
        tableNumber: editOrder.tableNumber || '',
        deliveryAgent: '',
        serviceType: '',
        deliveryFee: 0,
        discount: discountValue,
        taxPercent: Number(editOrder.taxPercent) || 0,
        serviceCharge: serviceValue,
        paymentMethod: editOrder.paymentMethod || 'Cash',
        paymentStatus: editOrder.paymentStatus || '',
        notes: editOrder.notes || '',
        status: editOrder.status || 'Pending',
        subtotal,
        total,
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
    setEditAddSearch('');
    setEditCart((order.items || []).map((item) => ({
      ...item,
      itemId: item.itemId || `${item.productId || item.id}-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`
    })));
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

  async function pushOwnerRequest(order, paymentMethod = 'Cash') {
    if (!order.paymentRequestImage) {
      setMessage('Attach a payment photo first');
      return;
    }
    setLoading(true);
    try {
      await fetchJson(`${apiBase}/pos/orders/${order.id}`, {
        method: 'PUT',
        body: JSON.stringify({
          paymentRequestStatus: 'owner-request',
          paymentRequestedAt: order.paymentRequestedAt || new Date().toISOString(),
          paymentMethod: paymentMethod || order.paymentMethod || 'Cash',
          orderTaker: orderTaker?.name || orderTaker?.username || '',
        }),
        token
      });
      setPaymentMethodOrder(null);
      setMessage(`Payment request (${paymentMethod}) pushed to Farhan Owner for #${order.orderNumber || order.id}`);
      await loadData();
    } catch (e) { setMessage(e.message); } finally { setLoading(false); }
  }

  async function markServed(order) {
    setLoading(true);
    try {
      await fetchJson(`${apiBase}/pos/orders/${order.id}`, {
        method: 'PUT',
        body: JSON.stringify({
          status: 'Served',
          servedAt: new Date().toISOString(),
          orderTaker: orderTaker?.name || orderTaker?.username || '',
        }),
        token
      });
      setExpandedOrderId(null);
      setMessage(`Order #${order.orderNumber || order.id} marked served ✅`);
      await loadData();
    } catch (e) { setMessage(e.message); } finally { setLoading(false); }
  }

  async function cancelOrder(order) {
    setLoading(true);
    try {
      await fetchJson(`${apiBase}/pos/orders/${order.id}`, {
        method: 'PUT',
        body: JSON.stringify({
          status: 'Cancelled',
          cancelledAt: new Date().toISOString(),
          paymentRequestStatus: '',
          orderTaker: orderTaker?.name || orderTaker?.username || '',
        }),
        token
      });
      setExpandedOrderId(null);
      setMessage(`Order #${order.orderNumber || order.id} cancelled ❌`);
      await loadData();
    } catch (e) { setMessage(e.message); } finally { setLoading(false); }
  }

  const orderTotals = (order) => {
    const items = order.items || [];
    const subtotal = Number(order.subtotal) ||
      items.reduce((s, i) => s + (Number(i.total) || (Number(i.price) || 0) * (Number(i.quantity) || 1)), 0);
    const total = Number(order.total) || Number(order.amount) || subtotal;
    return { subtotal, total };
  };

  const formatDuration = (ms) => {
    if (!ms || ms < 0) ms = 0;
    const totalSec = Math.floor(ms / 1000);
    const h = Math.floor(totalSec / 3600);
    const m = Math.floor((totalSec % 3600) / 60);
    const s = totalSec % 60;
    const pad = (n) => String(n).padStart(2, '0');
    return h > 0 ? `${h}:${pad(m)}:${pad(s)}` : `${pad(m)}:${pad(s)}`;
  };

  const printOrder = (order) => {
    if (btConnected || btInfo || settings.btPrintEnabled) {
      printOrderBT({ ...order, date: order.createdAt || new Date().toISOString() })
        .catch((err) => setMessage(`Bluetooth print failed: ${err.message}`));
    } else {
      window.print();
    }
  };

  const filteredEditAddProducts = useMemo(() => {
    const term = editAddSearch.toLowerCase().trim();
    return (products || []).filter(p => !term || (p.name || '').toLowerCase().includes(term)).slice(0, 50);
  }, [products, editAddSearch]);

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
        <div className="flex items-center gap-1.5 shrink-0">
          <button onClick={handleBtConnect} disabled={btConnecting} title={btConnected ? `Printer: ${btInfo?.name || ''}` : 'Attach Bluetooth Printer'}
            className={`shrink-0 rounded-full px-2.5 py-1.5 text-xs font-semibold ${btConnected ? 'bg-emerald-600 text-white' : 'bg-sky-100 text-sky-700 hover:bg-sky-200'}`}>
            {btConnecting ? '⏳' : btConnected ? `🖨️ ${(btInfo?.name || 'Printer').slice(0, 10)}` : '🖨️'}
          </button>
          <button onClick={() => setShowOrdersPopup(true)} className="relative shrink-0 rounded-full bg-emerald-100 px-3 py-1.5 text-xs font-bold text-emerald-800 hover:bg-emerald-200 active:scale-95 transition">
            📋 Orders
            {myNewOrders.length > 0 && (
              <span className="absolute -top-1.5 -right-1.5 flex h-5 min-w-5 items-center justify-center rounded-full bg-emerald-600 px-1 text-[10px] font-black text-white ring-2 ring-white shadow">
                {myNewOrders.length}
              </span>
            )}
          </button>
          <button onClick={handleLogout} className="shrink-0 rounded-full bg-rose-600 px-3 py-1.5 text-xs font-semibold text-white">Logout</button>
        </div>
      </div>

      {/* Order type tabs */}
      <div className="px-3 pt-2 pb-1 flex gap-1.5">
        <button onClick={() => setActiveType('Dine-In')} className={`flex-1 rounded-xl px-3 py-2.5 text-xs font-bold transition-all active:scale-95 ${activeType === 'Dine-In' ? 'bg-emerald-600 text-white shadow' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'}`}>
          🍽️ Table
        </button>
        <button onClick={() => setActiveType('Take Away')} className={`flex-1 rounded-xl px-3 py-2.5 text-xs font-bold transition-all active:scale-95 ${activeType === 'Take Away' ? 'bg-amber-500 text-white shadow' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'}`}>
          🛍️ Take Away
        </button>
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
              {filteredProducts.map(product => {
                const cartQty = cart.filter(i => i.id === product.id).reduce((s, i) => s + i.quantity, 0);
                return (
                <button key={product.id} type="button"
                  onTouchStart={() => handleProductPressStart(product)}
                  onTouchEnd={handleProductPressEnd}
                  onTouchCancel={handleProductPressEnd}
                  onMouseDown={() => handleProductPressStart(product)}
                  onMouseUp={handleProductPressEnd}
                  onMouseLeave={handleProductPressEnd}
                  onClick={() => handleProductClick(product)}
                  className={`relative rounded-xl border p-1.5 shadow-soft transition active:scale-[0.97] ${
                    orderedItems[product.id]
                      ? 'border-emerald-500 bg-emerald-50 scale-105'
                      : cartQty > 0
                        ? 'border-emerald-500 bg-emerald-50 ring-2 ring-emerald-400/60'
                        : 'border-slate-200 bg-white hover:border-emerald-300'
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
                  {cartQty > 0 && (
                    <span className="absolute -left-1.5 -top-1.5 z-10 flex h-5 min-w-[20px] items-center justify-center rounded-full bg-emerald-600 px-1 text-[10px] font-black text-white shadow-md">{cartQty}</span>
                  )}
                </button>
                );
              })}
            </div>
          )}
        </div>
      </div>

      {/* Floating cart button */}
      {cart.length > 0 && !showCart && !showDetails && (
        <button onClick={() => setShowCart(true)}
          className="fixed right-4 z-[60] flex items-center gap-2 rounded-2xl bg-emerald-600 px-4 py-3 text-sm font-bold text-white shadow-[0_8px_32px_rgba(16,185,129,0.5)] active:scale-95 transition-all duration-200 hover:shadow-[0_8px_32px_rgba(16,185,129,0.7)]"
          style={{ bottom: 80 }}>
          <span className="flex h-7 w-7 items-center justify-center rounded-full bg-white/20 text-xs">🛒</span>
          <span>{cartCount} items · {cartTotal} PKR</span>
        </button>
      )}

      {/* Variant / flavor selection popup */}
      {variantProduct && (
        <div className="fixed inset-0 z-[75] flex items-end sm:items-center justify-center bg-black/70" onClick={() => { setVariantProduct(null); setVariantFlavor(null); setVariantStep('flavors'); }}>
          <div className="w-full sm:max-w-md max-h-[85vh] rounded-t-3xl sm:rounded-3xl border border-slate-700 bg-slate-950 p-5 shadow-[0_35px_120px_-30px_rgba(0,0,0,0.8)] overflow-y-auto" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between gap-4 mb-4">
              <div>
                <p className="text-xs uppercase tracking-[0.2em] text-slate-500">{variantStep === 'flavors' ? 'Choose flavor' : 'Select size / weight'}</p>
                <h3 className="mt-2 text-xl font-semibold text-white">{variantProduct.name}</h3>
                {variantFlavor && <p className="text-sm text-slate-400">Flavor: {variantFlavor.label}</p>}
              </div>
              <button onClick={() => { setVariantProduct(null); setVariantFlavor(null); setVariantStep('flavors'); }} className="rounded-full border border-slate-700 bg-slate-900 px-3 py-2 text-sm text-slate-200 hover:bg-slate-800">✕</button>
            </div>
            <div className="space-y-3">
              {variantStep === 'flavors'
                ? (variantProduct.flavors || []).map((flavor, index) => (
                    <button key={index} type="button" onClick={() => selectVariantFlavor(flavor)} className="w-full rounded-3xl border border-slate-700 bg-slate-900 px-4 py-3 text-left text-sm text-slate-100 transition hover:border-emerald-500 hover:bg-slate-800">
                      <span>{flavor.label}</span>
                      {flavor.variants?.length > 0 && <span className="float-right text-xs text-slate-500">{flavor.variants.length} options</span>}
                    </button>
                  ))
                : (variantFlavor?.variants || []).map((variant, index) => (
                    <button key={index} type="button" onClick={() => selectVariantSize(variant)} className="w-full rounded-3xl border border-slate-700 bg-slate-900 px-4 py-3 text-left text-sm text-slate-100 transition hover:border-emerald-500 hover:bg-slate-800">
                      <div className="flex items-center justify-between">
                        <span>{variant.label}</span>
                        <span className="font-semibold">{variant.price} PKR</span>
                      </div>
                    </button>
                  ))}
            </div>
          </div>
        </div>
      )}

      {/* Cart / Place Order screen */}
      {showCart && (
        <div className="fixed inset-0 z-50 bg-white flex flex-col">
          <div className="flex items-center justify-between px-4 py-3 border-b border-slate-200">
            <h3 className="text-base font-bold text-slate-900">🛒 Place Order ({cartCount} items)</h3>
            <button onClick={() => setShowCart(false)} className="rounded-full p-1.5 text-slate-500 hover:bg-slate-100">✕</button>
          </div>
          <div className="flex-1 overflow-y-auto">
            {/* Cart items */}
            <div className="px-4 py-3 space-y-2">
              <p className="text-[11px] font-bold uppercase tracking-wider text-slate-500">Items</p>
              {cart.map(item => (
                <div key={item.itemId} className="flex items-center justify-between rounded-xl border border-slate-200 bg-white p-3 shadow-sm">
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-semibold text-slate-900 truncate">{item.name}</p>
                    {(item.flavor || item.weight) && (
                      <p className="text-[10px] text-slate-500 truncate">{item.flavor}{item.flavor && item.weight ? ' • ' : ''}{item.weight}</p>
                    )}
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

            {/* Order details */}
            <div className="px-4 py-3 space-y-2.5 bg-slate-50 border-t border-slate-200">
              <p className="text-[11px] font-bold uppercase tracking-wider text-slate-500">{activeType === 'Take Away' ? '🛍️ Take Away Details' : 'Order Details'}</p>
              {activeType === 'Dine-In' && (
                <div className="grid gap-1.5">
                  <label className="text-xs font-semibold text-slate-600">Table / Room <span className="text-rose-500">*</span></label>
                  {freeTablesBySection.floor.length === 0 && freeTablesBySection.outside.length === 0 ? (
                    <p className="rounded-xl border border-amber-200 bg-amber-50 px-3 py-2 text-xs font-semibold text-amber-700">No free tables available right now</p>
                  ) : (
                    <div className="space-y-2">
                      {freeTablesBySection.floor.length > 0 && (
                        <div>
                          <p className="mb-1 text-[10px] font-bold uppercase tracking-wider text-emerald-600">⬆️ Floor Tables ({freeTablesBySection.floor.length} free)</p>
                          <div className="grid grid-cols-4 gap-1.5">
                            {freeTablesBySection.floor.map((table) => {
                              const label = getTableLabel(table);
                              const sel = tableNumber === label;
                              return (
                                <button key={table.id} type="button" onClick={() => setTableNumber(sel ? '' : label)} className={`rounded-xl border px-1 py-2 text-xs font-bold transition active:scale-95 ${sel ? 'border-emerald-600 bg-emerald-600 text-white shadow-md' : 'border-emerald-200 bg-emerald-50 text-emerald-700 hover:bg-emerald-100'}`}>
                                  {label}
                                </button>
                              );
                            })}
                          </div>
                        </div>
                      )}
                      {freeTablesBySection.outside.length > 0 && (
                        <div>
                          <p className="mb-1 text-[10px] font-bold uppercase tracking-wider text-sky-600">⬇️ Outside Tables ({freeTablesBySection.outside.length} free)</p>
                          <div className="grid grid-cols-4 gap-1.5">
                            {freeTablesBySection.outside.map((table) => {
                              const label = getTableLabel(table);
                              const sel = tableNumber === label;
                              return (
                                <button key={table.id} type="button" onClick={() => setTableNumber(sel ? '' : label)} className={`rounded-xl border px-1 py-2 text-xs font-bold transition active:scale-95 ${sel ? 'border-sky-600 bg-sky-600 text-white shadow-md' : 'border-sky-200 bg-sky-50 text-sky-700 hover:bg-sky-100'}`}>
                                  {label}
                                </button>
                              );
                            })}
                          </div>
                        </div>
                      )}
                    </div>
                  )}
                  {!tableNumber && <p className="text-xs text-amber-600">Please select a table to place the order</p>}
                </div>
              )}
              <div className="grid gap-1.5">
                <label className="text-xs font-semibold text-slate-600">{activeType === 'Take Away' ? 'Customer Name (optional)' : 'Customer Name'}</label>
                <input type="text" value={customerName} onChange={(e) => setCustomerName(e.target.value)} placeholder="Customer name" className="w-full rounded-xl border border-slate-300 bg-white px-3 py-2.5 text-sm text-slate-900 outline-none focus:border-emerald-500" />
              </div>
              <div className="grid gap-1.5">
                <label className="text-xs font-semibold text-slate-600">Notes <span className="text-slate-400">(optional)</span></label>
                <textarea value={notes} onChange={(e) => setNotes(e.target.value)} placeholder="Order notes" rows={2} className="w-full rounded-xl border border-slate-300 bg-white px-3 py-2.5 text-sm text-slate-900 outline-none focus:border-emerald-500" />
              </div>
            </div>
          </div>
          <div className="px-4 py-3 border-t border-slate-200 space-y-2">
            <div className="flex items-center justify-between">
              <span className="text-sm text-slate-500">Total</span>
              <span className="text-lg font-bold text-emerald-600">{cartTotal} PKR</span>
            </div>
            <button onClick={() => { if (activeType === 'Take Away') { setShowPaymentPopup(true); return; } createOrder(); }} disabled={loading || !cart.length || (activeType === 'Dine-In' && !tableNumber)} className="w-full rounded-xl py-3 text-sm font-bold text-white hover:opacity-90 disabled:opacity-50 active:scale-[0.99]"
              style={{ background: activeType === 'Take Away' ? 'linear-gradient(135deg, #f59e0b, #f97316)' : '#059669' }}>
              {loading ? 'Creating...' : activeType === 'Take Away' ? 'Place 🛍️ Take Away Order' : 'Place 🍽️ Dine-In Order'}
            </button>
          </div>
        </div>
      )}

      {/* Takeaway payment popup */}
      {showPaymentPopup && (
        <div className="fixed inset-0 z-[80] flex items-end sm:items-center justify-center bg-black/70" onClick={() => setShowPaymentPopup(false)}>
          <div className="w-full sm:max-w-md rounded-t-3xl sm:rounded-3xl border border-slate-700 bg-slate-950 p-5 shadow-[0_35px_120px_-30px_rgba(0,0,0,0.8)] overflow-y-auto" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between">
              <div>
                <p className="text-xs uppercase tracking-[0.2em] text-slate-500">Payment</p>
                <h3 className="mt-2 text-xl font-semibold text-white">🛍️ Take Away Payment</h3>
              </div>
              <button onClick={() => setShowPaymentPopup(false)} className="rounded-full border border-slate-700 bg-slate-900 px-3 py-2 text-sm text-slate-200 hover:bg-slate-800">✕</button>
            </div>
            <div className="mt-6 space-y-4">
              <div className="grid gap-3">
                <p className="text-sm text-slate-400">Order type: <span className="font-semibold text-slate-100">Takeaway</span></p>
                <div className="grid grid-cols-3 gap-2">
                  {['Cash', 'Card', 'Online'].map((method) => (
                    <button key={method} onClick={() => setPaymentMethod(method)} className={`rounded-full px-3 py-2 text-sm font-semibold transition ${paymentMethod === method ? 'bg-emerald-600 text-slate-950 shadow-[0_8px_0_rgba(16,185,129,0.22)]' : 'bg-slate-800 text-slate-200 hover:bg-slate-700'}`}>
                      {method}
                    </button>
                  ))}
                </div>
              </div>
              <div className="flex items-center justify-between rounded-3xl border border-slate-800 bg-slate-900 p-4">
                <span className="text-sm text-slate-400">Total</span>
                <span className="text-xl font-bold text-emerald-400">{cartTotal} PKR</span>
              </div>
              <div className="grid gap-2">
                <button onClick={() => createOrder('Pay Later', {})} disabled={loading} className="w-full rounded-3xl bg-slate-700 px-4 py-3 text-sm font-semibold text-white hover:bg-slate-600 disabled:opacity-50">
                  {loading ? 'Saving...' : '⏳ Pay Later'}
                </button>
                <button onClick={() => createOrder('Completed', { paid: true, paymentMethod })} disabled={loading} className="w-full rounded-3xl bg-emerald-600 px-4 py-3 text-sm font-semibold text-slate-950 hover:bg-emerald-500 disabled:opacity-50">
                  {loading ? 'Saving...' : `💳 Pay Now (${paymentMethod})`}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Orders popup */}
      {showOrdersPopup && (
        <div className="fixed inset-0 z-[60] bg-black/70 px-2 py-4 flex items-start justify-center pt-12" onClick={() => setShowOrdersPopup(false)}>
          <div className="relative w-full max-w-md max-h-[80vh] flex flex-col rounded-2xl bg-slate-950 border border-slate-800 overflow-hidden" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between p-4 border-b border-slate-800">
              <h3 className="text-base font-bold text-white">📋 My Orders</h3>
              <div className="flex items-center gap-2">
                <span onClick={() => refreshOrdersOnly(true)} className="flex h-8 w-8 cursor-pointer items-center justify-center rounded-full bg-slate-800 text-sm text-emerald-400 transition active:scale-90 hover:bg-slate-700" title="Refresh orders">
                  <span className={`inline-block ${popupRefreshing ? 'animate-spin' : ''}`}>🔄</span>
                </span>
                <button onClick={() => setShowOrdersPopup(false)} className="rounded-full p-1 text-slate-300 hover:bg-slate-800">✕</button>
              </div>
            </div>

            {/* Tabs: New | Served | Cancelled | All */}
            <div className="grid grid-cols-4 gap-1 p-3 border-b border-slate-800">
              <button onClick={() => setOrdersTab('new')} className={`rounded-xl px-1 py-2 text-[10px] font-bold transition-all ${ordersTab === 'new' ? 'bg-amber-600 text-white shadow-lg' : 'bg-slate-900 text-slate-400 hover:bg-slate-800'}`}>
                🆕 New {myNewOrders.length > 0 && <span className="ml-0.5 rounded-full bg-white/20 px-1 py-0.5 text-[9px]">{myNewOrders.length}</span>}
              </button>
              <button onClick={() => setOrdersTab('served')} className={`rounded-xl px-1 py-2 text-[10px] font-bold transition-all ${ordersTab === 'served' ? 'bg-emerald-600 text-white shadow-lg' : 'bg-slate-900 text-slate-400 hover:bg-slate-800'}`}>
                ✅ Served {myServedOrders.length > 0 && <span className="ml-0.5 rounded-full bg-white/20 px-1 py-0.5 text-[9px]">{myServedOrders.length}</span>}
              </button>
              <button onClick={() => setOrdersTab('cancelled')} className={`rounded-xl px-1 py-2 text-[10px] font-bold transition-all ${ordersTab === 'cancelled' ? 'bg-rose-600 text-white shadow-lg' : 'bg-slate-900 text-slate-400 hover:bg-slate-800'}`}>
                ❌ Cancelled {myCancelledOrders.length > 0 && <span className="ml-0.5 rounded-full bg-white/20 px-1 py-0.5 text-[9px]">{myCancelledOrders.length}</span>}
              </button>
              <button onClick={() => setOrdersTab('all')} className={`rounded-xl px-1 py-2 text-[10px] font-bold transition-all ${ordersTab === 'all' ? 'bg-indigo-600 text-white shadow-lg' : 'bg-slate-900 text-slate-400 hover:bg-slate-800'}`}>
                📋 All {allTypeOrders.length > 0 && <span className="ml-0.5 rounded-full bg-white/20 px-1 py-0.5 text-[9px]">{allTypeOrders.length}</span>}
              </button>
            </div>

            <div className="flex-1 overflow-y-auto p-3 space-y-2">
              {popupOrders.length === 0 && (
                <p className="text-sm text-slate-500 text-center py-8">
                  {ordersTab === 'new' ? 'No new orders yet' : ordersTab === 'served' ? 'No served orders yet' : ordersTab === 'cancelled' ? 'No cancelled orders yet' : 'No orders yet'}
                </p>
              )}
              {popupOrders
                .map(order => {
                const isExpanded = expandedOrderId === order.id;
                const { subtotal, total } = orderTotals(order);
                const isPaid = (order.paymentStatus || '').toLowerCase() === 'paid' || (order.status || '').toLowerCase() === 'payment collected' || (order.status || '').toLowerCase() === 'completed';
                const requestSent = order.paymentRequestStatus === 'owner-request';
                const servedAtMs = order.servedAt ? new Date(order.servedAt).getTime() : null;
                const createdMs = order.createdAt ? new Date(order.createdAt).getTime() : null;
                const cancelledMs = order.cancelledAt ? new Date(order.cancelledAt).getTime() : null;
                const st = isCancelledOrder(order) ? 'cancelled' : isServedOrder(order) ? 'served' : 'new';
                return (
                  <div key={order.id} className={`rounded-xl border overflow-hidden ${st === 'cancelled' ? 'border-rose-900/60 bg-rose-950/20' : 'border-slate-800 bg-slate-900'}`}>
                    {/* Header - tap to expand */}
                    <button onClick={() => setExpandedOrderId(isExpanded ? null : order.id)} className="w-full p-3 text-left active:bg-slate-800/50 transition-colors">
                      <div className="flex items-center justify-between mb-1">
                        <span className="text-xs font-bold text-indigo-400">#{order.orderNumber || order.id}</span>
                        <span className="flex items-center gap-1.5">
                          {createdMs && <span className="text-[10px] text-slate-400">{new Date(createdMs).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true })}</span>}
                          <span className={`rounded-full px-1.5 py-0.5 text-[10px] font-bold ${st === 'new' ? 'bg-amber-500/15 text-amber-400' : st === 'served' ? 'bg-emerald-500/15 text-emerald-400' : 'bg-rose-500/15 text-rose-400'}`}>
                            ⏱ {formatDuration(now - (st === 'new' ? createdMs : st === 'served' ? servedAtMs : cancelledMs) || now)}
                          </span>
                          <span className={`text-[10px] ${isExpanded ? 'rotate-180' : ''} transition-transform text-slate-500`}>▼</span>
                        </span>
                      </div>
                      <div className="flex items-center gap-2 text-[10px] text-slate-400 mb-1">
                        <span className={`font-semibold ${st === 'new' ? 'text-amber-400' : st === 'served' ? 'text-emerald-400' : 'text-rose-400'}`}>
                          {st === 'new' ? order.orderType : st === 'served' ? 'Served' : 'Cancelled'}
                        </span>
                        <span>•</span>
                        <span>{order.customerName || order.tableNumber || '-'}</span>
                        <span>•</span>
                        <span className={`font-semibold rounded-full px-1.5 py-0.5 ${isPaid ? 'bg-emerald-500/15 text-emerald-400' : st === 'cancelled' ? 'bg-rose-500/15 text-rose-400' : 'bg-amber-500/15 text-amber-400'}`}>{order.status || order.paymentStatus || 'New'}</span>
                      </div>
                      <div className="flex items-center justify-between">
                        <span className="text-sm font-bold text-emerald-400">{total} PKR</span>
                        <span className="text-[10px] text-slate-500">{isExpanded ? 'Hide details' : 'Tap for details'}</span>
                      </div>
                    </button>

                    {isExpanded && (
                      <div className="px-3 pb-3 space-y-3">
                        {/* Items + price details */}
                        <div className="rounded-lg bg-slate-950 border border-slate-800 p-2.5 space-y-1.5">
                          {(order.items || []).map((item, idx) => (
                            <div key={idx} className="flex items-center justify-between gap-2 text-[11px]">
                              <span className="text-slate-200 min-w-0"><span className="text-amber-400 font-bold">{item.quantity}x</span> <span className="truncate">{item.name}</span></span>
                              <span className="text-slate-400 shrink-0">{Number(item.price) || 0} × {item.quantity} = <span className="text-emerald-400 font-bold">{Number(item.total) || ((Number(item.price) || 0) * item.quantity)}</span></span>
                            </div>
                          ))}
                          <div className="border-t border-slate-800 pt-1.5 space-y-0.5 text-[11px]">
                            <div className="flex justify-between text-slate-400"><span>Subtotal</span><span>{subtotal} PKR</span></div>
                            {Number(order.discount) > 0 && <div className="flex justify-between text-slate-400"><span>Discount</span><span className="text-rose-400">-{Number(order.discount)} PKR</span></div>}
                            {Number(order.taxPercent) > 0 && <div className="flex justify-between text-slate-400"><span>Tax ({order.taxPercent}%)</span><span>{Math.max(0, (subtotal - (Number(order.discount) || 0)) * (Number(order.taxPercent) || 0) / 100).toFixed(0)} PKR</span></div>}
                            {Number(order.serviceCharge) > 0 && <div className="flex justify-between text-slate-400"><span>Service Charge</span><span>{Number(order.serviceCharge)} PKR</span></div>}
                            {Number(order.deliveryFee) > 0 && <div className="flex justify-between text-slate-400"><span>Delivery Fee</span><span>{Number(order.deliveryFee)} PKR</span></div>}
                            <div className="flex justify-between pt-1 text-xs font-bold"><span className="text-slate-300">Total</span><span className="text-emerald-400">{total} PKR</span></div>
                          </div>
                        </div>

                        {st === 'new' && (
                          <div className="flex flex-wrap gap-1.5">
                            <button onClick={() => printOrder(order)} className="flex-1 min-w-[45%] rounded-full bg-slate-800 px-2.5 py-1.5 text-[10px] font-semibold text-slate-200 hover:bg-slate-700 active:scale-[0.97]">🖨️ Print</button>
                            <button onClick={() => openEditOrder(order)} className="flex-1 min-w-[45%] rounded-full bg-slate-800 px-2.5 py-1.5 text-[10px] font-semibold text-slate-200 hover:bg-slate-700 active:scale-[0.97]">✏️ Edit Order</button>
                            <button onClick={() => markServed(order)} disabled={loading} className="flex-1 min-w-[45%] rounded-full bg-emerald-600 px-2.5 py-1.5 text-[10px] font-bold text-white hover:bg-emerald-500 active:scale-[0.97] disabled:opacity-50">✅ Mark Served</button>
                            <button onClick={() => cancelOrder(order)} disabled={loading} className="flex-1 min-w-[45%] rounded-full bg-rose-600 px-2.5 py-1.5 text-[10px] font-bold text-white hover:bg-rose-500 active:scale-[0.97] disabled:opacity-50">❌ Cancel Order</button>
                          </div>
                        )}

                        {st === 'served' && (
                          <>
                            {/* Payment request photo (dine-in) */}
                            {!isPaid && (
                              <div className="rounded-lg border border-slate-800 bg-slate-950 p-2">
                                {order.paymentRequestImage ? (
                                  <div className="flex items-center gap-2">
                                    <img src={order.paymentRequestImage} alt="Payment request" onClick={() => setPreviewImage(order.paymentRequestImage)} className="h-12 w-12 rounded-lg object-cover cursor-pointer border border-amber-600/50" />
                                    <div className="flex-1 min-w-0">
                                      <p className="text-[10px] font-bold text-amber-400">📷 Payment Photo Attached</p>
                                      <p className="text-[9px] text-slate-500 truncate">{order.paymentRequestedAt ? new Date(order.paymentRequestedAt).toLocaleString('en-US', { year: 'numeric', month: '2-digit', day: '2-digit', hour: 'numeric', minute: '2-digit', hour12: true }) : ''}</p>
                                      {requestSent && <p className="text-[9px] font-bold text-violet-400 mt-0.5">✅ Request sent to Farhan Owner</p>}
                                    </div>
                                    <button onClick={() => openRequestCamera(order.id)} className="shrink-0 rounded-full bg-slate-800 px-2.5 py-1 text-[10px] font-semibold text-slate-200 hover:bg-slate-700">Retake</button>
                                  </div>
                                ) : (
                                  <button onClick={() => openRequestCamera(order.id)} disabled={loading}
                                    className="w-full rounded-lg bg-amber-600 px-3 py-2 text-[11px] font-bold text-white hover:bg-amber-500 active:scale-[0.98] transition-all disabled:opacity-50 flex items-center justify-center gap-1.5">
                                    📷 Attach Payment Photo
                                  </button>
                                )}
                              </div>
                            )}

                            {/* Push to Farhan Owner request with payment method */}
                            {isPaid ? (
                              <div className="rounded-lg bg-emerald-500/10 border border-emerald-500/30 px-3 py-2 text-center text-[11px] font-bold text-emerald-400">
                                ✅ Payment {order.paymentMethod ? `collected via ${order.paymentMethod}` : 'collected'}
                              </div>
                            ) : requestSent ? (
                              <div className="rounded-lg bg-violet-500/10 border border-violet-500/30 px-3 py-2 text-center text-[11px] font-bold text-violet-400">
                                👤 Request sent to Farhan Owner{order.paymentMethod ? ` (${order.paymentMethod === 'Online' ? '📱' : '💵'} ${order.paymentMethod})` : ''} - awaiting approval
                              </div>
                            ) : (
                              <button onClick={() => setPaymentMethodOrder(order)} disabled={loading || !order.paymentRequestImage}
                                className="w-full rounded-lg bg-violet-600 px-3 py-2 text-[11px] font-bold text-white hover:bg-violet-500 active:scale-[0.98] transition-all disabled:opacity-50 flex items-center justify-center gap-1.5">
                                👤 Push to Farhan Owner Request
                              </button>
                            )}

                            <div className="flex gap-1.5">
                              <button onClick={() => printOrder(order)} className="flex-1 rounded-full bg-slate-800 px-2.5 py-1.5 text-[10px] font-semibold text-slate-200 hover:bg-slate-700">🖨️ Print</button>
                              <button onClick={() => openEditOrder(order)} className="flex-1 rounded-full bg-emerald-600 px-2.5 py-1.5 text-[10px] font-bold text-white hover:bg-emerald-500">➕ Add More Items</button>
                            </div>
                          </>
                        )}

                        {st === 'cancelled' && (
                          <div className="rounded-lg bg-rose-500/10 border border-rose-500/30 px-3 py-2 text-center text-[11px] font-bold text-rose-400">
                            ❌ Order cancelled{cancelledMs ? ` at ${new Date(cancelledMs).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true })}` : ''}
                          </div>
                        )}
                      </div>
                    )}
                  </div>
                );
              })}
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
              <select value={editOrder.tableNumber || ''} onChange={(e) => setEditOrder({ ...editOrder, tableNumber: e.target.value })}
                className="w-full rounded-xl border border-slate-700 bg-slate-900 px-3 py-2 text-sm text-slate-100 outline-none">
                <option value="">Select table or room</option>
                {availableDineInTables.map((table) => (
                  <option key={table.id} value={getTableLabel(table)}>{getTableLabel(table)}{table.isOccupied && editOrder.tableNumber !== getTableLabel(table) ? ' (Busy)' : ''}</option>
                ))}
              </select>
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

              {/* Add more items */}
              <div className="rounded-xl border border-slate-800 bg-slate-900 p-2.5">
                <p className="text-[11px] font-bold text-emerald-400 mb-1.5">➕ Add More Items</p>
                <input type="text" value={editAddSearch} onChange={(e) => setEditAddSearch(e.target.value)} placeholder="Search items to add..." className="w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-xs text-slate-100 outline-none placeholder-slate-500 mb-1.5" />
                <div className="max-h-44 overflow-y-auto rounded-lg border border-slate-800 divide-y divide-slate-800">
                  {filteredEditAddProducts.map(product => (
                    <button key={product.id} onClick={() => {
                      const existingIdx = editCart.findIndex(i => (i.productId || i.id) === product.id);
                      if (existingIdx >= 0) {
                        const c = [...editCart];
                        c[existingIdx].quantity += 1;
                        setEditCart(c);
                      } else {
                        setEditCart([...editCart, { productId: product.id, id: product.id, name: product.name, price: Number(product.price) || 0, quantity: 1, itemId: `${product.id}-${Date.now()}-${Math.random().toString(36).slice(2, 8)}` }]);
                      }
                      setMessage(`${product.name} added`);
                    }} className="w-full flex items-center justify-between px-3 py-2 text-left hover:bg-slate-800 active:bg-slate-800/70">
                      <span className="text-xs text-slate-200 truncate flex-1">{product.name}</span>
                      <span className="text-xs font-bold text-emerald-400 shrink-0 ml-2">{Number(product.price) || 0} PKR</span>
                    </button>
                  ))}
                  {filteredEditAddProducts.length === 0 && <p className="px-3 py-3 text-[11px] text-slate-500 text-center">No items found</p>}
                </div>
              </div>
            </div>
            <div className="px-4 py-3 border-t border-slate-800">
              <div className="flex items-center justify-between mb-3">
                <span className="text-sm text-slate-400">Total</span>
                <span className="text-lg font-bold text-emerald-400">
                  {(() => {
                    const subtotal = editCart.reduce((s, i) => s + (Number(i.price) || 0) * (Number(i.quantity) || 1), 0);
                    const discount = Number(editOrder.discount) || 0;
                    const tax = ((subtotal - discount) * (Number(editOrder.taxPercent) || 0)) / 100;
                    const service = Number(editOrder.serviceCharge) || 0;
                    return `${Math.max(0, subtotal - discount + tax + service)} PKR`;
                  })()}
                </span>
              </div>
              <button onClick={saveEditOrder} disabled={loading} className="w-full rounded-xl bg-emerald-600 py-3 text-sm font-bold text-white hover:bg-emerald-500 disabled:opacity-50">
                {loading ? 'Saving...' : 'Save Changes'}
              </button>
            </div>
          </div>
        </div>
      )}

      <input ref={fileInputRef} type="file" accept="image/*" capture="environment" className="hidden" onChange={handleRequestImage} />

      {/* Payment method selection for Push to Farhan Owner request */}
      {paymentMethodOrder && (
        <div className="fixed inset-0 z-[75] bg-black/70 px-4 py-4 flex items-center justify-center" onClick={() => setPaymentMethodOrder(null)}>
          <div className="w-full max-w-sm rounded-2xl bg-slate-950 border border-slate-800 p-5 shadow-2xl" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between mb-1">
              <h3 className="text-base font-bold text-white">💳 Payment Method</h3>
              <button onClick={() => setPaymentMethodOrder(null)} className="rounded-full p-1 text-slate-300 hover:bg-slate-800">✕</button>
            </div>
            <p className="text-xs text-slate-400 mb-1">
              Push request for order <span className="font-bold text-indigo-400">#{paymentMethodOrder.orderNumber || paymentMethodOrder.id}</span> to Farhan Owner.
            </p>
            <p className="text-xs text-slate-500 mb-4">Select how the customer will pay:</p>
            <div className="space-y-2">
              <button onClick={() => pushOwnerRequest(paymentMethodOrder, 'Cash')} disabled={loading}
                className="w-full flex items-center justify-center gap-2 rounded-xl bg-emerald-600 py-3.5 text-sm font-bold text-white hover:bg-emerald-500 active:scale-[0.98] transition-all disabled:opacity-50">
                💵 Cash
              </button>
              <button onClick={() => pushOwnerRequest(paymentMethodOrder, 'Online')} disabled={loading}
                className="w-full flex items-center justify-center gap-2 rounded-xl bg-sky-600 py-3.5 text-sm font-bold text-white hover:bg-sky-500 active:scale-[0.98] transition-all disabled:opacity-50">
                📱 Online
              </button>
            </div>
            <button onClick={() => setPaymentMethodOrder(null)} className="mt-3 w-full rounded-xl border border-slate-700 py-2.5 text-xs font-semibold text-slate-300 hover:bg-slate-900">
              Cancel
            </button>
          </div>
        </div>
      )}

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
