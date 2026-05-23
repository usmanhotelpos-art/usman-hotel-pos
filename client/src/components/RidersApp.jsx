import { useState, useEffect, useRef } from 'react';
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
import { calculateRiderSummary } from '../utils/riderSummary';

const apiBase = '/api';

function getDisplayOrderNumber(order) {
  const original = order?.originalOrder || order || {};
  const orderNumber = original.orderNumber || order?.orderNumber || original.receiptNumber || original.invoiceNumber;
  if (orderNumber) return orderNumber;
  const id = original.id || order?.id || '';
  return id ? String(id).slice(0, 8) : 'N/A';
}

export function RidersApp() {
  const [view, setView] = useState('login'); // login, app
  const [riderTab, setRiderTab] = useState('assigned'); // assigned, kitchen, requested, deliveredCash, deliveredOnline
  const [selectedRoleTab, setSelectedRoleTab] = useState('biker'); // biker, admin-biker
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
  const [products, setProducts] = useState([]);
  const [deleteError, setDeleteError] = useState('');
  const [notification, setNotification] = useState(null);
  const [showNotification, setShowNotification] = useState(false);
  const [showSummaryModal, setShowSummaryModal] = useState(false);
  const [summaryType, setSummaryType] = useState('cash');
  const [summaryData, setSummaryData] = useState(null);
  const [shiftTimer, setShiftTimer] = useState(0);
  const shiftResetRef = useRef({ active: false, startedAt: '' });

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

  const formatCurrency = (value) => {
    const amount = Number(value || 0);
    return `${hotelSettings?.currency || 'PKR'} ${amount.toFixed(2)}`;
  };

  const getItemCategory = (item) => {
    if (!item) return '';
    const categoryFromItem = item.category || item.categoryName || item.type || item.subcategory || item.group;
    if (categoryFromItem) return categoryFromItem.toString();
    if (item.productId) {
      const product = products.find((product) => product.id === item.productId || product.id === String(item.productId));
      return product?.category || product?.type || product?.group || '';
    }
    return '';
  };

  const isExtrasItem = (item) => {
    const category = (getItemCategory(item) || item.name || '').toString().toLowerCase();
    return category.includes('extras') || category.includes('extra');
  };

  const getOrderDeliveryFee = (originalOrder) => {
    const original = originalOrder || {};
    return Number(original.deliveryCharge || original.deliveryFee || original.serviceCharge || 0);
  };

  const calculateSummaryForOrders = (orders, type) => {
    return calculateRiderSummary(orders, type, {
      getProductById: (id) => products.find((p) => p.id === id || String(p.id) === String(id)) || {},
      getServiceCharge: getOrderDeliveryFee
    });
  };

  const formatSignedCurrency = (value) => {
    const amount = Number(value || 0);
    const sign = amount > 0 ? '+' : '';
    return `${hotelSettings?.currency || 'PKR'} ${sign}${amount.toFixed(2)}`;
  };

  const openSummaryModal = (type) => {
    const orders = type === 'cash' ? deliveredCashOrders : deliveredOnlineOrders;
    const data = calculateSummaryForOrders(orders, type);
    const cashAmount = calculateSummaryForOrders(deliveredCashOrders, 'cash').riderAmount;
    const onlineAmount = calculateSummaryForOrders(deliveredOnlineOrders, 'online').riderAmount;
    const difference = cashAmount - onlineAmount;
    setSummaryType(type);
    setSummaryData({
      ...data,
      totalDifference: difference,
      differenceLabel: difference < 0 ? 'RIDER HAQ' : difference > 0 ? 'USMAN HOTEL HAQ' : 'BALANCED'
    });
    setShowSummaryModal(true);
  };

  const closeSummaryModal = () => {
    setShowSummaryModal(false);
  };

  const cashSummaryData = calculateSummaryForOrders(deliveredCashOrders, 'cash');
  const onlineSummaryData = calculateSummaryForOrders(deliveredOnlineOrders, 'online');
  const overallDifference = cashSummaryData.riderAmount - onlineSummaryData.riderAmount;
  const overallDifferenceLabel = overallDifference < 0 ? 'RIDER HAQ' : overallDifference > 0 ? 'USMAN HOTEL HAQ' : 'BALANCED';

  // Support both legacy single `riderShift` and newer `riderShifts` array.
  const allShifts = Array.isArray(hotelSettings?.riderShifts)
    ? hotelSettings.riderShifts
    : hotelSettings?.riderShift
    ? [hotelSettings.riderShift]
    : [];
  const activeShifts = (allShifts || []).filter((s) => s && Boolean(s.active));
  const shiftActive = activeShifts.length > 0;

  // Determine if the current login input matches any active shift (used for indicator and permissive login when multiple shifts present)
  const inputLoginLower = (loginForm.email || '').toString().trim().toLowerCase();
  const matchedShift = inputLoginLower
    ? activeShifts.find((s) => {
        const username = (s.riderUsername || '').toString().trim().toLowerCase();
        const name = (s.riderName || '').toString().trim().toLowerCase();
        const id = s.riderId ? String(s.riderId) : '';
        if (!inputLoginLower) return false;
        if (inputLoginLower === username || inputLoginLower === name || inputLoginLower === id) return true;
        const local = inputLoginLower.includes('@') ? inputLoginLower.split('@')[0] : inputLoginLower;
        if (local && (local === username || local === (username.includes('@') ? username.split('@')[0] : username))) return true;
        return false;
      })
    : null;

  // Choose a primary shift to display when needed: prefer matchedShift, otherwise if only one active shift use that.
  const primaryShift = matchedShift || (activeShifts.length === 1 ? activeShifts[0] : null);
  const shiftAssignedRiderId = primaryShift?.riderId || '';
  const shiftAssignedRiderName = primaryShift ? (primaryShift.riderName || primaryShift.riderUsername || 'assigned rider') : (activeShifts.length === 1 ? (activeShifts[0].riderName || activeShifts[0].riderUsername || 'assigned rider') : `${activeShifts.length} active`);
  const shiftStartedAt = primaryShift?.startedAt ? new Date(primaryShift.startedAt) : null;

  const activeShiftsStartedAtKey = activeShifts.map((s) => s?.startedAt || '').join('|');

  useEffect(() => {
    const previous = shiftResetRef.current;
    const currentNav = {
      active: shiftActive,
      startedAt: activeShiftsStartedAtKey
    };

    const becameActive = !previous.active && currentNav.active;
    const newShiftStarted = previous.active && currentNav.active && previous.startedAt !== currentNav.startedAt;

    if (becameActive || newShiftStarted) {
      setAssignedOrders([]);
      setKitchenOrders([]);
      setRequestedOrders([]);
      setDeliveredCashOrders([]);
      setDeliveredOnlineOrders([]);
      setSelectedOrder(null);
    }

    shiftResetRef.current = currentNav;
  }, [shiftActive, activeShiftsStartedAtKey]);

  const formatShiftElapsed = (startedAt) => {
    if (!startedAt) return '00h 00m';
    const startedTime = new Date(startedAt).getTime();
    if (Number.isNaN(startedTime)) return '00h 00m';
    const diffMs = Math.max(Date.now() - startedTime, 0);
    const hours = Math.floor(diffMs / 3600000);
    const minutes = Math.floor((diffMs % 3600000) / 60000);
    return `${hours.toString().padStart(2, '0')}h ${minutes.toString().padStart(2, '0')}m`;
  };

  const shiftLoginHint = () => {
    if (selectedRoleTab === 'admin-biker') {
      return 'Admin Biker mode - No shift requirement';
    }
    if (shiftActive) {
      const assigned = primaryShift?.riderUsername || primaryShift?.riderName;
      const isAssignedUser = Boolean(inputLoginLower && canAttemptLogin && assigned);
      if (isAssignedUser) {
        return 'Yes, your shift started. Please enter your password.';
      }
      if (shiftAssignedRiderName && inputLoginLower && !canAttemptLogin) {
        return `Shift active for ${shiftAssignedRiderName}. Please login with the assigned rider username.`;
      }
      return `Shift active for ${shiftAssignedRiderName}. Started at ${shiftStartedAt ? shiftStartedAt.toLocaleTimeString() : 'N/A'}`;
    }
    return 'Shift not started. Please ask Owner Farhan to start your shift.';
  };
  // Determine whether the current login input is allowed to attempt login.
  const shiftAssignedUsernameLower = (primaryShift?.riderUsername || '').toString().trim().toLowerCase();
  const shiftAssignedNameLower = (primaryShift?.riderName || '').toString().trim().toLowerCase();
  const shiftAssignedIdStr = primaryShift?.riderId ? String(primaryShift.riderId) : '';
  const shiftAssignedUsernameLocalPart = shiftAssignedUsernameLower && shiftAssignedUsernameLower.includes('@') ? shiftAssignedUsernameLower.split('@')[0] : shiftAssignedUsernameLower;

  const canAttemptLogin = (() => {
    if (selectedRoleTab === 'admin-biker') return true; // admin bikers can login anytime via that tab
    if (selectedRoleTab === 'biker') {
      // If there's a primary assigned shift (either matched by input or single active shift), require input to match that shift
      if ((shiftAssignedIdStr || shiftAssignedUsernameLower || shiftAssignedNameLower)) {
        if (!inputLoginLower) return false;
        if (
          inputLoginLower === shiftAssignedUsernameLower ||
          inputLoginLower === shiftAssignedNameLower ||
          inputLoginLower === shiftAssignedIdStr
        ) return true;
        const localPart = inputLoginLower.includes('@') ? inputLoginLower.split('@')[0] : inputLoginLower;
        if (localPart && (localPart === shiftAssignedUsernameLower || localPart === shiftAssignedUsernameLocalPart)) return true;
        return false;
      }

      // No single assigned shift: if multiple active shifts exist, allow any non-empty login input (user will still be authenticated server-side)
      if (activeShifts.length > 1) {
        return Boolean(inputLoginLower);
      }

      // No active shifts at all
      if (!shiftActive) return false;
      return true;
    }
    return false;
  })();

  useEffect(() => {
    if (!shiftActive) return undefined;
    const interval = window.setInterval(() => setShiftTimer(Date.now()), 60000);
    return () => window.clearInterval(interval);
  }, [shiftActive, activeShiftsStartedAtKey]);

  useEffect(() => {
    if (!hotelSettings || view !== 'app' || !rider) return undefined;
    const riderRoleStr = (rider?.role || '').toString().toLowerCase();
    const isAdminRiderUser = riderRoleStr.includes('admin');
    
    // Only enforce shift validation for non-admin riders
    if (!isAdminRiderUser && !shiftActive) {
      notify('Shift has been closed. Please login again after the next shift starts.', 'error');
      handleLogout();
    }
    return undefined;
  }, [hotelSettings, view, rider, shiftActive]);

  useEffect(() => {
    if (view !== 'login') return undefined;
    const interval = window.setInterval(() => fetchHotelSettings(), 15000);
    return () => window.clearInterval(interval);
  }, [view]);

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
        return data;
      }
    } catch (error) {
      console.error('Failed to fetch hotel settings:', error);
    }
    return null;
  };

  const fetchProducts = async () => {
    try {
      const res = await fetch(`${apiBase}/pos/products`);
      if (res.ok) {
        const data = await res.json();
        setProducts(Array.isArray(data) ? data : []);
      }
    } catch (error) {
      console.error('Failed to fetch products:', error);
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
    if (view !== 'app' || !rider?.id) return undefined;
    fetchHotelSettings();
    fetchProducts();
    loadOrders();
    return undefined;
  }, [view, riderTab, rider?.id]);

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

    const latestSettings = await fetchHotelSettings();
    const latestAllShifts = Array.isArray(latestSettings?.riderShifts)
      ? latestSettings.riderShifts
      : latestSettings?.riderShift
      ? [latestSettings.riderShift]
      : [];
    const latestActiveShifts = (latestAllShifts || []).filter((s) => s && Boolean(s.active));
    const latestShiftActive = latestActiveShifts.length > 0;
    const anyAssignedActive = latestActiveShifts.some((s) => s.riderId || s.riderUsername);
    const latestAssignedNames = latestActiveShifts.filter(s => s.riderName || s.riderUsername).map(s => s.riderName || s.riderUsername).join(', ');

    try {
      const res = await fetch(`${apiBase}/auth/rider-login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(loginForm)
      });

      if (res.ok) {
        const data = await res.json();
        const matchingAssigned = latestActiveShifts.some((s) => {
          const id = s.riderId ? String(s.riderId) : '';
          const username = (s.riderUsername || '').toString().trim().toLowerCase();
          const riderUsernameOrEmail = (data?.rider?.username || data?.rider?.email || '').toString().trim().toLowerCase();
          return (id && String(data?.rider?.id) === id) || (username && username === riderUsernameOrEmail);
        });
        const riderId = data.rider?.id;
        const riderRole = (data.rider?.role || '').toString().toLowerCase();
        const isAdminRider = riderRole.includes('admin');

        // Shift validation: Skip for Admin Biker, enforce for regular Biker
        if (selectedRoleTab === 'biker' && !isAdminRider) {
          if (!latestShiftActive) {
            const message = 'Shift not started. Please ask Owner Farhan to start your shift before login.';
            setLoginError(message);
            notify(message, 'error');
            setLoading(false);
            return;
          }

          // If active shifts contain explicit assignments, require the logged-in rider to be one of those assigned.
          if (anyAssignedActive && !matchingAssigned) {
            const message = `This shift is assigned to ${latestAssignedNames || 'another rider'}. Please login with the assigned rider account.`;
            setLoginError(message);
            notify(message, 'error');
            setLoading(false);
            return;
          }
        } else if (selectedRoleTab === 'admin-biker' && !isAdminRider) {
          const message = 'Admin Biker tab requires an admin rider account.';
          setLoginError(message);
          notify(message, 'error');
          setLoading(false);
          return;
        }

        const clearShiftOrders = () => {
          setAssignedOrders([]);
          setKitchenOrders([]);
          setRequestedOrders([]);
          setDeliveredCashOrders([]);
          setDeliveredOnlineOrders([]);
          setSelectedOrder(null);
        };

        clearShiftOrders();
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

  const decodeRiderRoleFromToken = (token) => {
    if (!token) return '';
    try {
      const payload = token.split('.')[1];
      if (!payload) return '';
      const decoded = JSON.parse(atob(payload.replace(/-/g, '+').replace(/_/g, '/')));
      return (decoded.role || '').toString().toLowerCase();
    } catch (error) {
      return '';
    }
  };

  const riderRole = (rider?.role || '').toString().toLowerCase() || decodeRiderRoleFromToken(riderToken);
  const isAdminRider = riderRole.includes('admin');
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

          <div className="mb-6 flex gap-3 border-b border-slate-800 pb-4">
            <button
              type="button"
              onClick={() => setSelectedRoleTab('biker')}
              className={`flex-1 rounded-3xl py-3 px-4 text-sm font-semibold transition ${
                selectedRoleTab === 'biker'
                  ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-500/30'
                  : 'bg-slate-900 text-slate-400 border border-slate-800 hover:bg-slate-800'
              }`}
            >
              Biker
            </button>
            <button
              type="button"
              onClick={() => setSelectedRoleTab('admin-biker')}
              className={`flex-1 rounded-3xl py-3 px-4 text-sm font-semibold transition ${
                selectedRoleTab === 'admin-biker'
                  ? 'bg-blue-600 text-white shadow-lg shadow-blue-500/30'
                  : 'bg-slate-900 text-slate-400 border border-slate-800 hover:bg-slate-800'
              }`}
            >
              Admin Biker
            </button>
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
              <label className="block text-sm font-medium text-slate-300 mb-2">Password</label>
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
                  <div className={`rounded-3xl border px-4 py-4 text-sm ${
                    selectedRoleTab === 'admin-biker'
                      ? 'border-blue-700/20 bg-blue-950/60 text-blue-200'
                      : 'border-orange-700/20 bg-orange-950/60 text-orange-200'
                  }`}>
              <p className="font-semibold">{shiftLoginHint()}</p>
              {selectedRoleTab === 'biker' && shiftActive && shiftStartedAt ? (
                <div className="mt-3 space-y-1 text-xs text-orange-300">
                  <p>Started at {shiftStartedAt.toLocaleTimeString()}</p>
                  <p>Elapsed: {formatShiftElapsed(primaryShift?.startedAt)}</p>
                </div>
              ) : null}
            </div>

            <button
              type="submit"
              disabled={loading || !canAttemptLogin}
              className={`w-full flex items-center justify-center gap-2 bg-gradient-to-r from-orange-500 to-pink-500 hover:from-orange-400 hover:to-pink-400 text-white font-semibold py-3 rounded-2xl transition duration-300 ${loading || !canAttemptLogin ? 'disabled:opacity-50 disabled:cursor-not-allowed opacity-50' : ''}`}
            >
              {loading ? 'Signing in...' : 'Login'}
              <ArrowUpRight size={18} />
            </button>
          </form>

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
                <div className="mt-4 grid grid-cols-2 gap-2 text-xs uppercase tracking-[0.2em] text-slate-400">
                  <div className="rounded-2xl bg-slate-950/80 p-2 text-center">
                    <p className="font-semibold text-white">Cash</p>
                    <p>{deliveredCashOrders.length}</p>
                  </div>
                  <div className="rounded-2xl bg-slate-950/80 p-2 text-center">
                    <p className="font-semibold text-white">Online</p>
                    <p>{deliveredOnlineOrders.length}</p>
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

          <div className="mt-6 grid grid-cols-1 gap-4 xl:grid-cols-4">
            <div
              role="button"
              onClick={() => openSummaryModal('cash')}
              className="rounded-3xl border border-slate-800 bg-slate-900/90 p-5 shadow-xl shadow-cyan-500/10 transition hover:-translate-y-1 hover:bg-slate-800 cursor-pointer"
            >
              <p className="text-xs uppercase tracking-[0.24em] text-slate-500">Cash amount</p>
              <p className="mt-4 text-3xl font-semibold text-white">{formatCurrency(cashSummaryData.riderAmount)}</p>
              <p className="mt-2 text-sm text-slate-400">Cash summary for collected orders.</p>
            </div>
            <div
              role="button"
              onClick={() => openSummaryModal('online')}
              className="rounded-3xl border border-slate-800 bg-slate-900/90 p-5 shadow-xl shadow-sky-500/10 transition hover:-translate-y-1 hover:bg-slate-800 cursor-pointer"
            >
              <p className="text-xs uppercase tracking-[0.24em] text-slate-500">Online amount</p>
              <p className="mt-4 text-3xl font-semibold text-white">{formatCurrency(onlineSummaryData.riderAmount)}</p>
              <p className="mt-2 text-sm text-slate-400">Online summary for owed rider amount.</p>
            </div>
            <div className="rounded-3xl border border-slate-800 bg-slate-900/90 p-5 shadow-xl shadow-emerald-500/10 transition hover:-translate-y-1">
              <p className="text-xs uppercase tracking-[0.24em] text-slate-400">Shift status</p>
              <p className={`mt-4 text-3xl font-semibold ${shiftActive ? 'text-emerald-400' : 'text-rose-400'}`}>{shiftActive ? 'Active' : 'Inactive'}</p>
              <p className="mt-2 text-sm text-slate-400">{shiftActive ? `Rider: ${shiftAssignedRiderName}` : 'Waiting for shift start'}</p>
              {shiftActive && primaryShift?.startedAt ? <p className="mt-2 text-xs uppercase tracking-[0.16em] text-slate-500">{formatShiftElapsed(primaryShift?.startedAt)} elapsed</p> : null}
            </div>
            <div className="rounded-3xl border border-slate-800 bg-gradient-to-r from-fuchsia-500/10 via-slate-900/70 to-cyan-500/10 p-5 shadow-xl shadow-fuchsia-500/15 animate-pulse">
              <p className="text-xs uppercase tracking-[0.24em] text-slate-300">Difference</p>
              <p className="mt-4 text-3xl font-semibold text-white">{formatSignedCurrency(overallDifference)}</p>
              <p className="mt-2 text-sm font-semibold uppercase tracking-[0.2em] text-white">{overallDifferenceLabel}</p>
            </div>
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
                    {(tab.key === 'deliveredCash' || tab.key === 'deliveredOnline') && (
                      <span
                        onClick={(e) => {
                          e.stopPropagation();
                          openSummaryModal(tab.key === 'deliveredCash' ? 'cash' : 'online');
                        }}
                        className="mt-3 inline-flex cursor-pointer rounded-full border border-white/10 bg-white/5 px-3 py-1 text-[11px] font-semibold uppercase tracking-[0.2em] text-slate-200 transition hover:bg-white/10"
                      >
                        Summary
                      </span>
                    )}
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
                    currency={hotelSettings?.currency || 'PKR'}
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
                      <p className="text-lg font-bold text-gray-900">Order #{getDisplayOrderNumber(order)}</p>
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
                      <p className="text-lg font-bold text-gray-900">Order #{getDisplayOrderNumber(order)}</p>
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
          <div className="space-y-4">
            <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
              <div>
                <h2 className="text-xl font-semibold text-white">Rider Book Cash</h2>
                <p className="text-sm text-slate-400">Cash payments summary for collected amounts.</p>
              </div>
              <button
                onClick={() => openSummaryModal('cash')}
                className="rounded-full bg-gradient-to-r from-emerald-500 to-cyan-500 px-5 py-3 text-sm font-semibold text-slate-950 shadow-lg shadow-emerald-500/30 hover:from-emerald-400 hover:to-cyan-400 transition"
              >
                ماشاءاللہ Summary
              </button>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {deliveredCashOrders.length === 0 ? (
                <p className="text-gray-500 col-span-full text-center py-8">No cash delivery records</p>
              ) : (
                deliveredCashOrders.map((order) => (
                  <div key={order.id} className="bg-white rounded-lg shadow p-4 border border-emerald-200">
                    <div className="flex justify-between items-start mb-3">
                      <div>
                        <p className="text-lg font-bold text-gray-900">Order #{getDisplayOrderNumber(order)}</p>
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
          </div>
        )}

        {riderTab === 'deliveredOnline' && (
          <div className="space-y-4">
            <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
              <div>
                <h2 className="text-xl font-semibold text-white">Rider Book Online</h2>
                <p className="text-sm text-slate-400">Online payments summary for extras and service charges.</p>
              </div>
              <button
                onClick={() => openSummaryModal('online')}
                className="rounded-full bg-gradient-to-r from-sky-500 to-indigo-500 px-5 py-3 text-sm font-semibold text-slate-950 shadow-lg shadow-sky-500/30 hover:from-sky-400 hover:to-indigo-400 transition"
              >
                ماشاءاللہ Summary
              </button>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {deliveredOnlineOrders.length === 0 ? (
                <p className="text-gray-500 col-span-full text-center py-8">No online payment delivery records</p>
              ) : (
                deliveredOnlineOrders.map((order) => (
                  <div key={order.id} className="bg-white rounded-lg shadow p-4 border border-blue-200">
                    <div className="flex justify-between items-start mb-3">
                      <div>
                        <p className="text-lg font-bold text-gray-900">Order #{getDisplayOrderNumber(order)}</p>
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
          </div>
        )}
      </div>

      {/* Order Slip Modal */}
      {showSummaryModal && summaryData && (
        <div className="fixed inset-0 bg-black/90 backdrop-blur-sm flex items-center justify-center p-4 z-50">
          <div className="relative rounded-[32px] border border-fuchsia-500/30 bg-gradient-to-br from-slate-950 via-slate-900 to-slate-950 p-6 shadow-[0_0_48px_rgba(191,90,242,0.20)] max-w-3xl w-full max-h-[92vh] overflow-y-auto">
            <button
              onClick={closeSummaryModal}
              className="absolute right-4 top-4 text-slate-300 hover:text-white rounded-full p-2 transition"
            >
              ✕
            </button>
            <div className="text-center">
              <div className="mx-auto flex h-28 w-28 items-center justify-center rounded-full bg-gradient-to-br from-fuchsia-500 via-cyan-500 to-emerald-500 shadow-[0_0_30px_rgba(127,199,255,0.45)] text-white text-3xl font-extrabold">
                {formatSignedCurrency(summaryData.totalDifference)}
              </div>
              <p className="mt-4 text-sm uppercase tracking-[0.35em] text-fuchsia-300">
                {summaryData.totalDifference < 0 ? 'RIDER HAQ' : summaryData.totalDifference > 0 ? 'USMAN HOTEL HAQ' : 'BALANCED'}
              </p>
              <h3 className="mt-2 text-2xl font-extrabold text-white">
                {summaryType === 'cash' ? 'Rider Book Cash Summary' : 'Rider Book Online Summary'}
              </h3>
              <p className="mt-2 max-w-2xl text-sm text-slate-400">
                {summaryType === 'cash'
                  ? 'Showing cash collection total excluding Extras category items and delivery fees.'
                  : 'Showing Extras category amount plus delivery fees that should be given to riders.'}
              </p>
            </div>

            <div className="mt-8 grid gap-4 md:grid-cols-4">
              <div className="rounded-3xl border border-white/10 bg-slate-900/80 p-5 shadow-lg shadow-cyan-500/10">
                <p className="text-sm text-slate-400">Order total</p>
                <p className="mt-2 text-3xl font-semibold text-white">{formatCurrency(summaryData.orderTotal)}</p>
              </div>
              <div className="rounded-3xl border border-white/10 bg-slate-900/80 p-5 shadow-lg shadow-fuchsia-500/10">
                <p className="text-sm text-slate-400">Extras total</p>
                <p className="mt-2 text-3xl font-semibold text-white">{formatCurrency(summaryData.extrasTotal)}</p>
              </div>
              <div className="rounded-3xl border border-white/10 bg-slate-900/80 p-5 shadow-lg shadow-emerald-500/10">
                <p className="text-sm text-slate-400">Delivery fee</p>
                <p className="mt-2 text-3xl font-semibold text-white">{formatCurrency(summaryData.deliveryFeeTotal)}</p>
              </div>
              <div className="rounded-3xl border border-white/10 bg-slate-900/80 p-5 shadow-lg shadow-slate-500/10">
                <p className="text-sm text-slate-400">{summaryType === 'cash' ? 'Cash orders' : 'Online orders'}</p>
                <p className="mt-2 text-3xl font-semibold text-white">{summaryData.count}</p>
              </div>
            </div>

            <div className="mt-6 rounded-3xl border border-slate-800 bg-slate-950/90 p-6 shadow-inner shadow-slate-950/20">
              <div className="flex items-center justify-between text-slate-400 uppercase tracking-[0.18em] text-xs font-semibold mb-4">
                <span>Summary amount</span>
                <span>{summaryType === 'cash' ? 'Total from rider' : 'Total for rider'}</span>
              </div>
              <div className="rounded-3xl bg-gradient-to-r from-cyan-500 to-fuchsia-500 p-5 text-center text-white shadow-[0_0_18px_rgba(56,189,248,0.35)]">
                <p className="text-sm uppercase tracking-[0.18em]">{summaryType === 'cash' ? 'Amount taken from rider' : 'Amount to give rider'}</p>
                <p className="mt-3 text-4xl font-extrabold">{formatCurrency(summaryData.riderAmount)}</p>
              </div>
            </div>
          </div>
        </div>
      )}

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
                  <p className="text-xl font-bold text-white">{getDisplayOrderNumber(selectedOrder)}</p>
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
                {Number(getOrderDeliveryFee(selectedOrder.originalOrder || selectedOrder)) > 0 && (
                  <div className="flex justify-between items-center text-slate-300">
                    <span>Delivery Fee:</span>
                    <span className="text-lg font-semibold text-cyan-300">{hotelSettings?.currency || 'PKR'} {getOrderDeliveryFee(selectedOrder.originalOrder || selectedOrder)}</span>
                  </div>
                )}
                {Number(selectedOrder.originalOrder?.serviceCharge || 0) > 0 && Number(selectedOrder.originalOrder?.deliveryCharge || selectedOrder.originalOrder?.deliveryFee || 0) > 0 && (
                  <div className="flex justify-between items-center text-slate-300">
                    <span>Service Charge:</span>
                    <span className="text-lg font-semibold text-cyan-300">{hotelSettings?.currency || 'PKR'} {selectedOrder.originalOrder?.serviceCharge || 0}</span>
                  </div>
                )}
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

function OrderCard({ order, currency = 'PKR', onViewSlip, status, actions = [], extraActions = [] }) {
  const original = order.originalOrder || order || {};
  const deliveryFee = Number(original.deliveryCharge || original.deliveryFee || original.serviceCharge || 0);

  return (
    <div className="bg-white rounded-lg shadow p-4 border border-gray-200">
      <div className="flex justify-between items-start mb-3">
        <div>
          <p className="text-lg font-bold text-gray-900">Order #{getDisplayOrderNumber(order)}</p>
          <p className="text-sm text-gray-600">
            {order.originalOrder?.customerName || 'Customer'}
          </p>
          <p className="text-xs text-gray-500 mt-1">
            {order.originalOrder?.address || order.originalOrder?.deliveryAddress || 'No address'} · {order.originalOrder?.serviceType || 'No service type'}
          </p>
          {deliveryFee > 0 && (
            <p className="text-xs text-gray-500 mt-1">
              Delivery fee: {currency} {deliveryFee}
            </p>
          )}
        </div>
        <span className="bg-blue-100 text-blue-800 text-xs px-2 py-1 rounded">{status}</span>
      </div>

      <div className="bg-gray-50 p-3 rounded mb-3">
        <p className="text-sm text-gray-700">
          <strong>Items:</strong> {order.originalOrder?.items?.length || 0}
        </p>
        <p className="text-sm text-gray-700">
          <strong>Total:</strong> {currency} {order.originalOrder?.total || 0}
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
