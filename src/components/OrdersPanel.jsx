import React, { useState, useMemo, useEffect, useCallback } from 'react';
import { Eye, Grid3X3, List, Bell, X, CheckCircle, Clock, Truck, Package, AlertCircle, ChefHat, Filter, Download, RefreshCw, Search, ShoppingCart, Trash2, Plus, Minus, Edit3, Save, XCircle, LayoutGrid, Table2 } from 'lucide-react';
import './OrdersPanel.css';

const menuCategories = [
  {
    id: 'breakfast',
    title: 'ناشتے کی آئٹمز',
    icon: '🍳',
    items: [
      { id: 'sada-chana', name: 'سادہ چنے', options: [{ label: 'ہاف', price: 150 }, { label: 'فل', price: 250 }] },
      { id: 'anda-chana', name: 'انڈہ چنے', options: [{ label: 'ہاف', price: 180 }, { label: 'فل', price: 300 }] },
      { id: 'kofta-chana', name: 'کوفتہ چنے', options: [{ label: 'ہاف', price: 200 }, { label: 'فل', price: 320 }] },
      { id: 'special-haleem', name: 'اسپیشل حلیم', options: [{ label: 'ہاف', price: 150 }, { label: 'فل', price: 250 }] },
      { id: 'special-paya', name: 'اسپیشل پائے', options: [{ label: 'ہاف', price: 400 }, { label: 'فل', price: 600 }] },
      { id: 'raita', name: 'رائتہ', price: 50 },
      { id: 'tawa-paratha', name: 'توہ پراٹھا', price: 60 },
    ],
  },
  {
    id: 'karahi',
    title: 'چکن کڑاہی مینیو',
    icon: '🍗',
    items: [
      { id: 'red-chicken-karahi', name: 'ریڈ چکن کڑاہی', options: [{ label: 'ہاف', price: 800 }, { label: 'فل', price: 1600 }] },
      { id: 'white-chicken-karahi', name: 'وائٹ چکن کڑاہی', options: [{ label: 'ہاف', price: 1000 }, { label: 'فل', price: 2000 }] },
      { id: 'green-chicken-karahi', name: 'گرین چکن کڑاہی', options: [{ label: 'ہاف', price: 900 }, { label: 'فل', price: 1800 }] },
      { id: 'achari-chicken-karahi', name: 'اچاری چکن کڑاہی', options: [{ label: 'ہاف', price: 900 }, { label: 'فل', price: 1800 }] },
      { id: 'makkhani-chicken-karahi', name: 'مکھنی چکن کڑاہی', options: [{ label: 'ہاف', price: 1000 }, { label: 'فل', price: 2000 }] },
    ],
  },
  {
    id: 'seekh-kabab',
    title: 'سیخ کباب',
    icon: '🥩',
    items: [
      { id: 'chicken-kabab', name: 'چکن کباب', price: 170 },
      { id: 'beef-kabab', name: 'بیف کباب', price: 250 },
      { id: 'chicken-reshmi-kabab', name: 'چکن ریشمی کباب', price: 300 },
      { id: 'chicken-cheese-kabab', name: 'چکن چیز کباب', price: 300 },
    ],
  },
  {
    id: 'boti-items',
    title: 'بوٹی آئٹمز',
    icon: '🍢',
    items: [
      { id: 'tikka-boti', name: 'تکہ بوٹی', price: 220 },
      { id: 'malai-boti', name: 'ملائی بوٹی', price: 350 },
      { id: 'green-boti', name: 'گرین بوٹی', price: 400 },
      { id: 'sasami-boti', name: 'ساسمی بوٹی', price: 450 },
      { id: 'pasha-boti', name: 'پاشا بوٹی', price: 450 },
      { id: 'cheese-malai-boti', name: 'چیز ملائی بوٹی', price: 450 },
    ],
  },
  {
    id: 'chicken-pieces',
    title: 'چکن پیسز',
    icon: '🍖',
    items: [
      { id: 'leg-piece', name: 'لیگ پیس', price: 370 },
      { id: 'chest-piece', name: 'چیسٹ پیس', price: 400 },
    ],
  },
  {
    id: 'naan-roti',
    title: 'نان اور روٹی',
    icon: '🫓',
    items: [
      { id: 'naan-sada', name: 'نان سادہ', price: 30 },
      { id: 'sada-roti', name: 'سادہ روٹی', price: 14 },
      { id: 'khameeri-roti', name: 'خمیری روٹی', price: 30 },
      { id: 'dhaniya-naan', name: 'دھنیا نان', price: 35 },
      { id: 'kulcha-naan', name: 'کلچہ نان', price: 35 },
      { id: 'kalonji-naan', name: 'کلونجی نان', price: 35 },
      { id: 'tawa-paratha', name: 'توہ پراٹھا', price: 60 },
    ],
  },
  {
    id: 'special-naan',
    title: 'اسپیشل نان',
    icon: '🥖',
    items: [
      { id: 'roghni-naan', name: 'روغنی نان', price: 90 },
      { id: 'half-roghni', name: 'ہاف روغنی', price: 60 },
      { id: 'garlic-naan', name: 'گارلک نان', price: 120 },
      { id: 'special-kulcha', name: 'اسپیشل کلچہ', price: 50 },
      { id: 'tandoori-paratha', name: 'تندوری پراٹھا', price: 70 },
      { id: 'aloo-naan', name: 'آلو نان', price: 150 },
      { id: 'chicken-keema-naan', name: 'چکن قیمہ نان', price: 350 },
      { id: 'beef-keema-naan', name: 'بیف قیمہ نان', price: 450 },
      { id: 'cheese-naan', name: 'چیز نان', price: 350 },
      { id: 'chicken-cheese-naan', name: 'چکن چیز نان', price: 450 },
      { id: 'chocolate-naan', name: 'چاکلیٹ نان', price: 400 },
      { id: 'nutella-naan', name: 'نٹیلا نان', price: 400 },
      { id: 'achari-naan', name: 'اچاری نان', price: 120 },
    ],
  },
  {
    id: 'extras',
    title: 'Extras',
    icon: '➕',
    items: [
      { id: 'extra-1', name: 'Extra', options: [{ label: 'Extra', price: 200 }] },
      { id: 'extra-2', name: 'Extra', options: [{ label: 'Extra', price: 200 }] },
      { id: 'extra-3', name: 'Extra', options: [{ label: 'Extra', price: 200 }] },
      { id: 'extra-4', name: 'Extra', options: [{ label: 'Extra', price: 200 }] },
      { id: 'extra-5', name: 'Extra', options: [{ label: 'Extra', price: 200 }] },
      { id: 'extra-6', name: 'Extra', options: [{ label: 'Extra', price: 200 }] },
      { id: 'extra-7', name: 'Extra', options: [{ label: 'Extra', price: 200 }] },
    ],
  },
];

// Status configuration with colors and icons
const STATUS_CONFIG = {
  pending: { label: 'Pending', color: '#f59e0b', bg: '#fef3c7', border: '#fcd34d', icon: '⏳', glow: 'rgba(245, 158, 11, 0.3)' },
  preparing: { label: 'Preparing', color: '#8b5cf6', bg: '#ede9fe', border: '#c4b5fd', icon: '👨‍🍳', glow: 'rgba(139, 92, 246, 0.3)' },
  ready: { label: 'Ready', color: '#06b6d4', bg: '#cffafe', border: '#67e8f9', icon: '✅', glow: 'rgba(6, 182, 212, 0.3)' },
  dispatched: { label: 'Dispatched', color: '#3b82f6', bg: '#dbeafe', border: '#93c5fd', icon: '🚀', glow: 'rgba(59, 130, 246, 0.3)' },
  delivered: { label: 'Delivered', color: '#10b981', bg: '#d1fae5', border: '#6ee7b7', icon: '📦', glow: 'rgba(16, 185, 129, 0.3)' },
  paid: { label: 'Paid', color: '#10b981', bg: '#d1fae5', border: '#6ee7b7', icon: '💰', glow: 'rgba(16, 185, 129, 0.3)' },
  completed: { label: 'Completed', color: '#3b82f6', bg: '#dbeafe', border: '#93c5fd', icon: '✔️', glow: 'rgba(59, 130, 246, 0.3)' },
  cancelled: { label: 'Cancelled', color: '#ef4444', bg: '#fee2e2', border: '#fca5a5', icon: '❌', glow: 'rgba(239, 68, 68, 0.3)' },
};

const OrdersPanel = () => {
  const [orders, setOrders] = useState([
    { id: 1, orderNum: 'ORD-001', table: 1, items: 'Biryani (2), Karahi (1)', category: 'Biryani', total: 2500, status: 'pending', date: '2026-06-09', time: '12:30 PM', rider: null, type: 'dine-in' },
    { id: 2, orderNum: 'ORD-002', table: 2, items: 'Karahi Chicken (1)', category: 'Karahi', total: 1800, status: 'preparing', date: '2026-06-09', time: '01:15 PM', rider: null, type: 'dine-in' },
    { id: 3, orderNum: 'ORD-003', table: 3, items: 'Nihari (3), Naan (3)', category: 'Nihari', total: 3200, status: 'ready', date: '2026-06-09', time: '02:00 PM', rider: 'Ali Khan', type: 'delivery' },
    { id: 4, orderNum: 'ORD-004', table: 5, items: 'Tikka Masala (2)', category: 'Tikka', total: 2200, status: 'dispatched', date: '2026-06-09', time: '02:45 PM', rider: 'Hamza', type: 'delivery' },
    { id: 5, orderNum: 'ORD-005', table: 1, items: 'Kebab (4), Salad (1)', category: 'Kebab', total: 1600, status: 'paid', date: '2026-06-09', time: '03:30 PM', rider: null, type: 'dine-in' },
    { id: 6, orderNum: 'ORD-006', table: 4, items: 'Haleem (2)', category: 'Haleem', total: 2000, status: 'completed', date: '2026-06-09', time: '06:15 PM', rider: null, type: 'takeaway' },
    { id: 7, orderNum: 'ORD-007', table: null, items: 'Karahi (1), Naan (4)', category: 'Karahi', total: 1750, status: 'delivered', date: '2026-06-09', time: '04:00 PM', rider: 'Bilal', type: 'delivery' },
    { id: 8, orderNum: 'ORD-008', table: 6, items: 'Boti (3), Raita (2)', category: 'Boti', total: 1300, status: 'cancelled', date: '2026-06-09', time: '05:10 PM', rider: null, type: 'dine-in' },
  ]);

  // Main tab: orders | rider-book
  const [mainTab, setMainTab] = useState('orders');
  // Orders sub-tab: live | sales | all-orders
  const [ordersTab, setOrdersTab] = useState('all-orders');
  // View mode: tiles | table
  const [viewMode, setViewMode] = useState('tiles');
  const [statusFilter, setStatusFilter] = useState('all');
  const [typeFilter, setTypeFilter] = useState('all');

  const [liveSearch, setLiveSearch] = useState('');
  const [salesSearch, setSalesSearch] = useState('');
  const [liveDateFilter, setLiveDateFilter] = useState('today');
  const [salesDateFilter, setSalesDateFilter] = useState('today');
  const [liveCustomFrom, setLiveCustomFrom] = useState(() => new Date().toISOString().slice(0, 10));
  const [liveCustomTo, setLiveCustomTo] = useState(() => new Date().toISOString().slice(0, 10));
  const [salesCustomFrom, setSalesCustomFrom] = useState(() => new Date().toISOString().slice(0, 10));
  const [salesCustomTo, setSalesCustomTo] = useState(() => new Date().toISOString().slice(0, 10));
  const [categoryFilter, setCategoryFilter] = useState('');
  const [activeMenuCategory, setActiveMenuCategory] = useState(menuCategories[0].id);
  const [selectedOptions, setSelectedOptions] = useState({});
  const [cartItems, setCartItems] = useState([]);
  const [editingCartIndex, setEditingCartIndex] = useState(null);
  const [editingData, setEditingData] = useState({ name: '', price: 0 });

  // Notification system
  const [notifications, setNotifications] = useState([
    { id: 1, message: 'Order ORD-003 is ready for dispatch!', type: 'success', time: '2 min ago', read: false },
    { id: 2, message: 'Rider Ali Khan picked up ORD-004', type: 'info', time: '5 min ago', read: false },
    { id: 3, message: 'New order ORD-008 received', type: 'warning', time: '8 min ago', read: true },
  ]);
  const [showNotifications, setShowNotifications] = useState(false);
  const [toasts, setToasts] = useState([]);

  // Rider Book state
  const [riders] = useState([
    { id: 1, name: 'Ali Khan', phone: '0300-1234567', status: 'active', deliveries: 12, rating: 4.8 },
    { id: 2, name: 'Hamza', phone: '0311-2345678', status: 'on-delivery', deliveries: 8, rating: 4.5 },
    { id: 3, name: 'Bilal', phone: '0321-3456789', status: 'active', deliveries: 15, rating: 4.9 },
    { id: 4, name: 'Usman', phone: '0333-4567890', status: 'offline', deliveries: 5, rating: 4.2 },
    { id: 5, name: 'Farhan', phone: '0345-5678901', status: 'active', deliveries: 20, rating: 4.7 },
  ]);

  // Order detail modal
  const [selectedOrder, setSelectedOrder] = useState(null);

  const categories = ['Biryani', 'Karahi', 'Nihari', 'Tikka', 'Kebab', 'Haleem', 'Tandoori', 'Raita', 'Naan', 'Boti'];

  const activeMenu = menuCategories.find(category => category.id === activeMenuCategory) || menuCategories[0];

  const activeSearch = ordersTab === 'live' ? liveSearch : salesSearch;
  const activeDateFilter = ordersTab === 'live' ? liveDateFilter : salesDateFilter;
  const activeCustomFrom = ordersTab === 'live' ? liveCustomFrom : salesCustomFrom;
  const activeCustomTo = ordersTab === 'live' ? liveCustomTo : salesCustomTo;

  const unreadCount = notifications.filter(n => !n.read).length;

  // Toast notification helper
  const addToast = useCallback((message, type = 'info') => {
    const id = Date.now();
    setToasts(prev => [...prev, { id, message, type }]);
    setTimeout(() => {
      setToasts(prev => prev.filter(t => t.id !== id));
    }, 4000);
  }, []);

  const dateRange = useMemo(() => {
    const today = new Date();
    const format = (date) => date.toISOString().slice(0, 10);
    const current = format(today);
    const yesterday = format(new Date(today.getFullYear(), today.getMonth(), today.getDate() - 1));

    if (activeDateFilter === 'today') {
      return [current, current];
    }
    if (activeDateFilter === 'yesterday') {
      return [yesterday, yesterday];
    }
    if (activeDateFilter === 'last5') {
      return [format(new Date(today.getFullYear(), today.getMonth(), today.getDate() - 4)), current];
    }
    if (activeDateFilter === 'custom') {
      return [activeCustomFrom || current, activeCustomTo || current];
    }
    return [null, null];
  }, [activeDateFilter, activeCustomFrom, activeCustomTo]);

  const filteredOrders = useMemo(() => {
    const searchTerm = activeSearch.trim().toLowerCase();
    return orders.filter(order => {
      const matchesSearch = !searchTerm || [order.orderNum, order.table?.toString(), order.items, order.category, order.status, order.rider]
        .some(value => String(value || '').toLowerCase().includes(searchTerm));
      
      // For all-orders tab, skip date filter
      let matchesDate = true;
      if (ordersTab !== 'all-orders') {
        const [fromDate, toDate] = dateRange;
        matchesDate = !fromDate || (order.date >= fromDate && order.date <= toDate);
      }
      
      const categoryMatch = !categoryFilter || order.category === categoryFilter;
      const statusMatch = statusFilter === 'all' || order.status === statusFilter;
      const typeMatch = typeFilter === 'all' || order.type === typeFilter;
      return matchesSearch && matchesDate && categoryMatch && statusMatch && typeMatch;
    });
  }, [orders, activeSearch, dateRange, categoryFilter, statusFilter, typeFilter, ordersTab]);

  const stats = useMemo(() => {
    const statusCounts = {};
    Object.keys(STATUS_CONFIG).forEach(s => { statusCounts[s] = 0; });
    filteredOrders.forEach(o => { statusCounts[o.status] = (statusCounts[o.status] || 0) + 1; });
    
    return {
      totalOrders: filteredOrders.length,
      totalSales: filteredOrders.reduce((sum, order) => sum + order.total, 0),
      averageOrder: filteredOrders.length > 0
        ? Math.round(filteredOrders.reduce((sum, order) => sum + order.total, 0) / filteredOrders.length)
        : 0,
      statusCounts,
    };
  }, [filteredOrders]);

  const handleClearFilters = () => {
    setLiveSearch('');
    setSalesSearch('');
    setLiveDateFilter('today');
    setSalesDateFilter('today');
    setCategoryFilter('');
    setStatusFilter('all');
    setTypeFilter('all');
    addToast('All filters cleared', 'info');
  };

  const handleExportCSV = () => {
    const headers = ['Order #', 'Table', 'Items', 'Category', 'Total', 'Status', 'Type', 'Rider', 'Date', 'Time'];
    const csv = [
      headers.join(','),
      ...filteredOrders.map(order =>
        `${order.orderNum},${order.table || 'N/A'},"${order.items}",${order.category},${order.total},${order.status},${order.type},${order.rider || 'N/A'},${order.date},${order.time}`
      ),
    ].join('\n');

    const blob = new Blob([csv], { type: 'text/csv' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `orders_${new Date().toISOString().split('T')[0]}.csv`;
    a.click();
    window.URL.revokeObjectURL(url);
    addToast('CSV exported successfully!', 'success');
  };

  const handleViewOrder = (orderId) => {
    const order = orders.find(o => o.id === orderId);
    setSelectedOrder(order);
  };

  const handleStatusChange = (orderId, newStatus) => {
    setOrders(prev => prev.map(o => o.id === orderId ? { ...o, status: newStatus } : o));
    const order = orders.find(o => o.id === orderId);
    addToast(`${order.orderNum} status → ${STATUS_CONFIG[newStatus].label}`, 'success');
    setNotifications(prev => [{
      id: Date.now(),
      message: `${order.orderNum} updated to ${STATUS_CONFIG[newStatus].label}`,
      type: 'info',
      time: 'Just now',
      read: false,
    }, ...prev]);
  };

  const handleSelectOption = (itemId, optionLabel) => {
    setSelectedOptions(prev => ({ ...prev, [itemId]: optionLabel }));
  };

  const handleAddToCart = (item) => {
    const optionLabel = item.options ? (selectedOptions[item.id] || item.options[0].label) : null;
    const option = item.options ? item.options.find(opt => opt.label === optionLabel) : undefined;
    const price = option ? option.price : item.price;
    const label = option ? `${item.name} (${option.label})` : item.name;

    setCartItems(prev => {
      return [...prev, {
        id: item.id,
        name: item.name,
        option: optionLabel,
        label,
        price,
        quantity: 1,
        originalName: label,
        originalPrice: price
      }];
    });
    addToast(`${item.name} added to cart`, 'success');
  };

  const handleEditCartItem = (index) => {
    const item = cartItems[index];
    setEditingCartIndex(index);
    setEditingData({ name: item.label, price: item.price });
  };

  const handleSaveEdit = () => {
    if (editingCartIndex !== null) {
      setCartItems(prev => prev.map((item, idx) => {
        if (idx !== editingCartIndex) return item;
        return {
          ...item,
          label: editingData.name,
          price: Number(editingData.price) || 0
        };
      }));
      setEditingCartIndex(null);
      setEditingData({ name: '', price: 0 });
      addToast('Cart item updated', 'success');
    }
  };

  const handleCancelEdit = () => {
    setEditingCartIndex(null);
    setEditingData({ name: '', price: 0 });
  };

  const handleQuantityChange = (index, delta) => {
    setCartItems(prev => prev.map((cartItem, idx) => {
      if (idx !== index) return cartItem;
      const newQuantity = cartItem.quantity + delta;
      return newQuantity < 1 ? cartItem : { ...cartItem, quantity: newQuantity };
    }).filter(item => item.quantity > 0));
  };

  const handleRemoveCartItem = (index) => {
    setCartItems(prev => prev.filter((_, idx) => idx !== index));
    addToast('Item removed from cart', 'warning');
  };

  const handleClearCart = () => {
    setCartItems([]);
    addToast('Cart cleared', 'warning');
  };

  const markAllRead = () => {
    setNotifications(prev => prev.map(n => ({ ...n, read: true })));
  };

  const removeNotification = (id) => {
    setNotifications(prev => prev.filter(n => n.id !== id));
  };

  const cartTotal = cartItems.reduce((sum, item) => sum + item.price * item.quantity, 0);

  const getStatusNextActions = (status) => {
    const flow = {
      pending: ['preparing', 'cancelled'],
      preparing: ['ready', 'cancelled'],
      ready: ['dispatched', 'delivered'],
      dispatched: ['delivered'],
      delivered: ['paid', 'completed'],
      paid: ['completed'],
      completed: [],
      cancelled: [],
    };
    return flow[status] || [];
  };

  // ── Render: Order Tile Card ──
  const renderOrderTile = (order) => {
    const cfg = STATUS_CONFIG[order.status] || STATUS_CONFIG.pending;
    const nextActions = getStatusNextActions(order.status);

    return (
      <div
        key={order.id}
        className={`order-tile order-tile--${order.status}`}
        style={{ '--status-color': cfg.color, '--status-bg': cfg.bg, '--status-border': cfg.border, '--status-glow': cfg.glow }}
      >
        <div className="order-tile__header">
          <div className="order-tile__id">
            <span className="order-tile__hash">{order.orderNum}</span>
            <span className={`order-tile__type-badge order-tile__type-badge--${order.type}`}>
              {order.type === 'dine-in' ? '🍽️' : order.type === 'delivery' ? '🚀' : '🛍️'} {order.type}
            </span>
          </div>
          <div className="order-tile__status-badge" style={{ background: cfg.bg, color: cfg.color, borderColor: cfg.border }}>
            <span className="order-tile__status-dot" style={{ background: cfg.color }}></span>
            {cfg.icon} {cfg.label}
          </div>
        </div>

        <div className="order-tile__body">
          <div className="order-tile__info-row">
            <span className="order-tile__label">📋 Items</span>
            <span className="order-tile__value">{order.items}</span>
          </div>
          <div className="order-tile__info-row">
            <span className="order-tile__label">🪑 Table</span>
            <span className="order-tile__value">{order.table ? `T-${order.table}` : 'N/A'}</span>
          </div>
          <div className="order-tile__info-row">
            <span className="order-tile__label">🏷️ Category</span>
            <span className="order-tile__category-tag">{order.category}</span>
          </div>
          {order.rider && (
            <div className="order-tile__info-row">
              <span className="order-tile__label">🏍️ Rider</span>
              <span className="order-tile__value order-tile__rider">{order.rider}</span>
            </div>
          )}
          <div className="order-tile__info-row">
            <span className="order-tile__label">🕐 Time</span>
            <span className="order-tile__value">{order.time}</span>
          </div>
        </div>

        <div className="order-tile__footer">
          <div className="order-tile__total">
            Rs. {order.total.toLocaleString()}
          </div>
          <div className="order-tile__actions">
            <button className="order-tile__btn order-tile__btn--view" onClick={() => handleViewOrder(order.id)} title="View Details">
              <Eye size={15} />
            </button>
            {nextActions.map(nextStatus => {
              const nextCfg = STATUS_CONFIG[nextStatus];
              return (
                <button
                  key={nextStatus}
                  className="order-tile__btn order-tile__btn--action"
                  style={{ '--btn-color': nextCfg.color, '--btn-bg': nextCfg.bg }}
                  onClick={() => handleStatusChange(order.id, nextStatus)}
                  title={`Mark as ${nextCfg.label}`}
                >
                  {nextCfg.icon} {nextCfg.label}
                </button>
              );
            })}
          </div>
        </div>
      </div>
    );
  };

  // ── Render: Rider Book ──
  const renderRiderBook = () => {
    const riderStatusColors = {
      active: { color: '#10b981', bg: '#d1fae5', label: 'Active' },
      'on-delivery': { color: '#3b82f6', bg: '#dbeafe', label: 'On Delivery' },
      offline: { color: '#6b7280', bg: '#f3f4f6', label: 'Offline' },
    };

    return (
      <div className="rider-book">
        <div className="rider-book__header">
          <h3>🏍️ Rider Book</h3>
          <span className="rider-book__count">{riders.length} Riders</span>
        </div>
        <div className="rider-book__grid">
          {riders.map(rider => {
            const rCfg = riderStatusColors[rider.status];
            const assignedOrders = orders.filter(o => o.rider === rider.name && !['completed', 'cancelled', 'paid'].includes(o.status));
            return (
              <div key={rider.id} className={`rider-card rider-card--${rider.status}`}>
                <div className="rider-card__avatar">
                  {rider.name.charAt(0)}
                </div>
                <div className="rider-card__info">
                  <h4>{rider.name}</h4>
                  <p className="rider-card__phone">{rider.phone}</p>
                  <div className="rider-card__meta">
                    <span className="rider-card__status" style={{ background: rCfg.bg, color: rCfg.color }}>
                      {rCfg.label}
                    </span>
                    <span className="rider-card__deliveries">📦 {rider.deliveries} deliveries</span>
                    <span className="rider-card__rating">⭐ {rider.rating}</span>
                  </div>
                  {assignedOrders.length > 0 && (
                    <div className="rider-card__active-orders">
                      <span className="rider-card__active-label">Active Orders:</span>
                      {assignedOrders.map(o => (
                        <span key={o.id} className="rider-card__order-tag" style={{ background: STATUS_CONFIG[o.status]?.bg, color: STATUS_CONFIG[o.status]?.color }}>
                          {o.orderNum}
                        </span>
                      ))}
                    </div>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      </div>
    );
  };

  return (
    <div className="orders-panel">
      {/* Toast Notifications */}
      <div className="toast-container">
        {toasts.map(toast => (
          <div key={toast.id} className={`toast toast--${toast.type}`}>
            <span className="toast__icon">
              {toast.type === 'success' ? '✅' : toast.type === 'warning' ? '⚠️' : toast.type === 'error' ? '❌' : 'ℹ️'}
            </span>
            <span className="toast__message">{toast.message}</span>
            <button className="toast__close" onClick={() => setToasts(prev => prev.filter(t => t.id !== toast.id))}>
              <X size={14} />
            </button>
          </div>
        ))}
      </div>

      {/* ── Header Section ── */}
      <div className="orders-panel__top-bar">
        <div className="orders-panel__title-area">
          <h2>📋 Orders & Sales Dashboard</h2>
          <p className="orders-panel__subtitle">Manage all orders, riders, and sales in one place</p>
        </div>
        <div className="orders-panel__top-actions">
          <button className={`notification-btn ${unreadCount > 0 ? 'notification-btn--active' : ''}`} onClick={() => setShowNotifications(!showNotifications)}>
            <Bell size={20} />
            {unreadCount > 0 && <span className="notification-btn__badge">{unreadCount}</span>}
          </button>
          <button className="refresh-btn" onClick={() => addToast('Orders refreshed', 'info')}>
            <RefreshCw size={18} />
          </button>
        </div>
      </div>

      {/* Notification Dropdown */}
      {showNotifications && (
        <div className="notification-dropdown">
          <div className="notification-dropdown__header">
            <h4>🔔 Notifications</h4>
            <button onClick={markAllRead}>Mark all read</button>
          </div>
          <div className="notification-dropdown__list">
            {notifications.length === 0 ? (
              <p className="notification-dropdown__empty">No notifications</p>
            ) : (
              notifications.map(n => (
                <div key={n.id} className={`notification-item ${!n.read ? 'notification-item--unread' : ''}`}>
                  <div className="notification-item__content">
                    <span className={`notification-item__dot notification-item__dot--${n.type}`}></span>
                    <div>
                      <p>{n.message}</p>
                      <span className="notification-item__time">{n.time}</span>
                    </div>
                  </div>
                  <button className="notification-item__close" onClick={() => removeNotification(n.id)}>
                    <X size={14} />
                  </button>
                </div>
              ))
            )}
          </div>
        </div>
      )}

      {/* ── Main Tabs: Orders | Rider Book ── */}
      <div className="main-tabs">
        <button className={`main-tab ${mainTab === 'orders' ? 'main-tab--active' : ''}`} onClick={() => setMainTab('orders')}>
          <Package size={18} /> Orders
        </button>
        <button className={`main-tab ${mainTab === 'rider-book' ? 'main-tab--active' : ''}`} onClick={() => setMainTab('rider-book')}>
          <Truck size={18} /> Rider Book
        </button>
      </div>

      {mainTab === 'rider-book' ? renderRiderBook() : (
        <>
          {/* Stats Section */}
          <div className="stats-container">
            <div className="stat-card stat-card--orders">
              <div className="stat-card__icon">📦</div>
              <div className="stat-card__content">
                <div className="stat-label">Total Orders</div>
                <div className="stat-value">{stats.totalOrders}</div>
              </div>
            </div>
            <div className="stat-card stat-card--sales">
              <div className="stat-card__icon">💰</div>
              <div className="stat-card__content">
                <div className="stat-label">Total Sales</div>
                <div className="stat-value">Rs. {stats.totalSales.toLocaleString()}</div>
              </div>
            </div>
            <div className="stat-card stat-card--avg">
              <div className="stat-card__icon">📊</div>
              <div className="stat-card__content">
                <div className="stat-label">Average Order</div>
                <div className="stat-value">Rs. {stats.averageOrder.toLocaleString()}</div>
              </div>
            </div>
            <div className="stat-card stat-card--pending">
              <div className="stat-card__icon">⏳</div>
              <div className="stat-card__content">
                <div className="stat-label">Pending</div>
                <div className="stat-value">{stats.statusCounts.pending || 0}</div>
              </div>
            </div>
          </div>

          {/* Sub-Tabs & View Toggle */}
          <div className="toolbar-container">
            <div className="toolbar-panel toolbar-tabs-panel">
              <div className="toolbar-label">Tabs</div>
              <div className="sub-tabs-row">
                {[
                  { key: 'all-orders', label: '📋 All Orders', count: orders.length },
                  { key: 'live', label: '🔴 Live', count: orders.filter(o => ['pending', 'preparing', 'ready'].includes(o.status)).length },
                  { key: 'sales', label: '💰 Sales', count: orders.filter(o => ['paid', 'completed'].includes(o.status)).length },
                ].map(tab => (
                  <button
                    key={tab.key}
                    className={`tab-pill ${ordersTab === tab.key ? 'active' : ''}`}
                    onClick={() => setOrdersTab(tab.key)}
                  >
                    {tab.label}
                    <span className="tab-pill__count">{tab.count}</span>
                  </button>
                ))}
              </div>
            </div>

            <div className="toolbar-panel toolbar-search-panel">
              <label htmlFor="orders-search" className="toolbar-label">Search</label>
              <div className="search-input-wrapper">
                <Search size={16} className="search-input-icon" />
                <input
                  id="orders-search"
                  type="text"
                  className="toolbar-search-input"
                  placeholder={ordersTab === 'live' ? 'Search live orders...' : ordersTab === 'sales' ? 'Search sales...' : 'Search all orders...'}
                  value={activeSearch}
                  onChange={(e) => ordersTab === 'live' ? setLiveSearch(e.target.value) : setSalesSearch(e.target.value)}
                />
              </div>
            </div>

            <div className="toolbar-panel toolbar-view-panel">
              <div className="toolbar-label">View Mode</div>
              <div className="view-toggle">
                <button className={`view-toggle__btn ${viewMode === 'tiles' ? 'view-toggle__btn--active' : ''}`} onClick={() => setViewMode('tiles')} title="Tile View">
                  <LayoutGrid size={18} /> Tiles
                </button>
                <button className={`view-toggle__btn ${viewMode === 'table' ? 'view-toggle__btn--active' : ''}`} onClick={() => setViewMode('table')} title="Table View">
                  <Table2 size={18} /> Table
                </button>
              </div>
            </div>
          </div>

          {/* Date & Filter Row */}
          {ordersTab !== 'all-orders' && (
            <div className="toolbar-container toolbar-container--secondary">
              <div className="toolbar-panel toolbar-date-panel">
                <div className="toolbar-label">📅 Date Range</div>
                <div className="date-pill-group">
                  {['today', 'yesterday', 'last5', 'custom'].map((key) => {
                    const label = key === 'today' ? 'Today' : key === 'yesterday' ? 'Yesterday' : key === 'last5' ? 'Last 5 Days' : 'Custom';
                    return (
                      <button
                        key={key}
                        className={`date-pill ${activeDateFilter === key ? 'active' : ''}`}
                        onClick={() => {
                          if (ordersTab === 'live') {
                            setLiveDateFilter(key);
                          } else {
                            setSalesDateFilter(key);
                          }
                        }}
                      >
                        {label}
                      </button>
                    );
                  })}
                </div>

                {activeDateFilter === 'custom' && (
                  <div className="custom-date-inputs">
                    <div className="custom-date-group">
                      <label htmlFor="custom-from">From</label>
                      <input
                        id="custom-from"
                        type="date"
                        value={activeCustomFrom}
                        onChange={(e) => ordersTab === 'live' ? setLiveCustomFrom(e.target.value) : setSalesCustomFrom(e.target.value)}
                      />
                    </div>
                    <div className="custom-date-group">
                      <label htmlFor="custom-to">To</label>
                      <input
                        id="custom-to"
                        type="date"
                        value={activeCustomTo}
                        onChange={(e) => ordersTab === 'live' ? setLiveCustomTo(e.target.value) : setSalesCustomTo(e.target.value)}
                      />
                    </div>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* Status Filter Pills */}
          <div className="status-filter-bar">
            <div className="status-filter-bar__label">
              <Filter size={15} /> Filter by Status:
            </div>
            <div className="status-filter-bar__pills">
              <button
                className={`status-pill ${statusFilter === 'all' ? 'status-pill--active' : ''}`}
                onClick={() => setStatusFilter('all')}
              >
                All
                <span className="status-pill__count">{orders.length}</span>
              </button>
              {Object.entries(STATUS_CONFIG).map(([key, cfg]) => {
                const count = orders.filter(o => o.status === key).length;
                if (count === 0) return null;
                return (
                  <button
                    key={key}
                    className={`status-pill ${statusFilter === key ? 'status-pill--active' : ''}`}
                    style={{ '--pill-color': cfg.color, '--pill-bg': cfg.bg, '--pill-border': cfg.border }}
                    onClick={() => setStatusFilter(key)}
                  >
                    {cfg.icon} {cfg.label}
                    <span className="status-pill__count">{count}</span>
                  </button>
                );
              })}
            </div>

            <div className="status-filter-bar__type-pills">
              {['all', 'dine-in', 'delivery', 'takeaway'].map(type => (
                <button
                  key={type}
                  className={`type-pill ${typeFilter === type ? 'type-pill--active' : ''}`}
                  onClick={() => setTypeFilter(type)}
                >
                  {type === 'all' ? '🔄 All' : type === 'dine-in' ? '🍽️ Dine-in' : type === 'delivery' ? '🚀 Delivery' : '🛍️ Takeaway'}
                </button>
              ))}
            </div>
          </div>

          {/* Filters + Actions Bar */}
          <div className="filters-container">
            <div className="filter-group">
              <label htmlFor="category-filter">🍛 Category:</label>
              <select
                id="category-filter"
                className="filter-select"
                value={categoryFilter}
                onChange={(e) => setCategoryFilter(e.target.value)}
              >
                <option value="">All Categories</option>
                {categories.map(cat => (
                  <option key={cat} value={cat}>{cat}</option>
                ))}
              </select>
            </div>

            <div className="filters-container__actions">
              <button className="action-pill action-pill--danger" onClick={handleClearFilters}>
                <XCircle size={15} /> Clear Filters
              </button>
              <button className="action-pill action-pill--success" onClick={handleExportCSV}>
                <Download size={15} /> Export CSV
              </button>
            </div>
          </div>

          {/* Menu + Cart Section */}
          <div className="menu-cart-layout">
            <section className="product-section">
              <div className="section-header">
                <div>
                  <h3>🍽️ مینو</h3>
                  <p>کٹیگریز کے ذریعے فاسٹ آئٹم تلاش کریں</p>
                </div>
                <div className="category-count">{menuCategories.length} Categories</div>
              </div>

              <div className="menu-categories">
                {menuCategories.map(category => (
                  <button
                    key={category.id}
                    className={`menu-category-btn ${activeMenuCategory === category.id ? 'active' : ''}`}
                    onClick={() => setActiveMenuCategory(category.id)}
                  >
                    <span className="menu-category-btn__icon">{category.icon}</span>
                    {category.title}
                  </button>
                ))}
              </div>

              <div className="menu-grid">
                {activeMenu.items.map(item => (
                  <div
                    key={item.id}
                    className="menu-card"
                    role="button"
                    tabIndex={0}
                    onClick={() => handleAddToCart(item)}
                    onKeyDown={(e) => {
                      if (e.key === 'Enter' || e.key === ' ') {
                        e.preventDefault();
                        handleAddToCart(item);
                      }
                    }}
                  >
                    <div className="menu-card-header">
                      <h4>{item.name}</h4>
                      <span className="menu-price">
                        {item.options ? `${item.options[0].price} / ${item.options[1]?.price || ''}` : item.price} Rs
                      </span>
                    </div>

                    <p className="menu-price-note">{item.options ? 'ہاف / فل دستیاب' : 'قیمت فی پیس'}</p>

                    {item.options && (
                      <select
                        className="option-select"
                        value={selectedOptions[item.id] || item.options[0].label}
                        onChange={(e) => handleSelectOption(item.id, e.target.value)}
                        onClick={(e) => e.stopPropagation()}
                        onKeyDown={(e) => e.stopPropagation()}
                      >
                        {item.options.map(option => (
                          <option key={option.label} value={option.label}>
                            {option.label} - Rs. {option.price}
                          </option>
                        ))}
                      </select>
                    )}

                    <div className="menu-card-action-note">
                      <Plus size={14} /> Add to Cart
                    </div>
                  </div>
                ))}
              </div>
            </section>

            <aside className="cart-section">
              <div className="section-header cart-header">
                <div>
                  <h3><ShoppingCart size={20} /> کارٹ</h3>
                  <p>منتخب آئٹمز یہاں دکھیں</p>
                </div>
                <span className="cart-badge">{cartItems.length} آئٹمز</span>
              </div>

              {cartItems.length === 0 ? (
                <div className="cart-empty">
                  <div className="cart-empty__icon">🛒</div>
                  <p>کوئی آئٹم ابھی کارٹ میں نہیں ہے</p>
                </div>
              ) : (
                <div className="cart-list">
                  {cartItems.map((item, index) => (
                    <div key={`${item.id}-${item.option}-${index}`} className="cart-item">
                      {editingCartIndex === index ? (
                        <div className="cart-item-editing">
                          <div className="editing-fields">
                            <input
                              type="text"
                              className="edit-name-input"
                              value={editingData.name}
                              onChange={(e) => setEditingData(prev => ({ ...prev, name: e.target.value }))}
                              placeholder="Product name"
                            />
                            <input
                              type="number"
                              className="edit-price-input"
                              value={editingData.price}
                              onChange={(e) => setEditingData(prev => ({ ...prev, price: parseFloat(e.target.value) || 0 }))}
                              placeholder="Price"
                              step="0.01"
                            />
                          </div>
                          <div className="editing-buttons">
                            <button className="save-edit-btn" onClick={handleSaveEdit}><Save size={14} /></button>
                            <button className="cancel-edit-btn" onClick={handleCancelEdit}><XCircle size={14} /></button>
                          </div>
                        </div>
                      ) : (
                        <>
                          <div>
                            <div className="cart-item-name">{item.label}</div>
                            <div className="cart-item-price">Rs. {item.price.toLocaleString()}</div>
                          </div>
                          <div className="cart-item-controls">
                            <button onClick={() => handleQuantityChange(index, -1)}><Minus size={14} /></button>
                            <span>{item.quantity}</span>
                            <button onClick={() => handleQuantityChange(index, 1)}><Plus size={14} /></button>
                          </div>
                          <div className="cart-item-actions">
                            <button className="edit-item-btn" onClick={() => handleEditCartItem(index)} title="Edit">
                              <Edit3 size={13} /> Edit
                            </button>
                            <button className="remove-item-btn" onClick={() => handleRemoveCartItem(index)}>
                              <Trash2 size={14} />
                            </button>
                          </div>
                        </>
                      )}
                    </div>
                  ))}
                </div>
              )}

              <div className="cart-summary">
                <div>
                  <span>کل</span>
                  <strong>Rs. {cartTotal.toLocaleString()}</strong>
                </div>
                <button className="clear-cart-btn" onClick={handleClearCart}>
                  <Trash2 size={15} /> کارٹ خالی کریں
                </button>
              </div>
            </aside>
          </div>

          {/* ── Orders Display: Tiles or Table ── */}
          <div className="orders-display-section">
            <div className="orders-display-section__header">
              <h3>
                {viewMode === 'tiles' ? <LayoutGrid size={20} /> : <Table2 size={20} />}
                {' '}{ordersTab === 'all-orders' ? 'All Orders' : ordersTab === 'live' ? 'Live Orders' : 'Sales Orders'}
                <span className="orders-display-section__count">{filteredOrders.length}</span>
              </h3>
            </div>

            {viewMode === 'tiles' ? (
              <div className="orders-tiles-grid">
                {filteredOrders.length > 0 ? (
                  filteredOrders.map(order => renderOrderTile(order))
                ) : (
                  <div className="no-data-card">
                    <div className="no-data-card__icon">📭</div>
                    <p>No orders found for the selected filters.</p>
                  </div>
                )}
              </div>
            ) : (
              <div className="table-wrapper">
                <table className="orders-table">
                  <thead>
                    <tr>
                      <th>Order #</th>
                      <th>Table</th>
                      <th>Items</th>
                      <th>Category</th>
                      <th>Type</th>
                      <th>Total</th>
                      <th>Status</th>
                      <th>Rider</th>
                      <th>Date</th>
                      <th>Time</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredOrders.length > 0 ? (
                      filteredOrders.map(order => {
                        const cfg = STATUS_CONFIG[order.status] || STATUS_CONFIG.pending;
                        const nextActions = getStatusNextActions(order.status);
                        return (
                          <tr key={order.id} className={`status-${order.status}`}>
                            <td className="order-number">{order.orderNum}</td>
                            <td><span className="table-num">{order.table ? `T-${order.table}` : '—'}</span></td>
                            <td className="items">{order.items}</td>
                            <td><span className="category">{order.category}</span></td>
                            <td>
                              <span className={`type-badge type-badge--${order.type}`}>
                                {order.type === 'dine-in' ? '🍽️' : order.type === 'delivery' ? '🚀' : '🛍️'} {order.type}
                              </span>
                            </td>
                            <td className="total">Rs. {order.total.toLocaleString()}</td>
                            <td>
                              <span className="status-badge-enhanced" style={{ background: cfg.bg, color: cfg.color, borderColor: cfg.border }}>
                                <span className="status-badge-dot" style={{ background: cfg.color }}></span>
                                {cfg.icon} {cfg.label}
                              </span>
                            </td>
                            <td>{order.rider || '—'}</td>
                            <td className="date">{order.date}</td>
                            <td className="time">{order.time}</td>
                            <td className="actions">
                              <button
                                className="action-icon view-btn"
                                onClick={() => handleViewOrder(order.id)}
                                title="View Details"
                              >
                                <Eye size={16} />
                              </button>
                              {nextActions.slice(0, 2).map(nextStatus => {
                                const nCfg = STATUS_CONFIG[nextStatus];
                                return (
                                  <button
                                    key={nextStatus}
                                    className="action-icon status-action-btn"
                                    style={{ background: nCfg.bg, color: nCfg.color }}
                                    onClick={() => handleStatusChange(order.id, nextStatus)}
                                    title={`Mark as ${nCfg.label}`}
                                  >
                                    {nCfg.icon}
                                  </button>
                                );
                              })}
                            </td>
                          </tr>
                        );
                      })
                    ) : (
                      <tr>
                        <td colSpan="11" className="no-data">
                          No orders found for the selected filters.
                        </td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </>
      )}

      {/* Order Detail Modal */}
      {selectedOrder && (
        <div className="order-modal-overlay" onClick={() => setSelectedOrder(null)}>
          <div className="order-modal" onClick={(e) => e.stopPropagation()}>
            <div className="order-modal__header">
              <h3>{selectedOrder.orderNum} Details</h3>
              <button className="order-modal__close" onClick={() => setSelectedOrder(null)}>
                <X size={20} />
              </button>
            </div>
            <div className="order-modal__body">
              <div className="order-modal__row">
                <span className="order-modal__label">Order #</span>
                <span className="order-modal__value">{selectedOrder.orderNum}</span>
              </div>
              <div className="order-modal__row">
                <span className="order-modal__label">Table</span>
                <span className="order-modal__value">{selectedOrder.table ? `T-${selectedOrder.table}` : 'N/A'}</span>
              </div>
              <div className="order-modal__row">
                <span className="order-modal__label">Items</span>
                <span className="order-modal__value">{selectedOrder.items}</span>
              </div>
              <div className="order-modal__row">
                <span className="order-modal__label">Category</span>
                <span className="order-modal__value">{selectedOrder.category}</span>
              </div>
              <div className="order-modal__row">
                <span className="order-modal__label">Type</span>
                <span className="order-modal__value">{selectedOrder.type}</span>
              </div>
              <div className="order-modal__row">
                <span className="order-modal__label">Total</span>
                <span className="order-modal__value order-modal__total">Rs. {selectedOrder.total.toLocaleString()}</span>
              </div>
              <div className="order-modal__row">
                <span className="order-modal__label">Status</span>
                <span className="status-badge-enhanced" style={{
                  background: STATUS_CONFIG[selectedOrder.status]?.bg,
                  color: STATUS_CONFIG[selectedOrder.status]?.color,
                  borderColor: STATUS_CONFIG[selectedOrder.status]?.border,
                }}>
                  {STATUS_CONFIG[selectedOrder.status]?.icon} {STATUS_CONFIG[selectedOrder.status]?.label}
                </span>
              </div>
              {selectedOrder.rider && (
                <div className="order-modal__row">
                  <span className="order-modal__label">Rider</span>
                  <span className="order-modal__value">{selectedOrder.rider}</span>
                </div>
              )}
              <div className="order-modal__row">
                <span className="order-modal__label">Date</span>
                <span className="order-modal__value">{selectedOrder.date}</span>
              </div>
              <div className="order-modal__row">
                <span className="order-modal__label">Time</span>
                <span className="order-modal__value">{selectedOrder.time}</span>
              </div>
            </div>
            <div className="order-modal__footer">
              {getStatusNextActions(selectedOrder.status).map(nextStatus => {
                const nCfg = STATUS_CONFIG[nextStatus];
                return (
                  <button
                    key={nextStatus}
                    className="order-modal__action-btn"
                    style={{ background: nCfg.color, color: '#fff' }}
                    onClick={() => {
                      handleStatusChange(selectedOrder.id, nextStatus);
                      setSelectedOrder(prev => ({ ...prev, status: nextStatus }));
                    }}
                  >
                    {nCfg.icon} Mark as {nCfg.label}
                  </button>
                );
              })}
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default OrdersPanel;
