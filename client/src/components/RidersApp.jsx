import { useState, useEffect } from 'react';
import {
  ChevronDown,
  LogOut,
  Package,
  Clock,
  CheckCircle,
  XCircle,
  Eye,
  EyeOff,
  Trash2,
  ShoppingBag,
  CreditCard,
  DollarSign,
  Zap,
  ArrowUpRight,
  ArrowDownRight,
  Check,
  Bell,
  User,
  Sparkles,
  Truck,
  HelpingHand
} from 'lucide-react';

const apiBase = '/api';

export function RidersApp() {
  const [view, setView] = useState('login'); // login, app
  const [riderTab, setRiderTab] = useState('assigned'); // assigned, kitchen, requested, deliveredCash, deliveredOnline
  const [loading, setLoading] = useState(false);
  const [loginForm, setLoginForm] = useState({ email: '', password: '' });
  const [showPassword, setShowPassword] = useState(false);
  const [loginError, setLoginError] = useState('');
  const [riderToken, setRiderToken] = useState(localStorage.getItem('riderToken') || '');
  const [rider, setRider] = useState(null);
  const [assignedOrders, setAssignedOrders] = useState([]);
  const [kitchenOrders, setKitchenOrders] = useState([]);
  const [requestedOrders, setRequestedOrders] = useState([]);
  const [deliveredCashOrders, setDeliveredCashOrders] = useState([]);
  const [deliveredOnlineOrders, setDeliveredOnlineOrders] = useState([]);
  const [requestingIds, setRequestingIds] = useState([]);
  const [selectedOrder, setSelectedOrder] = useState(null);
  const [hotelSettings, setHotelSettings] = useState(null);
  const [deleteError, setDeleteError] = useState('');
  const [notification, setNotification] = useState(null);
  const [showNotification, setShowNotification] = useState(false);

  const tabItems = [
    {
      key: 'assigned',
      label: 'Assigned',
      subtitle: 'Start delivery',
      icon: Package,
      accent: 'from-orange-500 to-rose-500'
    },
    {
      key: 'kitchen',
      label: 'Available',
      subtitle: 'Request approval',
      icon: ShoppingBag,
      accent: 'from-sky-500 to-cyan-500'
    },
    {
      key: 'requested',
      label: 'Requests',
      subtitle: 'Approval queue',
      icon: XCircle,
      accent: 'from-violet-500 to-fuchsia-500'
    },
    {
      key: 'deliveredCash',
      label: 'Rider Book Cash',
      subtitle: 'Cash payments',
      icon: DollarSign,
      accent: 'from-emerald-500 to-green-500'
    },
    {
      key: 'deliveredOnline',
      label: 'Rider Book Online',
      subtitle: 'Online payments',
      icon: CreditCard,
      accent: 'from-blue-500 to-indigo-500'
    }
  ];

  useEffect(() => {
    if (riderToken) {
      setView('app');
      fetchRiderInfo();
    }
  }, [riderToken]);

  useEffect(() => {
    fetchHotelSettings();
  }, []);

  const playNotificationSound = () => {
    try {
      const AudioContext = window.AudioContext || window.webkitAudioContext;
      const ctx = new AudioContext();
      const oscillator = ctx.createOscillator();
      const gain = ctx.createGain();
      oscillator.type = 'triangle';
      oscillator.frequency.setValueAtTime(880, ctx.currentTime);
      gain.gain.setValueAtTime(0.02, ctx.currentTime);
      oscillator.connect(gain);
      gain.connect(ctx.destination);
      oscillator.start();
      oscillator.frequency.exponentialRampToValueAtTime(1320, ctx.currentTime + 0.16);
      gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.34);
      oscillator.stop(ctx.currentTime + 0.35);
    } catch (err) {
      console.warn('Notification sound unavailable', err);
    }
  };

  const notify = (message, type = 'info') => {
    setNotification({ message, type, id: Date.now() });
    setShowNotification(true);
    playNotificationSound();
    window.setTimeout(() => setShowNotification(false), 3200);
  };

  const fetchRiderInfo = async () => {
    try {
      const res = await fetch(`${apiBase}/auth/rider-me`, {
        headers: { Authorization: `Bearer ${riderToken}` }
      });
      if (res.ok) {
        const data = await res.json();
        setRider(data);
      } else {
        handleLogout();
      }
    } catch (error) {
      console.error('Failed to fetch rider info:', error);
    }
  };

  const fetchHotelSettings = async () => {
    try {
      const res = await fetch(`${apiBase}/settings`);
      if (res.ok) {
        const data = await res.json();
        setHotelSettings(data);
      }
    } catch (error) {
      console.error('Failed to fetch hotel settings:', error);
    }
  };

  const deduplicateOrders = (orders) => {
    const seen = new Set();
    return orders.filter(order => {
      const id = order.originalOrder?.id || order.id;
      if (seen.has(id)) return false;
      seen.add(id);
      return true;
    });
  };

  useEffect(() => {
    if (view === 'app') {
      fetchHotelSettings();
      loadOrders();
    }
  }, [view, riderTab]);

  const loadOrders = async () => {
    if (!rider?.id) return;

    try {
      setLoading(true);
      
      if (riderTab === 'assigned') {
        const res = await fetch(`${apiBase}/rider/assigned-orders/${rider.id}`, {
          headers: { Authorization: `Bearer ${riderToken}` }
        });
        if (res.ok) {
          const data = await res.json();
          setAssignedOrders(deduplicateOrders(data));
        }
      } else if (riderTab === 'kitchen') {
        const res = await fetch(`${apiBase}/rider/kitchen-orders`, {
          headers: { Authorization: `Bearer ${riderToken}` }
        });
        if (res.ok) {
          const data = await res.json();
          setKitchenOrders(deduplicateOrders(data));
        }
      } else if (riderTab === 'requested') {
        const res = await fetch(`${apiBase}/rider/requested-orders/${rider.id}`, {
          headers: { Authorization: `Bearer ${riderToken}` }
        });
        if (res.ok) {
          const data = await res.json();
          setRequestedOrders(deduplicateOrders(data));
        }
      } else if (riderTab === 'deliveredCash') {
        const res = await fetch(`${apiBase}/rider/delivered-orders/${rider.id}/cash`, {
          headers: { Authorization: `Bearer ${riderToken}` }
        });
        if (res.ok) {
          const data = await res.json();
          setDeliveredCashOrders(deduplicateOrders(data));
        }
      } else if (riderTab === 'deliveredOnline') {
        const res = await fetch(`${apiBase}/rider/delivered-orders/${rider.id}/online`, {
          headers: { Authorization: `Bearer ${riderToken}` }
        });
        if (res.ok) {
          const data = await res.json();
          setDeliveredOnlineOrders(deduplicateOrders(data));
        }
      }
    } catch (error) {
      console.error('Error loading orders:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleRiderLogin = async (e) => {
    e.preventDefault();
    setLoading(true);
    setLoginError('');

    try {
      const res = await fetch(`${apiBase}/auth/rider-login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(loginForm)
      });

      if (res.ok) {
        const data = await res.json();
        setRiderToken(data.token);
        localStorage.setItem('riderToken', data.token);
        setRider(data.rider);
        setView('app');
        setLoginForm({ email: '', password: '' });
        notify(`Welcome back, ${data.rider?.name || 'Rider'}!`, 'success');
      } else {
        const error = await res.json();
        const message = error.error || 'Login failed';
        setLoginError(message);
        notify(message, 'error');
      }
    } catch (error) {
      setLoginError('Connection error: ' + error.message);
    } finally {
      setLoading(false);
    }
  };

  const handleLogout = () => {
    setRiderToken('');
    localStorage.removeItem('riderToken');
    setRider(null);
    setView('login');
    setLoginForm({ email: '', password: '' });
  };

  const requestApproval = async (orderId) => {
    try {
      // mark this order id as requesting to disable its button
      setRequestingIds((ids) => [...ids, orderId]);
      setLoading(true);
      const res = await fetch(`${apiBase}/rider/request-approval`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${riderToken}`
        },
        body: JSON.stringify({ riderId: rider.id, orderId: orderId })
      });

      if (res.ok) {
        setRequestingIds((ids) => ids.filter((id) => id !== orderId));
        setKitchenOrders(kitchenOrders.filter((o) => o.id !== orderId));
        const order = kitchenOrders.find((o) => o.id === orderId);
        if (order) {
          setRequestedOrders((prev) => [...prev, { ...order, status: 'pending', orderId }]);
        }
        notify('Approval request sent to hotel manager.', 'success');
      } else {
        setRequestingIds((ids) => ids.filter((id) => id !== orderId));
        notify('Unable to request approval right now.', 'error');
      }
    } catch (error) {
      console.error('Error requesting approval:', error);
      setRequestingIds((ids) => ids.filter((id) => id !== orderId));
    } finally {
      setLoading(false);
    }
  };

  const markDelivered = async (order, paymentMethod, paymentStatus) => {
    const targetOrderId = order.originalOrder?.id || order.id;
    const existing = order.originalOrder || order;

    try {
      setLoading(true);
      const res = await fetch(`${apiBase}/pos/orders/${targetOrderId}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${riderToken}`
        },
        body: JSON.stringify({
          ...existing,
          status: 'Payment Collected',
          paymentMethod,
          paymentStatus,
          deliveryAgent: rider?.name
        })
      });

      if (res.ok) {
        setAssignedOrders((prev) => prev.filter((o) => (o.originalOrder?.id || o.id) !== targetOrderId));
        if (selectedOrder && (selectedOrder.originalOrder?.id || selectedOrder.id) === targetOrderId) {
          setSelectedOrder(null);
        }
        notify(`Delivered ${paymentMethod === 'Cash' ? 'with cash' : 'online payment'} successfully`, 'success');
        await loadOrders();
      } else {
        notify('Unable to update delivered status. Try again.', 'error');
      }
    } catch (error) {
      console.error('Error marking delivered:', error);
      notify('Unable to update delivered status. Try again.', 'error');
    } finally {
      setLoading(false);
    }
  };


  const handleDeleteOrder = async (order) => {
    const targetOrderId = order.originalOrder?.id || order.orderId || order.id;
    try {
      setDeleteError('');
      setLoading(true);
      console.log('Deleting order:', targetOrderId, 'Rider role:', rider?.role);
      const res = await fetch(`${apiBase}/pos/orders/${targetOrderId}`, {
        method: 'DELETE',
        headers: {
          Authorization: `Bearer ${riderToken}`
        }
      });

      if (res.ok) {
        setAssignedOrders(assignedOrders.filter((o) => (o.originalOrder?.id || o.id) !== targetOrderId));
        setKitchenOrders(kitchenOrders.filter((o) => (o.originalOrder?.id || o.id) !== targetOrderId));
        setRequestedOrders(requestedOrders.filter((o) => (o.orderId || o.originalOrder?.id || o.id) !== targetOrderId));
        if (selectedOrder && ((selectedOrder.originalOrder?.id || selectedOrder.orderId || selectedOrder.id) === targetOrderId)) {
          setSelectedOrder(null);
        }
        setDeleteError('Order deleted successfully');
        notify('Order deleted from rider list.', 'success');
        setTimeout(() => setDeleteError(''), 3000);
      } else {
        const errorData = await res.json().catch(() => ({}));
        const errorMsg = errorData.error || `Delete failed with status ${res.status}`;
        console.error('Delete failed:', errorMsg);
        setDeleteError(errorMsg);
        notify(errorMsg, 'error');
      }
    } catch (error) {
      console.error('Error deleting order:', error);
      setDeleteError('Error: ' + error.message);
    } finally {
      setLoading(false);
    }
  };

  const handlePrintOrder = (order) => {
    setSelectedOrder(order);
    window.setTimeout(() => {
      window.print();
      notify('Print preview opened. Use browser print dialog.', 'info');
    }, 250);
  };

  const riderRole = (rider?.role || '').toString().toLowerCase();
  const isAdminRider = riderRole === 'admin' || riderRole === 'admin rider' || riderRole.includes('admin');
  const pendingRequestOrderIds = requestedOrders.filter((request) => request.status === 'pending').map((request) => request.orderId);

  useEffect(() => {
    if (requestingIds.length === 0) return;
    setRequestingIds((ids) => ids.filter((id) => pendingRequestOrderIds.includes(id)));
  }, [pendingRequestOrderIds]);

  const viewOrderSlip = (order) => {
    setSelectedOrder(order);
  };

  if (view === 'login') {
    return (
      <div className="min-h-screen bg-[radial-gradient(circle_at_top_left,_rgba(249,115,22,0.24),_transparent_35%),radial-gradient(circle_at_bottom_right,_rgba(236,72,153,0.18),_transparent_28%),#0f172a] flex items-center justify-center p-4">
        <div className="bg-slate-950/95 border border-slate-800 shadow-2xl shadow-orange-500/10 rounded-3xl p-8 max-w-md w-full backdrop-blur-xl">
          <div className="flex items-center justify-between gap-4 mb-8">
            <div className="flex items-center gap-3">
              <div className="h-16 w-16 rounded-3xl bg-gradient-to-br from-orange-500 to-rose-500 flex items-center justify-center shadow-lg shadow-orange-500/20 overflow-hidden">
                {(hotelSettings?.riderAppLogo || hotelSettings?.logo) ? (
                  <img src={hotelSettings?.riderAppLogo || hotelSettings?.logo} alt="Rider App Logo" className="h-full w-full object-cover" />
                ) : (
                  <Sparkles size={32} className="text-white" />
                )}
              </div>
              <div>
                <p className="text-sm uppercase tracking-[0.24em] text-orange-300">{hotelSettings?.hotelName || 'Usman Hotel'}</p>
                <h1 className="text-2xl font-extrabold text-white">{hotelSettings?.riderAppTitle || 'Rider Portal'}</h1>
              </div>
            </div>
            <div className="rounded-3xl border border-white/10 bg-slate-900/80 px-4 py-3 flex items-center gap-3 shadow-lg shadow-slate-950/20">
              <User size={24} className="text-cyan-300" />
              <div>
                <p className="text-xs text-slate-400">Welcome rider</p>
                <p className="font-semibold text-white">{hotelSettings?.riderAppLoginNote || 'Login to continue'}</p>
              </div>
            </div>
          </div>

          <form onSubmit={handleRiderLogin} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-slate-300 mb-2">Email or username</label>
              <input
                type="text"
                value={loginForm.email}
                onChange={(e) => setLoginForm({ ...loginForm, email: e.target.value })}
                className="w-full bg-slate-900 border border-slate-700 text-white placeholder:text-slate-500 rounded-2xl px-4 py-3 focus:outline-none focus:ring-2 focus:ring-orange-500"
                placeholder="rider@example.com or username"
              />
            </div>

            <div className="relative">
              <label className="block text-sm font-medium text-slate-300 mb-2">Email or username</label>
              <input
                type={showPassword ? 'text' : 'password'}
                value={loginForm.password}
                onChange={(e) => setLoginForm({ ...loginForm, password: e.target.value })}
                className="w-full bg-slate-900 border border-slate-700 text-white placeholder:text-slate-500 rounded-2xl px-4 py-3 pr-12 focus:outline-none focus:ring-2 focus:ring-orange-500"
                placeholder="••••••••"
              />
              <button
                type="button"
                onClick={() => setShowPassword((current) => !current)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-300 hover:text-white"
                aria-label={showPassword ? 'Hide password' : 'Show password'}
              >
                {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
              </button>
            </div>

            {loginError && <div className="bg-red-950/70 border border-red-600 text-red-300 px-4 py-3 rounded-2xl">{loginError}</div>}

            <button
              type="submit"
              disabled={loading}
              className="w-full flex items-center justify-center gap-2 bg-gradient-to-r from-orange-500 to-pink-500 hover:from-orange-400 hover:to-pink-400 text-white font-semibold py-3 rounded-2xl transition duration-300 disabled:opacity-50"
            >
              {loading ? 'Signing in...' : 'Login'}
              <ArrowUpRight size={18} />
            </button>
          </form>

          <div className="mt-6 text-center text-slate-400 text-xs">
            Demo credentials: ahmed@rider.com / riderpass1 (set by admin)
          </div>
        </div>
      </div>
    );
  }
  
  return (
    <div>
      {/* Header */}
      <div className="bg-slate-950/95 border-b border-slate-800 shadow-2xl shadow-slate-950/10">
        <div className="max-w-7xl mx-auto px-4 py-5">
          <div className="flex flex-col gap-6 xl:flex-row xl:items-center xl:justify-between">
            <div className="flex items-center gap-4">
              <div className="relative h-20 w-20 rounded-[32px] bg-gradient-to-br from-orange-500 to-pink-500 shadow-lg shadow-orange-500/20 flex items-center justify-center">
                {hotelSettings?.logo ? (
                  <img src={hotelSettings.logo} alt="Hotel logo" className="h-14 w-14 rounded-2xl object-cover border border-white/10 shadow-inner" />
                ) : (
                  <div className="h-14 w-14 rounded-2xl bg-white/10 flex items-center justify-center text-white text-xl font-bold">U</div>
                )}
                <div className="absolute -bottom-2 right-0 rounded-full bg-slate-900 border border-white/10 p-2 shadow-xl shadow-slate-900/30">
                  <Sparkles size={20} className="text-white" />
                </div>
              </div>

              <div>
                <p className="text-sm uppercase tracking-[0.24em] text-orange-300">Usman Hotel Rider</p>
                <h1 className="text-3xl font-extrabold text-white tracking-tight">{hotelSettings?.hotelName || 'Usman Hotel'}</h1>
                <p className="mt-1 text-slate-400">{hotelSettings?.riderAppSubtitle || 'Ready for delivery, secure and fast.'}</p>
              </div>
            </div>

            <div className="grid grid-cols-1 gap-3 sm:grid-cols-3 xl:w-2/5">
              <div className="rounded-3xl border border-slate-800 bg-slate-900/80 p-4 shadow-lg shadow-slate-950/20">
                <p className="text-xs uppercase tracking-[0.24em] text-slate-500">Assigned</p>
                <div className="mt-3 flex items-center gap-3">
                  <Package size={24} className="text-orange-400" />
                  <div>
                    <p className="text-2xl font-semibold text-white">{assignedOrders.length}</p>
                    <p className="text-sm text-slate-500">Ready to deliver</p>
                  </div>
                </div>
              </div>
              <div className="rounded-3xl border border-slate-800 bg-slate-900/80 p-4 shadow-lg shadow-slate-950/20">
                <p className="text-xs uppercase tracking-[0.24em] text-slate-500">Requests</p>
                <div className="mt-3 flex items-center gap-3">
                  <HelpingHand size={24} className="text-violet-400" />
                  <div>
                    <p className="text-2xl font-semibold text-white">{requestedOrders.length}</p>
                    <p className="text-sm text-slate-500">Approval queue</p>
                  </div>
                </div>
              </div>
              <div className="rounded-3xl border border-slate-800 bg-slate-900/80 p-4 shadow-lg shadow-slate-950/20">
                <p className="text-xs uppercase tracking-[0.24em] text-slate-500">Delivered</p>
                <div className="mt-3 flex items-center gap-3">
                  <CheckCircle size={24} className="text-emerald-400" />
                  <div>
                    <p className="text-2xl font-semibold text-white">{deliveredCashOrders.length + deliveredOnlineOrders.length}</p>
                    <p className="text-sm text-slate-500">Total completed</p>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div className="mt-6 rounded-[32px] border border-slate-800 bg-slate-900/90 p-4 shadow-xl shadow-slate-950/20 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
            <div className="flex items-center gap-4">
              <div className="relative h-16 w-16 rounded-[28px] bg-gradient-to-br from-cyan-500 to-sky-500 flex items-center justify-center shadow-lg shadow-cyan-500/25 overflow-hidden">
                {(hotelSettings?.riderAppAvatar || hotelSettings?.logo) ? (
                  <img src={hotelSettings?.riderAppAvatar || hotelSettings?.logo} alt="Rider avatar" className="h-full w-full object-cover" />
                ) : (
                  <User size={28} className="text-white" />
                )}
              </div>
              <div>
                <p className="text-sm text-slate-400">Logged in as</p>
                <p className="text-xl font-semibold text-white">{rider?.name || 'Rider'}</p>
                <p className="text-sm text-slate-500">{rider?.phone || 'No phone available'}</p>
              </div>
            </div>
            <button
              onClick={handleLogout}
              className="inline-flex items-center gap-2 rounded-3xl bg-red-600/95 px-4 py-3 text-white font-semibold shadow-xl shadow-red-500/20 transition hover:bg-red-500"
            >
              <LogOut size={18} />
              Logout
            </button>
          </div>
        </div>
      </div>

      {showNotification && notification && (
        <div className="fixed right-5 top-28 z-50 w-80 rounded-3xl border border-slate-700 bg-slate-950/95 p-4 shadow-2xl shadow-slate-950/40">
          <div className="flex items-center gap-3">
            <div className={`flex h-11 w-11 items-center justify-center rounded-2xl ${notification.type === 'success' ? 'bg-emerald-500/15 text-emerald-300' : notification.type === 'error' ? 'bg-rose-500/15 text-rose-300' : 'bg-sky-500/15 text-sky-300'}`}>
              <Bell size={20} />
            </div>
            <div>
              <p className="text-sm text-slate-300">{notification.type === 'success' ? 'Great!' : notification.type === 'error' ? 'Oops!' : 'Notice'}</p>
              <p className="font-semibold text-white">{notification.message}</p>
            </div>
          </div>
        </div>
      )}

      {/* Error/Success Notification */}
      {deleteError && (
        <div className={`max-w-7xl mx-auto px-4 py-2 mt-2 rounded ${
          deleteError.includes('successfully') || deleteError.includes('Success')
            ? 'bg-emerald-50 border border-emerald-200 text-emerald-800'
            : 'bg-rose-50 border border-rose-200 text-rose-800'
        }`}>
          {deleteError}
        </div>
      )}

      {/* Tabs */}
      <div className="bg-slate-950/95 border-b border-slate-800 sticky top-0 z-20 backdrop-blur-xl">
        <div className="max-w-7xl mx-auto px-4 py-3 flex gap-3 overflow-x-auto">
          {tabItems.map((tab) => {
            const Icon = tab.icon;
            return (
              <button
                key={tab.key}
                onClick={() => setRiderTab(tab.key)}
                className={`min-w-[170px] flex-1 rounded-full border px-4 py-3 text-left transition duration-300 ${
                  riderTab === tab.key
                    ? 'bg-gradient-to-r from-orange-500 to-pink-500 text-white shadow-xl shadow-orange-500/20'
                    : 'bg-slate-900/80 text-slate-300 border-slate-800 hover:bg-slate-900'
                }`}
              >
                <div className="flex items-center gap-3">
                  <span className={`inline-flex h-11 w-11 items-center justify-center rounded-2xl bg-white/10 text-white ${riderTab === tab.key ? 'shadow-lg shadow-white/10' : 'shadow-sm shadow-slate-950/20'}`}>
                    <Icon size={22} />
                  </span>
                  <div>
                    <p className="text-sm font-semibold">{tab.label}</p>
                    <p className="text-xs text-slate-400">{tab.subtitle}</p>
                  </div>
                </div>
              </button>
            );
          })}
        </div>
      </div>

      {/* Content */}
      <div className="max-w-7xl mx-auto px-4 py-6">
        {loading && <div className="text-center text-gray-500 py-4">Loading...</div>}

        {riderTab === 'assigned' && (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {assignedOrders.length === 0 ? (
              <p className="text-gray-500 col-span-full text-center py-8">No assigned orders</p>
            ) : (
              assignedOrders.map(order => {
                const extraActions = isAdminRider ? [
                  {
                    label: 'Print',
                    icon: ArrowUpRight,
                    variant: 'primary',
                    onClick: () => handlePrintOrder(order)
                  },
                  {
                    label: 'Delete',
                    icon: Trash2,
                    variant: 'danger',
                    onClick: () => handleDeleteOrder(order)
                  }
                ] : [];

                return (
                  <OrderCard
                    key={order.id}
                    order={order}
                    onViewSlip={viewOrderSlip}
                    status="Go for Delivery"
                    actions={order.originalOrder ? [
                      {
                        label: 'Delivered Cash',
                        icon: DollarSign,
                        onClick: () => markDelivered(order, 'Cash', 'Receive Cash Till'),
                        accent: 'bg-yellow-500 hover:bg-yellow-600'
                      },
                      {
                        label: 'Delivered Online',
                        icon: CreditCard,
                        onClick: () => markDelivered(order, 'Online', 'May be Online'),
                        accent: 'bg-sky-500 hover:bg-sky-600'
                      }
                    ] : []}
                    extraActions={extraActions}
                  />
                );
              })
            )}
          </div>
        )}

        {riderTab === 'kitchen' && (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {kitchenOrders.length === 0 ? (
              <p className="text-gray-500 col-span-full text-center py-8">No available orders</p>
            ) : (
              kitchenOrders.map(order => (
                <div key={order.id} className="bg-white rounded-lg shadow p-4 border border-gray-200">
                  <div className="flex justify-between items-start mb-3">
                    <div>
                      <p className="text-lg font-bold text-gray-900">Order #{order.originalOrder?.id || order.id}</p>
                      <p className="text-sm text-gray-600">
                        {order.originalOrder?.customerName || 'Customer'}
                      </p>
                    </div>
                    <span className="bg-yellow-100 text-yellow-800 text-xs px-2 py-1 rounded">Available</span>
                  </div>

                  <div className="bg-gray-50 p-3 rounded mb-3">
                    <p className="text-sm text-gray-700">
                      <strong>Items:</strong> {order.originalOrder?.items?.length || 0}
                    </p>
                    <p className="text-sm text-gray-700">
                      <strong>Total:</strong> {hotelSettings?.currency} {order.originalOrder?.total || 0}
                    </p>
                  </div>

                  <div className="flex flex-wrap gap-2">
                    <button
                      onClick={() => requestApproval(order.originalOrder?.id || order.id)}
                      disabled={
                        loading ||
                        requestingIds.includes(order.originalOrder?.id || order.id) ||
                        pendingRequestOrderIds.includes(order.originalOrder?.id || order.id)
                      }
                      className={`flex-1 inline-flex items-center justify-center gap-2 py-2 px-3 rounded-2xl font-semibold transition ${
                        loading ||
                        requestingIds.includes(order.originalOrder?.id || order.id) ||
                        pendingRequestOrderIds.includes(order.originalOrder?.id || order.id)
                          ? 'bg-white text-gray-400 border border-gray-200 cursor-not-allowed'
                          : 'bg-violet-600 hover:bg-violet-700 text-white shadow-lg shadow-violet-500/20'
                      }`}
                    >
                      <HelpingHand size={18} />
                      {requestingIds.includes(order.originalOrder?.id || order.id) || pendingRequestOrderIds.includes(order.originalOrder?.id || order.id)
                        ? 'Requested'
                        : 'Request Approval'}
                    </button>
                    <button
                      onClick={() => viewOrderSlip(order)}
                      className="bg-slate-900 hover:bg-slate-800 text-white py-2 px-3 rounded-2xl transition inline-flex items-center justify-center gap-2 shadow-md shadow-slate-950/20"
                    >
                      <Eye size={18} />
                      Slip
                    </button>
                    {isAdminRider && (
                      <>
                        <button
                          onClick={() => handlePrintOrder(order)}
                          className="bg-cyan-600 hover:bg-cyan-700 text-white py-2 px-3 rounded-2xl font-semibold transition shadow-lg shadow-cyan-500/20 inline-flex items-center gap-2"
                        >
                          <ArrowUpRight size={18} />
                          Print
                        </button>
                        <button
                          onClick={() => handleDeleteOrder(order)}
                          className="bg-rose-600 hover:bg-rose-700 text-white py-2 px-3 rounded-2xl font-semibold transition shadow-lg shadow-rose-500/20 inline-flex items-center gap-2"
                        >
                          <Trash2 size={18} />
                          Delete
                        </button>
                      </>
                    )}
                  </div>
                </div>
              ))
            )}
          </div>
        )}

        {riderTab === 'requested' && (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {requestedOrders.length === 0 ? (
              <p className="text-gray-500 col-span-full text-center py-8">No requested orders</p>
            ) : (
              requestedOrders.map((order) => (
                <div key={order.id} className="bg-white rounded-lg shadow p-4 border border-orange-200">
                  <div className="flex justify-between items-start mb-3">
                    <div>
                      <p className="text-lg font-bold text-gray-900">Order #{order.originalOrder?.id || order.orderId || order.id}</p>
                      <p className="text-sm text-gray-600">
                        {order.originalOrder?.customerName || 'Customer'}
                      </p>
                      <p className="text-xs text-gray-500 mt-1">
                        {order.originalOrder?.address || order.originalOrder?.deliveryAddress || 'No address'} · {order.originalOrder?.serviceType || 'No service type'}
                      </p>
                    </div>
                    <span className="bg-orange-100 text-orange-800 text-xs px-2 py-1 rounded">Requested</span>
                  </div>

                  <div className="bg-gray-50 p-3 rounded mb-3">
                    <p className="text-sm text-gray-700">
                      <strong>Items:</strong> {order.originalOrder?.items?.length || 0}
                    </p>
                    <p className="text-sm text-gray-700">
                      <strong>Total:</strong> {hotelSettings?.currency} {order.originalOrder?.total || 0}
                    </p>
                  </div>

                  <div className="flex flex-wrap gap-2">
                    <button
                      onClick={() => viewOrderSlip(order)}
                      className="flex-1 inline-flex items-center justify-center gap-2 bg-slate-900 hover:bg-slate-800 text-white py-2 px-3 rounded-2xl font-semibold transition shadow-md shadow-slate-950/20"
                    >
                      <Eye size={18} />
                      Order Slip
                    </button>
                    {isAdminRider && (
                      <>
                        <button
                          onClick={() => handlePrintOrder(order)}
                          className="bg-cyan-600 hover:bg-cyan-700 text-white py-2 px-3 rounded-2xl font-semibold transition shadow-lg shadow-cyan-500/20 inline-flex items-center gap-2"
                        >
                          <ArrowUpRight size={18} />
                          Print
                        </button>
                        <button
                          onClick={() => handleDeleteOrder(order)}
                          className="bg-rose-600 hover:bg-rose-700 text-white py-2 px-3 rounded-2xl font-semibold transition shadow-lg shadow-rose-500/20 inline-flex items-center gap-2"
                        >
                          <Trash2 size={18} />
                          Delete
                        </button>
                      </>
                    )}
                  </div>
                </div>
              ))
            )}
          </div>
        )}

        {riderTab === 'deliveredCash' && (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {deliveredCashOrders.length === 0 ? (
              <p className="text-gray-500 col-span-full text-center py-8">No cash delivery records</p>
            ) : (
              deliveredCashOrders.map((order) => (
                <div key={order.id} className="bg-white rounded-lg shadow p-4 border border-emerald-200">
                  <div className="flex justify-between items-start mb-3">
                    <div>
                      <p className="text-lg font-bold text-gray-900">Order #{order.originalOrder?.id || order.id}</p>
                      <p className="text-sm text-gray-600">
                        {order.originalOrder?.customerName || 'Customer'}
                      </p>
                      <p className="text-xs text-gray-500 mt-1">
                        {order.originalOrder?.address || order.originalOrder?.deliveryAddress || 'No address'} · {order.originalOrder?.serviceType || 'No service type'}
                      </p>
                    </div>
                    <span className="bg-emerald-100 text-emerald-800 text-xs px-2 py-1 rounded flex items-center gap-1">
                      <DollarSign size={12} />
                      Delivered
                    </span>
                  </div>

                  <div className="bg-gray-50 p-3 rounded mb-3">
                    <p className="text-sm text-gray-700">
                      <strong>Items:</strong> {order.originalOrder?.items?.length || 0}
                    </p>
                    <p className="text-sm text-gray-700">
                      <strong>Total:</strong> {hotelSettings?.currency} {order.originalOrder?.total || 0}
                    </p>
                    <p className="text-sm text-emerald-700 mt-1">
                      <strong>Payment:</strong> Cash Collected
                    </p>
                  </div>

                  <div className="flex flex-wrap gap-2">
                    <button
                      onClick={() => viewOrderSlip(order)}
                      className="flex-1 inline-flex items-center justify-center gap-2 bg-slate-900 hover:bg-slate-800 text-white py-2 px-3 rounded-2xl font-semibold transition shadow-md shadow-slate-950/20"
                    >
                      <Eye size={18} />
                      View Slip
                    </button>
                    {isAdminRider && (
                      <>
                        <button
                          onClick={() => handlePrintOrder(order)}
                          className="bg-cyan-600 hover:bg-cyan-700 text-white py-2 px-3 rounded-2xl font-semibold transition shadow-lg shadow-cyan-500/20 inline-flex items-center gap-2"
                        >
                          <ArrowUpRight size={18} />
                          Print
                        </button>
                        <button
                          onClick={() => handleDeleteOrder(order)}
                          className="bg-rose-600 hover:bg-rose-700 text-white py-2 px-3 rounded-2xl font-semibold transition shadow-lg shadow-rose-500/20 inline-flex items-center gap-2"
                        >
                          <Trash2 size={18} />
                          Delete
                        </button>
                      </>
                    )}
                  </div>
                </div>
              ))
            )}
          </div>
        )}

        {riderTab === 'deliveredOnline' && (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {deliveredOnlineOrders.length === 0 ? (
              <p className="text-gray-500 col-span-full text-center py-8">No online payment delivery records</p>
            ) : (
              deliveredOnlineOrders.map((order) => (
                <div key={order.id} className="bg-white rounded-lg shadow p-4 border border-blue-200">
                  <div className="flex justify-between items-start mb-3">
                    <div>
                      <p className="text-lg font-bold text-gray-900">Order #{order.originalOrder?.id || order.id}</p>
                      <p className="text-sm text-gray-600">
                        {order.originalOrder?.customerName || 'Customer'}
                      </p>
                      <p className="text-xs text-gray-500 mt-1">
                        {order.originalOrder?.address || order.originalOrder?.deliveryAddress || 'No address'} · {order.originalOrder?.serviceType || 'No service type'}
                      </p>
                    </div>
                    <span className="bg-blue-100 text-blue-800 text-xs px-2 py-1 rounded flex items-center gap-1">
                      <CreditCard size={12} />
                      Delivered
                    </span>
                  </div>

                  <div className="bg-gray-50 p-3 rounded mb-3">
                    <p className="text-sm text-gray-700">
                      <strong>Items:</strong> {order.originalOrder?.items?.length || 0}
                    </p>
                    <p className="text-sm text-gray-700">
                      <strong>Total:</strong> {hotelSettings?.currency} {order.originalOrder?.total || 0}
                    </p>
                    <p className="text-sm text-blue-700 mt-1">
                      <strong>Payment:</strong> Online Payment
                    </p>
                  </div>

                  <div className="flex flex-wrap gap-2">
                    <button
                      onClick={() => viewOrderSlip(order)}
                      className="flex-1 inline-flex items-center justify-center gap-2 bg-slate-900 hover:bg-slate-800 text-white py-2 px-3 rounded-2xl font-semibold transition shadow-md shadow-slate-950/20"
                    >
                      <Eye size={18} />
                      View Slip
                    </button>
                    {isAdminRider && (
                      <>
                        <button
                          onClick={() => handlePrintOrder(order)}
                          className="bg-cyan-600 hover:bg-cyan-700 text-white py-2 px-3 rounded-2xl font-semibold transition shadow-lg shadow-cyan-500/20 inline-flex items-center gap-2"
                        >
                          <ArrowUpRight size={18} />
                          Print
                        </button>
                        <button
                          onClick={() => handleDeleteOrder(order)}
                          className="bg-rose-600 hover:bg-rose-700 text-white py-2 px-3 rounded-2xl font-semibold transition shadow-lg shadow-rose-500/20 inline-flex items-center gap-2"
                        >
                          <Trash2 size={18} />
                          Delete
                        </button>
                      </>
                    )}
                  </div>
                </div>
              ))
            )}
          </div>
        )}
      </div>

      {/* Order Slip Modal */}
      {selectedOrder && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4 z-50">
          <div className="bg-slate-950 rounded-2xl max-w-2xl w-full max-h-[90vh] overflow-y-auto p-8 border border-cyan-500/50 shadow-2xl shadow-cyan-500/30 relative">
            {/* Glowing top accent */}
            <div className="absolute top-0 left-1/2 -translate-x-1/2 w-1/2 h-1 bg-gradient-to-r from-transparent via-cyan-400 to-transparent blur-lg opacity-60"></div>
            
            <div className="flex justify-between items-center mb-6">
              <h2 className="text-3xl font-extrabold bg-gradient-to-r from-cyan-400 to-blue-400 bg-clip-text text-transparent">Order Slip</h2>
              <button
                onClick={() => setSelectedOrder(null)}
                className="text-cyan-400 hover:text-cyan-300 hover:bg-cyan-500/20 rounded-full p-2 transition text-2xl"
              >
                ✕
              </button>
            </div>

            <div className="border-t border-cyan-500/30 pt-6">
              <div className="grid grid-cols-2 gap-6 mb-6">
                <div className="bg-slate-900/50 border border-cyan-500/20 rounded-lg p-4">
                  <p className="text-xs uppercase tracking-wider text-cyan-400 font-semibold mb-2">Order ID</p>
                  <p className="text-xl font-bold text-white">{selectedOrder.originalOrder?.id || selectedOrder.id || 'N/A'}</p>
                </div>
                <div className="bg-slate-900/50 border border-cyan-500/20 rounded-lg p-4">
                  <p className="text-xs uppercase tracking-wider text-cyan-400 font-semibold mb-2">Customer</p>
                  <p className="text-xl font-bold text-white">{selectedOrder.originalOrder?.customerName || 'N/A'}</p>
                </div>
                <div className="bg-slate-900/50 border border-cyan-500/20 rounded-lg p-4">
                  <p className="text-xs uppercase tracking-wider text-cyan-400 font-semibold mb-2">Phone</p>
                  <p className="text-lg text-slate-200">{selectedOrder.originalOrder?.phone || selectedOrder.originalOrder?.customerPhone || 'N/A'}</p>
                </div>
                <div className="bg-slate-900/50 border border-cyan-500/20 rounded-lg p-4">
                  <p className="text-xs uppercase tracking-wider text-cyan-400 font-semibold mb-2">Address</p>
                  <p className="text-lg text-slate-200">{selectedOrder.originalOrder?.address || selectedOrder.originalOrder?.deliveryAddress || 'N/A'}</p>
                </div>
                <div className="col-span-2 bg-slate-900/50 border border-cyan-500/20 rounded-lg p-4">
                  <p className="text-xs uppercase tracking-wider text-cyan-400 font-semibold mb-2">Service Type</p>
                  <p className="text-lg text-slate-200">{selectedOrder.originalOrder?.serviceType || 'N/A'}</p>
                </div>
              </div>

              <div className="border-t border-cyan-500/30 pt-6 mt-6">
                <h3 className="text-lg font-bold text-cyan-400 mb-4 uppercase tracking-wider">Items</h3>
                <div className="bg-slate-900/30 border border-cyan-500/20 rounded-lg overflow-hidden">
                  <table className="w-full text-sm">
                    <thead>
                      <tr className="bg-slate-900/70 border-b border-cyan-500/20">
                        <th className="text-left py-3 px-4 text-cyan-400 font-semibold">Item</th>
                        <th className="text-center py-3 px-4 text-cyan-400 font-semibold">Qty</th>
                        <th className="text-right py-3 px-4 text-cyan-400 font-semibold">Price</th>
                        <th className="text-right py-3 px-4 text-cyan-400 font-semibold">Total</th>
                      </tr>
                    </thead>
                    <tbody>
                      {selectedOrder.originalOrder?.items?.map((item, idx) => (
                        <tr key={idx} className="border-b border-cyan-500/10 hover:bg-slate-900/50 transition">
                          <td className="py-3 px-4 text-slate-200">{item.name}</td>
                          <td className="text-center py-3 px-4 text-slate-300">{item.quantity}</td>
                          <td className="text-right py-3 px-4 text-slate-300">{hotelSettings?.currency || 'PKR'} {item.price}</td>
                          <td className="text-right py-3 px-4 font-semibold text-cyan-300">{hotelSettings?.currency || 'PKR'} {(item.quantity * item.price).toFixed(2)}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>

              <div className="border-t border-cyan-500/30 mt-6 pt-6 space-y-2">
                <div className="flex justify-between items-center text-slate-300">
                  <span>Subtotal:</span>
                  <span className="text-lg font-semibold text-cyan-300">{hotelSettings?.currency || 'PKR'} {selectedOrder.originalOrder?.subtotal || 0}</span>
                </div>
                <div className="flex justify-between items-center text-slate-300">
                  <span>Delivery Charge:</span>
                  <span className="text-lg font-semibold text-cyan-300">{hotelSettings?.currency || 'PKR'} {selectedOrder.originalOrder?.deliveryCharge || 0}</span>
                </div>
                <div className="flex justify-between items-center text-xl font-bold border-t border-cyan-500/30 pt-4 mt-4">
                  <span className="text-cyan-400">Total:</span>
                  <span className="text-2xl bg-gradient-to-r from-cyan-400 to-blue-400 bg-clip-text text-transparent">{hotelSettings?.currency || 'PKR'} {selectedOrder.originalOrder?.total || 0}</span>
                </div>
              </div>
            </div>

            <div className="flex justify-end gap-3 mt-8 pt-6 border-t border-cyan-500/30">
              <button
                onClick={() => handlePrintOrder(selectedOrder)}
                className="bg-gradient-to-r from-cyan-600 to-blue-600 hover:from-cyan-500 hover:to-blue-500 text-white py-3 px-6 rounded-lg font-semibold transition shadow-lg shadow-cyan-500/30 inline-flex items-center gap-2"
              >
                <ArrowUpRight size={18} />
                Print
              </button>
              {isAdminRider && (
                <button
                  onClick={() => {
                    handleDeleteOrder(selectedOrder);
                    setSelectedOrder(null);
                  }}
                  className="bg-gradient-to-r from-rose-600 to-red-600 hover:from-rose-500 hover:to-red-500 text-white py-3 px-6 rounded-lg font-semibold transition shadow-lg shadow-rose-500/30 inline-flex items-center gap-2"
                >
                  <Trash2 size={18} />
                  Delete
                </button>
              )}
              <button
                onClick={() => setSelectedOrder(null)}
                className="bg-slate-800 hover:bg-slate-700 text-cyan-400 py-3 px-6 rounded-lg font-semibold transition border border-cyan-500/30"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function OrderCard({ order, onViewSlip, status, actions = [], extraActions = [] }) {
  return (
    <div className="bg-white rounded-lg shadow p-4 border border-gray-200">
      <div className="flex justify-between items-start mb-3">
        <div>
          <p className="text-lg font-bold text-gray-900">Order #{order.originalOrder?.id || order.id}</p>
          <p className="text-sm text-gray-600">
            {order.originalOrder?.customerName || 'Customer'}
          </p>
          <p className="text-xs text-gray-500 mt-1">
            {order.originalOrder?.address || order.originalOrder?.deliveryAddress || 'No address'} · {order.originalOrder?.serviceType || 'No service type'}
          </p>
        </div>
        <span className="bg-blue-100 text-blue-800 text-xs px-2 py-1 rounded">{status}</span>
      </div>

      <div className="bg-gray-50 p-3 rounded mb-3">
        <p className="text-sm text-gray-700">
          <strong>Items:</strong> {order.originalOrder?.items?.length || 0}
        </p>
        <p className="text-sm text-gray-700">
          <strong>Total:</strong> PKR {order.originalOrder?.total || 0}
        </p>
      </div>

      {actions.length > 0 && (
        <div className="mt-3 grid gap-2">
          {actions.map((action) => {
            const ActionIcon = action.icon;
            return (
              <button
                key={action.label}
                onClick={action.onClick}
                className={`w-full inline-flex items-center justify-center gap-2 py-2 px-3 rounded-2xl font-semibold transition ${action.accent || 'bg-slate-800 hover:bg-slate-900 text-white'}`}
              >
                {ActionIcon ? <ActionIcon size={18} /> : null}
                {action.label}
              </button>
            );
          })}
        </div>
      )}
      {extraActions.length > 0 && (
        <div className="mt-3 flex flex-wrap gap-2">
          {extraActions.map((action) => {
            const ActionIcon = action.icon;
            return (
              <button
                key={action.label}
                onClick={action.onClick}
                className={`inline-flex items-center justify-center gap-2 py-2 px-3 rounded-2xl font-semibold transition ${action.variant === 'danger' ? 'bg-rose-600 hover:bg-rose-700 text-white shadow-lg shadow-rose-500/20' : 'bg-cyan-600 hover:bg-cyan-700 text-white shadow-lg shadow-cyan-500/20'}`}
              >
                {ActionIcon ? <ActionIcon size={18} /> : null}
                {action.label}
              </button>
            );
          })}
        </div>
      )}
      <button
        onClick={() => onViewSlip(order)}
        className="w-full bg-slate-100 hover:bg-slate-200 text-slate-900 py-2 px-3 rounded-2xl font-semibold transition flex items-center justify-center gap-2 mt-3 shadow-sm shadow-slate-900/10"
      >
        <Eye size={16} />
        View Order Slip
      </button>
    </div>
  );
}
