import { useEffect, useMemo, useRef, useState, startTransition } from 'react';
import { Lock, Bluetooth, BluetoothConnected } from 'lucide-react';
import { RidersApp } from './components/RidersApp';
import { buildEscposReceipt, renderReceiptToCanvas, canvasToEscposRaster, CMD } from './utils/escpos.js';
import { requestBluetoothPrinter, printToBluetooth, getSavedPrinterInfo, clearPrinterInfo, autoConnectSavedPrinter } from './utils/btPrint.js';

const envApiBase = import.meta.env.VITE_API_BASE || '';
const apiBase = envApiBase
  ? envApiBase.replace(/\/$/, '')
  : '/api';


function App() {
  const initialPath = typeof window !== 'undefined' ? window.location.pathname.toLowerCase() : '';
  const isMobileRiderRoute = initialPath.startsWith('/rider');
  const isHelperRoute = initialPath.startsWith('/helper');
  const defaultTabs = ['dashboard', 'pos', 'orders', 'rider-book', 'rider-order-requests', 'tables', 'inventory', 'staff', 'sales', 'catalogue-qr', 'customers', 'riders-app', 'settings'];
  const [tabs, setTabs] = useState(() => {
    if (typeof window === 'undefined') return defaultTabs;
    try {
      const saved = window.localStorage.getItem('posTabs');
      return saved ? JSON.parse(saved) : defaultTabs;
    } catch {
      return defaultTabs;
    }
  });
  const [activeTab, setActiveTab] = useState(isMobileRiderRoute ? 'riders-app' : isHelperRoute ? 'pos' : 'dashboard');
  const [isMobile, setIsMobile] = useState(false);
  const [helperRouteVisited, setHelperRouteVisited] = useState(false);
  const [loading, setLoading] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [dashboard, setDashboard] = useState(null);
  const [datePreset, setDatePreset] = useState('today');
  const [showDatePickerDropdown, setShowDatePickerDropdown] = useState(false);
  const [dashboardFilters, setDashboardFilters] = useState(() => {
    const today = new Date();
    const yyyy = today.getFullYear();
    const mm = String(today.getMonth() + 1).padStart(2, '0');
    const dd = String(today.getDate()).padStart(2, '0');
    const todayStr = `${yyyy}-${mm}-${dd}`;
    return { start: todayStr, end: todayStr };
  });
  const [items, setItems] = useState([]);
  const [showAuthPassword, setShowAuthPassword] = useState(false);
  const [settings, setSettings] = useState({
    hotelName: '',
    currency: '',
    location: '',
    taxRate: 0,
    logo: '',
    receiptLogoWidth: '120',
    receiptHeader: '',
    receiptCounterLabel: '',
    receiptFooter: '',
    receiptFontTitle: '',
    posHeaderSubtitle: 'POS Header',
    posHeaderTitle: 'POS Counter',
    posHeaderPhoto: '',
    developerPhoto: '',
    riderAppTitle: 'Rider Portal',
    riderAppSubtitle: 'Fast delivery management for riders',
    riderAppLoginNote: 'Login to continue',
    riderAppLogo: '',
    riderAppAvatar: '',
    loginAppLogo: '',
    receiptFontSize: '12',
    receiptFontStyle: 'Arial',
    receiptLineStyle: 'dashed',
    receiptDateTimeFormat: 'DD/MM/YYYY HH:mm',
    slipPrefix: 'usmanhotel',
    receiptTemplate: 'classic',
    receiptLanguage: 'English',
    receiptShowReceiptNumber: true,
    receiptShowDateTime: true,
    receiptShowCustomerName: true,
    receiptShowCustomerPhone: true,
    receiptShowDeliveryAddress: true,
    receiptShowRiderName: true,
    receiptShowWaiterName: true,
    receiptShowProductArea: true,
    receiptShowProductQuantity: true,
    receiptShowProductUnitPrice: true,
    receiptShowSubtotal: true,
    receiptShowDeliveryCharge: true,
    receiptShowServiceCharge: true,
    receiptShowTax: true,
    receiptShowDiscount: true,
    receiptShowTotal: true,
    receiptShowCustomerMessage: true,
    receiptShowNotes: true,
    receiptFontFamily: 'Arial',
    tokenSlipEnabled: true,
    tokenSlipPrefix: 'TS',
    tokenSlipNextNumber: 1,
    receiptFontSizes: {
      title: 16,
      section: 14,
      product: 12,
      customer: 12,
      notes: 11
    },
    printDeliveryAddress: true,
    printCustomerMobile: true,
    printSubtotal: true,
    printTotal: true,
    printTax: true,
    holdAutoRefreshSeconds: 24,
    holdDefaultViewMode: 'table',
    holdShowAutoRefresh: true,
    receiptPaperWidth: '58',
    btPrintEnabled: false,
    btFontSize: 20,
    btDividerStyle: 'dashed',
    btFontFamily: 'Noto Naskh Arabic, Segoe UI, Arial, sans-serif',
    btTotalFontSize: 26,
    btProductFontSize: 20,
    btTitleFontSize: 18,
    btSectionFontSize: 14,
    btCustomerFontSize: 12,
    btNotesFontSize: 11,
    btLogoEnabled: true,
    btLogoWidth: '80',
    btEncoding: 'bmp',
    btOrderTypeFontSize: 18,
    btServiceTypeFontSize: 16,
    btTokenFontSize: 44,
    btTextAlign: 'left',
    btMarginTop: 10,
    btMarginBottom: 10,
    btMarginCustom: false,
    btTokenLabelFontSize: 14,
    btReceiptHeader: '',
    btReceiptFooter: '',
    btShowTokenOnReceipt: true,
    btShowTotalOnToken: true,
    btTokenOnReceipt: true
  });
  const [form, setForm] = useState({});
  const [message, setMessage] = useState('');
  const [authMessage, setAuthMessage] = useState('');
  // Require manual login on app open — don't auto-use stored token
  const [token, setToken] = useState('');
  const [user, setUser] = useState(null);
  const [authForm, setAuthForm] = useState({ name: '', email: '', password: '' });

  const copyAppLink = async () => {
    const link = `${window.location.origin}`;
    try {
      if (navigator.clipboard?.writeText) {
        await navigator.clipboard.writeText(link);
      } else {
        const textarea = document.createElement('textarea');
        textarea.value = link;
        document.body.appendChild(textarea);
        textarea.select();
        document.execCommand('copy');
        document.body.removeChild(textarea);
      }
      setMessage(`App link copied to clipboard: ${link}`);
    } catch (error) {
      setMessage(`Unable to copy app link. Use: ${link}`);
    }
  };

  const copyHelperLink = async () => {
    const link = `${window.location.origin}/helper`;
    try {
      if (navigator.clipboard?.writeText) {
        await navigator.clipboard.writeText(link);
      } else {
        const textarea = document.createElement('textarea');
        textarea.value = link;
        document.body.appendChild(textarea);
        textarea.select();
        document.execCommand('copy');
        document.body.removeChild(textarea);
      }
      setMessage(`Helper app link copied to clipboard: ${link}`);
    } catch (error) {
      setMessage(`Unable to copy helper link. Use: ${link}`);
    }
  };

  const copyRiderAppLink = async () => {
    const link = `${window.location.origin}/rider`;
    try {
      if (navigator.clipboard?.writeText) {
        await navigator.clipboard.writeText(link);
      } else {
        const textarea = document.createElement('textarea');
        textarea.value = link;
        document.body.appendChild(textarea);
        textarea.select();
        document.execCommand('copy');
        document.body.removeChild(textarea);
      }
      setMessage(`Rider app link copied to clipboard: ${link}`);
    } catch (error) {
      setMessage(`Unable to copy rider link. Use: ${link}`);
    }
  };
  const [posCategories, setPosCategories] = useState([]);
  const [posProducts, setPosProducts] = useState([]);
  const [posTables, setPosTables] = useState([]);
  const [posDeliveryAgents, setPosDeliveryAgents] = useState([]);
  const [staff, setStaff] = useState([]);
  const [posOrders, setPosOrders] = useState([]);
  const [shiftRiderId, setShiftRiderId] = useState('');
  const [shiftActionLoading, setShiftActionLoading] = useState(false);
  const [customers, setCustomers] = useState([]);
  const [editingCustomer, setEditingCustomer] = useState(null);
  const [customerForm, setCustomerForm] = useState({ name: '', phone: '', address: '', serviceType: '' });
  const [pageSize, setPageSize] = useState(20);
  const [pageIndex, setPageIndex] = useState(0);
  const [selectedCustomerIds, setSelectedCustomerIds] = useState(new Set());
  const [serviceTypeFilter, setServiceTypeFilter] = useState('all');
  const [showNewCustomerModal, setShowNewCustomerModal] = useState(false);
  const MASHALLAH_CATEGORY = 'مَا شَاءَ ٱللَّٰهُ';
  const [selectedCategory, setSelectedCategory] = useState(MASHALLAH_CATEGORY);
  const loadStoredMashallahSlots = () => {
    const defaultSlots = Array.from({ length: 20 }, (_, index) => ({ slot: index + 1, productId: null }));
    try {
      const stored = JSON.parse(localStorage.getItem('mashallahSlots') || 'null');
      if (!Array.isArray(stored)) return defaultSlots;
      const normalized = stored.slice(0, 20).map((slot, index) => ({
        slot: slot?.slot || index + 1,
        productId: slot?.productId ?? null
      }));
      if (normalized.length < 20) {
        return [...normalized, ...defaultSlots.slice(normalized.length)];
      }
      return normalized;
    } catch {
      return defaultSlots;
    }
  };
  const [mashallahSlots, setMashallahSlots] = useState(loadStoredMashallahSlots);
  const [activeMashallahSlot, setActiveMashallahSlot] = useState(null);
  const [showMashallahSelector, setShowMashallahSelector] = useState(false);
  const [mashallahSearch, setMashallahSearch] = useState('');
  const eventSourceRef = useRef(null);
  const pollingRef = useRef(null);

  const normalizeText = (value) => String(value || '').trim().toLowerCase();
  const getTableLabel = (table) => String(table.label || table.name || table.number || `Table ${table.id}`);

  const Sparkline = ({ values = [], color = '#34D399', width = 120, height = 36 }) => {
    if (!values || values.length === 0) return <div style={{ width, height }} />;
    const max = Math.max(...values, 1);
    const w = width;
    const h = height;
    const points = values.map((v, i) => {
      const x = (i / (values.length - 1 || 1)) * (w - 2) + 1;
      const y = h - ((v / max) * (h - 4) + 2);
      return `${x},${y}`;
    }).join(' ');
    return (
      <svg width={w} height={h} className="inline-block">
        <polyline points={points} fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    );
  };

  const MiniLineChart = ({ lines = [], colors = ['#60A5FA', '#F59E0B', '#34D399'], width = 280, height = 140 }) => {
    const flat = lines.flat();
    const max = Math.max(...flat, 1);
    const w = width;
    const h = height;
    return (
      <svg width={w} height={h} className="w-full overflow-visible">
        {lines.map((series, index) => {
          const color = colors[index] || colors[0];
          const path = series.map((value, i) => {
            const x = series.length === 1 ? w / 2 : (i / (series.length - 1)) * (w - 24) + 12;
            const y = h - ((value / max) * (h - 24) + 12);
            return `${i === 0 ? 'M' : 'L'} ${x} ${y}`;
          }).join(' ');
          return <path key={index} d={path} fill="none" stroke={color} strokeWidth="3" strokeLinecap="round" />;
        })}
      </svg>
    );
  };

  const DashboardProgress = ({ value = 0 }) => (
    <div className="h-2 overflow-hidden rounded-full bg-slate-800">
      <div style={{ width: `${Math.min(100, Math.max(0, value))}%` }} className="h-full rounded-full bg-gradient-to-r from-emerald-400 to-sky-500" />
    </div>
  );

  const availableDineInTables = useMemo(() => {
    const occupiedTableNames = new Set(
      posOrders
        .filter((order) => order.orderType === 'Dine-In' && !['Completed', 'Payment Collected'].includes(normalizeText(order.status)))
        .map((order) => normalizeText(order.tableNumber))
        .filter(Boolean)
    );
    return posTables.filter((table) => !occupiedTableNames.has(normalizeText(getTableLabel(table))));
  }, [posTables, posOrders]);

  const [posSearch, setPosSearch] = useState('');
  const [cart, setCart] = useState([]);
  const [orderType, setOrderType] = useState('Dine-In');
  const [paymentMethod, setPaymentMethod] = useState('Cash');
  const [selectedCartIndex, setSelectedCartIndex] = useState(0);
  const posSearchInputRef = useRef(null);
  const [orderDetails, setOrderDetails] = useState({
    customerName: '',
    phone: '',
    address: '',
    tableNumber: '',
    deliveryAgent: '',
    serviceType: '',
    deliveryFee: 0,
    discount: 0,
    taxPercent: settings.taxRate || 0,
    serviceCharge: 0,
    notes: '',
    paymentStatus: ''
  });
  const [showCustomerDetailsPopup, setShowCustomerDetailsPopup] = useState(false);
  const [showPaymentPopup, setShowPaymentPopup] = useState(false);
  const [popupError, setPopupError] = useState('');
  const [orderModalOpen, setOrderModalOpen] = useState(false);

  const addressSearchResults = useMemo(() => {
    const query = normalizeText(orderDetails.address);
    if (!query) return [];
    return customers.filter((customer) => normalizeText(customer.address).includes(query));
  }, [orderDetails.address, customers]);

  const mashallahSaveTimerRef = useRef(null);

  useEffect(() => {
    localStorage.setItem('mashallahSlots', JSON.stringify(mashallahSlots));
    if (mashallahSaveTimerRef.current) clearTimeout(mashallahSaveTimerRef.current);
    mashallahSaveTimerRef.current = setTimeout(async () => {
      try {
        await fetchJson(`${apiBase}/pos/mashallah-slots`, {
          method: 'PUT',
          body: JSON.stringify(mashallahSlots)
        });
      } catch {
        // silently fail - localStorage is the fallback
      }
    }, 500);
  }, [mashallahSlots]);

  const handleAddressSelect = (customer) => {
    setOrderDetails((prev) => ({
      ...prev,
      address: customer.address,
      phone: customer.phone || prev.phone,
      customerName: customer.name || prev.customerName
    }));
    setPopupError('');
  };

  const mashallahProducts = useMemo(() => {
    return mashallahSlots
      .map((slot) => {
        const product = posProducts.find((item) => item.id === slot.productId);
        return product ? { ...product, mashallahSlot: slot.slot } : null;
      })
      .filter(Boolean);
  }, [mashallahSlots, posProducts]);

  const openMashallahSelector = (slot) => {
    setActiveMashallahSlot(slot);
    setMashallahSearch('');
    setShowMashallahSelector(true);
  };

  const assignProductToMashallah = (slotNumber, product) => {
    setMashallahSlots((prev) => prev.map((slot) => (slot.slot === slotNumber ? { ...slot, productId: product.id } : slot)));
    setShowMashallahSelector(false);
    setActiveMashallahSlot(null);
  };

  const clearMashallahSlot = (slotNumber) => {
    setMashallahSlots((prev) => prev.map((slot) => (slot.slot === slotNumber ? { ...slot, productId: null } : slot)));
  };

  const handleAddNewAddress = () => {
    const address = orderDetails.address.trim();
    if (!address) {
      setPopupError('Enter an address before adding a new customer.');
      return;
    }
    const exists = customers.some((customer) => normalizeText(customer.address) === normalizeText(address));
    if (exists) {
      setPopupError('This address already exists in your customer list.');
      return;
    }
    const newCustomer = { name: '', phone: orderDetails.phone || '', address };
    setLoading(true);
    persistCustomer(newCustomer)
      .then((created) => {
        if (created) {
          setCustomers((prev) => [...prev, created]);
          setPopupError('Address added to customer list.');
        } else {
          setPopupError('Failed to add address.');
        }
      })
      .catch((error) => {
        setPopupError(error.message || 'Failed to add address.');
      })
      .finally(() => setLoading(false));
  };
  const [editingOrder, setEditingOrder] = useState(null);
  const [currentSavedOrder, setCurrentSavedOrder] = useState(null);
  const [editingOrderCart, setEditingOrderCart] = useState([]);
  const [orderEditForm, setOrderEditForm] = useState({
    orderType: 'Dine-In',
    customerName: '',
    phone: '',
    address: '',
    tableNumber: '',
    deliveryAgent: '',
    serviceType: '',
    deliveryFee: 0,
    discount: 0,
    taxPercent: settings.taxRate || 0,
    serviceCharge: 0,
    paymentMethod: 'Cash',
    notes: '',
    status: ''
  });
  const [holdModalOpen, setHoldModalOpen] = useState(false);
  const [holdTab, setHoldTab] = useState('takeaway');
  const [holdSearch, setHoldSearch] = useState('');
  const [holdStatusFilter, setHoldStatusFilter] = useState('all');
  const [holdViewMode, setHoldViewMode] = useState(settings.holdDefaultViewMode || 'table');
  const [holdRefreshTimer, setHoldRefreshTimer] = useState(settings.holdAutoRefreshSeconds || 24);
  const [inventorySubTab, setInventorySubTab] = useState('categories');
  const [showProductModal, setShowProductModal] = useState(false);
  const [productForm, setProductForm] = useState({
    name: '',
    category: '',
    price: '',
    purchasePrice: '',
    unit: 'PKR',
    photo: '',
    code: '',
    stock: '',
    flavors: [],
    newFlavor: '',
    currentFlavorIndex: null,
    newVariant: '',
    newVariantPrice: ''
  });
  const [productNameInputMode, setProductNameInputMode] = useState('text');
  const [productNameOcrPhoto, setProductNameOcrPhoto] = useState('');
  const [productNameOcrLoading, setProductNameOcrLoading] = useState(false);
  const [selectedCartProduct, setSelectedCartProduct] = useState(null);
  const [selectedWeightOption, setSelectedWeightOption] = useState(null);
  const [selectedFlavorOption, setSelectedFlavorOption] = useState(null);
  const [showWeightPopup, setShowWeightPopup] = useState(false);
  const [showFlavorPopup, setShowFlavorPopup] = useState(false);
  const [ordersMainTab, setOrdersMainTab] = useState('delivery');
  // default to show all delivery orders as requested
  const [deliverySubTab, setDeliverySubTab] = useState('all');
  const [deliveryDateFilter, setDeliveryDateFilter] = useState('today');
  const [deliveryCustomDateFrom, setDeliveryCustomDateFrom] = useState(() => new Date().toISOString().slice(0, 10));
  const [deliveryCustomDateTo, setDeliveryCustomDateTo] = useState(() => new Date().toISOString().slice(0, 10));
  const [takeawaySubTab, setTakeawaySubTab] = useState('all');
  const [takeawayDateFilter, setTakeawayDateFilter] = useState('today');
  const [takeawayCustomDateFrom, setTakeawayCustomDateFrom] = useState(() => new Date().toISOString().slice(0, 10));
  const [takeawayCustomDateTo, setTakeawayCustomDateTo] = useState(() => new Date().toISOString().slice(0, 10));
  const [takeawayPageIndex, setTakeawayPageIndex] = useState(0);
  const [takeawayPageSize, setTakeawayPageSize] = useState(10);
  const [dineinSubTab, setDineinSubTab] = useState('tables');
  const [deliverySettingsSubTab, setDeliverySettingsSubTab] = useState('serviceTypes');
  const [deliveryViewMode, setDeliveryViewMode] = useState('table');
  const [takeawayViewMode, setTakeawayViewMode] = useState('table');
  const [selectedRider, setSelectedRider] = useState('');
  const [bulkRiderAssignmentOpen, setBulkRiderAssignmentOpen] = useState(false);
  const [orderFilterRider, setOrderFilterRider] = useState('');
  const [orderFilterPayment, setOrderFilterPayment] = useState('');
  const [orderPageIndex, setOrderPageIndex] = useState(0);
  // default per-page to 20; pagination options will include 20,50,100 and All
  const [orderPageSize, setOrderPageSize] = useState(20);
  const [deliveryLoading, setDeliveryLoading] = useState(false);
  const [recentOrderTab, setRecentOrderTab] = useState('Delivery');
  const [recentOrderDateFilter, setRecentOrderDateFilter] = useState('today');
  const [recentOrderCustomDate, setRecentOrderCustomDate] = useState(() => new Date().toISOString().slice(0, 10));
  const [recentOrderPageIndex, setRecentOrderPageIndex] = useState(0);
  const [recentOrderPageSize, setRecentOrderPageSize] = useState(12);
  const [darkMode, setDarkMode] = useState(false);
  const [posTheme, setPosTheme] = useState('classic'); // 'classic' or 'restaurant'
  const [sidebarExpanded, setSidebarExpanded] = useState(false);
  const [showPosSettings, setShowPosSettings] = useState(false);
  const [orderTypeStars, setOrderTypeStars] = useState(null);
  const [orderTypeNotif, setOrderTypeNotif] = useState(null);
  const [starKey, setStarKey] = useState(0);
  const [showRecentOrdersPopup, setShowRecentOrdersPopup] = useState(false);
  const [btDevice, setBtDevice] = useState(null);
  const [btInfo, setBtInfo] = useState(getSavedPrinterInfo);
  const [btConnected, setBtConnected] = useState(false);
  const [btPrintMode, setBtPrintMode] = useState(false);
  const [btConnecting, setBtConnecting] = useState(false);
  const [posTopBarMoved, setPosTopBarMoved] = useState(false);
  const [posTopSettings, setPosTopSettings] = useState(() => {
    try {
      const saved = window.localStorage.getItem('posTopSettings');
      return saved ? JSON.parse(saved) : {
        showSearch: true,
        showProfile: true,
        showCategories: true,
        categoryIconSize: 'md',
        categorySpacing: 'normal',
        hideScrollbar: true,
        stickyHeader: true,
      };
    } catch { return {
      showSearch: true, showProfile: true, showCategories: true,
      categoryIconSize: 'md', categorySpacing: 'normal',
      hideScrollbar: true, stickyHeader: true,
    };}
  });
  const [isMobileSidebar, setIsMobileSidebar] = useState(false);
  const [riderAssignmentModal, setRiderAssignmentModal] = useState(null);
  const [catalogueQrSubTab, setCatalogueQrSubTab] = useState('qr');
  const [catalogueLayout, setCatalogueLayout] = useState({
    theme: 'dark',
    columns: 3,
    showPrices: true,
    showCategories: true,
    accentColor: '#10b981',
    pageTitle: 'Usman Hotel Menu',
    pageDescription: 'Scan to open the hotel menu catalogue',
    layoutStyle: 'grid'
  });
  const [catalogueHost, setCatalogueHost] = useState('');
  const [cataloguePath, setCataloguePath] = useState('catalogue');
  const [catalogueAssignedCategories, setCatalogueAssignedCategories] = useState([]);

  useEffect(() => {
    const updateMobile = () => setIsMobile(typeof window !== 'undefined' && window.innerWidth <= 900);
    if (typeof window === 'undefined') return;
    updateMobile();
    window.addEventListener('resize', updateMobile);
    return () => window.removeEventListener('resize', updateMobile);
  }, []);

  // If the app was opened via /rider link, clear any existing rider token
  useEffect(() => {
    try {
      if (isMobileRiderRoute && typeof window !== 'undefined') {
        // Ensure riders must enter credentials on link open
        localStorage.removeItem('riderToken');
      }
    } catch (e) {
      // ignore
    }
  }, [isMobileRiderRoute]);

  // Version check - detect new deployments and refresh app
  useEffect(() => {
    if (typeof window === 'undefined') return;
    
    const checkForNewVersion = async () => {
      try {
        // Get all script tags to detect build changes
        const scripts = Array.from(document.querySelectorAll('script[src*="assets"]'))
          .map(s => s.src)
          .sort()
          .join('|');
        
        const versionKey = 'posAppBuildVersion';
        const storedVersion = localStorage.getItem(versionKey);
        
        if (storedVersion && storedVersion !== scripts && scripts) {
          // Build version changed - new deployment detected
          console.log('New app version detected');
          
          // Clear all POS app related data to force fresh load
          const keysToKeep = ['riderToken', 'riderLoginToken'];
          Object.keys(localStorage).forEach(key => {
            if (!keysToKeep.includes(key)) {
              localStorage.removeItem(key);
            }
          });
          
          // Update version and reload
          localStorage.setItem(versionKey, scripts);
          
          // Auto-reload to get fresh version
          setTimeout(() => {
            window.location.reload();
          }, 500);
        } else if (!storedVersion && scripts) {
          // First load - store version
          localStorage.setItem(versionKey, scripts);
        }
      } catch (err) {
        console.debug('Version check error:', err.message);
      }
    };

    // Check immediately on mount
    checkForNewVersion();
    
    // Also check periodically
    const interval = setInterval(checkForNewVersion, 2 * 60 * 1000);
    return () => clearInterval(interval);
  }, []);

  const [catalogueAssignedProducts, setCatalogueAssignedProducts] = useState({});
  const [catalogueAssignCategory, setCatalogueAssignCategory] = useState('');
  const [catalogueAssignSearch, setCatalogueAssignSearch] = useState('');
  const [cataloguePage, setCataloguePage] = useState(false);
  const [catalogueSearch, setCatalogueSearch] = useState('');
  const [catalogueCategory, setCatalogueCategory] = useState('All');
  const [catalogueCart, setCatalogueCart] = useState({});
  const [catalogueCustomer, setCatalogueCustomer] = useState({ name: '', phone: '', address: '' });
  const [catalogueOrderNote, setCatalogueOrderNote] = useState('');
  const [catalogueMessage, setCatalogueMessage] = useState('');
  const [receiptSettingsSubTab, setReceiptSettingsSubTab] = useState('app');

  useEffect(() => {
    if (activeTab === 'rider-root-settings') {
      setActiveTab('settings');
    }
  }, [activeTab]);

  useEffect(() => {
    const path = window.location.pathname.toLowerCase();
    if (/^\/(catalogue|menu|qr)(\/|$|\?)/.test(path)) {
      setCataloguePage(true);
    }
  }, []);

  useEffect(() => {
    if (cataloguePage || !settings.cataloguePath) return;
    const path = window.location.pathname.toLowerCase();
    const customPath = `/${settings.cataloguePath.toLowerCase()}`;
    if (path === customPath || path.startsWith(`${customPath}/`) || path.startsWith(`${customPath}?`)) {
      setCataloguePage(true);
    }
  }, [settings.cataloguePath, cataloguePage]);

  useEffect(() => {
    if (!cataloguePage) return;
    loadSettings();
    loadInventoryData();
  }, [cataloguePage]);

  useEffect(() => {
    // If settings saved from server include catalogue details, initialize local state
    if (settings.catalogueLayout) {
      setCatalogueLayout((prev) => ({ ...prev, ...settings.catalogueLayout }));
    }
    if (settings.catalogueHost) {
      setCatalogueHost(settings.catalogueHost);
    }
    if (settings.cataloguePath) {
      setCataloguePath(settings.cataloguePath);
    }
    if (Array.isArray(settings.catalogueAssignedCategories)) {
      setCatalogueAssignedCategories(settings.catalogueAssignedCategories);
    }
    if (settings.btPrintEnabled && btInfo && !btConnected) {
      setBtPrintMode(true);
    }
    if (settings.catalogueAssignedProducts && typeof settings.catalogueAssignedProducts === 'object') {
      setCatalogueAssignedProducts(settings.catalogueAssignedProducts);
    }
  }, [settings.catalogueLayout, settings.catalogueHost, settings.cataloguePath, settings.catalogueAssignedCategories, settings.catalogueAssignedProducts, settings.btPrintEnabled]);
  const defaultTabLabels = {
    'catalogue-qr': 'Catalogue QR',
    'rider-book': 'Rider Book',
    'rider-order-requests': 'Rider Order Requests',
    settings: 'Settings'
  };
  const defaultTabIcons = {
    dashboard: '🏠',
    tables: '🍽️',
    inventory: '📦',
    staff: '👤',
    sales: '💰',
    pos: '🛒',
    'catalogue-qr': '🔖',
    customers: '👥',
    orders: '🧾',
    'rider-book': '🚴',
    'rider-order-requests': '📋',
    settings: '⚙️'
  };
  const [tabIcons, setTabIcons] = useState(() => {
    if (typeof window === 'undefined') return defaultTabIcons;
    try {
      const saved = window.localStorage.getItem('posTabIcons');
      return saved ? JSON.parse(saved) : defaultTabIcons;
    } catch {
      return defaultTabIcons;
    }
  });
  const [tabLabels, setTabLabels] = useState(() => {
    if (typeof window === 'undefined') return defaultTabLabels;
    try {
      const saved = window.localStorage.getItem('posTabLabels');
      return saved ? JSON.parse(saved) : defaultTabLabels;
    } catch {
      return defaultTabLabels;
    }
  });
  const formatTabName = (tab) => tabLabels[tab] || tab.replace('-', ' ').replace(/\b\w/g, (l) => l.toUpperCase());
  
  // Category icons mapping
  const categoryIcons = {
    'All': '🎯',
    'Chicken': '🍗',
    'Steak': '🥩',
    'Fish': '🐟',
    'Salad': '🥗',
    'Juice': '🧃',
    'Dessert': '🍰',
    'Burger': '🍔',
    'Pizza': '🍕',
    'Soup': '🍜',
    'Biryani': '🍚'
  };

  const [editingRoleTabs, setEditingRoleTabs] = useState(null);
  const [newTabKey, setNewTabKey] = useState('');
  const [newTabLabel, setNewTabLabel] = useState('');

  function canAccessTab(tab) {
    if (!user) return false;
    const roleName = (user.role || '').toString().trim();
    if (!roleName) return false;
    if (roleName.toLowerCase().includes('admin')) return true;
    const roleObj = roles.find((r) => (r.name || '').toString().trim().toLowerCase() === roleName.toLowerCase());
    if (!roleObj) return false;
    return Boolean(roleObj.permissions && roleObj.permissions[tab]);
  }

  function getDefaultTabForRole(roleName) {
    const cleanName = (roleName || '').toString().trim().toLowerCase();
    if (!cleanName) return 'dashboard';
    if (cleanName.includes('admin')) return 'dashboard';
    if (cleanName === 'cashier') return canAccessTab('pos') ? 'pos' : tabs.find((tab) => canAccessTab(tab));
    if (canAccessTab('dashboard')) return 'dashboard';
    if (canAccessTab('pos')) return 'pos';
    return tabs.find((tab) => canAccessTab(tab)) || 'dashboard';
  }

  function addTab(key, label) {
    const k = (key || '').toString().trim();
    if (!k) return setMessage('Tab key is required');
    if (tabs.includes(k)) return setMessage('Tab key already exists');
    setTabs((prev) => [...prev, k]);
    setTabLabels((prev) => ({ ...prev, [k]: label || k.replace('-', ' ') }));
    setTabIcons((prev) => ({ ...prev, [k]: '•' }));
    // add permission flag to all roles (default false)
    setRoles((prev) => prev.map((r) => ({ ...r, permissions: { ...r.permissions, [k]: false } })));
    setNewTabKey('');
    setNewTabLabel('');
    setMessage(`Added tab ${k}`);
  }

  function removeTab(key) {
    if (!confirm(`Remove tab '${key}' from app? This will remove permissions for all roles.`)) return;
    setTabs((prev) => prev.filter((t) => t !== key));
    setTabLabels((prev) => {
      const copy = { ...prev };
      delete copy[key];
      return copy;
    });
    setTabIcons((prev) => {
      const copy = { ...prev };
      delete copy[key];
      return copy;
    });
    setRoles((prev) => prev.map((r) => ({ ...r, permissions: Object.fromEntries(Object.entries(r.permissions).filter(([p]) => p !== key)) })));
    setMessage(`Removed tab ${key}`);
  }
  const [deliveryServiceTypes, setDeliveryServiceTypes] = useState([]);
  const [deliveryLocations, setDeliveryLocations] = useState([]);
  const [deliveryServiceForm, setDeliveryServiceForm] = useState({ id: null, name: '', charge: 50, location: '', active: true });
  const [deliveryLocationForm, setDeliveryLocationForm] = useState({ id: null, name: '', description: '' });
  const [selectedOrders, setSelectedOrders] = useState([]);
  const [selectedTakeawayOrders, setSelectedTakeawayOrders] = useState([]);
  const [orderSearch, setOrderSearch] = useState('');
  const [viewOrderModal, setViewOrderModal] = useState(null);
  const [orderDetailsModal, setOrderDetailsModal] = useState(null);
  const [deleteConfirmOpen, setDeleteConfirmOpen] = useState(false);
  const [orderToDelete, setOrderToDelete] = useState(null);

  function playBeep(freq = 440, duration = 120) {
    try {
      const AudioCtx = window.AudioContext || window.webkitAudioContext;
      const ctx = new AudioCtx();
      const o = ctx.createOscillator();
      const g = ctx.createGain();
      o.type = 'sine';
      o.frequency.value = freq;
      g.gain.value = 0.02;
      o.connect(g);
      g.connect(ctx.destination);
      o.start();
      setTimeout(() => {
        o.stop();
        try { ctx.close(); } catch (e) {}
      }, duration);
    } catch (e) {
      // ignore if audio not supported
    }
  }

  function requestDeleteOrder(order) {
    setOrderToDelete(order);
    setDeleteConfirmOpen(true);
    playBeep(440, 140);
  }

  async function handleConfirmDelete() {
    if (!orderToDelete) return;
    playBeep(880, 140);
    setDeleteConfirmOpen(false);
    const id = orderToDelete.id || orderToDelete;
    setOrderToDelete(null);
    try {
      await deleteOrder(id);
    } catch (e) {
      // deleteOrder reports errors via setMessage
    }
  }

  useEffect(() => {
    setOrderPageIndex(0);
    // brief loading state to make list transitions feel smoother
    setDeliveryLoading(true);
    const _t = setTimeout(() => setDeliveryLoading(false), 180);
    return () => clearTimeout(_t);
  }, [deliverySubTab, orderSearch, orderFilterRider, orderFilterPayment, orderPageSize, deliveryDateFilter, deliveryCustomDateFrom, deliveryCustomDateTo]);

  useEffect(() => {
    if (deliverySubTab !== 'kitchen' && selectedOrders.length > 0) {
      setSelectedOrders([]);
    }
  }, [deliverySubTab]);

  useEffect(() => {
    setTakeawayPageIndex(0);
  }, [takeawaySubTab, takeawayDateFilter, takeawayCustomDateFrom, takeawayCustomDateTo, takeawayPageSize]);

  useEffect(() => {
    setRecentOrderPageIndex(0);
  }, [recentOrderTab, recentOrderPageSize]);

  const openBulkRiderAssignmentModal = () => {
    if (!selectedOrders.length) return;
    setBulkRiderAssignmentOpen(true);
    setSelectedRider('');
  };

  async function assignRiderToSelectedOrders() {
    if (!selectedOrders.length || !selectedRider) return;
    setLoading(true);
    setMessage('');
    try {
      await Promise.all(selectedOrders.map((orderId) =>
        fetchJson(`${apiBase}/pos/orders/${orderId}/assign-rider`, {
          method: 'PUT',
          body: JSON.stringify({ deliveryAgent: selectedRider, status: 'Riders Assigned' })
        })
      ));
      setMessage(`Rider ${selectedRider} assigned to ${selectedOrders.length} orders.`);
      await loadOrdersData();
      setSelectedRider('');
      setBulkRiderAssignmentOpen(false);
      setSelectedOrders([]);
    } catch (error) {
      setMessage(error.message);
    } finally {
      setLoading(false);
    }
  };
  const [riderBookMainTab, setRiderBookMainTab] = useState('live');
  const [riderBookSubTab, setRiderBookSubTab] = useState('cash');
  const [deliveryPaymentStatusFilter, setDeliveryPaymentStatusFilter] = useState('all');
  const [riderBookFilterRider, setRiderBookFilterRider] = useState('');
  const [riderBookDateFilter, setRiderBookDateFilter] = useState('today');
  const [riderBookCustomDateFrom, setRiderBookCustomDateFrom] = useState(() => new Date().toISOString().slice(0, 10));
  const [riderBookCustomDateTo, setRiderBookCustomDateTo] = useState(() => new Date().toISOString().slice(0, 10));
  const [riderBookSelectedOrders, setRiderBookSelectedOrders] = useState([]);
  const [riderBookSearch, setRiderBookSearch] = useState('');
  const [riderBookPageSize, setRiderBookPageSize] = useState(15);
  const [riderBookPageIndex, setRiderBookPageIndex] = useState(0);
  const [riderBookActionOpen, setRiderBookActionOpen] = useState(null);
  const [showRiderBookSummaryModal, setShowRiderBookSummaryModal] = useState(false);
  const [riderBookSummaryType, setRiderBookSummaryType] = useState('cash');
  const [riderBookSummaryData, setRiderBookSummaryData] = useState(null);
  const [pendingRequests, setPendingRequests] = useState([]);
  const [riderOrderRequestsMainTab, setRiderOrderRequestsMainTab] = useState('requests');
  const [riderOrderRequestsStatus, setRiderOrderRequestsStatus] = useState('pending');
  const [riderOrderRequestsDateFilter, setRiderOrderRequestsDateFilter] = useState('today');
  const [riderOrderRequestsCustomDateFrom, setRiderOrderRequestsCustomDateFrom] = useState('');
  const [riderOrderRequestsCustomDateTo, setRiderOrderRequestsCustomDateTo] = useState('');
  const [ridersList, setRidersList] = useState([]);
  const [editingProduct, setEditingProduct] = useState(null);
  const [editingCategory, setEditingCategory] = useState(null);
  const [showTableModal, setShowTableModal] = useState(false);
  const [editingTable, setEditingTable] = useState(null);
  const [tableForm, setTableForm] = useState({ label: '', section: 'Floor', type: 'Table', location: '', capacity: 4, status: 'available' });
  const [tableSectionFilter, setTableSectionFilter] = useState('Floor');
  const [dineinDateFrom, setDineinDateFrom] = useState('');
  const [dineinDateTo, setDineinDateTo] = useState('');
  const [dineinOrderSearch, setDineinOrderSearch] = useState('');
  const [dineinOrderStatusFilter, setDineinOrderStatusFilter] = useState('all');
  const [dineinPageIndex, setDineinPageIndex] = useState(0);
  const [dineinPageSize, setDineinPageSize] = useState(8);
  const [selectedDineinOrders, setSelectedDineinOrders] = useState([]);
  const [markPaidOrder, setMarkPaidOrder] = useState(null);
  const [markPaidAmount, setMarkPaidAmount] = useState('');
  const [markPaidMethod, setMarkPaidMethod] = useState('Cash');
  const [markDueOrder, setMarkDueOrder] = useState(null);
  const [markDueAmount, setMarkDueAmount] = useState(0);
  const [markDueMethod, setMarkDueMethod] = useState('Cash');
  const [editingProductSearch, setEditingProductSearch] = useState('');

  const [staffSubTab, setStaffSubTab] = useState('list');
  const [showStaffModal, setShowStaffModal] = useState(false);
  const [editingStaff, setEditingStaff] = useState(null);
  const [staffForm, setStaffForm] = useState({
    name: '',
    otherName: '',
    phone: '',
    username: '',
    password: '',
    role: '',
    facePhoto: '',
    idCardNumber: '',
    idCardFront: '',
    idCardBack: '',
    description: '',
    address: '',
    loginEnabled: true
  });
  const defaultRoles = [
    { name: 'Admin', permissions: { dashboard: true, tables: true, inventory: true, staff: true, sales: true, pos: true, orders: true, settings: true, login: true } },
    { name: 'Admin Rider', permissions: { dashboard: true, tables: true, inventory: true, staff: true, sales: true, pos: true, orders: true, settings: true, login: true } },
    { name: 'Cashier', permissions: { dashboard: false, tables: false, inventory: false, staff: false, sales: false, pos: true, orders: true, settings: false, login: true } },
    { name: 'Manager', permissions: { dashboard: true, tables: true, inventory: true, staff: false, sales: true, pos: true, orders: true, settings: true, login: true } },
    { name: 'Biker', permissions: { dashboard: false, tables: false, inventory: false, staff: false, sales: false, pos: false, orders: true, settings: false, login: true } },
    { name: 'Waiter', permissions: { dashboard: false, tables: false, inventory: false, staff: false, sales: false, pos: false, orders: true, settings: false, login: true } },
    { name: 'Helper', permissions: { dashboard: false, tables: false, inventory: false, staff: false, sales: false, pos: true, orders: true, 'rider-book': true, 'rider-order-requests': true, settings: false, login: true } },
    { name: 'Tandoor Staff', permissions: { dashboard: false, tables: false, inventory: false, staff: false, sales: false, pos: false, orders: false, settings: false, login: true } },
    { name: 'BS', permissions: { dashboard: false, tables: false, inventory: false, staff: false, sales: false, pos: false, orders: false, settings: false, login: true } }
  ];
  const [roles, setRoles] = useState(() => {
    if (typeof window === 'undefined') return defaultRoles;
    try {
      const saved = window.localStorage.getItem('posRoles');
      return saved ? JSON.parse(saved) : defaultRoles;
    } catch {
      return defaultRoles;
    }
  });

  useEffect(() => {
    if (typeof window === 'undefined') return;
    try {
      window.localStorage.setItem('posRoles', JSON.stringify(roles));
      window.localStorage.setItem('posTabs', JSON.stringify(tabs));
      window.localStorage.setItem('posTabLabels', JSON.stringify(tabLabels));
      window.localStorage.setItem('posTabIcons', JSON.stringify(tabIcons));
    } catch {
      // ignore storage errors
    }
  }, [roles, tabs, tabLabels, tabIcons]);

  useEffect(() => {
    try {
      window.localStorage.setItem('posTopSettings', JSON.stringify(posTopSettings));
    } catch {}
  }, [posTopSettings]);

  // Ensure every role has a permission key for every tab (so checkboxes and canAccessTab work)
  useEffect(() => {
    setRoles((prev) => prev.map((role) => {
      const perms = { ...(role.permissions || {}) };
      tabs.forEach((t) => {
        if (!(t in perms)) perms[t] = false;
      });
      return { ...role, permissions: perms };
    }));
  }, [tabs]);

  // Auto-fill delivery fee when a delivery service type is selected
  useEffect(() => {
    if (!orderDetails.serviceType) return;
    const type = deliveryServiceTypes.find((t) => t.name === orderDetails.serviceType || t.id === orderDetails.serviceType);
    if (type) {
      setOrderDetails((prev) => ({ ...prev, deliveryFee: Number(type.charge || prev.deliveryFee) }));
    }
  }, [orderDetails.serviceType, deliveryServiceTypes]);

  useEffect(() => {
    if (token) {
      validateToken();
      loadDeliverySettings();
    }
  }, [token]);

  async function loadCustomers() {
    try {
      const data = await fetchJson(`${apiBase}/pos_customers`);
      setCustomers(Array.isArray(data) ? data : []);
    } catch (error) {
      setMessage(error.message);
    }
  }

  async function persistCustomer(customer) {
    if (!customer) return null;
    try {
      if (customer.id) {
        return await fetchJson(`${apiBase}/pos_customers/${customer.id}`, {
          method: 'PUT',
          body: JSON.stringify(customer)
        });
      }
      return await fetchJson(`${apiBase}/pos_customers`, {
        method: 'POST',
        body: JSON.stringify(customer)
      });
    } catch (error) {
      setMessage(error.message);
      return null;
    }
  }

  async function deleteCustomerFromServer(customerId) {
    if (!customerId) return false;
    try {
      await fetchJson(`${apiBase}/pos_customers/${customerId}`, { method: 'DELETE' });
      return true;
    } catch (error) {
      setMessage(error.message);
      return false;
    }
  }

  useEffect(() => {
    if (user) {
      loadSettings();
      loadTab(activeTab);
    }
  }, [activeTab, user]);

  useEffect(() => {
    if (user) {
      loadCustomers();
    }
  }, [user]);

  useEffect(() => {
    if (user && !canAccessTab(activeTab)) {
      setActiveTab(getDefaultTabForRole(user.role));
    }
  }, [user, activeTab, roles, tabs]);

  useEffect(() => {
    setOrderDetails((prev) => ({ ...prev, taxPercent: settings.taxRate || 0 }));
  }, [settings.taxRate]);

  useEffect(() => {
    setRiderBookPageIndex(0);
  }, [riderBookFilterRider, riderBookSubTab, riderBookSearch, riderBookPageSize, riderBookDateFilter, riderBookCustomDateFrom, riderBookCustomDateTo]);

  const dateDropdownRef = useRef(null);
  useEffect(() => {
    function handleClickOutside(event) {
      if (dateDropdownRef.current && !dateDropdownRef.current.contains(event.target)) {
        setShowDatePickerDropdown(false);
      }
    }
    document.addEventListener("mousedown", handleClickOutside);
    return () => {
      document.removeEventListener("mousedown", handleClickOutside);
    };
  }, [dateDropdownRef]);

  const getDatePresetRange = (preset) => {
    const formatDateStr = (d) => {
      const yyyy = d.getFullYear();
      const mm = String(d.getMonth() + 1).padStart(2, '0');
      const dd = String(d.getDate()).padStart(2, '0');
      return `${yyyy}-${mm}-${dd}`;
    };

    const today = new Date();
    switch (preset) {
      case 'today': {
        const todayStr = formatDateStr(today);
        return { start: todayStr, end: todayStr };
      }
      case 'yesterday': {
        const yesterday = new Date();
        yesterday.setDate(yesterday.getDate() - 1);
        const yesterdayStr = formatDateStr(yesterday);
        return { start: yesterdayStr, end: yesterdayStr };
      }
      case '5days': {
        const fiveDaysAgo = new Date();
        fiveDaysAgo.setDate(fiveDaysAgo.getDate() - 4); // 5 days including today
        return { start: formatDateStr(fiveDaysAgo), end: formatDateStr(today) };
      }
      case 'custom':
      default:
        return { start: '', end: '' };
    }
  };

  const handlePresetSelect = async (preset) => {
    setDatePreset(preset);
    if (preset !== 'custom') {
      const range = getDatePresetRange(preset);
      setDashboardFilters(range);
      await loadTab('dashboard', range);
    }
  };

  const header = useMemo(() => {
    switch (activeTab) {
      case 'tables':
        return 'Table Management';
      case 'inventory':
        return 'Inventory';
      case 'staff':
        return 'Staff Management';
      case 'sales':
        return 'Sales History';
      case 'catalogue-qr':
        return 'Catalogue QR';
      case 'customers':
        return 'Customer Management';
      case 'riders-app':
        return 'Riders App';
      case 'settings':
        return 'Hotel Settings';
      case 'rider-book':
        return 'Rider Book';
      default:
        return 'Hotel Dashboard';
    }
  }, [activeTab]);

  function authHeaders() {
    return token ? { Authorization: `Bearer ${token}` } : {};
  }

  async function fetchJson(url, options = {}) {
    const response = await fetch(url, {
      ...options,
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        ...authHeaders(),
        ...(options.headers || {})
      }
    });

    const text = await response.text();
    if (!response.ok) {
      let errorMessage = response.statusText || 'Server error';
      if (text) {
        try {
          const body = JSON.parse(text);
          errorMessage = body.error || body.message || text;
        } catch {
          errorMessage = text;
        }
      }

      if (response.status === 401) {
        localStorage.removeItem('posToken');
        setToken('');
        setUser(null);
        setAuthMessage('Session expired, please login again.');
      }

      throw new Error(errorMessage || 'Server error');
    }

    if (!text) {
      return {};
    }

    try {
      return JSON.parse(text);
    } catch {
      return {};
    }
  }

  async function validateToken() {
    setLoading(true);
    setAuthMessage('');
    try {
      const data = await fetchJson(`${apiBase}/auth/me`);
      setUser(data);
      setAuthMessage('');
      // reload any persisted roles/tabs in case they were modified
      try {
        const savedRoles = window.localStorage.getItem('posRoles');
        if (savedRoles) setRoles(JSON.parse(savedRoles));
        const savedTabs = window.localStorage.getItem('posTabs');
        if (savedTabs) setTabs(JSON.parse(savedTabs));
        const savedTabLabels = window.localStorage.getItem('posTabLabels');
        if (savedTabLabels) setTabLabels(JSON.parse(savedTabLabels));
        const savedTabIcons = window.localStorage.getItem('posTabIcons');
        if (savedTabIcons) setTabIcons(JSON.parse(savedTabIcons));
      } catch (e) {
        // ignore
      }
    } catch (error) {
      setAuthMessage('Session expired, please login again.');
      localStorage.removeItem('posToken');
      setToken('');
      setUser(null);
    } finally {
      setLoading(false);
    }
  }

  async function login() {
    setLoading(true);
    setAuthMessage('');
    try {
      const data = await fetchJson(`${apiBase}/auth/login`, {
        method: 'POST',
        body: JSON.stringify(authForm)
      });
      localStorage.setItem('posToken', data.token);
      setToken(data.token);
      setUser(data.user);
      // reload persisted roles/tabs so permissions immediately apply
      try {
        const savedRoles = window.localStorage.getItem('posRoles');
        if (savedRoles) setRoles(JSON.parse(savedRoles));
        const savedTabs = window.localStorage.getItem('posTabs');
        if (savedTabs) setTabs(JSON.parse(savedTabs));
        const savedTabLabels = window.localStorage.getItem('posTabLabels');
        if (savedTabLabels) setTabLabels(JSON.parse(savedTabLabels));
        const savedTabIcons = window.localStorage.getItem('posTabIcons');
        if (savedTabIcons) setTabIcons(JSON.parse(savedTabIcons));
      } catch (e) {}
      setActiveTab(getDefaultTabForRole(data.user.role));
      setMessage('Logged in successfully');
    } catch (error) {
      setAuthMessage(error.message);
    } finally {
      setLoading(false);
    }
  }

  function logout() {
    localStorage.removeItem('posToken');
    setToken('');
    setUser(null);
    setAuthForm({ name: '', email: '', password: '' });
    setMessage('Logged out');
  }

  async function loadSettings() {
    try {
      const data = await fetchJson(`${apiBase}/settings`);
      setSettings((prev) => ({
        ...prev,
        ...data,
        receiptFontSizes: {
          ...prev.receiptFontSizes,
          ...(data.receiptFontSizes || {})
        }
      }));
    } catch (error) {
      setMessage(error.message);
    }
  }

  // Google Sheets integration removed

  async function loadTab(tab, overrideFilters = null) {
    setLoading(true);
    setMessage('');
    try {
      if (tab === 'dashboard') {
        const filters = overrideFilters || dashboardFilters;
        const qs = [];
        if (filters.start) qs.push(`start=${encodeURIComponent(filters.start)}`);
        if (filters.end) qs.push(`end=${encodeURIComponent(filters.end)}`);
        const url = `${apiBase}/dashboard${qs.length ? ('?' + qs.join('&')) : ''}`;
        const data = await fetchJson(url);
        setDashboard(data);
        await loadOrdersData();
      } else if (tab === 'settings') {
        await loadSettings();
      } else if (tab === 'inventory') {
        await loadInventoryData();
      } else if (tab === 'tables') {
        const data = await fetchJson(`${apiBase}/pos/tables`);
        setItems(data);
      } else if (tab === 'orders') {
        await loadOrdersData();
      } else if (tab === 'rider-book') {
        await loadOrdersData();
        await loadInventoryData();
      } else if (tab === 'rider-order-requests') {
        await loadPendingRequests();
        await loadStaffMembers();
      } else if (tab === 'riders-app') {
        // Riders App is a self-contained component and does not need generic tab data loading.
      } else if (tab === 'pos' || tab === 'catalogue-qr') {
        await loadPosData();
      } else if (tab === 'customers') {
        await loadCustomers();
        await loadOrdersData();
      } else {
        const data = await fetchJson(`${apiBase}/${tab}`);
        setItems(data);
      }
    } catch (error) {
      setMessage(error.message);
    } finally {
      setLoading(false);
    }
  }

  async function loadOrdersData() {
    setLoading(true);
    setMessage('');
    try {
      const orders = await fetchJson(`${apiBase}/pos/orders`);
      setPosOrders(orders);
      // Aggregate customers from delivery orders
      const deliveryCustomers = orders
        .filter((o) => o.orderType === 'Delivery' && o.address)
        .map((o) => ({ id: o.id, name: o.customerName || '', phone: o.phone || '', address: o.address || '', lastOrderNumber: o.orderNumber || '', serviceType: o.serviceType || '' }))
        .filter((c, index, self) => self.findIndex((sc) => normalizeText(sc.address) === normalizeText(c.address)) === index);
      // Persist any new delivery customers to server and update state
      setCustomers((prev) => {
        const existingAddresses = new Set(prev.map((c) => normalizeText(c.address)));
        const newCustomers = deliveryCustomers.filter((c) => !existingAddresses.has(normalizeText(c.address)));
        if (!newCustomers.length) return prev;
        // Optimistically add them locally with temporary ids, then persist
        const tempAdded = newCustomers.map((c) => ({ id: `temp-${Date.now()}-${Math.random()}`, ...c }));
        // Persist in background
        (async () => {
          try {
            const created = await Promise.all(newCustomers.map((nc) => persistCustomer(nc).catch(() => null)));
            const valid = created.filter(Boolean).map((c) => ({ ...c, _justAdded: true }));
            if (valid.length) {
              setCustomers((current) => {
                const withoutTemp = current.filter((item) => !item.id.toString().startsWith('temp-'));
                return [...valid, ...withoutTemp];
              });
            }
          } catch (err) {
            console.warn('Failed to persist delivery customers', err.message || err);
          }
        })();
        return [...prev, ...tempAdded];
      });
    } catch (error) {
      setMessage(error.message);
    } finally {
      setLoading(false);
    }
  }

  async function loadPendingRequests() {
    try {
      // Ensure we have orders and riders to augment the requests
      if (!posOrders || posOrders.length === 0) {
        await loadOrdersData();
      }
      if (!ridersList || ridersList.length === 0) {
        try {
          const r = await fetchJson(`${apiBase}/riders`);
          setRidersList(Array.isArray(r) ? r : []);
        } catch (e) {
          // ignore
        }
      }

      const data = await fetchJson(`${apiBase}/rider/requests`);
      const list = Array.isArray(data) ? data : [];

      const augmented = list.map((req) => {
        const rider = (ridersList || []).find((r) => r.id === req.riderId) || {};
        const order = (posOrders || []).find((o) => o.id === req.orderId) || null;
        return {
          ...req,
          riderName: rider.name || req.riderId,
          orderNumber: order?.orderNumber || req.orderId,
          orderTotal: order?.total || (order?.subtotal || 0)
        };
      });

      setPendingRequests(augmented);
    } catch (err) {
      console.warn('Failed to load rider requests:', err.message || err);
      setPendingRequests([]);
    }
  }

  async function loadInventoryData() {
    setLoading(true);
    setMessage('');
    try {
      const [categories, products] = await Promise.all([
        fetchJson(`${apiBase}/pos/categories`),
        fetchJson(`${apiBase}/pos/products`)
      ]);
      setPosCategories(categories);
      setPosProducts(products);
    } catch (error) {
      setMessage(error.message);
    } finally {
      setLoading(false);
    }
  }

  async function loadPosData() {
    setLoading(true);
    setMessage('');
    try {
      const [categories, products, tables, agents, staff, orders, riders] = await Promise.all([
        fetchJson(`${apiBase}/pos/categories`),
        fetchJson(`${apiBase}/pos/products`),
        fetchJson(`${apiBase}/pos/tables`),
        fetchJson(`${apiBase}/pos/delivery-agents`),
        fetchJson(`${apiBase}/staff`),
        fetchJson(`${apiBase}/pos/orders`)
        , fetchJson(`${apiBase}/riders`)
      ]);

      setPosCategories(categories);
      setPosProducts(products);
      setPosTables(tables);
      setPosDeliveryAgents([
        ...(agents || []),
        ...((staff || []).filter((member) => member.role === 'Biker' && member.loginEnabled))
      ]);
      setStaff(staff);
      setPosOrders(orders);
      setRidersList(Array.isArray(riders) ? riders : []);
      setSelectedCategory((current) => current === 'All' ? MASHALLAH_CATEGORY : current);
      setPosSearch('');
      loadMashallahSlots();
    } catch (error) {
      setMessage(error.message);
    } finally {
      setLoading(false);
    }
  }

  async function loadMashallahSlots() {
    try {
      const slots = await fetchJson(`${apiBase}/pos/mashallah-slots`);
      if (Array.isArray(slots) && slots.length > 0) {
        const normalized = slots.slice(0, 20).map((s) => ({
          slot: s.slot,
          productId: s.productId ?? null
        }));
        setMashallahSlots(normalized);
        localStorage.setItem('mashallahSlots', JSON.stringify(normalized));
      } else {
        const local = loadStoredMashallahSlots();
        setMashallahSlots(local);
      }
    } catch {
      const local = loadStoredMashallahSlots();
      setMashallahSlots(local);
    }
  }

  async function loadStaffMembers() {
    try {
      const staffData = await fetchJson(`${apiBase}/staff`);
      setStaff(Array.isArray(staffData) ? staffData : []);
    } catch (error) {
      console.warn('Failed to load staff members for shift control:', error.message || error);
    }
  }

  useEffect(() => {
    if (activeTab === 'rider-order-requests' && riderOrderRequestsMainTab === 'shift-control') {
      loadStaffMembers();
    }
  }, [activeTab, riderOrderRequestsMainTab]);

  // Realtime: try Server-Sent Events (SSE) and fallback to polling every 7s
  useEffect(() => {
    const startSse = () => {
      if (typeof window === 'undefined' || !window.EventSource) return false;
      const url = token ? `${apiBase}/events?token=${token}` : `${apiBase}/events`;
      try {
        const es = new EventSource(url);
        eventSourceRef.current = es;
        es.addEventListener('orders', (e) => {
          try {
            const data = JSON.parse(e.data || '[]');
            setPosOrders(Array.isArray(data) ? data : data || []);
          } catch (err) {
            console.warn('Failed to parse SSE orders payload', err);
          }
        });
        es.onopen = () => {
          console.debug('SSE connected to', url);
        };
        es.onerror = (err) => {
          console.warn('SSE error, falling back to polling', err);
          try { es.close(); } catch (e) {}
          eventSourceRef.current = null;
        };
        return true;
      } catch (err) {
        return false;
      }
    };

    // start SSE if possible
    startSse();

    // polling fallback to ensure updates even if SSE unsupported
    const intervalMs = 7000;
    pollingRef.current = setInterval(() => {
      loadOrdersData();
    }, intervalMs);

    return () => {
      if (eventSourceRef.current) {
        try { eventSourceRef.current.close(); } catch (e) {}
        eventSourceRef.current = null;
      }
      if (pollingRef.current) {
        clearInterval(pollingRef.current);
        pollingRef.current = null;
      }
    };
  }, [token]);

  async function approveRiderRequest(requestId) {
    if (!confirm('Approve this rider request?')) return;
    setLoading(true);
    try {
      await fetchJson(`${apiBase}/rider/approve-request/${requestId}`, { method: 'PUT' });
      setMessage('Request approved');
      setRiderOrderRequestsStatus('approved');
      await loadPendingRequests();
      await loadOrdersData();
    } catch (err) {
      setMessage(err.message || 'Failed to approve request');
    } finally {
      setLoading(false);
    }
  }

  async function rejectRiderRequest(requestId) {
    if (!confirm('Reject this rider request?')) return;
    setLoading(true);
    try {
      await fetchJson(`${apiBase}/rider/reject-request/${requestId}`, { method: 'PUT' });
      setMessage('Request rejected');
      setRiderOrderRequestsStatus('rejected');
      await loadPendingRequests();
      await loadOrdersData();
    } catch (err) {
      setMessage(err.message || 'Failed to reject request');
    } finally {
      setLoading(false);
    }
  }

  async function loadDeliverySettings() {
    setLoading(true);
    setMessage('');
    try {
      const [serviceTypes, locations] = await Promise.all([
        fetchJson(`${apiBase}/delivery_service_types`),
        fetchJson(`${apiBase}/delivery_locations`)
      ]);
      setDeliveryServiceTypes(Array.isArray(serviceTypes) ? serviceTypes : []);
      setDeliveryLocations(Array.isArray(locations) ? locations : []);
    } catch (error) {
      setMessage(error.message);
    } finally {
      setLoading(false);
    }
  }

  async function saveCatalogueLayoutSettings() {
    setLoading(true);
    setMessage('');
    try {
      const updated = await fetchJson(`${apiBase}/settings`, {
        method: 'PUT',
        body: JSON.stringify({
          catalogueLayout,
          catalogueHost,
          cataloguePath,
          catalogueAssignedCategories,
          catalogueAssignedProducts
        })
      });
      setSettings((prev) => ({ ...prev, ...updated }));
      setMessage('Catalogue layout settings saved.');
    } catch (error) {
      setMessage(error.message);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    if (holdModalOpen && settings.holdShowAutoRefresh) {
      setHoldRefreshTimer(settings.holdAutoRefreshSeconds || 24);
    }
  }, [holdModalOpen, settings.holdAutoRefreshSeconds, settings.holdShowAutoRefresh]);

  useEffect(() => {
    document.body.style.overflow = (holdModalOpen || orderModalOpen || orderDetailsModal || markPaidOrder || showTableModal || riderAssignmentModal || bulkRiderAssignmentOpen) ? 'hidden' : '';
    return () => {
      document.body.style.overflow = '';
    };
  }, [holdModalOpen, orderModalOpen, orderDetailsModal, markPaidOrder, showTableModal, riderAssignmentModal, bulkRiderAssignmentOpen]);

  useEffect(() => {
    const updateMobile = () => setIsMobileSidebar(window.innerWidth < 768);
    updateMobile();
    window.addEventListener('resize', updateMobile);
    return () => window.removeEventListener('resize', updateMobile);
  }, []);

  useEffect(() => {
    setDineinPageIndex(0);
  }, [dineinDateFrom, dineinDateTo, dineinOrderSearch, dineinOrderStatusFilter, dineinPageSize]);

  useEffect(() => {
    if (dineinSubTab !== 'paid') {
      setSelectedDineinOrders([]);
    }
  }, [dineinSubTab]);

  useEffect(() => {
    if (!holdModalOpen || !settings.holdShowAutoRefresh) return;
    const timer = setInterval(() => {
      setHoldRefreshTimer((prev) => {
        if (prev <= 1) {
          loadPosData();
          return settings.holdAutoRefreshSeconds || 24;
        }
        return prev - 1;
      });
    }, 1000);
    return () => clearInterval(timer);
  }, [holdModalOpen, settings.holdAutoRefreshSeconds, settings.holdShowAutoRefresh]);

  function getFilteredHoldOrders() {
    const searchTerm = holdSearch.toLowerCase();
    return posOrders.filter((order) => {
      const typeMatch = order.orderType === (holdTab === 'takeaway' ? 'Takeaway' : 'Delivery');
      const searchMatch = !searchTerm || [order.orderNumber, order.customerName, order.phone, order.tableNumber, order.deliveryAgent].some((field) => String(field || '').toLowerCase().includes(searchTerm));
      const statusMatch = holdStatusFilter === 'all' || (holdStatusFilter === 'assigned' ? Boolean(order.deliveryAgent || order.tableNumber) : !order.deliveryAgent && !order.tableNumber);
      return typeMatch && searchMatch && statusMatch;
    });
  }

  function getHoldCategoryCounts() {
    const counts = { BBQ: 0, Tandoor: 0 };
    posOrders.forEach((order) => {
      (order.items || []).forEach((item) => {
        if (String(item.category || item.name || '').toLowerCase().includes('bbq')) counts.BBQ += 1;
        if (String(item.category || item.name || '').toLowerCase().includes('tandoor')) counts.Tandoor += 1;
      });
    });
    return counts;
  }

  function handleClearHoldFilters() {
    setHoldSearch('');
    setHoldStatusFilter('all');
    setHoldTab('takeaway');
  }

  function handleMarkAllPaid() {
    setMessage('Marked current hold orders as paid.');
  }

  function handleDeleteAllHold() {
    setMessage('All current hold orders have been cleared from view.');
  }

  async function addRecord() {
    setLoading(true);
    setMessage('');
    try {
      const target = activeTab === 'tables' ? 'pos/tables' : activeTab;
      await fetchJson(`${apiBase}/${target}`, {
        method: 'POST',
        body: JSON.stringify(form)
      });
      setForm({});
      await loadTab(activeTab);
      setMessage('Created successfully');
    } catch (error) {
      setMessage(error.message);
    } finally {
      setLoading(false);
    }
  }

  async function deleteRecord(id, collection = activeTab) {
    setLoading(true);
    setMessage('');
    try {
      const target = collection === 'tables' ? 'pos/tables' : collection;
      await fetchJson(`${apiBase}/${target}/${id}`, { method: 'DELETE' });
      if (collection === 'pos_categories' || collection === 'pos_products') {
        await loadInventoryData();
      } else {
        await loadTab(activeTab);
        // If staff was deleted, refresh POS-related data including riders list
        if (activeTab === 'staff') {
          try {
            await loadPosData();
          } catch (e) {
            // ignore
          }
        }
      }
      setMessage('Deleted successfully');
    } catch (error) {
      setMessage(error.message);
    } finally {
      setLoading(false);
    }
  }

  function openTableModal(table = null) {
    if (table) {
      setEditingTable(table);
      setTableForm({
        label: table.label || '',
        section: table.section || 'Floor',
        type: table.type || 'Table',
        location: table.location || '',
        capacity: table.capacity || 4,
        status: table.status || 'available'
      });
    } else {
      setEditingTable(null);
      setTableForm({ label: '', section: 'Floor', type: 'Table', location: '', capacity: 4, status: 'available' });
    }
    setShowTableModal(true);
  }

  function closeTableModal() {
    setShowTableModal(false);
    setEditingTable(null);
  }

  async function saveTable() {
    setLoading(true);
    setMessage('');
    try {
      const payload = { ...tableForm };
      const method = editingTable ? 'PUT' : 'POST';
      const endpoint = editingTable ? `${apiBase}/pos/tables/${editingTable.id}` : `${apiBase}/pos/tables`;
      await fetchJson(endpoint, { method, body: JSON.stringify(payload) });
      closeTableModal();
      await loadTab('tables');
      setMessage(editingTable ? 'Table updated successfully' : 'Table created successfully');
    } catch (error) {
      setMessage(error.message);
    } finally {
      setLoading(false);
    }
  }

  async function deleteTable(id) {
    await deleteRecord(id, 'tables');
  }

  async function addCategory() {
    setLoading(true);
    setMessage('');
    try {
      await fetchJson(`${apiBase}/pos/categories`, {
        method: 'POST',
        body: JSON.stringify(form)
      });
      setForm({});
      await loadInventoryData();
      setMessage('Category created successfully');
    } catch (error) {
      setMessage(error.message);
    } finally {
      setLoading(false);
    }
  }

  async function addProduct() {
    setLoading(true);
    setMessage('');
    try {
      const { newFlavor, currentFlavorIndex, newVariant, newVariantPrice, ...cleanForm } = productForm;
      const payload = {
        ...cleanForm,
        flavors: productForm.flavors
      };
      await fetchJson(`${apiBase}/pos/products`, {
        method: 'POST',
        body: JSON.stringify(payload)
      });
      setProductForm({ name: '', category: '', price: '', purchasePrice: '', unit: 'PKR', photo: '', code: '', stock: '', flavors: [], newFlavor: '', currentFlavorIndex: null, newVariant: '', newVariantPrice: '' });
      setEditingProduct(null);
      setShowProductModal(false);
      await loadInventoryData();
      setMessage('Product created successfully');
    } catch (error) {
      setMessage(error.message);
    } finally {
      setLoading(false);
    }
  }

  const openProductModal = (product = null) => {
    if (product) {
      setEditingProduct(product);
      setProductForm({
        id: product.id,
        name: product.name || '',
        category: product.category || '',
        price: product.price || '',
        purchasePrice: product.purchasePrice || '',
        unit: product.unit || 'PKR',
        photo: product.photo || '',
        code: product.code || '',
        stock: product.stock || '',
        flavors: Array.isArray(product.flavors) ? product.flavors : [],
        newFlavor: '',
        currentFlavorIndex: null,
        newVariant: '',
        newVariantPrice: ''
      });
    } else {
      setEditingProduct(null);
      setProductForm({ name: '', category: '', price: '', purchasePrice: '', unit: 'PKR', photo: '', code: '', stock: '', flavors: [], newFlavor: '', currentFlavorIndex: null, newVariant: '', newVariantPrice: '' });
    }
    setProductNameInputMode('text');
    setProductNameOcrPhoto('');
    setProductNameOcrLoading(false);
    setShowProductModal(true);
  };

  async function saveProduct() {
    if (!editingProduct) {
      return addProduct();
    }
    setLoading(true);
    setMessage('');
    try {
      const { newFlavor, currentFlavorIndex, newVariant, newVariantPrice, ...cleanForm } = productForm;
      const payload = {
        ...cleanForm,
        flavors: productForm.flavors
      };
      await fetchJson(`${apiBase}/pos/products/${editingProduct.id}`, {
        method: 'PUT',
        body: JSON.stringify(payload)
      });
      setProductForm({ name: '', category: '', price: '', purchasePrice: '', unit: 'PKR', photo: '', code: '', stock: '', flavors: [], newFlavor: '', currentFlavorIndex: null, newVariant: '', newVariantPrice: '' });
      setEditingProduct(null);
      setShowProductModal(false);
      await loadInventoryData();
      setMessage('Product updated successfully');
    } catch (error) {
      setMessage(error.message);
    } finally {
      setLoading(false);
    }
  }

  const openCategoryEdit = (category) => {
    setEditingCategory(category);
    setForm({ name: category.name });
  };

  async function saveCategory() {
    if (!editingCategory) {
      return addCategory();
    }
    setLoading(true);
    setMessage('');
    try {
      await fetchJson(`${apiBase}/pos/categories/${editingCategory.id}`, {
        method: 'PUT',
        body: JSON.stringify(form)
      });
      setEditingCategory(null);
      setForm({});
      await loadInventoryData();
      setMessage('Category updated successfully');
    } catch (error) {
      setMessage(error.message);
    } finally {
      setLoading(false);
    }
  }

  const resizeImageFile = (file, maxWidth = 1200, quality = 0.8) => {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = (event) => {
        const img = new Image();
        img.onload = () => {
          const scale = Math.min(1, maxWidth / img.width);
          const width = img.width * scale;
          const height = img.height * scale;
          const canvas = document.createElement('canvas');
          canvas.width = width;
          canvas.height = height;
          const ctx = canvas.getContext('2d');
          ctx.drawImage(img, 0, 0, width, height);
          const resized = canvas.toDataURL('image/jpeg', quality);
          resolve(resized);
        };
        img.onerror = reject;
        img.src = event.target.result;
      };
      reader.onerror = reject;
      reader.readAsDataURL(file);
    });
  };

  const handleFileChange = async (e) => {
    const file = e.target.files?.[0];
    if (!file || !file.type.startsWith('image/')) return;
    try {
      const photo = await resizeImageFile(file, 1200, 0.8);
      setProductForm((prev) => ({ ...prev, photo }));
    } catch (error) {
      console.error('Image resize failed', error);
      const reader = new FileReader();
      reader.onload = () => {
        setProductForm((prev) => ({ ...prev, photo: reader.result }));
      };
      reader.onerror = () => {
        console.error('Failed to load image file');
      };
      reader.readAsDataURL(file);
    }
  };

  const handleProductNameOcr = async (e) => {
    const file = e.target.files?.[0];
    if (!file || !file.type.startsWith('image/')) return;
    setProductNameOcrLoading(true);
    try {
      const { createWorker } = await import('tesseract.js');
      const worker = await createWorker('urd');
      const { data: { text } } = await worker.recognize(file);
      await worker.terminate();
      setProductForm((prev) => ({ ...prev, name: text.trim() }));
    } catch (error) {
      console.error('OCR failed', error);
      setMessage('OCR failed. Please type the product name manually.');
    } finally {
      setProductNameOcrLoading(false);
      setProductNameOcrPhoto('');
      e.target.value = '';
    }
  };

  const handleProductNameOcrPhotoChange = (e) => {
    const file = e.target.files?.[0];
    if (!file || !file.type.startsWith('image/')) return;
    const reader = new FileReader();
    reader.onload = () => {
      setProductNameOcrPhoto(reader.result);
    };
    reader.readAsDataURL(file);
  };

  const handleSettingsLogoChange = (e) => {
    const file = e.target.files[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = () => {
        setSettings((prev) => ({ ...prev, logo: reader.result }));
      };
      reader.readAsDataURL(file);
    }
  };

  const handleDeveloperPhotoChange = (e) => {
    const file = e.target.files[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = () => {
        setSettings((prev) => ({ ...prev, developerPhoto: reader.result }));
      };
      reader.readAsDataURL(file);
    }
  };

  const handlePosHeaderPhotoChange = (e) => {
    const file = e.target.files[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = () => {
        setSettings((prev) => ({ ...prev, posHeaderPhoto: reader.result }));
      };
      reader.readAsDataURL(file);
    }
  };

  const handleRiderAppLogoChange = (e) => {
    const file = e.target.files[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = () => {
        setSettings((prev) => ({ ...prev, riderAppLogo: reader.result }));
      };
      reader.readAsDataURL(file);
    }
  };

  const handleLoginAppLogoChange = (e) => {
    const file = e.target.files[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = () => {
        setSettings((prev) => ({ ...prev, loginAppLogo: reader.result }));
      };
      reader.readAsDataURL(file);
    }
  };

  const handleRiderAppAvatarChange = (e) => {
    const file = e.target.files[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = () => {
        setSettings((prev) => ({ ...prev, riderAppAvatar: reader.result }));
      };
      reader.readAsDataURL(file);
    }
  };

  async function updateSettings() {
    setLoading(true);
    setMessage('');
    try {
      await fetchJson(`${apiBase}/settings`, {
        method: 'PUT',
        body: JSON.stringify(settings)
      });
      setMessage('Settings saved');
    } catch (error) {
      setMessage(error.message);
    } finally {
      setLoading(false);
    }
  }

  function formatReceiptDate(dateString, format) {
    const date = dateString ? new Date(dateString) : new Date();
    const zero = (value) => String(value).padStart(2, '0');
    const replacements = {
      'DD': zero(date.getDate()),
      'MM': zero(date.getMonth() + 1),
      'YYYY': date.getFullYear(),
      'HH': zero(date.getHours()),
      'mm': zero(date.getMinutes()),
      'ss': zero(date.getSeconds())
    };
    return Object.entries(replacements).reduce((str, [key, value]) => str.replaceAll(key, value), format);
  }



  function getFilteredProducts() {
    const searchTerm = normalizeText(posSearch);
    if (selectedCategory === MASHALLAH_CATEGORY) {
      return mashallahProducts.filter((product) => {
        const matchesSearch =
          normalizeText(product.name).includes(searchTerm) ||
          normalizeText(product.category).includes(searchTerm) ||
          normalizeText(product.code).includes(searchTerm) ||
          normalizeText(product.sku).includes(searchTerm) ||
          normalizeText(product.id).includes(searchTerm);
        return !searchTerm || matchesSearch;
      });
    }

    return posProducts.filter((product) => {
      const matchesCategory = selectedCategory === 'All' || product.category === selectedCategory;
      const matchesSearch =
        normalizeText(product.name).includes(searchTerm) ||
        normalizeText(product.category).includes(searchTerm) ||
        normalizeText(product.code).includes(searchTerm) ||
        normalizeText(product.sku).includes(searchTerm) ||
        normalizeText(product.id).includes(searchTerm);
      return matchesCategory && (!searchTerm || matchesSearch);
    });
  }

  function mergeCartItem(newItem) {
    setCart((prev) => {
      const existingIndex = prev.findIndex(
        (item) =>
          item.productId === newItem.productId &&
          item.weight === newItem.weight &&
          item.flavor === newItem.flavor
      );
      if (existingIndex >= 0) {
        return prev.map((item, idx) =>
          idx === existingIndex
            ? { ...item, quantity: item.quantity + 1, total: (item.quantity + 1) * (Number(item.price) || 0) }
            : item
        );
      }
      return [...prev, newItem];
    });
  }

  useEffect(() => {
    const searchTerm = normalizeText(posSearch);
    if (!searchTerm) return;
    const exactMatch = posProducts.find((product) =>
      normalizeText(product.code) === searchTerm ||
      normalizeText(product.sku) === searchTerm ||
      normalizeText(product.id) === searchTerm
    );
    if (!exactMatch) return;
    addToCart(exactMatch);
    setPosSearch('');
  }, [posSearch, posProducts]);

  useEffect(() => {
    if (selectedCartIndex >= cart.length) {
      setSelectedCartIndex(Math.max(0, cart.length - 1));
    }
  }, [cart, selectedCartIndex]);

  const focusPosSearch = () => {
    posSearchInputRef.current?.focus();
  };

  const handlePosSearchSubmit = () => {
    const trimmedSearch = posSearch.trim();
    if (!trimmedSearch) return;
    const exactMatch = posProducts.find((product) =>
      normalizeText(product.code) === normalizeText(trimmedSearch) ||
      normalizeText(product.sku) === normalizeText(trimmedSearch) ||
      normalizeText(product.id) === normalizeText(trimmedSearch)
    );
    if (exactMatch) {
      addToCart(exactMatch);
      setPosSearch('');
      return;
    }
    const filtered = getFilteredProducts();
    if (filtered.length > 0) {
      addToCart(filtered[0]);
      setPosSearch('');
    }
  };

  const handleCartSelectionKey = (direction) => {
    if (!cart.length) return;
    setSelectedCartIndex((prev) => {
      if (direction === 'up') return Math.max(0, prev - 1);
      if (direction === 'down') return Math.min(cart.length - 1, prev + 1);
      return prev;
    });
  };

  const handleSelectedCartQty = (delta) => {
    if (!cart.length) return;
    const selectedItem = cart[selectedCartIndex];
    if (!selectedItem) return;
    updateCartItem(selectedItem.itemId, delta);
  };

  const handlePosShortcuts = (event) => {
    if (activeTab !== 'pos') return;
    const targetTag = event.target.tagName;
    const isFormField = ['INPUT', 'TEXTAREA', 'SELECT'].includes(targetTag) || event.target.isContentEditable;

    if (event.altKey && !event.ctrlKey && !event.metaKey) {
      switch (event.key.toLowerCase()) {
        case 's':
          event.preventDefault();
          focusPosSearch();
          return;
        case '1':
          event.preventDefault();
          handleSelectOrderType('Dine-In');
          return;
        case '2':
          event.preventDefault();
          handleSelectOrderType('Takeaway');
          return;
        case '3':
          event.preventDefault();
          handleSelectOrderType('Delivery');
          return;
        case 'a':
          event.preventDefault();
          const filtered = getFilteredProducts();
          if (filtered.length) addToCart(filtered[0]);
          return;
        default:
          break;
      }
    }

    if (showCustomerDetailsPopup) {
      if (event.key === 'Escape') {
        event.preventDefault();
        closeCustomerDetailsPopup();
        return;
      }
      if (!isFormField) {
        if (orderType === 'Delivery') {
          if (event.key.toLowerCase() === 'c') {
            event.preventDefault();
            handleDeliveryPaymentStatus('Receive Cash Till');
            return;
          }
          if (event.key.toLowerCase() === 'o') {
            event.preventDefault();
            handleDeliveryPaymentStatus('May be Online');
            return;
          }
          if (event.key.toLowerCase() === 'p') {
            event.preventDefault();
            handleDeliveryPaymentStatus('Paid to Cash on Counter');
            return;
          }
        }
        if (orderType === 'Dine-In') {
          if (event.key.toLowerCase() === 's') {
            event.preventDefault();
            handleSaveOnly();
            return;
          }
          if (event.key.toLowerCase() === 'p') {
            event.preventDefault();
            handlePrintOnly();
            return;
          }
          if (event.key.toLowerCase() === 'r') {
            event.preventDefault();
            handleSaveAndPrint();
            return;
          }
        }
      }
    }

    if (showPaymentPopup) {
      if (event.key === 'Escape') {
        event.preventDefault();
        closePaymentPopup();
        return;
      }
      if (!isFormField) {
        if (event.key.toLowerCase() === 'l') {
          event.preventDefault();
          handleSavePayLater();
          return;
        }
        if (event.key.toLowerCase() === 's') {
          event.preventDefault();
          handlePaymentSave();
          return;
        }
      }
    }

    if (!isFormField) {
      const key = event.key;
      if (key === 'ArrowUp') {
        event.preventDefault();
        handleCartSelectionKey('up');
        return;
      }
      if (key === 'ArrowDown') {
        event.preventDefault();
        handleCartSelectionKey('down');
        return;
      }
      if (key === '+' || key === '=' ) {
        event.preventDefault();
        handleSelectedCartQty(1);
        return;
      }
      if (key === '-') {
        event.preventDefault();
        handleSelectedCartQty(-1);
        return;
      }
      if (key === 'Enter' && document.activeElement === posSearchInputRef.current) {
        event.preventDefault();
        handlePosSearchSubmit();
        return;
      }
    }
  };

  useEffect(() => {
    window.addEventListener('keydown', handlePosShortcuts);
    return () => window.removeEventListener('keydown', handlePosShortcuts);
  }, [activeTab, cart, selectedCartIndex, showCustomerDetailsPopup, showPaymentPopup, orderType, posSearch, posProducts, orderDetails]);

  function getProductStartingPrice(product) {
    if (product.flavors && product.flavors.length > 0) {
      const prices = product.flavors.flatMap((flavor) => flavor.variants?.map((v) => Number(v.price || 0)) || []);
      if (prices.length > 0) return Math.min(...prices);
    }
    return Number(product.price) || 0;
  }

  const buildCartItem = (product, variant, flavor) => {
    let price = Number(variant?.price ?? product.price) || 0;
    const label = product.name;
    if (!variant?.label && !flavor?.label) {
      return {
        itemId: `${product.id}-base-no-flavor-${Date.now()}`,
        productId: product.id,
        name: label,
        price,
        quantity: 1,
        weight: '',
        flavor: '',
        notes: '',
        total: price
      };
    }
    return {
      itemId: `${product.id}-${variant?.label || 'base'}-${flavor?.label || 'no-flavor'}-${Date.now()}`,
      productId: product.id,
      name: label,
      price,
      quantity: 1,
      weight: variant?.label || '',
      flavor: flavor?.label || '',
      notes: '',
      total: price
    };
  };

  function addToCart(product) {
    setMessage('');
    setSelectedCartProduct(product);
    setSelectedWeightOption(null);
    setSelectedFlavorOption(null);
    // Show flavor popup FIRST if flavors exist
    if (product.flavors?.length) {
      setShowFlavorPopup(true);
      return;
    }
    // Otherwise add directly (no flavors, no variants)
    mergeCartItem(buildCartItem(product));
  }

  function handleFlavorSelect(flavor) {
    setSelectedFlavorOption(flavor);
    setShowFlavorPopup(false);
    // If flavor has variants, show variant popup
    if (flavor.variants?.length) {
      setShowWeightPopup(true);
      return;
    }
    // Otherwise add to cart with just flavor (no variants)
    if (selectedCartProduct) {
      mergeCartItem(buildCartItem(selectedCartProduct, null, flavor));
      setSelectedCartProduct(null);
      setSelectedFlavorOption(null);
    }
  }

  function handleWeightSelect(weight) {
    setShowWeightPopup(false);
    if (selectedCartProduct) {
      // Add with both selected flavor and variant
      mergeCartItem(buildCartItem(selectedCartProduct, weight, selectedFlavorOption));
      setSelectedCartProduct(null);
      setSelectedWeightOption(null);
      setSelectedFlavorOption(null);
    }
  }

  function updateCartItem(itemId, delta) {
    setCart((prev) =>
      prev
        .map((item) => {
          if (item.itemId !== itemId) return item;
          const newQty = Math.max(1, (item.quantity || 0) + delta);
          return { ...item, quantity: newQty, total: newQty * (Number(item.price) || 0) };
        })
        .filter((item) => item.quantity > 0)
    );
  }

  function removeCartItem(itemId) {
    setCart((prev) => prev.filter((item) => item.itemId !== itemId));
  }

  function updateCartNotes(itemId, notes) {
    setCart((prev) => prev.map((item) => (item.itemId === itemId ? { ...item, notes } : item)));
  }

  // Edit cart item's name and price temporarily (POS-only)
  function editCartItemDetails(itemId) {
    const item = cart.find((c) => c.itemId === itemId);
    if (!item) return;
    const newName = window.prompt('Edit product name:', item.name);
    if (newName === null) return; // cancelled
    const priceInput = window.prompt('Edit product price (PKR):', String(item.price));
    if (priceInput === null) return; // cancelled
    const newPrice = Number(priceInput) || 0;
    setCart((prev) => prev.map((c) => (c.itemId === itemId ? { ...c, name: newName, price: newPrice, total: newPrice * c.quantity } : c)));
  }

  function updateOrderDetail(key, value) {
    setOrderDetails((prev) => ({ ...prev, [key]: value }));
  }

  function getCartSummary() {
    const subtotal = cart.reduce((sum, item) => sum + item.price * item.quantity, 0);
    const discount = Number(orderDetails.discount) || 0;
    const tax = ((subtotal - discount) * (Number(orderDetails.taxPercent) || 0)) / 100;
    const deliveryFee = orderType === 'Delivery' ? Number(orderDetails.deliveryFee) || 0 : 0;
    const serviceCharge = Number(orderDetails.serviceCharge) || 0;
    const total = Math.max(0, subtotal - discount + tax + deliveryFee + serviceCharge);
    return { subtotal, discount, tax, deliveryFee, serviceCharge, total };
  }

  function validatePosOrder() {
    if (!cart.length) return 'Cart cannot be empty.';
    if (orderType === 'Delivery' && (!orderDetails.address || !orderDetails.serviceType)) {
      return 'Delivery orders require delivery address and service type.';
    }
    if (orderType === 'Dine-In' && !orderDetails.tableNumber) {
      return 'Please select a table or room for Dine-In orders.';
    }
    return '';
  }

  function syncDeliveryCustomerFromOrder(address, phone, orderNumber) {
    if (!address) return;
    setCustomers((prev) => {
      const normalizedAddress = normalizeText(address);
      const existing = prev.find((customer) => normalizeText(customer.address) === normalizedAddress);
      if (existing) {
        const updatedFields = {};
        if (phone && existing.phone !== phone) {
          updatedFields.phone = phone;
        }
        if (orderNumber && existing.lastOrderNumber !== orderNumber) {
          updatedFields.lastOrderNumber = orderNumber;
        }
        if (!Object.keys(updatedFields).length) return prev;
        persistCustomer({ ...existing, ...updatedFields })
          .then((updated) => {
            if (updated) {
              setCustomers((current) => current.map((customer) => customer.id === updated.id ? updated : customer));
            }
          })
          .catch((err) => {
            console.warn('Failed to update delivery customer', err.message || err);
          });
        return prev.map((customer) =>
          customer.id === existing.id ? { ...customer, ...updatedFields } : customer
        );
      }
      const newCustomer = { name: '', phone: phone || '', address, lastOrderNumber: orderNumber || '' };
      persistCustomer(newCustomer)
        .then((created) => {
          if (created) {
            setCustomers((current) => [...current, created]);
          }
        })
        .catch((err) => {
          console.warn('Failed to persist delivery customer', err.message || err);
        });
      return prev;
    });
  }

  async function savePosOrder(orderStatus = 'Pending', overrides = {}, options = { refreshOrders: true }) {
    const error = validatePosOrder();
    if (error) {
      throw new Error(error);
    }

    setIsSaving(true);
    setMessage('');
    try {
      const isPickupOrder = orderType === 'Takeaway' && !orderDetails.customerName;
      const dineInCustomerName = orderType === 'Dine-In' ? (orderDetails.customerName || orderDetails.tableNumber || 'Table') : null;
      const payload = {
        items: cart,
        orderType,
        customerName: isPickupOrder ? 'Pickup' : (dineInCustomerName ?? orderDetails.customerName),
        phone: orderDetails.phone,
        address: orderType === 'Delivery' ? orderDetails.address : '',
        tableNumber: orderDetails.tableNumber,
        deliveryAgent: orderType === 'Delivery' ? orderDetails.deliveryAgent : '',
        serviceType: orderType === 'Delivery' ? orderDetails.serviceType : '',
        deliveryFee: orderType === 'Delivery' ? Number(orderDetails.deliveryFee) || 0 : 0,
        discount: Number(orderDetails.discount) || 0,
        taxPercent: Number(orderDetails.taxPercent) || 0,
        serviceCharge: Number(orderDetails.serviceCharge) || 0,
        paymentMethod: orderType === 'Takeaway' ? paymentMethod : '',
        paymentStatus: orderType === 'Delivery' ? (overrides.paymentStatus ?? orderDetails.paymentStatus) : '',
        notes: orderDetails.notes,
        status: orderStatus
      };
      const order = editingOrder && editingOrder.id
      ? await fetchJson(`${apiBase}/pos/orders/${editingOrder.id}`, {
          method: 'PUT',
          body: JSON.stringify({ ...payload, status: editingOrder.status || orderStatus })
        })
      : await fetchJson(`${apiBase}/pos/orders`, {
          method: 'POST',
          body: JSON.stringify(payload)
        });
      setMessage(`Order ${order.orderNumber || order.id} saved successfully.`);
      startTransition(() => {
        setCurrentSavedOrder(order);
        setCart([]);
        setOrderDetails((prev) => ({ ...prev, customerName: '', phone: '', address: '', tableNumber: '', deliveryAgent: '', paymentStatus: '' }));
        setEditingOrder(null);
      });
      if (orderType === 'Delivery' && order.address) {
        syncDeliveryCustomerFromOrder(order.address, order.phone, order.orderNumber);
      }
      if (options.refreshOrders !== false) {
        setTimeout(() => loadOrdersData().catch(err => console.warn('Failed to refresh orders', err)), 0);
      }
      return order;
    } catch (error) {
      throw new Error(error.message || 'Failed to save order');
    } finally {
      setIsSaving(false);
    }
  }

  async function completePayment() {
    const order = await savePosOrder('Completed');
    if (!order) return null;

    try {
      await fetchJson(`${apiBase}/pos/payments`, {
        method: 'POST',
        body: JSON.stringify({
          orderId: order.id,
          amount: order.total,
          paymentMethod,
          status: 'Completed',
          description: `Payment for order ${order.orderNumber || order.id}`
        })
      });
      setMessage(`Payment completed for ${order.orderNumber || order.id}.`);
      setTimeout(() => loadPosData(), 0);
      return order;
    } catch (error) {
      setMessage(error.message);
      return null;
    }
  }

  function handleSelectOrderType(type) {
    if (!cart.length) {
      setMessage('Add items to cart first before selecting order type.');
      return;
    }
    setOrderType(type);
    setOrderDetails((prev) => ({
      ...prev,
      deliveryFee: type === 'Delivery' ? prev.deliveryFee : 0,
      serviceType: type === 'Delivery' ? prev.serviceType : '',
      deliveryAgent: type === 'Delivery' ? prev.deliveryAgent : '',
      address: type === 'Delivery' ? prev.address : '',
      paymentStatus: type === 'Delivery' ? prev.paymentStatus : ''
    }));
    setPopupError('');
    setShowCustomerDetailsPopup(true);
    setShowPaymentPopup(false);

    // Sound
    try {
      const AudioCtx = window.AudioContext || window.webkitAudioContext;
      const ctx = new AudioCtx();
      const o = ctx.createOscillator();
      const g = ctx.createGain();
      o.type = 'sine';
      o.frequency.value = 520;
      g.gain.value = 0.03;
      o.connect(g);
      g.connect(ctx.destination);
      o.start();
      setTimeout(() => { o.stop(); try { ctx.close(); } catch (e) {} }, 180);
    } catch (e) {}

    // Star burst
    setOrderTypeStars(type);
    setStarKey((k) => k + 1);
    setTimeout(() => setOrderTypeStars(null), 1200);

    // Float notification
    setOrderTypeNotif(type);
    setTimeout(() => setOrderTypeNotif(null), 2500);
  }

  function closeCustomerDetailsPopup() {
    setShowCustomerDetailsPopup(false);
    setPopupError('');
  }

  function closePaymentPopup() {
    setShowPaymentPopup(false);
    setPopupError('');
  }

  function validateCustomerDetails() {
    if (orderType === 'Delivery' && (!orderDetails.address || !orderDetails.serviceType)) {
      return 'Delivery orders require delivery address and service type.';
    }
    if (orderType === 'Dine-In' && !orderDetails.tableNumber) {
      return 'Dine-In orders require a table or room selection.';
    }
    return '';
  }

  async function handleSaveOnly() {
    if (!cart.length) {
      setPopupError('Cart cannot be empty.');
      return;
    }
    const error = validateCustomerDetails();
    if (error) {
      setPopupError(error);
      return;
    }
    setPopupError('');

    if (orderType === 'Takeaway') {
      setShowCustomerDetailsPopup(false);
      setShowPaymentPopup(true);
      return;
    }
    setShowCustomerDetailsPopup(false);
    setShowPaymentPopup(false);

    try {
      const saveStatus = orderType === 'Dine-In'
        ? 'Pending'
        : orderType === 'Delivery'
          ? (orderDetails.deliveryAgent ? 'Riders Assigned' : 'Kitchen')
          : 'Completed';
      const order = await savePosOrder(saveStatus, {}, { refreshOrders: false });
      if (order) {
        setShowCustomerDetailsPopup(false);
        setShowPaymentPopup(false);
        startTransition(() => {
          const targetTab = orderType === 'Dine-In' ? 'dinein' : orderType === 'Delivery' ? 'delivery' : 'takeaway';
          setOrdersMainTab(targetTab);
          if (orderType === 'Dine-In') {
            setDineinSubTab('tables');
            setDineinOrderStatusFilter('all');
            setDineinPageIndex(0);
          }
          setActiveTab('orders');
        });
        setTimeout(() => loadOrdersData().catch(err => console.warn('Failed to refresh orders', err)), 0);
      } else {
        setPopupError('Failed to save order. Please try again.');
      }
    } catch (err) {
      setPopupError(`Error: ${err.message}`);
    }
  }

  async function handlePrintOnly() {
    if (!currentSavedOrder) {
      setPopupError('Please save the order first before printing.');
      return;
    }
    setPopupError('');
    try {
      await printReceipt(currentSavedOrder);
    } catch (err) {
      setPopupError(`Print error: ${err.message}`);
    }
  }

  async function handleSaveAndPrint() {
    if (!cart.length) {
      setPopupError('Cart cannot be empty.');
      return;
    }
    const error = validateCustomerDetails();
    if (error) {
      setPopupError(error);
      return;
    }
    setPopupError('');

    if (orderType === 'Takeaway') {
      setShowCustomerDetailsPopup(false);
      setShowPaymentPopup(true);
      return;
    }
    setShowCustomerDetailsPopup(false);
    setShowPaymentPopup(false);

    try {
      const saveStatus = orderType === 'Dine-In'
        ? 'Pending'
        : orderType === 'Delivery'
          ? (orderDetails.deliveryAgent ? 'Riders Assigned' : 'Kitchen')
          : 'Completed';
      const order = await savePosOrder(saveStatus, {}, { refreshOrders: false });
      if (order) {
        printReceipt(order).catch(err => console.warn('Print failed', err));
        const targetTab = orderType === 'Dine-In' ? 'dinein' : orderType === 'Delivery' ? 'delivery' : 'takeaway';
        startTransition(() => {
          setOrdersMainTab(targetTab);
          if (orderType === 'Dine-In') {
            setDineinSubTab('tables');
            setDineinOrderStatusFilter('all');
            setDineinPageIndex(0);
          }
          setActiveTab('orders');
        });
        setTimeout(() => loadOrdersData().catch(err => console.warn('Failed to refresh orders', err)), 0);
      } else {
        setPopupError('Failed to save order. Please try again.');
      }
    } catch (err) {
      setPopupError(`Error: ${err.message}`);
    }
  }

  async function handleDeliveryPaymentStatus(status) {
    if (!cart.length) {
      setPopupError('Cart cannot be empty.');
      return;
    }
    const error = validateCustomerDetails();
    if (error) {
      setPopupError(error);
      return;
    }
    setPopupError('');
    setShowCustomerDetailsPopup(false);
    setShowPaymentPopup(false);
    try {
      const saveStatus = orderType === 'Delivery'
        ? (orderDetails.deliveryAgent ? 'Riders Assigned' : 'Kitchen')
        : 'Kitchen';
      const order = await savePosOrder(saveStatus, { paymentStatus: status }, { refreshOrders: false });
      if (order) {
        printReceipt(order).catch(err => console.warn('Print failed', err));
        startTransition(() => {
          setActiveTab('orders');
        });
        setTimeout(() => loadOrdersData().catch(err => console.warn('Failed to refresh orders', err)), 0);
      } else {
        setPopupError('Failed to save order. Please try again.');
      }
    } catch (err) {
      setPopupError(`Error: ${err.message}`);
    }
  }

  async function handleCustomerDetailsSave() {
    const error = validateCustomerDetails();
    if (error) {
      setPopupError(error);
      return;
    }
    setPopupError('');

    if (orderType === 'Takeaway') {
      setShowCustomerDetailsPopup(false);
      setShowPaymentPopup(true);
      return;
    }
    setShowCustomerDetailsPopup(false);
    setShowPaymentPopup(false);

    const saveStatus = orderType === 'Dine-In'
      ? 'Pending'
      : orderType === 'Delivery'
        ? (orderDetails.deliveryAgent ? 'Riders Assigned' : 'Kitchen')
        : 'Completed';
    const order = await savePosOrder(saveStatus, {}, { refreshOrders: false });
    if (order) {
      printReceipt(order).catch(err => console.warn('Print failed', err));
    }
  }

  async function handlePaymentSave() {
    setShowPaymentPopup(false);
    setPopupError('');
    const order = await completePayment();
    if (order) {
      printReceipt(order).catch(err => console.warn('Print failed', err));
    }
  }

  async function handleSavePayLater() {
    if (!cart.length) {
      setPopupError('Cart cannot be empty.');
      return;
    }
    setShowPaymentPopup(false);
    setPopupError('');
    try {
      const order = await savePosOrder('Pay Later', {}, { refreshOrders: false });
      if (order) {
        printReceipt(order).catch(err => console.warn('Print failed', err));
        setTimeout(() => loadOrdersData().catch(err => console.warn('Failed to refresh orders', err)), 0);
      }
    } catch (err) {
      setPopupError(err.message || 'Failed to save order.');
    }
  }

  async function updateOrderStatus(orderId, newStatus) {
    setLoading(true);
    setMessage('');
    try {
      await fetchJson(`${apiBase}/pos/orders/${orderId}/status`, {
        method: 'PUT',
        body: JSON.stringify({ status: newStatus })
      });
      setMessage(`Order status updated to ${newStatus}`);
      await loadOrdersData();
    } catch (error) {
      setMessage(error.message);
    } finally {
      setLoading(false);
    }
  }

  async function markTakeawayOrderPaid(orderId) {
    await updateOrderStatus(orderId, 'Completed');
    setTakeawaySubTab('paid');
  }

  async function assignRiderToOrder(orderId, riderName) {
    setLoading(true);
    setMessage('');
    try {
      await fetchJson(`${apiBase}/pos/orders/${orderId}/assign-rider`, {
        method: 'PUT',
        body: JSON.stringify({ deliveryAgent: riderName, status: 'Riders Assigned' })
      });
      setMessage(`Rider ${riderName} assigned to order`);
      await loadOrdersData();
      setSelectedRider('');
      setRiderAssignmentModal(null);
    } catch (error) {
      setMessage(error.message);
    } finally {
      setLoading(false);
    }
  }

  async function assignWaiterToOrder(orderId, waiterName) {
    setLoading(true);
    setMessage('');
    try {
      await fetchJson(`${apiBase}/pos/orders/${orderId}/assign-waiter`, {
        method: 'PUT',
        body: JSON.stringify({ waiter: waiterName })
      });
      setMessage(`Waiter ${waiterName} assigned to order`);
      await loadOrdersData();
    } catch (error) {
      setMessage(error.message);
    } finally {
      setLoading(false);
    }
  }

  const openOrderModal = (order) => {
    setEditingOrder(order);
    setEditingOrderCart((order.items || []).map((item) => ({ ...item })));
    setOrderEditForm({
      orderType: order.orderType || 'Dine-In',
      customerName: order.customerName || '',
      phone: order.phone || '',
      address: order.orderType === 'Delivery' ? order.address || '' : '',
      tableNumber: order.tableNumber || '',
      deliveryAgent: order.orderType === 'Delivery' ? order.deliveryAgent || '' : '',
      serviceType: order.orderType === 'Delivery' ? order.serviceType || '' : '',
      deliveryFee: order.orderType === 'Delivery' ? (order.deliveryFee || 0) : 0,
      discount: order.discount || 0,
      taxPercent: order.taxPercent || settings.taxRate || 0,
      serviceCharge: order.serviceCharge || 0,
      paymentMethod: order.paymentMethod || 'Cash',
      notes: order.notes || '',
      status: order.status || '',
      paymentStatus: order.paymentStatus || ''
    });
    setOrderModalOpen(true);
  };

  const openOrderForEditInPos = (order) => {
    setHoldModalOpen(false);
    setActiveTab('pos');
    setCart((order.items || []).map((item) => ({ ...item })));
    setOrderType(order.orderType || 'Dine-In');
    setOrderDetails({
      customerName: order.customerName || '',
      phone: order.phone || '',
      address: order.orderType === 'Delivery' ? order.address || '' : '',
      tableNumber: order.tableNumber || '',
      deliveryAgent: order.orderType === 'Delivery' ? order.deliveryAgent || '' : '',
      serviceType: order.orderType === 'Delivery' ? order.serviceType || '' : '',
      deliveryFee: order.orderType === 'Delivery' ? (order.deliveryFee || 0) : 0,
      discount: order.discount || 0,
      taxPercent: order.taxPercent || settings.taxRate || 0,
      serviceCharge: order.serviceCharge || 0,
      notes: order.notes || ''
    });
    setEditingOrder(order);
    setCurrentSavedOrder(order);
    setMessage('Loaded order for editing in POS. Adjust items and save to update.');
  };

  const renderOrderEditButton = (order) => (
    <button
      type="button"
      title="Edit order"
      onClick={() => openOrderForEditInPos(order)}
      className="inline-flex h-11 w-11 items-center justify-center rounded-full border border-violet-400 bg-gradient-to-br from-violet-500 via-purple-600 to-slate-950 text-white shadow-[0_0_25px_rgba(139,92,246,0.35)] transition hover:scale-105 hover:shadow-[0_0_35px_rgba(139,92,246,0.55)]"
    >
      <svg viewBox="0 0 24 24" className="h-5 w-5" fill="currentColor"><path d="M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z"/></svg>
    </button>
  );

  async function saveOrderEdit() {
    if (!editingOrder) return;
    if (!editingOrderCart.length) {
      setMessage('Order must have at least one item.');
      return;
    }
    if (orderEditForm.orderType === 'Delivery' && (!orderEditForm.customerName || !orderEditForm.phone || !orderEditForm.address || !orderEditForm.serviceType)) {
      setMessage('Delivery orders require customer name, phone, address and service type.');
      return;
    }
    if (orderEditForm.orderType === 'Dine-In' && !orderEditForm.tableNumber) {
      setMessage('Please select a table or room for Dine-In orders.');
      return;
    }
    setLoading(true);
    setMessage('');
    try {
      const summary = getEditingOrderSummary();
      const payload = {
        items: editingOrderCart,
        customerName: orderEditForm.customerName,
        phone: orderEditForm.phone,
        address: orderEditForm.orderType === 'Delivery' ? orderEditForm.address : '',
        tableNumber: orderEditForm.tableNumber,
        deliveryAgent: orderEditForm.orderType === 'Delivery' ? orderEditForm.deliveryAgent : '',
        serviceType: orderEditForm.orderType === 'Delivery' ? orderEditForm.serviceType : '',
        deliveryFee: orderEditForm.orderType === 'Delivery' ? Number(orderEditForm.deliveryFee) || 0 : 0,
        discount: Number(orderEditForm.discount) || 0,
        taxPercent: Number(orderEditForm.taxPercent) || 0,
        serviceCharge: Number(orderEditForm.serviceCharge) || 0,
        paymentMethod: orderEditForm.paymentMethod,
        notes: orderEditForm.notes,
        status: orderEditForm.status,
        subtotal: summary.subtotal,
        total: summary.total
      };
      await fetchJson(`${apiBase}/pos/orders/${editingOrder.id}`, {
        method: 'PUT',
        body: JSON.stringify(payload)
      });
      setMessage('Order updated successfully.');
      setOrderModalOpen(false);
      setEditingOrder(null);
      setEditingOrderCart([]);
      await loadOrdersData();
      await loadPosData();
    } catch (error) {
      setMessage(error.message);
    } finally {
      setLoading(false);
    }
  }

  async function deleteOrder(orderId) {
    setLoading(true);
    setMessage('');
    try {
      await fetchJson(`${apiBase}/pos/orders/${orderId}`, { method: 'DELETE' });
      setMessage('Order deleted successfully.');
      await loadOrdersData();
      await loadPosData();
    } catch (error) {
      setMessage(error.message);
    } finally {
      setLoading(false);
    }
  }

  function toggleDineinOrderSelection(orderId) {
    setSelectedDineinOrders((prev) =>
      prev.includes(orderId) ? prev.filter((id) => id !== orderId) : [...prev, orderId]
    );
  }

  async function deleteSelectedDineinOrders() {
    if (!selectedDineinOrders.length) return;
    setLoading(true);
    setMessage('');
    try {
      await Promise.all(
        selectedDineinOrders.map((orderId) => fetchJson(`${apiBase}/pos/orders/${orderId}`, { method: 'DELETE' }))
      );
      setMessage(`${selectedDineinOrders.length} orders deleted successfully.`);
      setSelectedDineinOrders([]);
      await loadOrdersData();
      await loadPosData();
    } catch (error) {
      setMessage(error.message);
    } finally {
      setLoading(false);
    }
  }

  function confirmMarkPaid(order) {
    setMarkPaidOrder(order);
    setMarkPaidAmount(order.total || order.amount || 0);
    setMarkPaidMethod(order.paymentMethod || 'Cash');
    setMarkDueOrder(null);
  }

  function confirmMarkDue(order) {
    // ensure mark-paid modal is closed
    setMarkPaidOrder(null);
    setMarkDueOrder(order);
    setMarkDueAmount(0);
    setMarkDueMethod(order.paymentMethod || 'Cash');
  }

  async function handleMarkPaid() {
    if (!markPaidOrder) return;
    setLoading(true);
    setMessage('');
    try {
      const tableLabel = markPaidOrder.tableNumber;
      await fetchJson(`${apiBase}/pos/orders/${markPaidOrder.id}`, {
        method: 'PUT',
        body: JSON.stringify({
          status: 'Payment Collected',
          items: markPaidOrder.items || [],
          customerName: markPaidOrder.customerName || '',
          tableNumber: markPaidOrder.tableNumber || ''
        })
      });
      if (markPaidAmount) {
        await fetchJson(`${apiBase}/pos/payments`, {
          method: 'POST',
          body: JSON.stringify({
            orderId: markPaidOrder.id,
            amount: Number(markPaidAmount) || 0,
            paymentMethod: markPaidMethod,
            status: 'Completed',
            description: `Payment collected for order ${markPaidOrder.orderNumber || markPaidOrder.id}`
          })
        });
      }
      if (tableLabel) {
        const table = posTables.find((item) => item.label === tableLabel || item.name === tableLabel || item.number === tableLabel);
        if (table) {
          await fetchJson(`${apiBase}/pos/tables/${table.id}`, {
            method: 'PUT',
            body: JSON.stringify({ status: 'available' })
          });
        }
      }
      setMessage('Order marked paid successfully.');
      setMarkPaidOrder(null);
      setSelectedDineinOrders((prev) => prev.filter((id) => id !== markPaidOrder.id));
      await loadOrdersData();
      await loadPosData();
    } catch (error) {
      setMessage(error.message);
    } finally {
      setLoading(false);
    }
  }

  async function handleMarkDue() {
    if (!markDueOrder) return;
    setLoading(true);
    setMessage('');
    try {
      const total = Number(markDueOrder.total || markDueOrder.amount || 0);
      const collected = Number(markDueAmount) || 0;

      // Update order: set to Payment Pending / Due and clear tableNumber so table becomes free
      await fetchJson(`${apiBase}/pos/orders/${markDueOrder.id}`, {
        method: 'PUT',
        body: JSON.stringify({ status: 'Payment Pending', paymentStatus: 'Due', tableNumber: '' })
      });

      // If any amount was collected now, record a payment (partial)
      if (collected > 0) {
        const paymentStatus = collected >= total ? 'Completed' : 'Partial';
        await fetchJson(`${apiBase}/pos/payments`, {
          method: 'POST',
          body: JSON.stringify({
            orderId: markDueOrder.id,
            amount: Number(collected) || 0,
            paymentMethod: markDueMethod,
            status: paymentStatus,
            description: `Partial payment recorded for order ${markDueOrder.orderNumber || markDueOrder.id}`
          })
        });

        // If collected covers total treat as paid
        if (collected >= total) {
          await fetchJson(`${apiBase}/pos/orders/${markDueOrder.id}`, {
            method: 'PUT',
            body: JSON.stringify({ status: 'Payment Collected', paymentStatus: 'Paid', tableNumber: '' })
          });
        }
      }

      // Free table if exists
      const tableLabel = markDueOrder.tableNumber;
      if (tableLabel) {
        const table = posTables.find((item) => item.label === tableLabel || item.name === tableLabel || item.number === tableLabel);
        if (table) {
          await fetchJson(`${apiBase}/pos/tables/${table.id}`, {
            method: 'PUT',
            body: JSON.stringify({ status: 'available' })
          });
        }
      }

      setMessage('Order updated (marked due).');
      setMarkDueOrder(null);
      setMarkDueAmount(0);
      await loadOrdersData();
      await loadPosData();
    } catch (error) {
      setMessage(error.message);
    } finally {
      setLoading(false);
    }
  }

  function cancelMarkPaid() {
    setMarkPaidOrder(null);
    setMarkPaidAmount('');
    setMarkPaidMethod('Cash');
  }

  async function handleBtConnect() {
    if (btConnected && btDevice) {
      try {
        btDevice.gatt.disconnect();
      } catch {}
      setBtDevice(null);
      setBtConnected(false);
      setBtInfo(null);
      clearPrinterInfo();
      return;
    }
    setBtConnecting(true);
    try {
      let device, info;
      
      // Try to auto-reconnect to saved printer first
      const savedPrinter = getSavedPrinterInfo();
      if (savedPrinter?.id) {
        try {
          const result = await autoConnectSavedPrinter();
          device = result.device;
          info = result.info;
        } catch (err) {
          console.warn('Auto-reconnect failed, showing manual pairing:', err.message);
          // Fall back to manual pairing
          const result = await requestBluetoothPrinter();
          device = result.device;
          info = result.info;
        }
      } else {
        // No saved printer, request new one
        const result = await requestBluetoothPrinter();
        device = result.device;
        info = result.info;
      }
      
      setBtDevice(device);
      setBtInfo(info);
      setBtConnected(true);
      setBtPrintMode(true);
    } catch (err) {
      console.warn('Bluetooth connection failed:', err.message);
    } finally {
      setBtConnecting(false);
    }
  }

  async function printReceiptBT(order) {
    let device = btDevice;

    if (!btConnected || !device) {
      try {
        const result = await autoConnectSavedPrinter();
        device = result.device;
        setBtDevice(device);
        setBtConnected(true);
      } catch (err) {
        console.warn('Cannot auto-reconnect printer:', err.message);
        return null;
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
      const feedCmd = new Uint8Array(CMD.FEED_LINES(3));
      const finalData = new Uint8Array(rasterData.length + feedCmd.length + cutCmd.length);
      finalData.set(rasterData, 0);
      finalData.set(feedCmd, rasterData.length);
      finalData.set(cutCmd, rasterData.length + feedCmd.length);
      await printToBluetooth(device, finalData);
    };

    try {
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
      if (settings.tokenSlipEnabled) {
        const tokenOrder = { ...order, items: [] };
        if (settings.btEncoding === 'bmp') {
          const tokenCanvas = renderReceiptToCanvas(tokenOrder, { ...settings, _tokenOnly: true });
          const tokenRaster = canvasToEscposRaster(tokenCanvas);
          const tokenFeed = new Uint8Array(CMD.FEED_LINES(3));
          const tokenCut = new Uint8Array(CMD.CUT);
          const tokenFinal = new Uint8Array(tokenRaster.length + tokenFeed.length + tokenCut.length);
          tokenFinal.set(tokenRaster, 0);
          tokenFinal.set(tokenFeed, tokenRaster.length);
          tokenFinal.set(tokenCut, tokenRaster.length + tokenFeed.length);
          await printToBluetooth(device, tokenFinal);
        } else {
          const tokenData = buildEscposReceipt(tokenOrder, { ...settings, _tokenOnly: true });
          await printToBluetooth(device, tokenData);
        }
      }
      return true;
    } catch (err) {
      console.warn('BT print failed:', err.message);
      throw err;
    }
  }

  function printHtml(content) {
    return new Promise((resolve) => {
      const iframe = document.createElement('iframe');
      iframe.style.position = 'fixed';
      iframe.style.right = '0';
      iframe.style.bottom = '0';
      iframe.style.width = '0';
      iframe.style.height = '0';
      iframe.style.border = '0';
      iframe.style.visibility = 'hidden';
      document.body.appendChild(iframe);

      const iframeDoc = iframe.contentWindow?.document || iframe.document;
      iframeDoc.open();
      iframeDoc.write(content);
      iframeDoc.close();

      const cleanup = () => {
        if (iframe.parentNode) iframe.parentNode.removeChild(iframe);
        resolve();
      };

      const printFrame = () => {
        const win = iframe.contentWindow;
        if (!win) {
          cleanup();
          return;
        }
        win.focus();
        win.onafterprint = cleanup;
        win.print();
        setTimeout(cleanup, 1000);
      };

      if (iframe.contentWindow) {
        printFrame();
      } else {
        iframe.onload = printFrame;
      }
    });
  }

  async function printTokenSlip(order) {
    const tokenNumber = Number(settings.tokenSlipNextNumber || 1);
    const prefix = settings.tokenSlipPrefix || settings.slipPrefix || 'TS';
    const tokenText = `${prefix}-${tokenNumber}`;
    const dateText = formatReceiptDate(order.date || new Date().toISOString(), settings.receiptDateTimeFormat || 'DD/MM/YYYY HH:mm');
    const fontFamily = settings.receiptFontFamily || settings.receiptFontStyle || 'Arial';
    const logoHtml = settings.logo ? `<div class="logo"><img src="${settings.logo}" alt="Logo" style="max-width: 90px; width: auto; height: auto; display: block; margin: 0 auto 8px;" /></div>` : '';

    const tokenLabelSz = settings.btTokenLabelFontSize || 14;
    const tokenNumSz = Math.min(settings.btTokenFontSize || 44, 300);
    const content = `
      <html>
        <head>
          <style>
            body { font-family: ${fontFamily}, Arial, sans-serif; margin: 0; padding: 2px; color: #000; }
            .receipt { width: 100%; max-width: 100%; margin: 0; text-align: center; }
            .header { text-align: center; margin-bottom: 4px; }
            .header h2 { font-size: 18px; margin: 0; }
            .token-label { font-size: ${tokenLabelSz}px; font-weight: 700; letter-spacing: 1px; margin-top: 2px; }
            .token-number { font-size: ${tokenNumSz}px; font-weight: 900; margin: 2px 0; text-align: center; letter-spacing: 2px; line-height: 1; word-break: break-all; }
            .sub { font-size: 12px; text-align: center; margin-top: 4px; }
            .footer { text-align: center; font-size: 12px; margin-top: 4px; }
            .logo img { display: block; margin: 0 auto 4px; }
          </style>
        </head>
        <body>
          <div class="receipt">
            <div class="header">
              ${logoHtml}
              <h2>${settings.receiptHeader || 'Usman Hotel'}</h2>
              <div class="token-label">Token Slip</div>
            </div>
            <div class="token-number">${tokenText}</div>
            <div class="sub">${dateText}</div>
            <div class="footer">Please keep this token slip with you.</div>
          </div>
        </body>
      </html>
    `;

    await printHtml(content);

    const nextToken = tokenNumber + 1;
    setSettings((prev) => ({ ...prev, tokenSlipNextNumber: nextToken }));
    try {
      await fetchJson(`${apiBase}/settings`, {
        method: 'PUT',
        body: JSON.stringify({ tokenSlipNextNumber: nextToken })
      });
    } catch (error) {
      console.warn('Unable to save token number to settings:', error.message);
    }
  }

  function getReceiptHtml(order) {
    const header = settings.receiptHeader || 'Usman Hotel';
    const footer = settings.receiptFooter || 'Thank you for your business';
    const slipNumber = settings.receiptShowReceiptNumber ? `${settings.slipPrefix || 'UH'}-${order.orderNumber || order.id || Date.now()}` : '';
    const dateText = settings.receiptShowDateTime ? formatReceiptDate(order.date || new Date().toISOString(), settings.receiptDateTimeFormat || 'DD/MM/YYYY HH:mm') : '';
    const fontFamily = settings.receiptFontFamily || settings.receiptFontStyle || 'Arial';
    const titleSize = `${settings.receiptFontSizes?.title || 18}px`;
    const sectionSize = `${settings.receiptFontSizes?.section || 14}px`;
    const productSize = `${settings.receiptFontSizes?.product || 12}px`;
    const customerSize = `${settings.receiptFontSizes?.customer || 12}px`;
    const notesSize = `${settings.receiptFontSizes?.notes || 11}px`;
    const receiptTokenText = settings.tokenSlipEnabled ? `${settings.tokenSlipPrefix || settings.slipPrefix || 'TS'}-${settings.tokenSlipNextNumber || 1}` : '';
    const tokenLabelSz = settings.btTokenLabelFontSize || 14;
    const tokenNumSz = settings.btTokenFontSize || 44;
    const tokenHtml = receiptTokenText ? `<div class="receipt-token"><div class="token-label" style="font-size:${tokenLabelSz}px;">Token</div><div class="token-number" style="font-size:${tokenNumSz}px;">${receiptTokenText}</div></div>` : '';
    const logoHtml = settings.logo ? `<div class="logo"><img src="${settings.logo}" alt="Logo" style="max-width: ${settings.receiptLogoWidth || 120}px; max-height: 100px; width: auto; height: auto; display: block;" /></div>` : '<div class="logo empty"></div>';
    const counterLabelHtml = settings.receiptCounterLabel ? `<div class="counter">${settings.receiptCounterLabel}</div>` : '';

    const deliveryCharge = order.orderType === 'Delivery' ? Number(order.deliveryFee || order.deliveryCharge || 0) : 0;
    const serviceCharge = Number(order.serviceCharge || 0);
    const discountAmount = Number(order.discount || 0);
    const taxPercent = Number(order.taxPercent) || 0;
    const subtotal = (order.subtotal != null && order.subtotal !== 0)
      ? Number(order.subtotal)
      : (order.items || []).reduce((s, it) => s + (Number(it.price || 0) * Number(it.quantity || 0) || Number(it.total) || 0), 0);
    const taxAmount = Number(order.tax || ((subtotal - discountAmount) * taxPercent) / (taxPercent > 1 ? 100 : 1));
    const totalAmount = Math.max(0, subtotal - discountAmount + taxAmount + deliveryCharge + serviceCharge);

    const productRows = (order.items || []).map((item) => {
      const qty = settings.receiptShowProductQuantity ? item.quantity || 1 : '';
      const rate = settings.receiptShowProductUnitPrice ? item.price || item.unitPrice || 0 : '';
      const computedAmount = Number(item.price || 0) * Number(item.quantity || 1);
      const amount = computedAmount || Number(item.total) || 0;
      const details = [];
      if (item.weight) details.push(`Weight: ${item.weight}`);
      if (item.flavor) details.push(`Flavor: ${item.flavor}`);
      return `
        <tr>
          <td>
            <div>${item.name || ''}</div>
            ${details.length ? `<div style="font-size:${productSize}; color:#777; margin-top:4px;">${details.join(' / ')}</div>` : ''}
          </td>
          <td>${qty}</td>
          <td>${rate ? rate + ' Rs' : ''}</td>
          <td>${amount} ${settings.currency || 'PKR'}</td>
        </tr>
      `;
    }).join('');

    const orderTypeDisplay = order.orderType === 'Takeaway' ? 'Pickup' : order.orderType || '';
    const receiptCustomerName = order.orderType === 'Dine-In'
      ? (order.customerName || order.tableNumber || 'Table')
      : (order.customerName || (order.orderType === 'Takeaway' ? 'Pickup' : ''));
    const receiptTable = order.orderType === 'Dine-In' ? (order.tableNumber || '-') : '';
    const receiptWaiter = order.orderType === 'Dine-In' ? (order.waiter || '-') : '';
    const receiptLocation = order.orderType === 'Delivery' ? (order.address || '-') : '';
    const receiptServiceType = order.orderType === 'Delivery' ? (order.serviceType || '-') : '';
    const receiptRider = order.orderType === 'Delivery' ? (order.deliveryAgent || '-') : '';
    const receiptStatus = order.orderType === 'Delivery' ? (order.paymentStatus || order.status || '-') : '';
    const customerLines = [];
    if (orderTypeDisplay) customerLines.push(`<div class="meta-row"><span>Order Type</span><span>${orderTypeDisplay}</span></div>`);
    if (order.status === 'Completed') customerLines.push(`<div class="meta-row"><span>Payment</span><span>✔ Paid</span></div>`);
    if (order.status === 'Pay Later') customerLines.push(`<div class="meta-row"><span>Payment</span><span>✘ Pay Later</span></div>`);
    if (receiptCustomerName) customerLines.push(`<div class="meta-row"><span>Customer</span><span>${receiptCustomerName}</span></div>`);
    if (order.orderType === 'Dine-In') {
      customerLines.push(`<div class="meta-row"><span>Table</span><span>${receiptTable}</span></div>`);
      customerLines.push(`<div class="meta-row"><span>Sales Person</span><span>${receiptWaiter}</span></div>`);
    }
    if (order.orderType === 'Delivery') {
      customerLines.push(`<div class="meta-row"><span>Mobile</span><span>${order.phone || '-'}</span></div>`);
      customerLines.push(`<div class="meta-row"><span>Location</span><span>${receiptLocation}</span></div>`);
      customerLines.push(`<div class="meta-row"><span>Service Type</span><span>${receiptServiceType}</span></div>`);
      customerLines.push(`<div class="meta-row"><span>Rider</span><span>${receiptRider}</span></div>`);
      customerLines.push(`<div class="meta-row"><span>Status</span><span>${receiptStatus}</span></div>`);
    }
    if (order.orderType !== 'Dine-In' && order.orderType !== 'Delivery' && settings.receiptShowCustomerPhone) {
      customerLines.push(`<div class="meta-row"><span>Mobile</span><span>${order.phone || '-'}</span></div>`);
    }
    if (order.orderType !== 'Dine-In' && order.orderType !== 'Delivery' && settings.receiptShowWaiterName && order.waiter) {
      customerLines.push(`<div class="meta-row"><span>Sales Person</span><span>${order.waiter}</span></div>`);
    }

    const contactBlock = customerLines.length ? `<div class="box">${customerLines.join('')}</div>` : '';
    const customerMessageLine = settings.receiptShowCustomerMessage && order.customerMessage ? `<div class="notes" style="font-size:${notesSize};">${order.customerMessage}</div>` : '';
    const notesLine = settings.receiptShowNotes && order.notes ? `<div class="notes" style="font-size:${notesSize};">${order.notes}</div>` : '';

    return `
      <html>
        <head>
          <style>
            body { font-family: ${fontFamily}, Arial, sans-serif; padding: 2px; color: #000; background:#fff; margin:0; }
            .receipt { width: 100%; max-width: 100%; }
            .header { border: 1px solid #000; padding: 4px; margin-bottom: 4px; }
            .header-row { display: flex; justify-content: space-between; align-items: center; margin-bottom: 4px; gap: 4px; }
            .header h2 { font-size: ${titleSize}; margin: 0 0 2px; text-align: center; }
            .header .location { font-size: ${sectionSize}; margin-top: 2px; text-align: center; }
            .receipt-token { text-align: left; }
            .receipt-token .token-label { font-size: ${tokenLabelSz}px; font-weight: 700; margin-bottom: 4px; }
            .receipt-token .token-number { font-size: ${tokenNumSz}px; font-weight: 900; line-height: 1; }
            .logo img { max-width: 100px; max-height: 100px; width: auto; height: auto; display: block; margin: 0 auto; }
            .logo.empty { width: 100px; }
            .top-row { display: flex; justify-content: space-between; margin-bottom: 4px; font-size: ${customerSize}; border: 1px solid #000; padding: 4px; }
            .box { border: 1px solid #000; padding: 4px; margin-bottom: 4px; }
            .box .meta-row { display: flex; justify-content: space-between; margin-bottom: 2px; font-size: ${customerSize}; }
            .table { width: 100%; border-collapse: collapse; font-size: ${productSize}; }
            .table th, .table td { border: 1px solid #000; padding: 2px; word-break: break-word; }
            .table th { background: #f5f5f5; }
            .summary { display: flex; gap: 4px; margin-top: 4px; }
            .summary .left, .summary .right { flex: 1; border: 1px solid #000; padding: 4px; font-size: ${customerSize}; }
            .summary .left div, .summary .right div { display: flex; justify-content: space-between; margin-bottom: 2px; }
            .total-line { font-weight: bold; margin-top: 4px; display: flex; justify-content: space-between; }
            .footer { text-align: center; margin-top: 4px; font-size: ${sectionSize}; border: 1px solid #000; padding: 4px; }
            .counter { font-size: ${sectionSize}; margin-top: 2px; color: #000; }
            .notes { border: 1px solid #000; padding: 4px; margin-top: 4px; word-break: break-word; }
          </style>
        </head>
        <body>
          <div class="receipt">
            <div class="header">
              <div class="header-row">
                ${tokenHtml}
                ${logoHtml}
              </div>
              <h2>${header}</h2>
              ${counterLabelHtml}
              <div class="location">${settings.location || ''}</div>
            </div>
            <div class="top-row">
              <div>${slipNumber ? `Invoice No. ${slipNumber}` : ''}</div>
              <div>${dateText}</div>
            </div>
            ${contactBlock}
            <table class="table">
              <thead>
                <tr>
                  <th>Product</th>
                  <th>Qty</th>
                  <th>Rate</th>
                  <th>Subtotal</th>
                </tr>
              </thead>
              <tbody>
                ${productRows}
              </tbody>
            </table>
            <div class="summary">
              <div class="left">
                <div><span>Total Due</span><span>${totalAmount} Rs</span></div>
              </div>
              <div class="right">
                ${settings.receiptShowSubtotal ? `<div><span>Subtotal:</span><span>${subtotal} Rs</span></div>` : ''}
                ${order.orderType === 'Delivery' && settings.receiptShowDeliveryCharge ? `<div><span>Delivery:</span><span>${deliveryCharge} Rs</span></div>` : ''}
                ${settings.receiptShowServiceCharge ? `<div><span>Service:</span><span>${serviceCharge} Rs</span></div>` : ''}
                ${settings.receiptShowDiscount ? `<div><span>Discount:</span><span>${discountAmount} Rs</span></div>` : ''}
                ${settings.receiptShowTax ? `<div><span>Tax:</span><span>${taxAmount} Rs</span></div>` : ''}
                ${settings.receiptShowTotal ? `<div class="total-line"><span>Total:</span><span>${totalAmount} Rs</span></div>` : ''}
              </div>
            </div>
            ${customerMessageLine}
            ${notesLine}
            <div class="footer">${footer}</div>
          </div>
        </body>
      </html>
    `;
  }

  function printReceipt(order) {
    if (btConnected || btInfo) {
      return printReceiptBT(order).catch((err) => {
        console.warn('BT print failed:', err.message);
        alert('Bluetooth print failed. Make sure printer is on and paired.');
        return null;
      });
    }
    return printHtmlReceipt(order);
  }

  function printHtmlReceipt(order) {
    const content = getReceiptHtml(order);

    const printPromise = printHtml(content).catch((err) => {
      console.error('Print failed', err);
    });

    if (settings.tokenSlipEnabled) {
      printPromise.then(() => {
        printTokenSlip(order).catch((err) => {
          console.error('Token slip print failed', err);
        });
      });
    }

    return printPromise;
  }

  const toggleOrderSelection = (orderId) => {
    setSelectedOrders(prev => 
      prev.includes(orderId) 
        ? prev.filter(id => id !== orderId)
        : [...prev, orderId]
    );
  };

  const selectAllOrders = (orders) => {
    setSelectedOrders(orders.map(order => order.id));
  };

  const clearOrderSelection = () => {
    setSelectedOrders([]);
  };

  const toggleTakeawaySelection = (orderId) => {
    setSelectedTakeawayOrders(prev => 
      prev.includes(orderId) 
        ? prev.filter(id => id !== orderId)
        : [...prev, orderId]
    );
  };

  const selectAllTakeawayOrders = (orders) => {
    setSelectedTakeawayOrders(orders.map((order) => order.id));
  };

  const clearTakeawaySelection = () => {
    setSelectedTakeawayOrders([]);
  };

  async function deleteMultipleOrders() {
    if (selectedOrders.length === 0) return;
    if (!confirm(`Delete ${selectedOrders.length} selected orders?`)) return;
    
    setLoading(true);
    setMessage('');
    try {
      await Promise.all(selectedOrders.map(orderId => 
        fetchJson(`${apiBase}/pos/orders/${orderId}`, { method: 'DELETE' })
      ));
      setMessage(`${selectedOrders.length} orders deleted successfully.`);
      setSelectedOrders([]);
      await loadOrdersData();
      await loadPosData();
    } catch (error) {
      setMessage(error.message);
    } finally {
      setLoading(false);
    }
  };

  async function deleteMultipleTakeawayOrders() {
    if (selectedTakeawayOrders.length === 0) return;
    if (!confirm(`Delete ${selectedTakeawayOrders.length} selected takeaway orders?`)) return;

    setLoading(true);
    setMessage('');
    try {
      await Promise.all(selectedTakeawayOrders.map(orderId => 
        fetchJson(`${apiBase}/pos/orders/${orderId}`, { method: 'DELETE' })
      ));
      setMessage(`${selectedTakeawayOrders.length} takeaway orders deleted successfully.`);
      setSelectedTakeawayOrders([]);
      await loadOrdersData();
      await loadPosData();
    } catch (error) {
      setMessage(error.message);
    } finally {
      setLoading(false);
    }
  };

  async function markSelectedTakeawayOrdersDue() {
    if (selectedTakeawayOrders.length === 0) return;
    
    setLoading(true);
    setMessage('');
    try {
      await Promise.all(selectedTakeawayOrders.map(orderId => 
        updateOrderStatus(orderId, 'Due')
      ));
      setMessage(`${selectedTakeawayOrders.length} order${selectedTakeawayOrders.length > 1 ? 's' : ''} marked as Due.`);
      setSelectedTakeawayOrders([]);
      setTakeawaySubTab('due');
      setTakeawayPageIndex(0);
      await loadOrdersData();
    } catch (error) {
      setMessage(error.message);
    } finally {
      setLoading(false);
    }
  }

  async function markSelectedTakeawayOrdersPaid() {
    if (selectedTakeawayOrders.length === 0) return;
    
    setLoading(true);
    setMessage('');
    try {
      await Promise.all(selectedTakeawayOrders.map(orderId => 
        updateOrderStatus(orderId, 'Completed')
      ));
      setMessage(`${selectedTakeawayOrders.length} order${selectedTakeawayOrders.length > 1 ? 's' : ''} marked as Paid.`);
      setSelectedTakeawayOrders([]);
      setTakeawaySubTab('paid');
      setTakeawayPageIndex(0);
      await loadOrdersData();
    } catch (error) {
      setMessage(error.message);
    } finally {
      setLoading(false);
    }
  };

  const openViewOrderModal = (order) => {
    setOrderDetailsModal(order);
  };

  async function viewOrderById(orderId) {
    setLoading(true);
    try {
      let order = (posOrders || []).find((o) => o.id === orderId);
      if (!order) {
        order = await fetchJson(`${apiBase}/pos/orders/${orderId}`);
      }
      openViewOrderModal(order);
    } catch (err) {
      setMessage(err.message || 'Failed to load order');
    } finally {
      setLoading(false);
    }
  }

  const openRiderAssignmentModal = (order) => {
    setRiderAssignmentModal(order);
    setSelectedRider(order.deliveryAgent || '');
  };

  const getProductById = (productId) => posProducts.find((product) => String(product.id) === String(productId)) || {};
  const getOrderItemCategory = (item) => {
    const product = getProductById(item.productId);
    const category = (product.category || item.category || '').toString().toLowerCase();
    return category;
  };
  const calculateOrderAmountByCategories = (order, categories) => {
    return (order.items || []).reduce((sum, item) => {
      const category = getOrderItemCategory(item);
      const matches = categories.some((cat) => {
        const normalized = cat.toString().toLowerCase();
        return category === normalized || category.includes(normalized);
      });
      return matches ? sum + (Number(item.total) || (Number(item.price) || 0) * (Number(item.quantity) || 0) || 0) : sum;
    }, 0);
  };

  const getOrderExtrasAmount = (order) => calculateOrderAmountByCategories(order, ['Extras']);
  const getOrderBbqTandoorAmount = (order) => calculateOrderAmountByCategories(order, ['BBQ', 'Tandoor']);
  const getOrderServiceTypeCharge = (order) => {
    if (order.orderType !== 'Delivery') return 0;
    const fee = Number(order.deliveryFee || 0);
    if (order.serviceType) {
      const type = deliveryServiceTypes.find((type) => type.name === order.serviceType);
      return type ? Number(type.charge || fee) : fee;
    }
    return fee;
  };

  const getRiderBookDateRange = () => {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    if (riderBookDateFilter === 'today') {
      return { from: new Date(today), to: new Date(today.getTime() + 24 * 60 * 60 * 1000) };
    }
    if (riderBookDateFilter === 'yesterday') {
      const yesterday = new Date(today);
      yesterday.setDate(yesterday.getDate() - 1);
      return { from: new Date(yesterday), to: new Date(today) };
    }
    if (riderBookDateFilter === 'previous-5-days') {
      const fiveDaysAgo = new Date(today);
      fiveDaysAgo.setDate(fiveDaysAgo.getDate() - 5);
      return { from: new Date(fiveDaysAgo), to: new Date(today.getTime() + 24 * 60 * 60 * 1000) };
    }
    if (riderBookDateFilter === 'custom') {
      return {
        from: new Date(riderBookCustomDateFrom + 'T00:00:00'),
        to: new Date(riderBookCustomDateTo + 'T23:59:59')
      };
    }
    return { from: null, to: null };
  };

  const getRiderBookOrderDate = (order) => {
    if (order.createdAt) return new Date(order.createdAt);
    if (order.date) return new Date(order.date);
    return null;
  };

  const matchesRiderBookSearch = (order, search) => {
    if (!search) return true;
    const lowered = search.toLowerCase();
    return [order.orderNumber, order.customerName, order.phone, order.address, order.deliveryAgent, order.serviceType]
      .filter(Boolean)
      .some((value) => String(value).toLowerCase().includes(lowered));
  };

  const isRiderBookOrderInDateRange = (order, from, to) => {
    if (!from || !to) return true;
    const orderDate = getRiderBookOrderDate(order);
    return orderDate ? orderDate >= from && orderDate <= to : false;
  };

  const riderBookCashFilter = (order) => {
    const paymentStatus = String(order.paymentStatus || '').toLowerCase();
    const paymentMethod = String(order.paymentMethod || '').toLowerCase();
    const orderStatus = String(order.status || '').toLowerCase();
    const isPaidOrCompleted = paymentStatus === 'paid' || orderStatus === 'completed';
    if (isPaidOrCompleted) return false;
    return paymentStatus === 'receive cash till' || paymentMethod === 'cash' || (orderStatus === 'payment collected' && paymentMethod === 'cash');
  };

  const riderBookOnlineFilter = (order) => {
    const paymentStatus = String(order.paymentStatus || '').toLowerCase();
    const paymentMethod = String(order.paymentMethod || '').toLowerCase();
    const orderStatus = String(order.status || '').toLowerCase();
    const isPaidOrCompleted = paymentStatus === 'paid' || orderStatus === 'completed';
    if (isPaidOrCompleted) return false;
    return (
      paymentStatus === 'may be online' ||
      paymentStatus === 'online' ||
      paymentMethod === 'online' ||
      paymentStatus === 'paid to cash on counter' ||
      (orderStatus === 'payment collected' && paymentMethod === 'online')
    );
  };

  const calculateRiderBookSummary = (orders, type) => {
    return orders.reduce(
      (summary, order) => {
        const amount = Number(order.total || order.amount || 0);
        const extras = getOrderExtrasAmount(order);
        const serviceCharge = getOrderServiceTypeCharge(order);
        summary.orderValue += amount;
        summary.extras += extras;
        summary.serviceCharge += serviceCharge;
        if (type === 'cash') {
          summary.riderAmount += amount - extras - serviceCharge;
        } else {
          summary.riderAmount += extras + serviceCharge;
        }
        summary.count += 1;
        return summary;
      },
      { orderValue: 0, extras: 0, serviceCharge: 0, riderAmount: 0, count: 0 }
    );
  };

  const openRiderBookSummaryModal = (type, useVisibleOrders = false) => {
    const summaryOrders = type === 'cash'
      ? (useVisibleOrders ? riderBookCashVisibleOrders : riderBookCashSummaryOrders)
      : (useVisibleOrders ? riderBookOnlineVisibleOrders : riderBookOnlineSummaryOrders);
    const summaryData = calculateRiderBookSummary(summaryOrders, type);
    setRiderBookSummaryType(type);
    setRiderBookSummaryData(summaryData);
    setShowRiderBookSummaryModal(true);
  };

  const closeRiderBookSummaryModal = () => {
    setShowRiderBookSummaryModal(false);
    setRiderBookSummaryData(null);
  };

  const riderBookAssignedOrders = posOrders.filter((order) => order.deliveryAgent || (String(order.status || '').toLowerCase() === 'payment collected'));
  const riderBookFilteredByRider = riderBookFilterRider
    ? riderBookAssignedOrders.filter((order) => {
        if (String(order.status || '').toLowerCase() === 'payment collected') {
          return order.deliveryAgent === riderBookFilterRider;
        }
        return order.deliveryAgent === riderBookFilterRider;
      })
    : riderBookAssignedOrders;
  const riderBookFilteredBySubTab = riderBookFilteredByRider.filter((order) => {
    const paymentStatus = String(order.paymentStatus || '').toLowerCase();
    const paymentMethod = String(order.paymentMethod || '').toLowerCase();
    const orderStatus = String(order.status || '').toLowerCase();

    if (riderBookMainTab === 'live') {
      if (riderBookSubTab === 'cash') {
        return paymentStatus === 'receive cash till';
      }
      if (riderBookSubTab === 'online') {
        if (paymentStatus === 'paid' || orderStatus === 'completed') return false;
        return (
          paymentStatus === 'may be online' ||
          paymentStatus === 'online' ||
          paymentMethod === 'online' ||
          paymentStatus === 'paid to cash on counter' ||
          (orderStatus === 'payment collected' && paymentMethod === 'online')
        );
      }
      if (riderBookSubTab === 'all') {
        if (paymentStatus === 'paid' || orderStatus === 'completed') return false;
        return (
          paymentStatus === 'receive cash till' ||
          paymentStatus === 'may be online' ||
          paymentStatus === 'online' ||
          paymentMethod === 'online' ||
          paymentMethod === 'cash' ||
          paymentStatus === 'paid to cash on counter' ||
          (orderStatus === 'payment collected' && (paymentMethod === 'online' || paymentMethod === 'cash'))
        );
      }
    }
    if (riderBookMainTab === 'sales') {
      if (riderBookSubTab === 'due') {
        return orderStatus === 'payment pending';
      }
      if (riderBookSubTab === 'paid') {
        return paymentStatus === 'paid' || orderStatus === 'completed';
      }
      if (riderBookSubTab === 'all') {
        return orderStatus === 'payment pending' || paymentStatus === 'paid' || orderStatus === 'completed';
      }
    }
    return true;
  });

  const riderBookDateFilteredAll = riderBookFilteredByRider.filter((order) => {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const getDateRange = () => {
      const from = new Date(today);
      const to = new Date(today);

      if (riderBookDateFilter === 'today') {
        return { from: new Date(today), to: new Date(today.getTime() + 24 * 60 * 60 * 1000) };
      }
      if (riderBookDateFilter === 'yesterday') {
        const yesterday = new Date(today);
        yesterday.setDate(yesterday.getDate() - 1);
        return { from: new Date(yesterday), to: new Date(today) };
      }
      if (riderBookDateFilter === 'previous-5-days') {
        const fiveDaysAgo = new Date(today);
        fiveDaysAgo.setDate(fiveDaysAgo.getDate() - 5);
        return { from: new Date(fiveDaysAgo), to: new Date(today.getTime() + 24 * 60 * 60 * 1000) };
      }
      if (riderBookDateFilter === 'custom') {
        return {
          from: new Date(riderBookCustomDateFrom + 'T00:00:00'),
          to: new Date(riderBookCustomDateTo + 'T23:59:59')
        };
      }
      return { from: null, to: null };
    };

    const { from, to } = getDateRange();
    if (!from || !to) return true;

    const orderDate = order.createdAt ? new Date(order.createdAt) : order.date ? new Date(order.date) : null;
    return orderDate ? orderDate >= from && orderDate <= to : false;
  });

  const riderBookDateFiltered = riderBookFilteredBySubTab.filter((order) => {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const getDateRange = () => {
      const from = new Date(today);
      const to = new Date(today);

      if (riderBookDateFilter === 'today') {
        return { from: new Date(today), to: new Date(today.getTime() + 24 * 60 * 60 * 1000) };
      }
      if (riderBookDateFilter === 'yesterday') {
        const yesterday = new Date(today);
        yesterday.setDate(yesterday.getDate() - 1);
        return { from: new Date(yesterday), to: new Date(today) };
      }
      if (riderBookDateFilter === 'previous-5-days') {
        const fiveDaysAgo = new Date(today);
        fiveDaysAgo.setDate(fiveDaysAgo.getDate() - 5);
        return { from: new Date(fiveDaysAgo), to: new Date(today.getTime() + 24 * 60 * 60 * 1000) };
      }
      if (riderBookDateFilter === 'custom') {
        return {
          from: new Date(riderBookCustomDateFrom + 'T00:00:00'),
          to: new Date(riderBookCustomDateTo + 'T23:59:59')
        };
      }
      return { from: null, to: null };
    };

    const { from, to } = getDateRange();
    if (!from || !to) return true;

    const orderDate = order.createdAt ? new Date(order.createdAt) : order.date ? new Date(order.date) : null;
    return orderDate ? orderDate >= from && orderDate <= to : false;
  });

  const riderBookSearchFiltered = riderBookDateFiltered.filter((order) => {
    const search = riderBookSearch.trim().toLowerCase();
    if (!search) return true;
    return [order.orderNumber, order.customerName, order.phone, order.address, order.deliveryAgent, order.serviceType]
      .filter(Boolean)
      .some((value) => value.toLowerCase().includes(search));
  });

  // Build visible cash/online lists from the same filtered set the table uses
  const riderBookSearchFilteredAll = riderBookDateFilteredAll.filter((order) => {
    const search = riderBookSearch.trim().toLowerCase();
    if (!search) return true;
    return [order.orderNumber, order.customerName, order.phone, order.address, order.deliveryAgent, order.serviceType]
      .filter(Boolean)
      .some((value) => value.toLowerCase().includes(search));
  });

  const riderBookCashSummaryOrders = riderBookSearchFilteredAll.filter(riderBookCashFilter);
  const riderBookOnlineSummaryOrders = riderBookSearchFilteredAll.filter(riderBookOnlineFilter);

  const riderBookCashVisibleOrders = riderBookSearchFiltered.filter(riderBookCashFilter);

  const riderBookOnlineVisibleOrders = riderBookSearchFiltered.filter(riderBookOnlineFilter);

  const riderBookVisibleCashOnlineOrders = Array.from(
    new Map(
      [...riderBookCashVisibleOrders, ...riderBookOnlineVisibleOrders].map((order) => [order.id, order])
    ).values()
  );

  const riderBookSelectedOrdersList = posOrders.filter((order) => riderBookSelectedOrders.includes(order.id));
  const selectedTotals = riderBookSelectedOrdersList.reduce((sum, order) => {
    const amount = Number(order.total || order.amount || 0);
    sum.total += amount;
    sum.extras += getOrderExtrasAmount(order);
    sum.serviceType += getOrderServiceTypeCharge(order);
    sum.bbqTandoor += getOrderBbqTandoorAmount(order);
    return sum;
  }, { total: 0, extras: 0, serviceType: 0, bbqTandoor: 0 });
  selectedTotals.excluded = Math.max(0, selectedTotals.total - selectedTotals.extras - selectedTotals.serviceType);

  const riderBookVisibleOrders = riderBookSearchFiltered;
  const riderBookPageCount = Math.max(1, Math.ceil(riderBookVisibleOrders.length / riderBookPageSize));
  const riderBookPaginatedOrders = riderBookVisibleOrders.slice(riderBookPageIndex * riderBookPageSize, (riderBookPageIndex + 1) * riderBookPageSize);
  const riderBookTotals = riderBookVisibleOrders.reduce((sum, order) => {
    const amount = Number(order.total || order.amount || 0);
    sum.total += amount;
    sum.extras += getOrderExtrasAmount(order);
    sum.serviceType += getOrderServiceTypeCharge(order);
    sum.bbqTandoor += getOrderBbqTandoorAmount(order);
    return sum;
  }, { total: 0, extras: 0, serviceType: 0, bbqTandoor: 0 });
  riderBookTotals.excluded = Math.max(0, riderBookTotals.total - riderBookTotals.extras - riderBookTotals.serviceType);

  // Build rider list for the Rider Book dropdown from the staff roster only.
  // Only show staff members who are configured as bikers/riders.
  const riderBookRiders = Array.from(
    new Set(
      (staff || [])
        .filter((member) => ['Biker', 'Admin Rider'].includes(member.role) && member.loginEnabled)
        .map((member) => String(member.name || member.username || member.email || '').trim())
        .filter(Boolean)
    )
  );

  const toggleRiderBookOrderSelection = (orderId) => {
    setRiderBookSelectedOrders((prev) =>
      prev.includes(orderId) ? prev.filter((id) => id !== orderId) : [...prev, orderId]
    );
  };

  const selectAllRiderBookOrders = (orders) => {
    setRiderBookSelectedOrders(orders.map((order) => order.id));
  };

  const clearRiderBookSelection = () => {
    setRiderBookSelectedOrders([]);
  };

  async function updateRiderBookOrdersStatus(orderIds, status, paymentMethod = null, paymentStatus = null) {
    if (!orderIds.length) {
      setMessage('Please select at least one order to update.');
      return false;
    }
    setLoading(true);
    setMessage('');
    try {
      await Promise.all(orderIds.map(async (orderId) => {
        const order = posOrders.find((item) => item.id === orderId);
        if (!order) return;
        await fetchJson(`${apiBase}/pos/orders/${orderId}`, {
          method: 'PUT',
          body: JSON.stringify({
            ...order,
            status,
            paymentMethod: paymentMethod || order.paymentMethod,
            paymentStatus: paymentStatus !== null ? paymentStatus : order.paymentStatus
          })
        });
      }));
      setMessage(`Updated ${orderIds.length} rider order(s) to ${status}.`);
      setRiderBookSelectedOrders([]);
      await loadOrdersData();
      return true;
    } catch (error) {
      setMessage(error.message);
      return false;
    } finally {
      setLoading(false);
    }
  }

  const markRiderCash = async () => {
    const success = await updateRiderBookOrdersStatus(riderBookSelectedOrders, 'Payment Collected', 'Cash', 'Receive Cash Till');
    if (success) {
      setRiderBookMainTab('live');
      setRiderBookSubTab('cash');
    }
  };

  const markRiderOnline = async () => {
    const success = await updateRiderBookOrdersStatus(riderBookSelectedOrders, 'Payment Collected', 'Online', 'May be Online');
    if (success) {
      setRiderBookMainTab('live');
      setRiderBookSubTab('online');
    }
  };

  const markRiderPaid = async () => {
    const success = await updateRiderBookOrdersStatus(riderBookSelectedOrders, 'Completed', null, 'Paid');
    if (success) {
      setRiderBookMainTab('sales');
      setRiderBookSubTab('paid');
    }
  };

  const markCustomerPending = async () => {
    const success = await updateRiderBookOrdersStatus(riderBookSelectedOrders, 'Payment Pending', null, 'Due');
    if (success) {
      setRiderBookMainTab('sales');
      setRiderBookSubTab('due');
    }
  };

  const renderRiderBook = () => {
    const displayTotals = riderBookSelectedOrdersList.length ? selectedTotals : riderBookTotals;
    const isCashTab = riderBookSubTab === 'cash';
    const riderBookExtrasServiceTotal = displayTotals.extras + displayTotals.serviceType;
    const riderBookCashOrderCount = riderBookVisibleOrders.length;
    const riderBookCashSummary = calculateRiderBookSummary(riderBookCashSummaryOrders, 'cash');
    const riderBookOnlineSummary = calculateRiderBookSummary(riderBookOnlineSummaryOrders, 'online');
    const riderBookDifference = riderBookCashSummary.riderAmount - riderBookOnlineSummary.riderAmount;
    const pageStart = riderBookPageIndex * riderBookPageSize + 1;
    const pageEnd = Math.min((riderBookPageIndex + 1) * riderBookPageSize, riderBookVisibleOrders.length);

    const getRiderBookPaymentStatus = (order) => {
      if (order.status === 'Payment Pending') return 'Due';
      if (order.paymentStatus && order.paymentStatus !== 'Paid') return order.paymentStatus;
      if (order.status === 'Payment Collected' || order.status === 'Completed' || order.paymentStatus === 'Paid') return 'PAID';
      if (order.paymentMethod === 'Online') return 'May be Online';
      if (order.paymentMethod === 'Cash') return 'Receive Cash Till';
      return '';
    };

    return (
      <div className="space-y-6">
        <div className="rounded-[32px] border border-slate-800 bg-slate-900 p-6 shadow-soft glow-border glow-pulse">


          <div className="space-y-4">
            <div className="grid grid-cols-1 gap-3 xl:grid-cols-3 mb-2">
              <div
                onClick={() => openRiderBookSummaryModal('cash')}
                className="cursor-pointer rounded-3xl border border-slate-800 bg-slate-950 p-4 shadow-soft transition hover:border-emerald-500/40 hover:bg-slate-900"
              >
                <div className="text-xs uppercase tracking-[0.24em] text-slate-400">Cash Summary</div>
                <div className="mt-3 text-2xl font-semibold text-white">{Number(riderBookCashSummary.riderAmount).toLocaleString()} Rs</div>
                <div className="mt-1 text-xs text-slate-400">Cash minus extras & fees</div>
                <div className="mt-3 inline-flex items-center gap-2 rounded-full bg-emerald-600 px-3 py-1 text-xs font-semibold text-white">Summary</div>
              </div>
              <div
                onClick={() => openRiderBookSummaryModal('online')}
                className="cursor-pointer rounded-3xl border border-slate-800 bg-slate-950 p-4 shadow-soft transition hover:border-sky-500/40 hover:bg-slate-900"
              >
                <div className="text-xs uppercase tracking-[0.24em] text-slate-400">Online Summary</div>
                <div className="mt-3 text-2xl font-semibold text-white">{Number(riderBookOnlineSummary.riderAmount).toLocaleString()} Rs</div>
                <div className="mt-1 text-xs text-slate-400">Extras + delivery fees</div>
                <div className="mt-3 inline-flex items-center gap-2 rounded-full bg-sky-600 px-3 py-1 text-xs font-semibold text-white">Summary</div>
              </div>
              <div className="rounded-3xl border border-slate-800 bg-slate-950 p-4 shadow-soft">
                <div className="text-xs uppercase tracking-[0.24em] text-slate-400">Difference</div>
                <div className="mt-3 text-2xl font-semibold text-white">{Number(riderBookDifference).toLocaleString()} Rs</div>
                <div className="mt-1 text-xs text-slate-400">Net rider amount</div>
                {riderBookVisibleCashOnlineOrders.length > 0 && (
                  <button
                    onClick={async () => {
                      await updateRiderBookOrdersStatus(
                        riderBookVisibleCashOnlineOrders.map((order) => order.id),
                        'Payment Collected',
                        null,
                        'Paid'
                      );
                      setRiderBookSubTab('paid');
                    }}
                    className="mt-4 w-full rounded-full bg-emerald-600 px-4 py-3 text-sm font-semibold text-white transition hover:bg-emerald-500"
                  >
                    {riderBookDifference < 0 ? 'Pay to Rider' : 'Collect Amount from Rider'}
                  </button>
                )}
              </div>
            </div>

            <div className="flex flex-wrap items-center justify-between gap-3 rounded-3xl border border-slate-800 bg-slate-900 p-4">
              <div className="flex flex-wrap gap-2">
                {['live', 'sales'].map((tab) => (
                  <button
                    key={tab}
                    onClick={() => {
                      setRiderBookMainTab(tab);
                      setRiderBookSubTab(tab === 'live' ? 'cash' : 'due');
                    }}
                    className={`rounded-full px-4 py-2 text-sm font-semibold transition ${riderBookMainTab === tab ? 'bg-emerald-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}
                  >
                    {tab === 'live' ? 'Live' : 'Sales'}
                  </button>
                ))}
              </div>

              <div className="flex-1 min-w-[200px] max-w-[360px]">
                <input
                  type="text"
                  value={riderBookSearch}
                  onChange={(e) => setRiderBookSearch(e.target.value)}
                  placeholder="Search rider, order, address..."
                  className="w-full rounded-full border border-slate-800 bg-slate-900 px-4 py-2 text-sm text-slate-100 outline-none focus:border-emerald-500"
                />
              </div>

              <select
                value={riderBookFilterRider}
                onChange={(e) => {
                  setRiderBookFilterRider(e.target.value);
                  setRiderBookPageIndex(0);
                }}
                className="rounded-full border border-slate-800 bg-slate-900 px-4 py-2 text-sm text-slate-200 outline-none focus:border-emerald-500"
              >
                <option value="">All Riders</option>
                {Array.from(new Set(riderBookAssignedOrders.map((o) => o.deliveryAgent).filter(Boolean))).map((rider) => (
                  <option key={rider} value={rider}>
                    {rider}
                  </option>
                ))}
              </select>

              <div className="flex flex-wrap items-center gap-2">
                {riderBookSelectedOrders.length > 0 && (
                  <>
                    <button onClick={() => selectAllRiderBookOrders(riderBookVisibleOrders)} className="rounded-full bg-slate-800 px-4 py-2 text-sm text-slate-200 transition hover:bg-slate-700">Select All</button>
                    <button onClick={clearRiderBookSelection} className="rounded-full bg-slate-800 px-4 py-2 text-sm text-slate-200 transition hover:bg-slate-700">Clear</button>
                    <span className="text-sm text-slate-400">{riderBookSelectedOrders.length} selected</span>
                  </>
                )}
                <span className="text-xs uppercase tracking-[0.2em] text-slate-400">Date</span>
                {['today', 'yesterday', 'previous-5-days', 'custom'].map((filter) => (
                  <button
                    key={filter}
                    onClick={() => {
                      setRiderBookDateFilter(filter);
                      setRiderBookPageIndex(0);
                    }}
                    className={`rounded-full px-3 py-1 text-xs font-semibold transition ${riderBookDateFilter === filter ? 'bg-cyan-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}
                  >
                    {filter === 'today' ? '📅 Today' : filter === 'yesterday' ? '📅 Yesterday' : filter === 'previous-5-days' ? '📅 Last 5 Days' : '📅 Custom'}
                  </button>
                ))}
                {riderBookDateFilter === 'custom' && (
                  <div className="flex flex-wrap items-center gap-2 ml-2 pl-2 border-l border-slate-700">
                    <input
                      type="date"
                      value={riderBookCustomDateFrom}
                      onChange={(e) => {
                        setRiderBookCustomDateFrom(e.target.value);
                        setRiderBookPageIndex(0);
                      }}
                      className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-xs text-slate-200 focus:outline-none"
                    />
                    <span className="text-slate-400">to</span>
                    <input
                      type="date"
                      value={riderBookCustomDateTo}
                      onChange={(e) => {
                        setRiderBookCustomDateTo(e.target.value);
                        setRiderBookPageIndex(0);
                      }}
                      className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-xs text-slate-200 focus:outline-none"
                    />
                  </div>
                )}
              </div>
            </div>

            <div className="flex flex-wrap items-center gap-2">
              {(riderBookMainTab === 'live' ? ['cash', 'online'] : ['due', 'paid', 'all']).map((sub) => {
                const isActive = riderBookSubTab === sub;
                const gradient = sub === 'cash' ? 'from-emerald-500 to-emerald-700' : sub === 'online' ? 'from-sky-500 to-indigo-600' : 'from-slate-700 to-slate-800';
                return (
                  <div key={sub} className="flex items-center gap-2">
                    <button
                      onClick={() => setRiderBookSubTab(sub)}
                      className={`rounded-full px-4 py-2 text-sm font-semibold transition ${isActive ? `bg-gradient-to-r ${gradient} text-white shadow-lg` : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}
                    >
                      {riderBookMainTab === 'live'
                        ? sub === 'all'
                          ? 'All'
                          : sub === 'cash'
                          ? 'Cash'
                          : 'Online'
                        : sub === 'all'
                        ? 'All'
                        : sub === 'due'
                        ? 'Due'
                        : 'Paid'}
                    </button>
                    {(sub === 'cash' || sub === 'online') && (
                      <button
                        onClick={() => openRiderBookSummaryModal(sub, true)}
                        className="rounded-full border border-slate-700 bg-slate-800 px-3 py-2 text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-300 transition hover:border-cyan-500 hover:text-white hover:bg-slate-700"
                      >
                        Summary
                      </button>
                    )}
                  </div>
                );
              })}
            </div>
          </div>
        </div>

        {riderBookSelectedOrders.length > 0 && (
          <div className="flex flex-wrap gap-2 mb-4 p-4 rounded-xl bg-slate-800/50 border border-slate-700">
            <button onClick={markRiderCash} className="rounded-full bg-slate-800 px-4 py-2 text-sm font-semibold text-slate-200 transition hover:bg-slate-700">Mark Cash</button>
            <button onClick={markRiderOnline} className="rounded-full bg-slate-800 px-4 py-2 text-sm font-semibold text-slate-200 transition hover:bg-slate-700">Mark Online</button>
            <button onClick={markRiderPaid} className="rounded-full bg-slate-800 px-4 py-2 text-sm font-semibold text-slate-200 transition hover:bg-slate-700">Mark Paid</button>
            <button onClick={markCustomerPending} className="rounded-full bg-slate-800 px-4 py-2 text-sm font-semibold text-slate-200 transition hover:bg-slate-700">Mark Pending Due</button>
          </div>
        )}
        <div className="rounded-[32px] border border-slate-800 bg-slate-950 p-4 shadow-soft overflow-x-auto">
          <div className="hidden lg:grid grid-cols-[40px_1.2fr_1.5fr_1fr_1.2fr_1.2fr_1fr_1fr_1.2fr_1.2fr_1.5fr] gap-3 text-[10px] uppercase tracking-[0.24em] text-slate-400 border-b border-slate-800 pb-3 mb-3">
            <span></span>
            <span>Order #</span>
            <span>Delivery Address</span>
            <span>Phone</span>
            <span>Service Type</span>
            <span>Products</span>
            <span>Total</span>
            <span>Rider</span>
            <span>Payment</span>
            <span>Date</span>
            <span>Actions</span>
          </div>
          <div className="space-y-2">
            {riderBookPaginatedOrders.map((order) => {
              const isSelected = riderBookSelectedOrders.includes(order.id);
              const itemCount = (order.items || []).length;
              const orderDate = order.createdAt ? new Date(order.createdAt).toLocaleString('en-US', { month: '2-digit', day: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit', hour12: true }) : 'N/A';
              const paymentStatus = getRiderBookPaymentStatus(order);
              const isPaidStatus = paymentStatus === 'PAID';
              const isDueStatus = paymentStatus === 'Due';
              return (
                <div key={order.id} className="hidden lg:grid grid-cols-[40px_1.2fr_1.5fr_1fr_1.2fr_1.2fr_1fr_1fr_1.2fr_1.2fr_1.5fr] gap-3 rounded-3xl border border-slate-800 bg-slate-900 p-3 text-xs text-slate-200 items-center transition hover:border-emerald-500/20 hover:bg-slate-900">
                  <input type="checkbox" checked={isSelected} onChange={() => toggleRiderBookOrderSelection(order.id)} className="h-4 w-4 rounded border-slate-700 bg-slate-900 text-emerald-600 focus:ring-emerald-500" />
                  <div className="font-semibold text-white">{order.orderNumber || order.id}</div>
                  <div className="text-[11px] text-slate-300 truncate">{order.address || 'Walk-In'}</div>
                  <div className="text-[11px] text-slate-300">{order.phone || '-'}</div>
                  <div className="text-[11px] text-slate-300">{order.serviceType || '-'}</div>
                  <div className="text-[11px] text-slate-300">{itemCount} item{itemCount !== 1 ? 's' : ''}</div>
                  <div className="font-semibold text-white">{Number(order.total || order.amount || 0)} Rs</div>
                  <div className="text-[11px] text-slate-300">{order.deliveryAgent || '-'}</div>
                  <div className="px-2 py-2">
                    <div className={`inline-flex items-center gap-1 rounded-xl px-2 py-1 text-[11px] font-semibold ${isPaidStatus ? 'border-emerald-500 bg-emerald-950 text-emerald-300' : isDueStatus ? 'border-rose-500 bg-rose-950 text-rose-300' : 'border-slate-700 bg-slate-950 text-slate-200'}`}>
                      {paymentStatus ? (
                        <>
                          {isPaidStatus && (
                            <svg viewBox="0 0 24 24" className="h-3 w-3 text-emerald-300" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                              <path d="M20 6L9 17l-5-5" />
                            </svg>
                          )}
                          <span className="truncate max-w-[90px]">{paymentStatus}</span>
                        </>
                      ) : (
                        <span className="text-slate-500">-</span>
                      )}
                    </div>
                  </div>
                  <div className="text-[11px] text-slate-400">{orderDate}</div>
                  <div className="relative flex items-center justify-end">
                    <button
                      onClick={() => setRiderBookActionOpen(riderBookActionOpen === order.id ? null : order.id)}
                      className="rounded-full border border-slate-700 bg-slate-950 p-2 text-slate-200 transition hover:border-emerald-500 hover:bg-slate-900"
                      title="Actions"
                    >
                      <svg viewBox="0 0 24 24" className="h-4 w-4"><path d="M12 7a5 5 0 100 10 5 5 0 000-10zm0-5C7 2 2.7 4.4 1 8.5 2.7 12.6 7 15 12 15s9.3-2.4 11-6.5C21.3 4.4 17 2 12 2zm0 11a4 4 0 110-8 4 4 0 010 8z" fill="currentColor"/></svg>
                    </button>
                    {riderBookActionOpen === order.id && (
                      <div className="absolute right-0 top-full mt-2 z-50 rounded-2xl border border-slate-700 bg-slate-900 shadow-xl overflow-hidden">
                        <button
                          type="button"
                          title="View order"
                          onClick={() => {
                            openViewOrderModal(order);
                            setRiderBookActionOpen(null);
                          }}
                          className="w-full px-4 py-2 text-left text-xs text-slate-200 hover:bg-slate-800 transition flex items-center gap-2 border-b border-slate-800"
                        >
                          <svg viewBox="0 0 24 24" className="h-4 w-4"><path d="M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5C21.27 7.61 17 4.5 12 4.5zm0 12c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5zm0-8.5a3.5 3.5 0 1 0 0 7 3.5 3.5 0 0 0 0-7z" fill="currentColor"/></svg>
                          View
                        </button>
                        <button
                          type="button"
                          title="Delete order"
                          onClick={() => {
                            deleteOrder(order.id);
                            setRiderBookActionOpen(null);
                          }}
                          className="w-full px-4 py-2 text-left text-xs text-rose-300 hover:bg-slate-800 transition flex items-center gap-2 border-b border-slate-800"
                        >
                          <svg viewBox="0 0 24 24" className="h-4 w-4"><path d="M3 6h18" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/><path d="M8 6V4h8v2" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/><path d="M19 6l-1 14H6L5 6" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/><path d="M10 11v6" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/><path d="M14 11v6" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/></svg>
                          Delete
                        </button>
                        <button
                          type="button"
                          title="Print order"
                          onClick={() => {
                            printReceipt(order);
                            setRiderBookActionOpen(null);
                          }}
                          className="w-full px-4 py-2 text-left text-xs text-emerald-300 hover:bg-slate-800 transition flex items-center gap-2 border-b border-slate-800"
                        >
                          <svg viewBox="0 0 24 24" className="h-4 w-4"><path d="M6 9V3h12v6" stroke="currentColor" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/><path d="M6 18h12v-6H6v6z" stroke="currentColor" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/><path d="M9 21h6" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/></svg>
                          Print
                        </button>
                        <button
                          type="button"
                          title="Assign rider"
                          onClick={() => {
                            openRiderAssignmentModal(order);
                            setRiderBookActionOpen(null);
                          }}
                          className="w-full px-4 py-2 text-left text-xs text-purple-300 hover:bg-slate-800 transition flex items-center gap-2"
                        >
                          <svg viewBox="0 0 24 24" className="h-4 w-4"><path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" fill="currentColor"/></svg>
                          Assign Rider
                        </button>
                      </div>
                    )}
                  </div>
                </div>
              );
            })}
            {!riderBookPaginatedOrders.length && (
              <div className="rounded-3xl border border-slate-800 bg-slate-900 p-8 text-center text-slate-400">No rider orders found for the selected filters.</div>
            )}
          </div>
        </div>

        <div className="space-y-3">
          <div className="flex flex-wrap items-center gap-4 text-sm text-slate-400">
            <div>Visible orders: <span className="font-semibold text-white">{riderBookVisibleOrders.length}</span></div>
            <div>Selected: <span className="font-semibold text-white">{riderBookSelectedOrders.length || 0}</span></div>
            <div>Page size: <span className="font-semibold text-white">{riderBookPageSize}</span></div>
          </div>
          <div className="flex flex-wrap items-center gap-2 text-sm text-slate-400">
            <span>Show</span>
            {[15, 50, 100].map((size) => (
              <button
                key={size}
                onClick={() => setRiderBookPageSize(size)}
                className={`rounded-full px-3 py-2 font-semibold transition ${riderBookPageSize === size ? 'bg-emerald-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}
              >
                {size}
              </button>
            ))}
          </div>
          <div className="flex flex-wrap items-center justify-between gap-3 text-sm text-slate-400">
            <div>{riderBookVisibleOrders.length ? `Showing ${pageStart}-${pageEnd} of ${riderBookVisibleOrders.length}` : 'No orders to display'}</div>
            <div className="flex items-center gap-2">
              <button onClick={() => setRiderBookPageIndex((prev) => Math.max(prev - 1, 0))} disabled={riderBookPageIndex === 0} className="rounded-full bg-slate-800 px-3 py-2 text-sm text-slate-200 transition hover:bg-slate-700 disabled:opacity-50">Prev</button>
              <button onClick={() => setRiderBookPageIndex((prev) => Math.min(prev + 1, riderBookPageCount - 1))} disabled={riderBookPageIndex >= riderBookPageCount - 1} className="rounded-full bg-slate-800 px-3 py-2 text-sm text-slate-200 transition hover:bg-slate-700 disabled:opacity-50">Next</button>
            </div>
          </div>
        </div>
        {showRiderBookSummaryModal && riderBookSummaryData && (
          <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/80 p-4">
            <div className="w-full max-w-2xl rounded-[32px] border border-slate-700 bg-slate-900 p-6 shadow-2xl">
              <div className="flex items-start justify-between gap-4">
                <div>
                  <div className="text-sm uppercase tracking-[0.24em] text-slate-400">Rider Book Summary</div>
                  <div className="mt-2 text-3xl font-semibold text-white">{riderBookSummaryType === 'cash' ? 'Cash Summary' : 'Online Summary'}</div>
                </div>
                <button onClick={closeRiderBookSummaryModal} className="rounded-full border border-slate-700 bg-slate-950 px-4 py-2 text-sm text-slate-200 hover:border-rose-500 hover:text-white">Close</button>
              </div>
              <div className="mt-6 grid gap-4 sm:grid-cols-2">
                <div className="rounded-3xl border border-slate-800 bg-slate-950 p-5">
                  <div className="text-xs uppercase tracking-[0.24em] text-slate-400">Order Value</div>
                  <div className="mt-3 text-2xl font-semibold text-white">{Number(riderBookSummaryData.orderValue).toLocaleString()} Rs</div>
                </div>
                <div className="rounded-3xl border border-slate-800 bg-slate-950 p-5">
                  <div className="text-xs uppercase tracking-[0.24em] text-slate-400">Extras Total</div>
                  <div className="mt-3 text-2xl font-semibold text-white">{Number(riderBookSummaryData.extras).toLocaleString()} Rs</div>
                </div>
                <div className="rounded-3xl border border-slate-800 bg-slate-950 p-5">
                  <div className="text-xs uppercase tracking-[0.24em] text-slate-400">Delivery Fees</div>
                  <div className="mt-3 text-2xl font-semibold text-white">{Number(riderBookSummaryData.serviceCharge).toLocaleString()} Rs</div>
                </div>
                <div className="rounded-3xl border border-slate-800 bg-slate-950 p-5">
                  <div className="text-xs uppercase tracking-[0.24em] text-slate-400">Rider Amount</div>
                  <div className="mt-3 text-2xl font-semibold text-white">{Number(riderBookSummaryData.riderAmount).toLocaleString()} Rs</div>
                </div>
              </div>
              <div className="mt-6 rounded-3xl border border-slate-800 bg-slate-950 p-5 text-sm text-slate-300">
                {riderBookSummaryType === 'cash'
                  ? 'Cash summary shows cash collected after subtracting extras and delivery fees from the order total.'
                  : 'Online summary shows online rider balance from extras and delivery fees owed to riders.'}
              </div>
            </div>
          </div>
        )}
      </div>
    );
  };

  const renderRiderOrderRequests = () => {
    const filteredByStatus = pendingRequests.filter((req) => {
      if (riderOrderRequestsStatus === 'pending') return req.status === 'pending';
      if (riderOrderRequestsStatus === 'approved') return req.status === 'approved';
      if (riderOrderRequestsStatus === 'rejected') return req.status === 'rejected';
      return true;
    });

    const filteredByDate = filteredByStatus.filter((req) => {
      const reqDate = req.createdAt ? new Date(req.createdAt).toDateString() : '';
      const today = new Date().toDateString();
      const yesterday = new Date(Date.now() - 86400000).toDateString();
      const fiveDaysAgo = new Date(Date.now() - 5 * 86400000).toDateString();

      if (riderOrderRequestsDateFilter === 'today') return reqDate === today;
      if (riderOrderRequestsDateFilter === 'yesterday') return reqDate === yesterday;
      if (riderOrderRequestsDateFilter === 'previous-5-days') return new Date(reqDate) >= new Date(fiveDaysAgo);
      if (riderOrderRequestsDateFilter === 'custom') {
        const from = riderOrderRequestsCustomDateFrom ? new Date(riderOrderRequestsCustomDateFrom).toDateString() : '';
        const to = riderOrderRequestsCustomDateTo ? new Date(riderOrderRequestsCustomDateTo).toDateString() : '';
        return (!from || reqDate >= from) && (!to || reqDate <= to);
      }
      return true;
    });

    return (
      <div className="space-y-6">
        {/* Main Tab Switcher */}
        <div className="flex flex-wrap gap-2 items-center rounded-3xl border border-slate-800 bg-slate-900 p-4">
          {['requests', 'shift-control'].map((tab) => (
            <button
              key={tab}
              onClick={() => setRiderOrderRequestsMainTab(tab)}
              className={`rounded-full px-4 py-2 text-sm font-semibold transition ${riderOrderRequestsMainTab === tab ? 'bg-emerald-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}
            >
              {tab === 'requests' ? 'Requests' : 'Shift Control'}
            </button>
          ))}
        </div>

        {/* Rider Requests View */}
        {riderOrderRequestsMainTab === 'requests' && (
          <div className="space-y-4">
            <div className="space-y-3">
              <div className="flex flex-wrap gap-2 items-center">
                {['pending', 'approved', 'rejected'].map((status) => (
                  <button
                    key={status}
                    onClick={() => setRiderOrderRequestsStatus(status)}
                    className={`rounded-full px-4 py-2 text-sm font-semibold transition ${riderOrderRequestsStatus === status ? 'bg-emerald-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}
                  >
                    {status === 'pending' ? 'New Request' : status === 'approved' ? 'Approved' : 'Rejected'}
                  </button>
                ))}
              </div>

              <div className="flex flex-wrap items-center gap-3 rounded-3xl border border-slate-800 bg-slate-900 p-4">
                <div className="flex flex-wrap items-center gap-2">
                  <span className="text-xs uppercase tracking-[0.2em] text-slate-400">Date</span>
                  {['today', 'yesterday', 'previous-5-days', 'custom'].map((filter) => (
                    <button
                      key={filter}
                      onClick={() => {
                        setRiderOrderRequestsDateFilter(filter);
                      }}
                      className={`rounded-full px-3 py-1 text-xs font-semibold transition ${riderOrderRequestsDateFilter === filter ? 'bg-cyan-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}
                    >
                      {filter === 'today' ? '📅 Today' : filter === 'yesterday' ? '📅 Yesterday' : filter === 'previous-5-days' ? '📅 Last 5 Days' : '📅 Custom'}
                    </button>
                  ))}
                </div>
                {riderOrderRequestsDateFilter === 'custom' && (
                  <div className="flex flex-wrap items-center gap-2 ml-2 pl-2 border-l border-slate-700">
                    <input
                      type="date"
                      value={riderOrderRequestsCustomDateFrom}
                      onChange={(e) => setRiderOrderRequestsCustomDateFrom(e.target.value)}
                      className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-xs text-slate-200 focus:outline-none"
                    />
                    <span className="text-slate-400">to</span>
                    <input
                      type="date"
                      value={riderOrderRequestsCustomDateTo}
                      onChange={(e) => setRiderOrderRequestsCustomDateTo(e.target.value)}
                      className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-xs text-slate-200 focus:outline-none"
                    />
                  </div>
                )}
              </div>
            </div>

            <div className="rounded-[12px] border border-slate-800 bg-slate-900 p-4 shadow-soft">
              <div className="flex items-center justify-between mb-3">
                <h3 className="text-sm font-semibold text-white">
                  {riderOrderRequestsStatus === 'pending' ? 'New Requests' : riderOrderRequestsStatus === 'approved' ? 'Approved Requests' : 'Rejected Requests'}
                  <span className="ml-2 text-slate-400">({filteredByDate.length})</span>
                </h3>
                <button onClick={loadPendingRequests} className="text-sm px-3 py-1 rounded bg-slate-800 text-slate-200 hover:bg-slate-700">Refresh</button>
              </div>
              {filteredByDate.length === 0 ? (
                <p className="text-sm text-slate-400">No requests found</p>
              ) : (
                <div className="space-y-2">
                  {filteredByDate.map((req) => (
                    <div key={req.id} className="flex items-center justify-between bg-slate-800 p-3 rounded">
                      <div>
                        <div className="text-sm text-slate-200 font-semibold">{req.orderNumber}</div>
                        <div className="text-xs text-slate-400">Rider: {req.riderName} · Status: {req.status}</div>
                        <div className="text-xs text-slate-400">Total: {req.orderTotal} Rs</div>
                      </div>
                      <div className="flex gap-2">
                        <button onClick={() => viewOrderById(req.orderId)} className="px-3 py-1 rounded bg-gray-700 text-white text-sm hover:bg-gray-600">View</button>
                        {req.status === 'pending' && (
                          <>
                            <button onClick={() => approveRiderRequest(req.id)} className="px-3 py-1 rounded bg-emerald-600 text-white text-sm hover:bg-emerald-700">Approve</button>
                            <button onClick={() => rejectRiderRequest(req.id)} className="px-3 py-1 rounded bg-rose-600 text-white text-sm hover:bg-rose-700">Reject</button>
                          </>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        )}

        {/* Shift Control View */}
        {riderOrderRequestsMainTab === 'shift-control' && (
          <div className="rounded-[32px] border border-slate-800 bg-slate-950 p-6 shadow-soft">
            <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
              <div>
                <p className="text-sm uppercase tracking-[0.2em] text-slate-400">Shift Control</p>
                <h3 className="mt-2 text-2xl font-semibold text-slate-100">Start and close rider shifts</h3>
                <p className="mt-3 text-sm text-slate-400">Pick a biker and start the shift. Closing the shift will clear previous rider app entries so the next shift starts fresh.</p>
              </div>
              <div className="space-y-3">
                {riderShifts && riderShifts.length > 0 ? (
                  riderShifts.map((sh, idx) => (
                    <div key={idx} className="rounded-3xl border border-slate-800 bg-slate-900/80 p-4 text-right">
                      <div className="flex items-start justify-between gap-3">
                        <div>
                          <p className="text-xs uppercase tracking-[0.2em] text-slate-400">Shift status</p>
                          <p className={`mt-2 text-lg font-semibold ${sh?.active ? 'text-emerald-400' : 'text-rose-400'}`}>
                            {sh?.active ? 'Active' : 'Inactive'}
                          </p>
                        </div>
                        <div className="flex items-center gap-2">
                          <button onClick={() => handleCloseShift(idx)} disabled={shiftActionLoading} className="rounded-3xl bg-rose-600 px-4 py-2 text-xs font-semibold text-white transition hover:bg-rose-500 disabled:cursor-not-allowed disabled:opacity-50">
                            Close Shift
                          </button>
                        </div>
                      </div>
                      <div className="mt-4 text-left text-sm text-slate-400 space-y-2">
                        {sh?.startedAt ? (
                          <>
                            <p>Started: {formatShiftStartedAt(sh.startedAt)}</p>
                            <p>Elapsed: {formatShiftDuration(sh.startedAt)}</p>
                            {sh.riderName ? <p>Assigned rider: {sh.riderName}</p> : null}
                          </>
                        ) : (
                          <p>No start time</p>
                        )}
                      </div>
                    </div>
                  ))
                ) : (
                  <div className="rounded-3xl border border-slate-800 bg-slate-900/80 p-4 text-right">
                    <p className="text-sm text-slate-400">No shifts recorded</p>
                  </div>
                )}
              </div>
            </div>
            <div className="mt-6 grid gap-4 lg:grid-cols-2">
              <div>
                <label className="block text-sm font-medium text-slate-400">Select Rider</label>
                <select value={shiftRiderId} onChange={(e) => setShiftRiderId(e.target.value)} className="mt-2 w-full rounded-3xl border border-slate-700 bg-slate-900 px-4 py-3 text-sm outline-none text-slate-100">
                  <option value="">Select Biker role rider</option>
                  {shiftRiderOptions.map((member) => (
                    <option key={member.id} value={member.id}>{member.name || member.username} ({member.role})</option>
                  ))}
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-400">Actions</label>
                <div className="mt-2 flex flex-wrap gap-3">
                  <button
                    onClick={handleStartShift}
                    disabled={
                      shiftActionLoading ||
                      !shiftRiderId ||
                      (riderShift?.active && riderShift?.riderId === shiftRiderId)
                    }
                    className="rounded-3xl bg-emerald-600 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-500 disabled:cursor-not-allowed disabled:opacity-50"
                  >
                    Start Shift
                  </button>
                  <button onClick={handleCloseShift} disabled={shiftActionLoading || !riderShift?.active} className="rounded-3xl bg-rose-600 px-5 py-3 text-sm font-semibold text-white transition hover:bg-rose-500 disabled:cursor-not-allowed disabled:opacity-50">Close Shift</button>
                </div>
                <p className="mt-3 text-sm text-slate-400">{riderShift?.active ? 'Closing shift removes old rider order history and unlocks the next shift.' : 'Start a new shift when the rider is ready to take delivery.'}</p>
              </div>
            </div>
            <div className="mt-6 border-t border-slate-800 pt-6">
              <label className="block text-sm font-medium text-slate-400 mb-2">Clear Selected Rider Delivered Orders</label>
              <p className="text-sm text-slate-500 mb-3">Remove all cash and online delivered orders for the selected rider</p>
              <button onClick={handleClearSelectedRiderOrders} disabled={shiftActionLoading || !shiftRiderId} className="rounded-3xl bg-orange-600 px-5 py-3 text-sm font-semibold text-white transition hover:bg-orange-500 disabled:cursor-not-allowed disabled:opacity-50">
                Clear Rider Orders
              </button>
            </div>
          </div>
        )}
      </div>
    );
  };

  const handleStaffFileChange = (field, e) => {
    const file = e.target.files[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = () => {
        setStaffForm({ ...staffForm, [field]: reader.result });
      };
      reader.readAsDataURL(file);
    }
  };

  const openStaffModal = (staff = null) => {
    if (staff) {
      setEditingStaff(staff);
      setStaffForm({
        name: staff.name || '',
        otherName: staff.otherName || '',
        phone: staff.phone || '',
        username: staff.username || '',
        password: '',
        role: staff.role || '',
        facePhoto: staff.facePhoto || '',
        idCardNumber: staff.idCardNumber || '',
        idCardFront: staff.idCardFront || '',
        idCardBack: staff.idCardBack || '',
        description: staff.description || '',
        address: staff.address || '',
        loginEnabled: staff.loginEnabled !== false
      });
    } else {
      setEditingStaff(null);
      setStaffForm({
        name: '',
        otherName: '',
        phone: '',
        username: '',
        password: '',
        role: '',
        facePhoto: '',
        idCardNumber: '',
        idCardFront: '',
        idCardBack: '',
        description: '',
        address: '',
        loginEnabled: true
      });
    }
    setShowStaffModal(true);
  };

  const duplicateStaff = (staff) => {
    if (!staff) {
      setMessage('Cannot duplicate: No staff selected');
      return;
    }
    setEditingStaff(null);
    setStaffForm({
      name: staff.name ? `${staff.name} (Copy)` : '',
      otherName: staff.otherName || '',
      phone: staff.phone || '',
      username: staff.username ? `${staff.username}-copy` : '',
      password: staff.password || '',
      role: staff.role || '',
      facePhoto: staff.facePhoto || '',
      idCardNumber: staff.idCardNumber || '',
      idCardFront: staff.idCardFront || '',
      idCardBack: staff.idCardBack || '',
      description: staff.description || '',
      address: staff.address || '',
      loginEnabled: staff.loginEnabled !== false
    });
    setShowStaffModal(true);
  };

  async function saveStaff() {
    if (!staffForm.name || !staffForm.username || !staffForm.role) {
      setMessage('Please fill all required fields');
      return;
    }
    if (!editingStaff && !staffForm.password) {
      setMessage('Password is required for new staff');
      return;
    }
    if (staffForm.role === 'Biker' && !staffForm.phone) {
      setMessage('Phone number is required for Bikers');
      return;
    }

    setLoading(true);
    setMessage('');
    try {
      const payload = { ...staffForm, status: 'active' };
      if (editingStaff && !payload.password) {
        delete payload.password;
      }
      let successMessage = '';
      if (editingStaff) {
        // update existing staff
        const updated = await fetchJson(`${apiBase}/staff/${editingStaff.id}`, {
          method: 'PUT',
          body: JSON.stringify(payload)
        });

        successMessage = 'Staff updated successfully';
        if ((payload.role === 'Biker' || payload.role === 'Admin Rider') && payload.loginEnabled) {
          if (updated.riderId) {
            if (payload.password) {
              try {
                await fetchJson(`${apiBase}/rider/set-password`, {
                  method: 'POST',
                  body: JSON.stringify({ riderId: updated.riderId, password: payload.password })
                });
              } catch (err) {
                console.warn('Failed to update rider password', err.message || err);
              }
            }
          } else if (payload.password) {
            try {
              const riderRole = payload.username?.toLowerCase() === 'ahmed@rider.com' ? payload.role : 'Rider';
              const riderResp = await fetchJson(`${apiBase}/riders/create`, {
                method: 'POST',
                body: JSON.stringify({
                  name: payload.name,
                  phone: payload.phone,
                  email: payload.username,
                  password: payload.password,
                  role: riderRole
                })
              });
              await fetchJson(`${apiBase}/staff/${updated.id}`, {
                method: 'PUT',
                body: JSON.stringify({ ...updated, riderId: riderResp.id })
              });
              successMessage = 'Staff updated and Rider account created successfully';
            } catch (err) {
              console.warn('Failed to create rider account', err.message || err);
              successMessage = 'Staff updated but rider account creation failed';
            }
          }
        }
      } else {
        // create staff first
        const createdStaff = await fetchJson(`${apiBase}/staff`, {
          method: 'POST',
          body: JSON.stringify(payload)
        });

        // If new staff is a Biker with login enabled, create a rider account and link
        if ((payload.role === 'Biker' || payload.role === 'Admin Rider') && payload.loginEnabled) {
          try {
            const riderRole = payload.username?.toLowerCase() === 'ahmed@rider.com' ? payload.role : 'Rider';
            const riderResp = await fetchJson(`${apiBase}/riders/create`, {
              method: 'POST',
              body: JSON.stringify({
                name: payload.name,
                phone: payload.phone,
                email: payload.username,
                password: payload.password,
                role: riderRole
              })
            });
            // update staff record to include riderId
            await fetchJson(`${apiBase}/staff/${createdStaff.id}`, {
              method: 'PUT',
              body: JSON.stringify({ ...createdStaff, riderId: riderResp.id })
            });
            setMessage('Staff and Rider account created successfully');
          } catch (err) {
            console.warn('Failed to create rider account', err.message || err);
            setMessage('Staff added but rider account creation failed');
          }
        } else {
          setMessage('Staff added successfully');
        }
      }
      if (successMessage) {
        setMessage(successMessage);
      }
      setShowStaffModal(false);
      await loadPosData();
      await loadTab('staff');
    } catch (error) {
      setMessage(error.message);
    } finally {
      setLoading(false);
    }
  }

  const updateRolePermissions = (roleName, permission, value) => {
    setRoles((prev) => prev.map((role) =>
      role.name === roleName
        ? { ...role, permissions: { ...role.permissions, [permission]: value } }
        : role
    ));
  };

  const getBikers = () => {
    return (staff || []).filter((member) => member.role === 'Biker' && member.loginEnabled);
  };

  const getDeliveryServiceTypeById = (id) => deliveryServiceTypes.find((type) => type.id === id);

  const handleDeliveryServiceTypeChange = (serviceTypeId) => {
    const type = getDeliveryServiceTypeById(serviceTypeId);
    setOrderDetails((prev) => ({
      ...prev,
      serviceType: type?.id || '',
      deliveryFee: type?.charge || 0
    }));
  };

  const getEditingOrderSummary = () => {
    const subtotal = editingOrderCart.reduce((sum, item) => sum + item.price * item.quantity, 0);
    const discount = Number(orderEditForm.discount) || 0;
    const tax = ((subtotal - discount) * (Number(orderEditForm.taxPercent) || 0)) / 100;
    const deliveryFee = orderEditForm.orderType === 'Delivery' ? Number(orderEditForm.deliveryFee) || 0 : 0;
    const serviceCharge = Number(orderEditForm.serviceCharge) || 0;
    const total = Math.max(0, subtotal - discount + tax + deliveryFee + serviceCharge);
    return { subtotal, discount, tax, deliveryFee, serviceCharge, total };
  };

  const addToEditingCart = (product) => {
    setEditingOrderCart((prev) => {
      const existing = prev.find((item) => item.productId === product.id);
      if (existing) {
        return prev.map((item) => (item.productId === product.id ? { ...item, quantity: item.quantity + 1 } : item));
      }
      return [...prev, { productId: product.id, name: product.name, price: product.price, quantity: 1, notes: '' }];
    });
  };

  const removeFromEditingCart = (productId) => {
    setEditingOrderCart((prev) => prev.filter((item) => item.productId !== productId));
  };

  const updateEditingCartItem = (productId, delta) => {
    setEditingOrderCart((prev) =>
      prev
        .map((item) => (item.productId === productId ? { ...item, quantity: Math.max(1, item.quantity + delta) } : item))
        .filter((item) => item.quantity > 0)
    );
  };

  const updateEditingCartNotes = (productId, notes) => {
    setEditingOrderCart((prev) => prev.map((item) => (item.productId === productId ? { ...item, notes } : item)));
  };

  const saveDeliveryServiceType = async () => {
    if (!deliveryServiceForm.name.trim()) {
      setMessage('Service type name is required.');
      return;
    }
    setLoading(true);
    setMessage('');
    try {
      const payload = {
        ...deliveryServiceForm,
        id: deliveryServiceForm.id || `stype-${Date.now()}`
      };
      let saved;
      if (deliveryServiceForm.id) {
        saved = await fetchJson(`${apiBase}/delivery_service_types/${payload.id}`, {
          method: 'PUT',
          body: JSON.stringify(payload)
        });
        setDeliveryServiceTypes((prev) => prev.map((type) => (type.id === saved.id ? saved : type)));
      } else {
        saved = await fetchJson(`${apiBase}/delivery_service_types`, {
          method: 'POST',
          body: JSON.stringify(payload)
        });
        setDeliveryServiceTypes((prev) => [...prev, saved]);
      }
      setDeliveryServiceForm({ id: null, name: '', charge: 50, location: '', active: true });
      setMessage('Service type saved.');
    } catch (error) {
      setMessage(error.message);
    } finally {
      setLoading(false);
    }
  };

  const deleteDeliveryServiceType = async (id) => {
    setLoading(true);
    setMessage('');
    try {
      await fetchJson(`${apiBase}/delivery_service_types/${id}`, { method: 'DELETE' });
      setDeliveryServiceTypes((prev) => prev.filter((type) => type.id !== id));
      setMessage('Service type deleted.');
    } catch (error) {
      setMessage(error.message);
    } finally {
      setLoading(false);
    }
  };

  const editDeliveryServiceType = (type) => {
    setDeliveryServiceForm({ ...type });
  };

  const saveDeliveryLocation = async () => {
    if (!deliveryLocationForm.name.trim()) {
      setMessage('Location name is required.');
      return;
    }
    setLoading(true);
    setMessage('');
    try {
      const payload = {
        ...deliveryLocationForm,
        id: deliveryLocationForm.id || `loc-${Date.now()}`
      };
      let saved;
      if (deliveryLocationForm.id) {
        saved = await fetchJson(`${apiBase}/delivery_locations/${payload.id}`, {
          method: 'PUT',
          body: JSON.stringify(payload)
        });
        setDeliveryLocations((prev) => prev.map((loc) => (loc.id === saved.id ? saved : loc)));
      } else {
        saved = await fetchJson(`${apiBase}/delivery_locations`, {
          method: 'POST',
          body: JSON.stringify(payload)
        });
        setDeliveryLocations((prev) => [...prev, saved]);
      }
      setDeliveryLocationForm({ id: null, name: '', description: '' });
      setMessage('Location saved.');
    } catch (error) {
      setMessage(error.message);
    } finally {
      setLoading(false);
    }
  };

  const deleteDeliveryLocation = async (id) => {
    setLoading(true);
    setMessage('');
    try {
      await fetchJson(`${apiBase}/delivery_locations/${id}`, { method: 'DELETE' });
      setDeliveryLocations((prev) => prev.filter((loc) => loc.id !== id));
      setMessage('Location deleted.');
    } catch (error) {
      setMessage(error.message);
    } finally {
      setLoading(false);
    }
  };

  const editDeliveryLocation = (location) => {
    setDeliveryLocationForm({ ...location });
  };

  function getStatusBadge(status) {
    const map = {
      New: 'bg-blue-600',
      Accepted: 'bg-indigo-600',
      Preparing: 'bg-amber-600',
      Ready: 'bg-emerald-600',
      'Ready for pickup': 'bg-teal-600',
      'Out for delivery': 'bg-purple-600',
      Completed: 'bg-emerald-600',
      'Pay Later': 'bg-amber-600',
      Due: 'bg-red-600',
      Cancelled: 'bg-rose-600',
      Pending: 'bg-slate-500'
    };
    return map[status] || 'bg-slate-500';
  }

  function renderTable() {
    if (activeTab === 'tables') return renderTables();
    if (activeTab === 'inventory') return renderInventory();
    if (activeTab === 'staff') return renderStaff();
    if (activeTab === 'sales') return renderSales();
    return null;
  }

  function renderTables() {
    const floorTables = items.filter((table) => (table.section || 'Floor') === 'Floor');
    const outsideTables = items.filter((table) => (table.section || 'Floor') === 'Outside');
    const displayTables = tableSectionFilter === 'Outside' ? outsideTables : floorTables;

    return (
      <div className="space-y-6">
        <div className="flex flex-wrap items-center justify-between gap-3 rounded-[32px] border border-slate-800 bg-slate-900 p-5 shadow-soft">
          <div>
            <p className="text-sm uppercase tracking-[0.2em] text-slate-400">Table Management</p>
            <h3 className="mt-2 text-2xl font-semibold text-white">In hotel and outside tables</h3>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <button onClick={() => setTableSectionFilter('Floor')} className={`rounded-full px-4 py-2 text-sm font-semibold transition ${tableSectionFilter === 'Floor' ? 'bg-emerald-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}>
              Floor Tables
            </button>
            <button onClick={() => setTableSectionFilter('Outside')} className={`rounded-full px-4 py-2 text-sm font-semibold transition ${tableSectionFilter === 'Outside' ? 'bg-emerald-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}>
              Outside Tables
            </button>
            <button onClick={() => openTableModal()} className="rounded-full bg-emerald-600 px-4 py-2 text-sm font-semibold text-slate-950 transition hover:bg-emerald-500">
              Add Table
            </button>
          </div>
        </div>

        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          {displayTables.map((table) => (
            <div key={table.id} className="rounded-3xl border border-slate-800 bg-slate-900 p-4 shadow-soft">
              <div className="flex items-start justify-between gap-4">
                <div>
                  <div className="text-2xl font-semibold text-white">{table.label || table.name || `Table ${table.number || table.id}`}</div>
                  <div className="mt-1 text-sm text-slate-400">{table.capacity ? `${table.capacity} seats` : table.type || 'Table'}</div>
                  <div className="text-xs uppercase tracking-[0.2em] text-slate-500 mt-1">{(table.section || 'Floor').toUpperCase()}</div>
                </div>
                <span className={`rounded-full px-3 py-1 text-xs font-semibold ${table.status === 'occupied' ? 'bg-rose-600 text-white' : 'bg-emerald-600 text-white'}`}>
                  {table.status}
                </span>
              </div>
              <div className="mt-3 text-slate-400">Location: {table.location || 'Main floor'}</div>
              <div className="mt-4 flex flex-wrap gap-2">
                <button onClick={() => openTableModal(table)} title="Edit table" className="inline-flex items-center justify-center rounded-full border border-slate-700 bg-slate-800 px-3 py-2 text-slate-200 transition hover:bg-slate-700">
                  <svg viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M12 20h9"/><path d="M16.5 3.5a2.121 2.121 0 113 3L7 19l-4 1 1-4 12.5-12.5z"/></svg>
                </button>
                <button onClick={() => deleteTable(table.id)} title="Delete table" className="inline-flex items-center justify-center rounded-full border border-slate-700 bg-rose-600 px-3 py-2 text-white transition hover:bg-rose-500">
                  <svg viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M3 6h18"/><path d="M8 6V4h8v2"/><path d="M19 6l-1 14H6L5 6"/><path d="M10 11v6"/><path d="M14 11v6"/></svg>
                </button>
              </div>
            </div>
          ))}
        </div>

        {showTableModal && (
          <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/70 p-4">
            <div className="w-full max-w-2xl rounded-[32px] border border-slate-700 bg-slate-900 p-6 shadow-2xl">
              <div className="flex items-center justify-between gap-4">
                <div>
                  <h3 className="text-xl font-semibold text-white">{editingTable ? 'Edit Table' : 'Add Table'}</h3>
                  <p className="text-sm text-slate-400">Manage floor and outside tables with capacity, location and status.</p>
                </div>
                <button onClick={closeTableModal} className="rounded-full border border-slate-700 bg-slate-800 px-3 py-2 text-slate-200 hover:bg-slate-700">Close</button>
              </div>

              <div className="mt-6 grid gap-4 lg:grid-cols-2">
                <label className="block text-sm text-slate-400">Label</label>
                <input value={tableForm.label} onChange={(e) => setTableForm((prev) => ({ ...prev, label: e.target.value }))} className="rounded-3xl border border-slate-700 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none" />
                <label className="block text-sm text-slate-400">Section</label>
                <select value={tableForm.section} onChange={(e) => setTableForm((prev) => ({ ...prev, section: e.target.value }))} className="rounded-3xl border border-slate-700 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none">
                  <option value="Floor">Floor</option>
                  <option value="Outside">Outside</option>
                </select>
                <label className="block text-sm text-slate-400">Type</label>
                <select value={tableForm.type} onChange={(e) => setTableForm((prev) => ({ ...prev, type: e.target.value }))} className="rounded-3xl border border-slate-700 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none">
                  <option value="Table">Table</option>
                  <option value="Room">Room</option>
                </select>
                <label className="block text-sm text-slate-400">Capacity</label>
                <input type="number" min="1" value={tableForm.capacity} onChange={(e) => setTableForm((prev) => ({ ...prev, capacity: Number(e.target.value) }))} className="rounded-3xl border border-slate-700 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none" />
                <label className="block text-sm text-slate-400">Status</label>
                <select value={tableForm.status} onChange={(e) => setTableForm((prev) => ({ ...prev, status: e.target.value }))} className="rounded-3xl border border-slate-700 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none">
                  <option value="available">Available</option>
                  <option value="occupied">Occupied</option>
                  <option value="reserved">Reserved</option>
                </select>
                <label className="block text-sm text-slate-400">Location</label>
                <input value={tableForm.location} onChange={(e) => setTableForm((prev) => ({ ...prev, location: e.target.value }))} className="rounded-3xl border border-slate-700 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none" />
              </div>

              <div className="mt-6 flex flex-wrap items-center gap-3">
                <button onClick={saveTable} className="rounded-3xl bg-emerald-600 px-6 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-500">{editingTable ? 'Update Table' : 'Save Table'}</button>
                <button onClick={closeTableModal} className="rounded-3xl border border-slate-700 px-6 py-3 text-sm font-semibold text-slate-200 hover:bg-slate-800">Cancel</button>
              </div>
            </div>
          </div>
        )}

          {markDueOrder && (
            <div className="fixed inset-0 z-50 overflow-y-auto bg-slate-950/92 p-4 backdrop-blur-sm flex items-center justify-center">
              <div className="relative w-full max-w-lg rounded-[32px] border border-white/10 bg-slate-900 p-6 shadow-2xl shadow-rose-500/10">
                <div className="flex items-start justify-between gap-4">
                  <div>
                    <h2 className="text-2xl font-semibold text-white">Mark Order Due</h2>
                    <p className="mt-1 text-sm text-slate-400">Record amount collected (optional) and mark remaining as due.</p>
                  </div>
                  <button onClick={() => setMarkDueOrder(null)} className="inline-flex h-11 w-11 items-center justify-center rounded-full border border-slate-700 bg-slate-800 text-slate-200 transition hover:bg-slate-700">
                    <svg viewBox="0 0 24 24" className="h-6 w-6"><path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12 19 6.41z" fill="currentColor"/></svg>
                  </button>
                </div>
                <div className="mt-6 space-y-4">
                  <div className="rounded-3xl border border-slate-700 bg-slate-950 p-4">
                    <div className="text-sm text-slate-400">Order</div>
                    <div className="mt-2 text-lg font-semibold text-white">{markDueOrder.orderNumber || markDueOrder.id}</div>
                    <div className="text-sm text-slate-400">Table: {markDueOrder.tableNumber || 'N/A'}</div>
                    <div className="text-sm text-slate-400">Customer: {markDueOrder.customerName || 'TABLE'}</div>
                  </div>

                  <div className="grid gap-4 sm:grid-cols-2">
                    <div>
                      <label className="block text-sm text-slate-300 mb-2">Total amount</label>
                      <div className="rounded-2xl border border-slate-700 bg-slate-900 px-4 py-3 text-sm text-slate-100">{markDueOrder.total || markDueOrder.amount || 0} PKR</div>
                    </div>
                    <div>
                      <label className="block text-sm text-slate-300 mb-2">Amount collected now (optional)</label>
                      <input type="number" value={markDueAmount} onChange={(e) => setMarkDueAmount(e.target.value)} className="w-full rounded-3xl border border-slate-700 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none focus:border-rose-500" />
                    </div>
                    <div>
                      <label className="block text-sm text-slate-300 mb-2">Payment method</label>
                      <select value={markDueMethod} onChange={(e) => setMarkDueMethod(e.target.value)} className="w-full rounded-3xl border border-slate-700 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none">
                        {['Cash', 'Card', 'Transfer', 'Other'].map((m) => <option key={m} value={m}>{m}</option>)}
                      </select>
                    </div>
                    <div>
                      <label className="block text-sm text-slate-300 mb-2">Remaining due</label>
                      <div className="rounded-2xl border border-slate-700 bg-slate-900 px-4 py-3 text-sm text-slate-100">{Math.max(0, (markDueOrder.total || markDueOrder.amount || 0) - (Number(markDueAmount) || 0))} PKR</div>
                    </div>
                  </div>
                </div>
                <div className="mt-6 flex justify-end gap-3">
                  <button onClick={() => setMarkDueOrder(null)} className="rounded-3xl border border-slate-700 bg-slate-800 px-4 py-3 text-sm font-semibold text-slate-200 transition hover:bg-slate-700">Cancel</button>
                  <button onClick={handleMarkDue} className="rounded-3xl bg-rose-600 px-4 py-3 text-sm font-semibold text-white transition hover:bg-rose-500">Confirm Due</button>
                </div>
              </div>
            </div>
          )}
      </div>
    );
  }

  function renderInventory() {
    return (
      <div className="space-y-6">
        <div className="flex gap-3 flex-wrap">
          <button
            onClick={() => setInventorySubTab('categories')}
            className={`rounded-full px-4 py-2 text-sm font-semibold transition ${inventorySubTab === 'categories' ? 'bg-emerald-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}
          >
            Categories
          </button>
          <button
            onClick={() => setInventorySubTab('products')}
            className={`rounded-full px-4 py-2 text-sm font-semibold transition ${inventorySubTab === 'products' ? 'bg-emerald-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}
          >
            Products
          </button>
          <button
            onClick={() => setInventorySubTab('mashallah')}
            className={`rounded-full px-4 py-2 text-sm font-semibold transition ${inventorySubTab === 'mashallah' ? 'bg-emerald-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}
          >
            {MASHALLAH_CATEGORY}
          </button>
          <button
            onClick={() => setInventorySubTab('settings')}
            className={`rounded-full px-4 py-2 text-sm font-semibold transition ${inventorySubTab === 'settings' ? 'bg-emerald-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}
          >
            ⚙️ Settings
          </button>
        </div>
        {inventorySubTab === 'categories' && renderCategories()}
        {inventorySubTab === 'products' && renderProducts()}
        {inventorySubTab === 'mashallah' && renderMashallahSlots()}
        {inventorySubTab === 'settings' && renderInventorySettings()}
      </div>
    );
  }

  function renderInventorySettings() {
    return (
      <div className="space-y-6">
        {/* POS Theme Settings */}
        <div className="rounded-[32px] border border-slate-800 bg-slate-900 p-6 shadow-soft">
          <div className="flex items-center justify-between">
            <div>
              <h3 className="text-lg font-semibold text-white">POS Display Theme</h3>
              <p className="mt-1 text-sm text-slate-400">Choose your POS interface theme</p>
            </div>
            <select 
              value={posTheme}
              onChange={(e) => setPosTheme(e.target.value)}
              className="rounded-2xl border border-slate-700 bg-slate-950 px-4 py-2 text-sm font-semibold text-slate-100 outline-none focus:border-emerald-500"
            >
              <option value="classic">Classic (Dark)</option>
              <option value="restaurant">Restaurant (Red & White)</option>
            </select>
          </div>
          <div className="mt-6 grid gap-4 sm:grid-cols-2">
            <div className="rounded-2xl border-2 border-slate-700 p-4" style={{borderColor: posTheme === 'classic' ? '#10b981' : undefined}}>
              <h4 className="text-sm font-bold text-white mb-3">Classic (Dark)</h4>
              <div className="flex gap-2 items-center">
                <div className="w-8 h-8 rounded bg-slate-950 border border-slate-700"></div>
                <div className="w-8 h-8 rounded bg-slate-900"></div>
                <div className="w-8 h-8 rounded bg-emerald-600"></div>
                <span className="text-xs text-slate-400">Current theme</span>
              </div>
            </div>
            <div className="rounded-2xl border-2 border-slate-700 p-4" style={{borderColor: posTheme === 'restaurant' ? '#10b981' : undefined}}>
              <h4 className="text-sm font-bold text-white mb-3">Restaurant (New)</h4>
              <div className="flex gap-2 items-center">
                <div className="w-8 h-8 rounded bg-red-600"></div>
                <div className="w-8 h-8 rounded bg-white border border-slate-300"></div>
                <div className="w-8 h-8 rounded bg-slate-100"></div>
                <span className="text-xs text-slate-400">Red & White</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  function renderCategories() {
    return (
      <div className="space-y-6">
        <div className="grid gap-4 lg:grid-cols-3">
          {posCategories.map((category) => (
            <div key={category.id} className="rounded-[34px] border border-slate-800 bg-slate-950 p-5 shadow-soft">
              <div className="flex items-center justify-between gap-3">
                <div className="text-lg font-semibold text-white">{category.name}</div>
                <div className="flex gap-2">
                  <button onClick={() => openCategoryEdit(category)} title="Edit category" className="inline-flex h-10 w-10 items-center justify-center rounded-full border border-slate-700 bg-slate-800 text-slate-200 transition hover:bg-slate-700">
                    <svg viewBox="0 0 24 24" className="h-5 w-5"><path d="M3 17.25V21h3.75L17.81 9.94l-3.75-3.75L3 17.25zM20.71 7.04a1.003 1.003 0 0 0 0-1.41l-2.34-2.34a1.003 1.003 0 0 0-1.41 0l-1.83 1.83 3.75 3.75 1.83-1.83z" fill="currentColor"/></svg>
                  </button>
                  <button onClick={() => deleteRecord(category.id, 'pos_categories')} title="Delete category" className="inline-flex h-10 w-10 items-center justify-center rounded-full bg-rose-600 text-white transition hover:bg-rose-700">
                    <svg viewBox="0 0 24 24" className="h-5 w-5"><path d="M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z" fill="currentColor"/></svg>
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
        <div className="rounded-[32px] border border-slate-800 bg-slate-950 p-5">
          <p className="text-sm font-semibold uppercase tracking-[0.2em] text-slate-400">{editingCategory ? 'Edit Category' : 'Add New Category'}</p>
          <div className="mt-4 space-y-4">
            <input value={form.name || ''} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder="Category Name" className="w-full rounded-3xl border border-slate-800 bg-slate-900 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" />
            <div>
              <label className="block text-xs text-slate-400 mb-1.5">Category Icon (optional PNG image)</label>
              <div className="flex items-center gap-3">
                {form.icon && (
                  <img src={form.icon} alt="icon" className="w-10 h-10 rounded-full object-cover border border-slate-700" />
                )}
                <input type="file" accept="image/*" onChange={(e) => {
                  const file = e.target.files?.[0];
                  if (file) {
                    const reader = new FileReader();
                    reader.onload = (ev) => setForm({ ...form, icon: ev.target?.result || '' });
                    reader.readAsDataURL(file);
                  }
                }} className="w-full text-xs text-slate-400 file:mr-3 file:py-1.5 file:px-4 file:rounded-full file:border-0 file:text-xs file:font-semibold file:bg-slate-800 file:text-slate-200 hover:file:bg-slate-700" />
                {form.icon && (
                  <button onClick={() => setForm({ ...form, icon: '' })} className="text-xs text-rose-400 hover:text-rose-300">✕</button>
                )}
              </div>
            </div>
            <div className="flex gap-3">
              <button onClick={editingCategory ? saveCategory : addCategory} className="flex-1 rounded-3xl bg-slate-900 px-4 py-3 text-sm font-semibold text-white transition hover:bg-slate-800">{editingCategory ? 'Save Category' : 'Add Category'}</button>
              {editingCategory && (
                <button onClick={() => { setEditingCategory(null); setForm({}); }} className="flex-1 rounded-3xl bg-slate-800 px-4 py-3 text-sm font-semibold text-slate-200 transition hover:bg-slate-700">Cancel</button>
              )}
            </div>
          </div>
        </div>
      </div>
    );
  }

  function renderProducts() {
    return (
      <div className="space-y-6">
        <button onClick={() => openProductModal()} className="rounded-3xl bg-emerald-600 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-500">Add New Product</button>
        <div className="grid gap-4 lg:grid-cols-3">
          {posProducts.map((product) => (
            <div key={product.id} className="rounded-[34px] border border-slate-800 bg-slate-950 p-5 shadow-soft">
              {product.photo && <img src={product.photo} alt={product.name} className="w-full h-32 object-cover rounded-[28px] mb-3" />}
              <div className="flex items-center justify-between gap-3">
                <div>
                  <div className="text-lg font-semibold text-white">{product.name}</div>
                  {product.code && <div className="text-sm text-slate-400">Code: {product.code}</div>}
                </div>
                <div className="flex gap-2">
                  <button onClick={() => openProductModal(product)} title="Edit product" className="inline-flex h-10 w-10 items-center justify-center rounded-full border border-slate-700 bg-slate-800 text-slate-200 transition hover:bg-slate-700">
                    <svg viewBox="0 0 24 24" className="h-5 w-5"><path d="M3 17.25V21h3.75L17.81 9.94l-3.75-3.75L3 17.25zM20.71 7.04a1.003 1.003 0 0 0 0-1.41l-2.34-2.34a1.003 1.003 0 0 0-1.41 0l-1.83 1.83 3.75 3.75 1.83-1.83z" fill="currentColor"/></svg>
                  </button>
                  <button onClick={() => deleteRecord(product.id, 'pos_products')} title="Delete product" className="inline-flex h-10 w-10 items-center justify-center rounded-full bg-rose-600 text-white transition hover:bg-rose-700">
                    <svg viewBox="0 0 24 24" className="h-5 w-5"><path d="M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z" fill="currentColor"/></svg>
                  </button>
                </div>
              </div>
              <div className="mt-3 text-slate-400">Category: {product.category}</div>
              <div className="mt-1 text-slate-400">Price: {product.price} {product.unit}</div>
              {product.purchasePrice && <div className="mt-1 text-slate-400">Purchase: {product.purchasePrice} {product.unit}</div>}
            </div>
          ))}
        </div>
        {showProductModal && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 px-4 py-6">
            <div className="bg-slate-900 rounded-3xl w-full max-w-md max-h-[90vh] flex flex-col shadow-[0_35px_120px_-30px_rgba(0,0,0,0.8)]">
              <div className="flex items-center justify-between gap-4 p-6 border-b border-slate-800 flex-shrink-0">
                <div>
                  <p className="text-xs uppercase tracking-[0.2em] text-slate-500">{editingProduct ? 'Edit Product' : 'Add New Product'}</p>
                  <h3 className="mt-2 text-xl font-semibold text-white">{editingProduct ? editingProduct.name : 'New Product'}</h3>
                </div>
                <button type="button" onClick={() => { setShowProductModal(false); setEditingProduct(null); }} className="rounded-full border border-slate-700 bg-slate-900 px-3 py-2 text-sm text-slate-200 hover:bg-slate-800 flex-shrink-0">✕</button>
              </div>
      <div className="flex-1 min-w-0 overflow-y-auto max-h-[70vh] pr-4 scrollbar-thin scrollbar-thumb-slate-700 scrollbar-track-slate-950">
        <div className="space-y-4">
          <div className="flex gap-2">
            <button type="button" onClick={() => { setProductNameInputMode('text'); setProductNameOcrPhoto(''); }} className={`flex-1 rounded-3xl px-4 py-2 text-sm font-semibold transition ${productNameInputMode === 'text' ? 'bg-emerald-600 text-slate-950' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}>Text</button>
            <button type="button" onClick={() => { setProductNameInputMode('photo'); }} className={`flex-1 rounded-3xl px-4 py-2 text-sm font-semibold transition ${productNameInputMode === 'photo' ? 'bg-emerald-600 text-slate-950' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}>Photo</button>
          </div>
          {productNameInputMode === 'text' ? (
            <input value={productForm.name} onChange={(e) => setProductForm({ ...productForm, name: e.target.value })} placeholder="Product Name" className="w-full rounded-3xl border border-slate-800 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" />
          ) : (
            <div className="space-y-3">
              <input type="file" accept="image/*" capture="environment" onChange={(e) => { handleProductNameOcrPhotoChange(e); handleProductNameOcr(e); }} className="w-full rounded-3xl border border-slate-800 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500 file:mr-3 file:rounded-full file:border-0 file:bg-emerald-600 file:px-4 file:py-2 file:text-sm file:font-semibold file:text-slate-950 hover:file:bg-emerald-500" />
              {productNameOcrLoading && (
                <div className="flex items-center gap-2 text-sm text-emerald-400">
                  <svg className="animate-spin h-4 w-4" viewBox="0 0 24 24"><circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" fill="none" /><path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" /></svg>
                  Extracting Urdu text from photo...
                </div>
              )}
              {productNameOcrPhoto && !productNameOcrLoading && (
                <img src={productNameOcrPhoto} alt="OCR preview" className="w-full h-32 object-contain rounded-[28px] border border-slate-700" />
              )}
              {productForm.name && !productNameOcrLoading && productNameInputMode === 'photo' && (
                <div className="rounded-3xl bg-slate-800 px-4 py-3 text-sm text-slate-100 break-words">Extracted: {productForm.name}</div>
              )}
            </div>
          )}
          <select value={productForm.category} onChange={(e) => setProductForm({ ...productForm, category: e.target.value })} className="w-full rounded-3xl border border-slate-800 bg-slate-950 px-4 py-3 text-slate-100 outline-none focus:border-emerald-500">
            <option value="">Select Category</option>
            {posCategories.map((cat) => <option key={cat.id} value={cat.name}>{cat.name}</option>)}
          </select>
          <input type="number" value={productForm.price} onChange={(e) => setProductForm({ ...productForm, price: e.target.value })} placeholder="Selling Price" className="w-full rounded-3xl border border-slate-800 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" />
          <input type="number" value={productForm.purchasePrice} onChange={(e) => setProductForm({ ...productForm, purchasePrice: e.target.value })} placeholder="Purchase Price (Optional)" className="w-full rounded-3xl border border-slate-800 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" />
          <input value={productForm.code} onChange={(e) => setProductForm({ ...productForm, code: e.target.value })} placeholder="Product Code / SKU" className="w-full rounded-3xl border border-slate-800 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" />
          <input type="number" value={productForm.stock} onChange={(e) => setProductForm({ ...productForm, stock: e.target.value })} placeholder="Stock Quantity (leave blank for unlimited)" className="w-full rounded-3xl border border-slate-800 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" />
          <input value={productForm.unit} onChange={(e) => setProductForm({ ...productForm, unit: e.target.value })} placeholder="Unit (e.g., PKR)" className="w-full rounded-3xl border border-slate-800 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" />
          <input type="file" accept="image/png,image/jpeg" onChange={handleFileChange} className="w-full rounded-3xl border border-slate-800 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" />
          <p className="text-xs text-slate-500">Upload PNG/JPG only. Large images may slow down payloads, use smaller images if possible.</p>

          <div className="rounded-[28px] border border-slate-800 bg-slate-950 p-4">
            <div className="flex items-center justify-between mb-3">
              <div>
                <p className="text-sm font-semibold uppercase tracking-[0.2em] text-slate-400">Flavors and Variants</p>
                <p className="text-xs text-slate-500">Add flavors with their weight variants and prices.</p>
              </div>
            </div>
            <div className="space-y-4">
              {(productForm.flavors || []).map((flavor, flavorIndex) => (
                <div key={flavorIndex} className="rounded-3xl border border-slate-700 bg-slate-900 p-4">
                  <div className="flex items-center justify-between mb-3">
                    <div className="text-lg font-semibold text-white">{flavor.label}</div>
                    <button type="button" onClick={() => setProductForm((prev) => ({ ...prev, flavors: prev.flavors.filter((_, idx) => idx !== flavorIndex) }))} className="rounded-full bg-rose-600 px-3 py-1 text-xs font-semibold text-white hover:bg-rose-500">Remove Flavor</button>
                  </div>
                  <div className="space-y-3">
                    {(flavor.variants || []).map((variant, variantIndex) => (
                      <div key={variantIndex} className="flex items-center justify-between gap-3 rounded-3xl border border-slate-800 bg-slate-950 px-4 py-3 text-sm text-slate-100">
                        <div>
                          <div>{variant.label}</div>
                          <div className="text-xs text-slate-500">{variant.price} PKR</div>
                        </div>
                        <button type="button" onClick={() => setProductForm((prev) => {
                          const newFlavors = [...prev.flavors];
                          newFlavors[flavorIndex].variants = newFlavors[flavorIndex].variants.filter((_, idx) => idx !== variantIndex);
                          return { ...prev, flavors: newFlavors };
                        })} className="rounded-full bg-rose-600 px-3 py-1 text-xs font-semibold text-white hover:bg-rose-500">Remove</button>
                      </div>
                    ))}
                    {productForm.currentFlavorIndex === flavorIndex && (
                      <div className="grid gap-3 sm:grid-cols-[1fr_1fr]">
                        <input value={productForm.newVariant} onChange={(e) => setProductForm({ ...productForm, newVariant: e.target.value })} placeholder="Variant label (e.g. 500g)" className="w-full rounded-3xl border border-slate-800 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" />
                        <input type="number" value={productForm.newVariantPrice} onChange={(e) => setProductForm({ ...productForm, newVariantPrice: e.target.value })} placeholder="Price" className="w-full rounded-3xl border border-slate-800 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" />
                      </div>
                    )}
                    {productForm.currentFlavorIndex === flavorIndex ? (
                      <div className="flex gap-2">
                        <button type="button" onClick={() => {
                          if (!productForm.newVariant || !productForm.newVariantPrice) return;
                          setProductForm((prev) => {
                            const newFlavors = [...prev.flavors];
                            newFlavors[flavorIndex].variants = [...(newFlavors[flavorIndex].variants || []), { label: prev.newVariant, price: Number(prev.newVariantPrice) }];
                            return { ...prev, flavors: newFlavors, newVariant: '', newVariantPrice: '', currentFlavorIndex: null };
                          });
                        }} className="flex-1 rounded-3xl bg-emerald-600 px-4 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-500">Add Variant</button>
                        <button type="button" onClick={() => setProductForm({ ...productForm, currentFlavorIndex: null, newVariant: '', newVariantPrice: '' })} className="flex-1 rounded-3xl bg-slate-800 px-4 py-3 text-sm font-semibold text-slate-100 transition hover:bg-slate-700">Cancel</button>
                      </div>
                    ) : (
                      <button type="button" onClick={() => setProductForm({ ...productForm, currentFlavorIndex: flavorIndex })} className="w-full rounded-3xl bg-slate-800 px-4 py-3 text-sm font-semibold text-slate-100 transition hover:bg-slate-700">Add Variants for {flavor.label}</button>
                    )}
                  </div>
                </div>
              ))}
              <div className="grid gap-3">
                <input value={productForm.newFlavor} onChange={(e) => setProductForm({ ...productForm, newFlavor: e.target.value })} placeholder="Flavor name (e.g. Spicy)" className="w-full rounded-3xl border border-slate-800 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" />
              </div>
              <button type="button" onClick={() => {
                if (!productForm.newFlavor) return;
                setProductForm((prev) => ({
                  ...prev,
                  flavors: [...(prev.flavors || []), { label: prev.newFlavor, variants: [] }],
                  newFlavor: ''
                }));
              }} className="w-full rounded-3xl bg-slate-800 px-4 py-3 text-sm font-semibold text-slate-100 transition hover:bg-slate-700">Add Flavor</button>
            </div>
          </div>
        </div>
      </div>
              <div className="flex gap-3 p-6 border-t border-slate-800 flex-shrink-0">
                <button type="button" onClick={editingProduct ? saveProduct : addProduct} className="flex-1 rounded-3xl bg-emerald-600 px-4 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-500">{editingProduct ? 'Save Product' : 'Add Product'}</button>
                <button type="button" onClick={() => { setShowProductModal(false); setEditingProduct(null); }} className="flex-1 rounded-3xl bg-slate-800 px-4 py-3 text-sm font-semibold text-white transition hover:bg-slate-700">Cancel</button>
              </div>
            </div>
          </div>
        )}
      </div>
    );
  }

  function renderMashallahSlots() {
    const filteredProducts = posProducts.filter((product) => {
      const searchTerm = normalizeText(mashallahSearch);
      return (
        !searchTerm ||
        normalizeText(product.name).includes(searchTerm) ||
        normalizeText(product.category).includes(searchTerm) ||
        normalizeText(product.code).includes(searchTerm) ||
        normalizeText(product.sku).includes(searchTerm) ||
        normalizeText(product.id).includes(searchTerm)
      );
    });

    return (
      <div className="space-y-6">
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          {mashallahSlots.map((slot) => {
            const assignedProduct = posProducts.find((product) => product.id === slot.productId);
            return (
              <div key={slot.slot} className="rounded-xl border border-slate-800 bg-slate-900 p-4">
                <div className="flex items-center justify-between mb-2">
                  <span className="text-sm font-bold text-emerald-400">Slot {slot.slot}</span>
                  <button onClick={() => clearMashallahSlot(slot.slot)} className="text-xs text-red-400 hover:text-red-300">Clear</button>
                </div>
                {assignedProduct ? (
                  <div className="text-sm text-slate-200">{assignedProduct.name}</div>
                ) : (
                  <button onClick={() => openMashallahSelector(slot)} className="text-sm text-slate-500 hover:text-slate-300">Click to assign product</button>
                )}
              </div>
            );
          })}
        </div>

        <div className="rounded-[32px] border border-slate-800 bg-slate-950 p-5">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <p className="text-sm uppercase tracking-[0.2em] text-slate-400">{MASHALLAH_CATEGORY} Slots</p>
              <h3 className="mt-2 text-xl font-semibold text-white">Assign existing products to numbered slots</h3>
            </div>
            <div className="flex items-center gap-2">
              <span className="rounded-full bg-emerald-600 px-3 py-2 text-sm font-semibold text-slate-950">10 slots</span>
            </div>
          </div>
          <p className="mt-4 text-sm text-slate-400">Click any number to open a selector of existing products. Each assigned item appears in POS under the same slot number and tab.</p>
          <div className="mt-6 grid gap-3 sm:grid-cols-2">
            <input value={mashallahSearch} onChange={(e) => setMashallahSearch(e.target.value)} placeholder="Search products to assign" className="w-full rounded-3xl border border-slate-800 bg-slate-900 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" />
          </div>
        </div>

        {showMashallahSelector && activeMashallahSlot && (
          <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/90 p-4">
            <div className="w-full max-w-4xl max-h-[90vh] rounded-[32px] border border-slate-700 bg-slate-900 shadow-2xl flex flex-col overflow-hidden">
              <div className="flex items-center justify-between gap-4 border-b border-slate-800 px-6 py-5 flex-shrink-0">
                <div>
                  <p className="text-xs uppercase tracking-[0.2em] text-slate-500">Select product for slot {activeMashallahSlot.slot}</p>
                  <h3 className="mt-2 text-2xl font-semibold text-white">Choose existing product</h3>
                </div>
                <button onClick={() => { setShowMashallahSelector(false); setActiveMashallahSlot(null); }} className="rounded-full border border-slate-700 bg-slate-900 px-4 py-2 text-sm text-slate-200 hover:bg-slate-800 flex-shrink-0">Close</button>
              </div>
              <div className="flex-1 overflow-y-auto p-6 modal-scrollable">
                <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
                  {filteredProducts.length ? filteredProducts.map((product) => (
                    <button key={product.id} onClick={() => assignProductToMashallah(activeMashallahSlot.slot, product)} className="group rounded-[28px] border border-slate-800 bg-slate-950 p-4 text-left transition hover:border-emerald-500/70 hover:bg-slate-900">
                      {product.photo ? (
                        <img src={product.photo} alt={product.name} className="h-32 w-full rounded-3xl object-cover" />
                      ) : (
                        <div className="flex h-32 items-center justify-center rounded-3xl bg-slate-800 text-slate-400">No image</div>
                      )}
                      <div className="mt-4 flex items-center justify-between gap-3">
                        <div>
                          <div className="text-base font-semibold text-white">{product.name}</div>
                          <div className="text-sm text-slate-400">{product.category}</div>
                        </div>
                        <div className="rounded-full bg-emerald-600 px-3 py-1 text-xs font-semibold text-slate-950">{product.price} PKR</div>
                      </div>
                    </button>
                  )) : (
                    <div className="col-span-full rounded-[28px] border border-dashed border-slate-700 bg-slate-950 p-6 text-center text-sm text-slate-400">
                      No matching products found.
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    );
  }

  function renderStaff() {
    return (
      <div className="space-y-6">
        <div className="flex gap-3">
          <button onClick={() => setStaffSubTab('list')} className={`rounded-full px-4 py-2 text-sm font-semibold transition ${staffSubTab === 'list' ? 'bg-emerald-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}>Staff List</button>
          <button onClick={() => setStaffSubTab('roles')} className={`rounded-full px-4 py-2 text-sm font-semibold transition ${staffSubTab === 'roles' ? 'bg-emerald-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}>Roles</button>
          <button onClick={() => setStaffSubTab('settings')} className={`rounded-full px-4 py-2 text-sm font-semibold transition ${staffSubTab === 'settings' ? 'bg-emerald-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}>Settings</button>
        </div>
        {staffSubTab === 'list' && renderStaffList()}
        {staffSubTab === 'roles' && renderRoles()}
        {staffSubTab === 'settings' && renderStaffSettings()}
      </div>
    );
  }

  function renderStaffList() {
    return (
      <div className="space-y-6">
        <button onClick={() => openStaffModal()} className="rounded-3xl bg-emerald-600 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-500">Add New Staff</button>
        <div className="grid gap-4 lg:grid-cols-2">
          {items.map((member) => (
            <div key={member.id} className="rounded-3xl border border-slate-800 bg-slate-900 p-5 shadow-soft">
              <div className="flex justify-between gap-4">
                <div>
                  <div className="text-lg font-semibold text-white">{member.name}</div>
                  <div className="flex flex-wrap items-center gap-2 text-slate-400">
                    <span>{member.role}</span>
                    {member.role === 'Biker' && (
                      <span className="inline-flex items-center gap-1 rounded-full bg-slate-800 px-2 py-1 text-[11px] font-semibold text-emerald-400 shadow-[0_6px_12px_rgba(16,185,129,0.18)]">
                        <span>🚴</span>
                        <span>Bike</span>
                      </span>
                    )}
                  </div>
                  <div className="text-sm text-slate-400 mt-1">{member.username}</div>
                  {member.phone && <div className="text-sm text-slate-400">{member.phone}</div>}
                </div>
                <span className={`rounded-full px-3 py-1 text-sm text-slate-100 ${member.status === 'active' ? 'bg-emerald-600' : 'bg-slate-700'}`}>{member.status}</span>
              </div>
              {member.facePhoto && <img src={member.facePhoto} alt={member.name} className="w-16 h-16 rounded-full mt-3 object-cover" />}
              <div className="flex gap-2 mt-4">
                <button onClick={() => openStaffModal(member)} className="flex-1 rounded-full bg-blue-600 px-3 py-2 text-sm text-white transition hover:bg-blue-700">Edit</button>
                {member.riderId && (
                  <button onClick={() => viewRiderPassword(member)} className="rounded-full bg-yellow-500 px-3 py-2 text-sm text-slate-900 transition hover:bg-yellow-400">View PW</button>
                )}
                <button onClick={() => duplicateStaff(member)} className="flex-1 rounded-full bg-purple-600 px-3 py-2 text-sm text-white transition hover:bg-purple-700">Duplicate</button>
                <button onClick={() => deleteRecord(member.id)} className="flex-1 rounded-full bg-rose-600 px-3 py-2 text-sm text-white transition hover:bg-rose-700">Delete</button>
              </div>
            </div>
          ))}
        </div>
        {showStaffModal && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
            <div className="bg-slate-900 rounded-3xl p-6 w-full max-w-2xl max-h-[90vh] overflow-y-auto">
              <h3 className="text-lg font-semibold text-white mb-4">{editingStaff ? 'Edit Staff' : 'Add New Staff'}</h3>
              <div className="grid gap-4 md:grid-cols-2">
                <input value={staffForm.name} onChange={(e) => setStaffForm({ ...staffForm, name: e.target.value })} placeholder="Staff Name *" className="rounded-3xl border border-slate-800 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" required />
                <input value={staffForm.otherName} onChange={(e) => setStaffForm({ ...staffForm, otherName: e.target.value })} placeholder="Other Name" className="rounded-3xl border border-slate-800 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" />
                <input value={staffForm.phone} onChange={(e) => setStaffForm({ ...staffForm, phone: e.target.value })} placeholder={`Phone Number ${staffForm.role === 'Biker' ? '*' : ''}`} className="rounded-3xl border border-slate-800 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" />
                <input value={staffForm.username} onChange={(e) => setStaffForm({ ...staffForm, username: e.target.value })} placeholder="Username *" className="rounded-3xl border border-slate-800 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" required />
                <div className="relative">
                  <Lock className="pointer-events-none absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
                  <input
                    type="password"
                    value={staffForm.password}
                    onChange={(e) => setStaffForm({ ...staffForm, password: e.target.value })}
                    placeholder={editingStaff ? 'Password (leave blank to keep current)' : 'Password *'}
                    className="rounded-3xl border border-slate-800 bg-slate-950 px-11 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500"
                    required={!editingStaff}
                  />
                </div>
                <p className="text-xs text-slate-500">{editingStaff ? 'Leave blank to keep the existing password.' : 'Password is required for login access.'}</p>
                <select value={staffForm.role} onChange={(e) => setStaffForm({ ...staffForm, role: e.target.value })} className="rounded-3xl border border-slate-800 bg-slate-950 px-4 py-3 text-slate-100 outline-none focus:border-emerald-500">
                  <option value="">Select Role *</option>
                  {roles.map((role) => <option key={role.name} value={role.name}>{role.name}</option>)}
                </select>
                <input value={staffForm.idCardNumber} onChange={(e) => setStaffForm({ ...staffForm, idCardNumber: e.target.value })} placeholder="ID Card Number" className="rounded-3xl border border-slate-800 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" />
                <textarea value={staffForm.description} onChange={(e) => setStaffForm({ ...staffForm, description: e.target.value })} placeholder="Description" className="rounded-3xl border border-slate-800 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" rows={2} />
                <textarea value={staffForm.address} onChange={(e) => setStaffForm({ ...staffForm, address: e.target.value })} placeholder="Address" className="rounded-3xl border border-slate-800 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" rows={2} />
                <div className="flex items-center gap-2">
                  <input type="checkbox" checked={staffForm.loginEnabled} onChange={(e) => setStaffForm({ ...staffForm, loginEnabled: e.target.checked })} id="loginEnabled" />
                  <label htmlFor="loginEnabled" className="text-sm text-slate-300">Enable Login</label>
                </div>
              </div>
              <div className="grid gap-4 md:grid-cols-3 mt-4">
                <div>
                  <label className="block text-sm text-slate-400 mb-2">Face Photo</label>
                  <input type="file" accept="image/*" onChange={(e) => handleStaffFileChange('facePhoto', e)} className="w-full rounded-3xl border border-slate-800 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" />
                </div>
                <div>
                  <label className="block text-sm text-slate-400 mb-2">ID Card Front</label>
                  <input type="file" accept="image/*" onChange={(e) => handleStaffFileChange('idCardFront', e)} className="w-full rounded-3xl border border-slate-800 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" />
                </div>
                <div>
                  <label className="block text-sm text-slate-400 mb-2">ID Card Back</label>
                  <input type="file" accept="image/*" onChange={(e) => handleStaffFileChange('idCardBack', e)} className="w-full rounded-3xl border border-slate-800 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" />
                </div>
              </div>
              <div className="flex gap-3 mt-6">
                <button onClick={saveStaff} className="flex-1 rounded-3xl bg-emerald-600 px-4 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-500">Save Staff</button>
                <button onClick={() => setShowStaffModal(false)} className="flex-1 rounded-3xl bg-slate-800 px-4 py-3 text-sm font-semibold text-white transition hover:bg-slate-700">Cancel</button>
              </div>
            </div>
          </div>
        )}
      </div>
    );
  }

  async function viewRiderPassword(member) {
    if (!member.riderId) return setMessage('No rider account linked');
    try {
      setLoading(true);
      const data = await fetchJson(`${apiBase}/riders/raw/${member.riderId}`);
      const pw = data.rawPassword || '(not available)';
      alert(`Rider ${data.email} password: ${pw}`);
    } catch (err) {
      setMessage(err.message || 'Failed to fetch password');
    } finally {
      setLoading(false);
    }
  }

  function renderRoles() {
    return (
      <div className="space-y-4">
        {roles.map((role) => (
          <div key={role.name} className="rounded-3xl border border-slate-800 bg-slate-900 p-5">
            <div className="flex items-center justify-between mb-4">
              <h4 className="text-lg font-semibold text-white">{role.name}</h4>
              <div className="flex items-center gap-2">
                <button onClick={() => setEditingRoleTabs(editingRoleTabs === role.name ? null : role.name)} className="rounded-full px-3 py-1 text-sm bg-slate-800 text-slate-200">{editingRoleTabs === role.name ? 'Close' : 'Edit Tabs'}</button>
              </div>
            </div>
            <div className="grid gap-3 md:grid-cols-2 lg:grid-cols-3">
              {Object.entries(role.permissions).map(([perm, value]) => (
                <label key={perm} className="flex items-center gap-2">
                  <input
                    type="checkbox"
                    checked={value}
                    onChange={(e) => updateRolePermissions(role.name, perm, e.target.checked)}
                    className="rounded border-slate-600"
                  />
                  <span className="text-sm text-slate-300 capitalize">{formatTabName(perm)}</span>
                </label>
              ))}
            </div>

            {editingRoleTabs === role.name && (
              <div className="mt-4 rounded-2xl border border-slate-700 p-4 bg-slate-950">
                <h5 className="text-sm font-semibold text-slate-200 mb-2">All Sidebar Tabs</h5>
                <div className="grid gap-2 md:grid-cols-2 lg:grid-cols-3">
                  {tabs.map((t) => (
                    <div key={t} className="flex items-center justify-between">
                      <label className="flex items-center gap-2">
                        <input type="checkbox" checked={Boolean(role.permissions[t])} onChange={(e) => updateRolePermissions(role.name, t, e.target.checked)} className="rounded border-slate-600" />
                        <span className="text-sm text-slate-300">{formatTabName(t)}</span>
                      </label>
                      <div className="flex items-center gap-2">
                        <button onClick={() => removeTab(t)} className="text-xs text-rose-400">Remove</button>
                      </div>
                    </div>
                  ))}
                </div>
                <div className="mt-3 flex items-center gap-2">
                  <input value={newTabKey} onChange={(e) => setNewTabKey(e.target.value)} placeholder="tab-key" className="rounded px-3 py-2 bg-slate-900 text-slate-200" />
                  <input value={newTabLabel} onChange={(e) => setNewTabLabel(e.target.value)} placeholder="Tab Label" className="rounded px-3 py-2 bg-slate-900 text-slate-200" />
                  <button onClick={() => addTab(newTabKey, newTabLabel)} className="rounded-full bg-emerald-600 px-3 py-2 text-sm text-white">Add Tab</button>
                </div>
              </div>
            )}
          </div>
        ))}
      </div>
    );
  }

  function renderStaffSettings() {
    return (
      <div className="rounded-3xl border border-slate-800 bg-slate-900 p-6">
        <h3 className="text-xl font-semibold text-white mb-4">Roles Settings</h3>
        <div className="space-y-6">
          {roles.map((role) => (
            <div key={role.name} className="border-b border-slate-700 pb-4">
              <h4 className="text-lg font-semibold text-emerald-400 mb-3">{role.name}</h4>
              <div className="grid gap-2 md:grid-cols-2">
                {Object.entries(role.permissions).map(([perm, value]) => (
                  <div key={perm} className="flex items-center justify-between">
                    <span className="text-sm text-slate-300 capitalize">{perm.replace(/([A-Z])/g, ' $1')}</span>
                    <span className={`text-sm ${value ? 'text-emerald-400' : 'text-rose-400'}`}>{value ? '✓' : '✗'}</span>
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>
      </div>
    );
  }

  function renderSales() {
    return (
      <div className="overflow-x-auto rounded-3xl border border-slate-800 bg-slate-900 shadow-soft">
        <table className="w-full min-w-[700px] divide-y divide-slate-700 text-left text-sm text-slate-300">
          <thead className="bg-slate-950 text-slate-200">
            <tr>
              <th className="px-4 py-3">Description</th>
              <th className="px-4 py-3">Amount</th>
              <th className="px-4 py-3">Date</th>
              <th className="px-4 py-3">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-800 bg-slate-950">
            {items.map((sale) => (
              <tr key={sale.id}>
                <td className="px-4 py-3">{sale.description}</td>
                <td className="px-4 py-3">{sale.amount}</td>
                <td className="px-4 py-3">{sale.date}</td>
                <td className="px-4 py-3">
                  <button onClick={() => deleteRecord(sale.id)} className="rounded-full bg-rose-600 px-3 py-1 text-xs text-white transition hover:bg-rose-700">Remove</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    );
  }



  function renderPos() {
    const filteredProducts = getFilteredProducts();
    const summary = getCartSummary();
    const userAvatar = (user?.name || user?.email || 'U').toString().split(' ').map((p) => p[0]).join('').slice(0, 2).toUpperCase();
    const iconSizes = { sm: 'h-8 w-8 text-sm', md: 'h-10 w-10 text-base', lg: 'h-12 w-12 text-lg', xl: 'h-14 w-14 text-xl' };
    const spacingStyles = { compact: 'gap-1.5', normal: 'gap-3', relaxed: 'gap-5' };

    return (
      <div className="space-y-0">
        {/* Top Section: Search + Profile + Categories */}
        <div className={`${posTopSettings.stickyHeader ? 'sticky top-0 z-40' : ''} pt-1 pb-0`}>
          <div className="flex items-center gap-3">
            {/* Search Bar - small */}
            {posTopSettings.showSearch && (
              <div className="relative flex-1 max-w-xs">
                <input
                  ref={posSearchInputRef}
                  value={posSearch}
                  onChange={(e) => setPosSearch(e.target.value)}
                  placeholder="Search menu..."
                  className={`w-full rounded-full border pl-4 pr-9 py-1.5 text-xs outline-none transition-all duration-200 ${
                    darkMode
                      ? 'border-slate-700 bg-slate-900/80 text-slate-100 placeholder-slate-500 focus:border-slate-500 focus:shadow-[0_0_0_2px_rgba(100,116,139,0.15)]'
                      : 'border-slate-200 bg-white text-slate-900 placeholder-slate-400 focus:border-emerald-400 focus:shadow-[0_0_0_2px_rgba(16,185,129,0.1)]'
                  }`}
                  style={{
                    boxShadow: darkMode
                      ? '0 2px 8px rgba(0,0,0,0.15)'
                      : '0 2px 8px rgba(0,0,0,0.04)'
                  }}
                />
                <div className={`pointer-events-none absolute right-0 top-0 flex h-full w-8 items-center justify-center rounded-r-full text-xs ${
                  darkMode ? 'text-slate-400' : 'text-slate-400'
                }`}>
                  🔍
                </div>
              </div>
            )}

            {/* Icons: Dashboard + POS + Recent Orders + Dark Mode */}
            <div className="flex items-center gap-2 mx-auto shrink-0">
              <button
                onClick={() => setActiveTab('dashboard')}
                className={`flex h-8 w-8 items-center justify-center rounded-full text-sm transition-all duration-200 header-btn-3d ${
                  activeTab === 'dashboard'
                    ? 'rainbow-icon-glow'
                    : darkMode
                      ? 'text-slate-400 hover:bg-slate-800'
                      : 'text-slate-500 hover:bg-slate-100'
                }`}
                title="Dashboard"
              >
                📊
              </button>
              <button
                onClick={() => setActiveTab('pos')}
                className={`flex h-8 w-8 items-center justify-center rounded-full text-sm transition-all duration-200 header-btn-3d ${
                  activeTab === 'pos'
                    ? 'rainbow-icon-glow'
                    : darkMode
                      ? 'text-slate-400 hover:bg-slate-800'
                      : 'text-slate-500 hover:bg-slate-100'
                }`}
                title="POS"
              >
                🛒
              </button>
              <button
                onClick={() => setShowRecentOrdersPopup(true)}
                className={`flex h-8 w-8 items-center justify-center rounded-full text-sm transition-all duration-200 header-btn-3d ${
                  darkMode
                    ? 'text-slate-400 hover:bg-slate-800'
                    : 'text-slate-500 hover:bg-slate-100'
                }`}
                title="Recent Orders"
              >
                🕐
              </button>
              <div className="w-px h-5 bg-slate-600/30 mx-1" />
              <button onClick={() => setDarkMode((prev) => !prev)} className={`header-btn-3d rounded-full px-2.5 py-1 text-[10px] font-semibold shadow-[0_2px_8px_rgba(0,0,0,0.15)] transition-all duration-200 ${
                darkMode
                  ? 'bg-gradient-to-br from-slate-700 via-slate-600 to-slate-800 text-slate-200'
                  : 'bg-gradient-to-br from-slate-200 via-slate-100 to-white text-slate-600'
              }`}>
                {darkMode ? '☀️' : '🌙'}
              </button>
            </div>
          </div>
        </div>

        <section className="grid gap-4 lg:grid-cols-[1.5fr_0.65fr] xl:grid-cols-[1.55fr_0.6fr]">
          <div className={`w-full min-w-0 rounded-[32px] border p-4 shadow-soft mt-5 ${darkMode ? 'border-slate-700 bg-slate-950' : 'border-slate-200 bg-white'}`}>
            {/* Categories - only above catalog, max 3 lines */}
            {posTopSettings.showCategories && (
              <div className="flex flex-wrap items-center gap-2 mb-4 max-h-[100px] overflow-y-auto">
                <button onClick={() => setSelectedCategory('All')} className={`flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium transition-all duration-200 ${
                  selectedCategory === 'All'
                    ? 'bg-emerald-600 text-white shadow-md'
                    : `${darkMode ? 'bg-slate-800 text-slate-300 hover:bg-slate-700' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'}`
                }`}>
                  <span className="text-sm">🎯</span> All
                </button>
                <button onClick={() => setSelectedCategory(MASHALLAH_CATEGORY)} className={`flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium transition-all duration-200 ${
                  selectedCategory === MASHALLAH_CATEGORY
                    ? 'bg-amber-600 text-white shadow-md'
                    : `${darkMode ? 'bg-slate-800 text-slate-300 hover:bg-slate-700' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'}`
                }`}>
                  <span className="text-sm">🌟</span> Mashallah
                </button>
                {posCategories.map((category) => (
                  <button key={category.id || category.name} onClick={() => setSelectedCategory(category.name)} className={`flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium transition-all duration-200 ${
                    selectedCategory === category.name
                      ? 'bg-violet-600 text-white shadow-md'
                      : `${darkMode ? 'bg-slate-800 text-slate-300 hover:bg-slate-700' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'}`
                  }`}>
                    {category.icon ? (
                      <img src={category.icon} alt="" className="w-4 h-4 rounded-full object-cover" />
                    ) : (
                      <span className="text-sm">📁</span>
                    )}
                    {category.name}
                  </button>
                ))}
                <button onClick={() => { setEditingCategory(null); setForm({ name: '' }); setInventorySubTab('categories'); }} className={`flex items-center gap-1 px-3 py-1.5 rounded-full text-xs font-medium border border-dashed transition ${
                  darkMode ? 'border-slate-600 text-slate-400 hover:bg-slate-800' : 'border-slate-300 text-slate-400 hover:bg-slate-50'
                }`}>
                  + Add
                </button>
              </div>
            )}
            <div className="flex items-center justify-between mb-4">
              <div>
                <p className={`text-xs uppercase tracking-[0.2em] ${darkMode ? 'text-slate-400' : 'text-slate-500'}`}>POS Catalog</p>
                <h3 className={`mt-1 text-xl font-semibold ${darkMode ? 'text-slate-100' : 'text-slate-900'}`}>Select products</h3>
              </div>
            </div>
            <div className="grid grid-cols-4 gap-2">
              {filteredProducts.map((product) => (
                <button
                  key={product.id}
                  type="button"
                  className="rounded-3xl border border-slate-200 bg-white p-3 shadow-soft transition duration-200 hover:-translate-y-0.5 hover:border-sky-300 hover:shadow-md"
                  onClick={() => addToCart(product)}
                >
                  <div className="flex flex-col items-center text-center mb-2">
                    {product.photo ? (
                      <img src={product.photo} alt={product.name} className="w-12 h-12 rounded-full object-cover mb-2 shadow-sm" />
                    ) : (
                      <div className="w-12 h-12 rounded-full bg-slate-200 flex items-center justify-center mb-2 text-slate-400 text-xl">📦</div>
                    )}
                  </div>
                  <div className="text-left">
                    <div className="text-xs font-semibold text-slate-900 mb-1">{product.name}</div>
                    <div className="text-sm font-bold text-emerald-600">
                      {product.weights?.length ? `From ${getProductStartingPrice(product)} PKR` : `${Number(product.price) || 0} PKR`}
                    </div>
                  </div>
                </button>
              ))}
            </div>
          </div>

          {showWeightPopup && selectedCartProduct && (
            <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 px-4 py-6">
              <div className="w-full max-w-sm rounded-[32px] border border-slate-700 bg-slate-950 p-6 shadow-[0_35px_120px_-30px_rgba(0,0,0,0.8)]">
                <div className="flex items-center justify-between gap-4 mb-4">
                  <div>
                    <p className="text-xs uppercase tracking-[0.2em] text-slate-500">Select weight</p>
                    <h3 className="mt-2 text-xl font-semibold text-white">{selectedCartProduct.name}</h3>
                    {selectedFlavorOption && <p className="text-sm text-slate-400">Flavor: {selectedFlavorOption.label}</p>}
                  </div>
                  <button onClick={() => { setShowWeightPopup(false); setSelectedCartProduct(null); setSelectedFlavorOption(null); }} className="rounded-full border border-slate-700 bg-slate-900 px-3 py-2 text-sm text-slate-200 hover:bg-slate-800">✕</button>
                </div>
                <div className="space-y-3">
                  {(selectedFlavorOption?.variants || []).map((variant) => (
                    <button key={variant.label} type="button" onClick={() => handleWeightSelect(variant)} className="w-full rounded-3xl border border-slate-700 bg-slate-900 px-4 py-3 text-left text-sm text-slate-100 transition hover:border-emerald-500 hover:bg-slate-800">
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

          {showFlavorPopup && selectedCartProduct && (
            <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 px-4 py-6">
              <div className="w-full max-w-sm rounded-[32px] border border-slate-700 bg-slate-950 p-6 shadow-[0_35px_120px_-30px_rgba(0,0,0,0.8)]">
                <div className="flex items-center justify-between gap-4 mb-4">
                  <div>
                    <p className="text-xs uppercase tracking-[0.2em] text-slate-500">Choose flavor</p>
                    <h3 className="mt-2 text-xl font-semibold text-white">{selectedCartProduct.name}</h3>
                    {selectedWeightOption && <p className="text-sm text-slate-400">Weight: {selectedWeightOption.label} — Price: {selectedWeightOption.price} PKR</p>}
                  </div>
                  <button onClick={() => { setShowFlavorPopup(false); setSelectedCartProduct(null); setSelectedFlavorOption(null); }} className="rounded-full border border-slate-700 bg-slate-900 px-3 py-2 text-sm text-slate-200 hover:bg-slate-800">✕</button>
                </div>
                <div className="space-y-3">
                  {(selectedCartProduct.flavors || []).map((flavor, index) => (
                    <button key={index} type="button" onClick={() => handleFlavorSelect(flavor)} className="w-full rounded-3xl border border-slate-700 bg-slate-900 px-4 py-3 text-left text-sm text-slate-100 transition hover:border-emerald-500 hover:bg-slate-800">
                      <span>{flavor.label}</span>
                    </button>
                  ))}
                </div>
              </div>
            </div>
          )}

          {/* Star burst popup */}
          {orderTypeStars && (
            <div className="fixed inset-0 z-[60] pointer-events-none flex items-center justify-center">
              <div className="animate-star-burst text-6xl" key={starKey}>
                ⭐🌟✨💫
              </div>
            </div>
          )}

          {/* Float notification */}
          {orderTypeNotif && (
            <div className="fixed bottom-32 left-1/2 -translate-x-1/2 z-[60] animate-float-up pointer-events-none">
              <div className="rounded-full bg-gradient-to-r from-emerald-500 to-sky-500 px-5 py-2.5 text-sm font-bold text-white shadow-[0_8px_32px_rgba(16,185,129,0.4)] whitespace-nowrap">
                🎉 {orderTypeNotif} order selected!
              </div>
            </div>
          )}

          <div className={`min-w-0 lg:sticky lg:top-0 rounded-[16px] border shadow-soft ${darkMode ? 'border-slate-700 bg-slate-950' : 'border-slate-200 bg-white'}`}>
            <div className="px-3 pt-1.5 mb-2 relative">
              <div className="absolute top-1.5 right-3">
                <div className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-emerald-600 text-white text-xs font-semibold shadow-md">
                  {cart.reduce((sum, it) => sum + (Number(it.price) || 0) * (it.quantity || 0), 0)} PKR
                </div>
              </div>
              <p className={`text-[10px] uppercase tracking-[0.2em] ${darkMode ? 'text-slate-400' : 'text-slate-500'}`}>Cart summary</p>
              <h3 className={`text-sm font-semibold ${darkMode ? 'text-slate-100' : 'text-slate-900'}`}>{cart.length} items</h3>
            </div>
            <div className="space-y-1.5 px-3">
              {cart.map((item, index) => (
                <div
                  key={item.itemId}
                  onClick={() => setSelectedCartIndex(index)}
                  className={`rounded-[12px] border p-2 cursor-pointer transition ${darkMode ? 'bg-slate-900' : 'bg-slate-50'} ${selectedCartIndex === index ? 'border-emerald-500 shadow-[0_0_0_2px_rgba(16,185,129,0.12)]' : darkMode ? 'border-slate-700' : 'border-slate-200'}`}>
                  <div className="flex items-center justify-between gap-1.5">
                    <div>
                      <div className={`text-sm font-semibold ${darkMode ? 'text-slate-100' : 'text-slate-900'}`}>{item.name}</div>
                      <div className={`text-xs ${darkMode ? 'text-slate-400' : 'text-slate-500'}`}>{item.quantity} × {item.price} PKR</div>
                      {(item.weight || item.flavor) && (
                        <div className={`mt-1 text-xs ${darkMode ? 'text-slate-500' : 'text-slate-600'}`}>
                          {item.weight && <span className="mr-2">Weight: {item.weight}</span>}
                          {item.flavor && <span>Flavor: {item.flavor}</span>}
                        </div>
                      )}
                    </div>
                    <div className="flex items-center gap-2">
                      <div className="flex items-center gap-1 rounded-full bg-slate-900 px-1.5 py-0.5 shadow-[0_4px_0_rgba(15,23,42,0.25)]">
                        <button onClick={() => updateCartItem(item.itemId, -1)} className="inline-flex h-6 w-6 items-center justify-center rounded-full bg-slate-800 text-xs font-semibold text-slate-100 transition hover:bg-slate-700 active:translate-y-[1px]">-</button>
                        <span className="inline-flex h-6 min-w-[24px] items-center justify-center rounded-full bg-slate-950 px-2 text-xs font-semibold text-slate-100">{item.quantity}</span>
                        <button onClick={() => updateCartItem(item.itemId, 1)} className="inline-flex h-6 w-6 items-center justify-center rounded-full bg-slate-800 text-xs font-semibold text-slate-100 transition hover:bg-slate-700 active:translate-y-[1px]">+</button>
                      </div>
                      <button onClick={() => editCartItemDetails(item.itemId)} className="inline-flex h-6 w-6 items-center justify-center rounded-full bg-gradient-to-br from-blue-500 to-blue-600 text-[10px] font-bold text-white transition hover:from-blue-600 hover:to-blue-700 shadow-[0_2px_8px_rgba(59,130,246,0.3)] active:translate-y-[1px]" title="Edit product">✎</button>
                      <button onClick={() => { setCart(cart.filter(cartItem => cartItem.itemId !== item.itemId)); }} className="inline-flex h-6 w-6 items-center justify-center rounded-full bg-gradient-to-br from-red-500 to-red-600 text-[10px] font-bold text-white transition hover:from-red-600 hover:to-red-700 shadow-[0_2px_8px_rgba(239,68,68,0.3)] active:translate-y-[1px]" title="Delete product">✕</button>
                    </div>
                  </div>
                  {/* notes removed per request; temporary edits available via Edit button */}
                </div>
              ))}
            </div>
            <div className="mt-2 rounded-[12px] border border-slate-800 bg-slate-950 px-2.5 py-2">
              <div className="flex items-center gap-1.5 text-[10px] uppercase tracking-[0.2em] text-slate-400 mb-1.5">
                <span>📋</span>
                <span>Order type</span>
              </div>
              <div className="flex gap-1">
                {[
                  { name: 'Dine-In', colors: 'from-emerald-500 to-emerald-600', shadow: 'rgba(16,185,129,0.35)', icon: '🍽️' },
                  { name: 'Takeaway', colors: 'from-amber-500 to-orange-500', shadow: 'rgba(245,158,11,0.35)', icon: '🛍️' },
                  { name: 'Delivery', colors: 'from-sky-500 to-blue-600', shadow: 'rgba(14,165,233,0.35)', icon: '🚚' },
                ].map(({ name, colors, shadow, icon }) => (
                  <button key={name} onClick={() => handleSelectOrderType(name)} className={`flex-1 rounded-full px-1.5 py-1 text-[10px] font-bold tracking-wide uppercase transition-all duration-200 active:scale-[0.97] text-center leading-tight ${
                    orderType === name
                      ? `bg-gradient-to-br ${colors} text-white shadow-[0_2px_8px_${shadow}]`
                      : 'bg-slate-800/80 text-slate-400 hover:bg-slate-700 hover:text-slate-200'
                  }`}
                  style={orderType === name ? {
                    boxShadow: `0 2px 8px ${shadow}, inset 0 1px 1px rgba(255,255,255,0.15)`
                  } : {}}
                  >
                    {icon} {name}
                  </button>
                ))}
              </div>
            </div>
            <div className="mx-3 mb-1 mt-1.5">
              <button type="button" onClick={handleBtConnect} disabled={btConnecting} className={`w-full rounded-full px-2.5 py-1.5 text-[10px] font-bold tracking-wide uppercase transition-all duration-200 flex items-center justify-center gap-1.5 ${btConnected ? 'bg-emerald-600 text-white shadow-[0_2px_8px_rgba(16,185,129,0.35)]' : 'bg-slate-800/80 text-slate-400 hover:bg-slate-700 hover:text-slate-200'}`}>
                {btConnecting ? (
                  <span className="inline-block w-3 h-3 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                ) : btConnected ? (
                  <BluetoothConnected className="w-3 h-3" />
                ) : (
                  <Bluetooth className="w-3 h-3" />
                )}
                {btConnecting ? 'Connecting...' : btConnected ? `BT: ${btInfo?.name || 'Connected'}` : 'BT Printer'}
              </button>
            </div>
            <div className={`mx-3 mb-2 mt-2 space-y-1.5 rounded-[12px] border p-2.5 ${darkMode ? 'border-slate-700 bg-slate-900' : 'border-slate-200 bg-slate-50'}`}>
              <div className="flex justify-between text-[11px] text-slate-400"><span>Subtotal</span><span>{summary.subtotal} PKR</span></div>
              <div className="flex justify-between text-[11px] text-slate-400"><span>Discount</span><span>{summary.discount} PKR</span></div>
              <div className="flex justify-between text-[11px] text-slate-400"><span>Tax</span><span>{summary.tax} PKR</span></div>
              {orderType === 'Delivery' && (
                <div className="flex justify-between text-[11px] text-slate-400"><span>Delivery</span><span>{summary.deliveryFee} PKR</span></div>
              )}
              <div className="flex justify-between text-[11px] text-slate-400"><span>Service</span><span>{summary.serviceCharge} PKR</span></div>
              <div className={`flex justify-between text-sm font-semibold ${darkMode ? 'text-slate-100' : 'text-slate-900'}`}><span>Total</span><span>{summary.total} PKR</span></div>
            </div>
          </div>
        </section>

        {showCustomerDetailsPopup && (
          <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 px-4 py-6">
            <div className="w-full max-w-md rounded-[32px] border border-slate-700 bg-slate-950 p-6 shadow-[0_35px_120px_-30px_rgba(0,0,0,0.8)] max-h-[calc(100vh-3rem)] overflow-y-auto flex flex-col">
              {popupError && <div className="mb-4 rounded-3xl border border-rose-500 bg-rose-900/20 px-4 py-3 text-sm text-rose-200 font-semibold">{popupError}</div>}
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-xs uppercase tracking-[0.2em] text-slate-500">Customer details</p>
                  <h3 className="mt-2 text-xl font-semibold text-white">{orderType} order</h3>
                </div>
                <button type="button" onClick={closeCustomerDetailsPopup} className="rounded-full border border-slate-700 bg-slate-900 px-3 py-2 text-sm text-slate-200 hover:bg-slate-800">✕</button>
              </div>
              <div className="mt-6 space-y-4">
                {orderType === 'Delivery' && (
                  <>
                    <div className="grid gap-3 relative">
                      <label className="text-sm text-slate-400">Delivery address <span className="text-rose-500">*</span></label>
                      <input type="text" value={orderDetails.address} onChange={(e) => updateOrderDetail('address', e.target.value)} className="w-full rounded-3xl border border-slate-800 bg-slate-900 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" placeholder="Search or enter delivery address" />
                      {orderDetails.address.trim() && (
                        <div className="mt-2 rounded-3xl border border-slate-700 bg-slate-900 p-3 text-sm text-slate-200 max-h-44 overflow-y-auto">
                          {addressSearchResults.length > 0 ? (
            <div className="space-y-1.5">
                              <p className="text-slate-400">Matching address(es)</p>
                              {addressSearchResults.slice(0, 5).map((customer) => (
                                <button type="button" key={customer.id} onClick={() => handleAddressSelect(customer)} className="w-full rounded-3xl border border-slate-700 bg-slate-950 px-4 py-3 text-left text-sm text-slate-100 hover:border-emerald-500 hover:bg-slate-900">
                                  <div className="font-semibold text-slate-100">{customer.address}</div>
                                  <div className="text-xs text-slate-500">{customer.phone || 'No phone'}{customer.name ? ` • ${customer.name}` : ''}</div>
                                </button>
                              ))}
                            </div>
                          ) : (
                            <div className="rounded-3xl border border-slate-700 bg-slate-950 p-4 text-sm text-slate-400">
                              <p>No matching address found.</p>
                              <button type="button" onClick={handleAddNewAddress} className="mt-3 inline-flex rounded-full border border-emerald-600 bg-emerald-600 px-3 py-2 text-sm font-semibold text-slate-950 hover:bg-emerald-500">
                                Add new address
                              </button>
                            </div>
                          )}
                        </div>
                      )}
                    </div>
                    <div className="grid gap-3">
                      <label className="text-sm text-slate-400">Service type <span className="text-rose-500">*</span></label>
                      <select value={orderDetails.serviceType} onChange={(e) => updateOrderDetail('serviceType', e.target.value)} className="w-full rounded-3xl border border-slate-800 bg-slate-900 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500">
                        <option value="">Select service type</option>
                        {deliveryServiceTypes.map((type) => (
                          <option key={type.id} value={type.name}>{type.name}</option>
                        ))}
                      </select>
                    </div>
                    <div className="grid gap-3">
                      <label className="text-sm text-slate-400">Rider <span className="text-slate-500">(optional)</span></label>
                      <select value={orderDetails.deliveryAgent} onChange={(e) => updateOrderDetail('deliveryAgent', e.target.value)} className="w-full rounded-3xl border border-slate-800 bg-slate-900 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500">
                        <option value="">Select rider</option>
                        {getBikers().map((rider) => (
                          <option key={rider.id || rider.name} value={rider.name || rider.username}>{rider.name || rider.username}</option>
                        ))}
                      </select>
                    </div>
                  </>
                )}
                {orderType === 'Takeaway' && (
                  <>
                    <div className="grid gap-3">
                      <label className="text-sm text-slate-400">Customer name <span className="text-slate-500">(optional)</span></label>
                      <input type="text" value={orderDetails.customerName} onChange={(e) => updateOrderDetail('customerName', e.target.value)} className="w-full rounded-3xl border border-slate-800 bg-slate-900 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" placeholder="Customer name" />
                    </div>
                    <div className="grid gap-3">
                      <label className="text-sm text-slate-400">Notes <span className="text-slate-500">(optional)</span></label>
                      <textarea value={orderDetails.notes} onChange={(e) => updateOrderDetail('notes', e.target.value)} className="w-full rounded-3xl border border-slate-800 bg-slate-900 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" placeholder="Customer notes" rows={3} />
                    </div>
                  </>
                )}
                {(orderType === 'Delivery' || orderType === 'Takeaway') && (
                  <div className="grid gap-3">
                    <label className="text-sm text-slate-400">Phone <span className="text-slate-500">(optional)</span></label>
                    <input type="text" value={orderDetails.phone} onChange={(e) => updateOrderDetail('phone', e.target.value)} className="w-full rounded-3xl border border-slate-800 bg-slate-900 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" placeholder="Phone number" />
                  </div>
                )}
                {orderType === 'Dine-In' && (
                  <>
                    <div className="grid gap-3">
                      <label className="text-sm text-slate-400">Customer name <span className="text-slate-500">(optional)</span></label>
                      <input type="text" value={orderDetails.customerName} onChange={(e) => updateOrderDetail('customerName', e.target.value)} className="w-full rounded-3xl border border-slate-800 bg-slate-900 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" placeholder="Customer name" />
                    </div>
                    <div className="grid gap-3">
                      <label className="text-sm text-slate-400">Table / Room</label>
                      <select value={orderDetails.tableNumber} onChange={(e) => updateOrderDetail('tableNumber', e.target.value)} className="w-full rounded-3xl border border-slate-800 bg-slate-900 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500">
                        <option value="">Select table or room</option>
                        {availableDineInTables.length ? availableDineInTables.map((table) => {
                          const tableLabel = getTableLabel(table);
                          return <option key={table.id} value={tableLabel}>{tableLabel}</option>;
                        }) : <option value="" disabled>No free tables available</option>}
                      </select>
                    </div>
                  </>
                )}
                {orderType === 'Delivery' && (
                  <div className="grid gap-3">
                    <label className="text-sm text-slate-400">Payment status</label>
                    <p className="text-sm text-slate-500">Tap a payment status to save the delivery order and print the receipt.</p>
                    <div className="flex flex-wrap gap-2">
                      {['Receive Cash Till', 'May be Online', 'Paid to Cash on Counter'].map((status) => (
                        <button
                          key={status}
                          type="button"
                          onClick={() => handleDeliveryPaymentStatus(status)}
                          className={`px-4 py-2 rounded-3xl text-sm font-semibold transition-all ${
                            orderDetails.paymentStatus === status
                              ? 'bg-emerald-600 text-slate-950 border border-emerald-500'
                              : 'border border-slate-700 bg-slate-900 text-slate-200 hover:bg-slate-800'
                          }`}
                        >
                          {status}
                        </button>
                      ))}
                    </div>
                  </div>
                )}
                <div className="flex flex-wrap justify-end gap-3 pt-2">
                  <button type="button" onClick={closeCustomerDetailsPopup} disabled={isSaving} className="rounded-3xl border border-slate-700 px-4 py-3 text-sm font-semibold text-slate-200 hover:bg-slate-800 disabled:opacity-50 disabled:cursor-not-allowed">Cancel</button>
                  {orderType === 'Takeaway' ? (
                    <button type="button" onClick={handleCustomerDetailsSave} disabled={isSaving} className="rounded-3xl bg-emerald-600 px-4 py-3 text-sm font-semibold text-slate-950 hover:bg-emerald-500 disabled:opacity-50 disabled:cursor-not-allowed">{isSaving ? 'Saving...' : 'Save & Continue'}</button>
                  ) : orderType === 'Dine-In' ? (
                    <>
                      <button type="button" onClick={handleSaveOnly} disabled={isSaving} className="rounded-3xl border border-emerald-600 px-4 py-3 text-sm font-semibold text-emerald-400 hover:bg-emerald-600/20 disabled:opacity-50 disabled:cursor-not-allowed">{isSaving ? 'Saving...' : 'Save'}</button>
                      <button type="button" onClick={handlePrintOnly} disabled={isSaving} className="rounded-3xl border border-emerald-600 px-4 py-3 text-sm font-semibold text-emerald-400 hover:bg-emerald-600/20 disabled:opacity-50 disabled:cursor-not-allowed">{isSaving ? 'Printing...' : 'Print'}</button>
                      <button type="button" onClick={handleSaveAndPrint} disabled={isSaving} className="rounded-3xl bg-emerald-600 px-4 py-3 text-sm font-semibold text-slate-950 hover:bg-emerald-500 disabled:opacity-50 disabled:cursor-not-allowed">{isSaving ? 'Saving & Printing...' : 'Save & Print'}</button>
                    </>
                  ) : null}
                </div>
              </div>
            </div>
          </div>
        )}

        {showPaymentPopup && (
          <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 px-4 py-6">
            <div className="w-full max-w-md rounded-[32px] border border-slate-700 bg-slate-950 p-6 shadow-[0_35px_120px_-30px_rgba(0,0,0,0.8)]">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-xs uppercase tracking-[0.2em] text-slate-500">Payment</p>
                  <h3 className="mt-2 text-xl font-semibold text-white">Payment details</h3>
                </div>
                <button onClick={closePaymentPopup} className="rounded-full border border-slate-700 bg-slate-900 px-3 py-2 text-sm text-slate-200 hover:bg-slate-800">✕</button>
              </div>
              <div className="mt-6 space-y-4 max-h-[72vh] overflow-y-auto pr-2">
                <div className="grid gap-3">
                  <p className="text-sm text-slate-400">Order type: <span className="font-semibold text-slate-100">{orderType}</span></p>
                  <div className="grid gap-2 sm:grid-cols-3">
                    {['Cash', 'Card', 'Online'].map((method) => (
                      <button key={method} onClick={() => setPaymentMethod(method)} className={`rounded-full px-3 py-2 text-sm font-semibold transition ${paymentMethod === method ? 'bg-emerald-600 text-slate-950 shadow-[0_8px_0_rgba(16,185,129,0.22)]' : 'bg-slate-800 text-slate-200 hover:bg-slate-700'}`}>
                        {method}
                      </button>
                    ))}
                  </div>
                </div>
                <div className="grid gap-3 rounded-3xl border border-slate-800 bg-slate-900 p-4">
                  <div className="grid gap-3">
                    <label className="text-sm text-slate-400">Discount</label>
                    <input type="number" value={orderDetails.discount} onChange={(e) => updateOrderDetail('discount', e.target.value)} className="w-full rounded-3xl border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-100 outline-none focus:border-emerald-500" />
                  </div>
                  <div className="grid gap-3 sm:grid-cols-3">
                    <div className="grid gap-2">
                      <label className="text-sm text-slate-400">Tax %</label>
                      <input type="number" value={orderDetails.taxPercent} onChange={(e) => updateOrderDetail('taxPercent', e.target.value)} className="w-full rounded-3xl border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-100 outline-none focus:border-emerald-500" />
                    </div>
                    <div className="grid gap-2">
                      <label className="text-sm text-slate-400">Service</label>
                      <input type="number" value={orderDetails.serviceCharge} onChange={(e) => updateOrderDetail('serviceCharge', e.target.value)} className="w-full rounded-3xl border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-100 outline-none focus:border-emerald-500" />
                    </div>
                    <div className="grid gap-2">
                      <label className="text-sm text-slate-400">Amount</label>
                      <input type="number" value={summary.total} readOnly className="w-full rounded-3xl border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-100 outline-none" />
                    </div>
                  </div>
                  <div className="grid gap-2">
                    <label className="text-sm text-slate-400">Special notes</label>
                    <textarea value={orderDetails.notes} onChange={(e) => updateOrderDetail('notes', e.target.value)} className="w-full rounded-3xl border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-100 outline-none focus:border-emerald-500" rows={3} />
                  </div>
                </div>
                <div className="grid gap-2 rounded-3xl border border-slate-800 bg-slate-900 p-4">
                  <div className="flex items-center justify-between text-sm text-slate-400"><span>Total</span><span className="font-semibold text-slate-100">{summary.total} PKR</span></div>
                  <div className="flex items-center justify-between text-sm text-slate-400"><span>Discount</span><span>{summary.discount} PKR</span></div>
                  <div className="flex items-center justify-between text-sm text-slate-400"><span>Tax</span><span>{summary.tax} PKR</span></div>
                  <div className="flex items-center justify-between text-sm text-slate-400"><span>Service</span><span>{summary.serviceCharge} PKR</span></div>
                </div>
                <div className="flex flex-wrap justify-end gap-3">
                  <button onClick={closePaymentPopup} disabled={isSaving} className="rounded-3xl border border-slate-700 px-4 py-3 text-sm font-semibold text-slate-200 hover:bg-slate-800 disabled:opacity-50">Cancel</button>
                  <button onClick={handleSavePayLater} disabled={isSaving} className="rounded-3xl bg-slate-700 px-4 py-3 text-sm font-semibold text-white hover:bg-slate-600 disabled:opacity-50">{isSaving ? 'Saving...' : 'Save & Pay Later'}</button>
                  <button onClick={handlePaymentSave} disabled={isSaving} className="rounded-3xl bg-emerald-600 px-4 py-3 text-sm font-semibold text-slate-950 hover:bg-emerald-500 disabled:opacity-50">{isSaving ? 'Saving...' : 'Pay & Save'}</button>
                </div>
                {popupError && <div className="rounded-3xl border border-rose-500 bg-rose-900/20 px-4 py-3 text-sm text-rose-200">{popupError}</div>}
              </div>
            </div>
          </div>
        )}

        {showRecentOrdersPopup && (
          <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 px-4 py-6">
            <div className="w-full max-w-5xl max-h-[90vh] overflow-y-auto rounded-[32px] border border-slate-700 bg-slate-950 p-6 shadow-[0_35px_120px_-30px_rgba(0,0,0,0.8)]">
              <div className="flex items-center justify-between mb-4">
                <div>
                  <p className="text-xs uppercase tracking-[0.2em] text-slate-500">Order history</p>
                  <h3 className="mt-1 text-xl font-semibold text-white">Recent POS orders</h3>
                </div>
                <button onClick={() => setShowRecentOrdersPopup(false)} className="rounded-full border border-slate-700 bg-slate-900 px-3 py-2 text-sm text-slate-200 hover:bg-slate-800">✕</button>
              </div>
              {renderRecentOrders(true)}
            </div>
          </div>
        )}
      </div>
    );
  }

  const receiptField = (label, key) => (
            <label className="flex items-center gap-3 rounded-3xl border border-slate-700 bg-slate-950 px-4 py-3 text-sm text-slate-200">
              <input type="checkbox" checked={settings[key]} onChange={(e) => setSettings((prev) => ({ ...prev, [key]: e.target.checked }))} className="h-4 w-4 rounded border-slate-600 bg-slate-900 text-emerald-500" />
              {label}
            </label>
          );

  function renderSettings() {
    const receiptFontSizes = settings.receiptFontSizes || {
      title: 16,
      section: 14,
      product: 12,
      customer: 12,
      notes: 11
    };

    return (
      <div className="space-y-6">
        <div className={`rounded-[32px] border p-6 shadow-soft ${darkMode ? 'border-slate-700 bg-slate-950' : 'border-slate-200 bg-white'}`}>
          <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
            <div>
              <p className={`text-sm uppercase tracking-[0.2em] ${darkMode ? 'text-slate-400' : 'text-slate-500'}`}>Hotel Settings</p>
              <h3 className={`mt-2 text-2xl font-semibold ${darkMode ? 'text-slate-100' : 'text-slate-900'}`}>Branding and receipt settings</h3>
            </div>
            <div className={`rounded-full px-4 py-2 text-sm font-semibold ${darkMode ? 'bg-slate-900 text-slate-100 border border-slate-700' : 'bg-slate-100 text-slate-900 border border-slate-200'}`}>
              Dark mode is {darkMode ? 'on' : 'off'}
            </div>
          </div>

          <div className="mt-6 grid gap-4 lg:grid-cols-2">
            <div>
              <label className="block text-sm font-medium text-slate-400">Hotel Name</label>
              <input value={settings.hotelName} onChange={(e) => setSettings((prev) => ({ ...prev, hotelName: e.target.value }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} />
            </div>
            <div>
              <label className="block text-sm font-medium text-slate-400">Currency</label>
              <input value={settings.currency} onChange={(e) => setSettings((prev) => ({ ...prev, currency: e.target.value }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} />
            </div>
            <div>
              <label className="block text-sm font-medium text-slate-400">Location</label>
              <input value={settings.location} onChange={(e) => setSettings((prev) => ({ ...prev, location: e.target.value }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} />
            </div>
            <div>
              <label className="block text-sm font-medium text-slate-400">Tax Rate (%)</label>
              <input type="number" value={settings.taxRate} onChange={(e) => setSettings((prev) => ({ ...prev, taxRate: Number(e.target.value) }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} />
            </div>
          </div>

          <div className="mt-6 grid gap-4 lg:grid-cols-2">
            <div>
              <label className="block text-sm font-medium text-slate-400">Receipt Header</label>
              <input value={settings.receiptHeader} onChange={(e) => setSettings((prev) => ({ ...prev, receiptHeader: e.target.value }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} />
            </div>
            <div>
              <label className="block text-sm font-medium text-slate-400">Receipt Footer</label>
              <input value={settings.receiptFooter} onChange={(e) => setSettings((prev) => ({ ...prev, receiptFooter: e.target.value }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} />
            </div>
          </div>

                  <div className="mt-6 grid gap-4 lg:grid-cols-2">
            <div>
              <label className="block text-sm font-medium text-slate-400">POS Header Label</label>
              <input value={settings.posHeaderSubtitle} onChange={(e) => setSettings((prev) => ({ ...prev, posHeaderSubtitle: e.target.value }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} placeholder="e.g. POS Header" />
            </div>
            <div>
              <label className="block text-sm font-medium text-slate-400">POS Header Title</label>
              <input value={settings.posHeaderTitle} onChange={(e) => setSettings((prev) => ({ ...prev, posHeaderTitle: e.target.value }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} placeholder="e.g. POS Counter" />
            </div>
          </div>

          <div className="mt-6 rounded-[24px] border border-slate-300/40 bg-slate-50 p-4">
            <p className="text-sm font-semibold text-slate-700">Rider App Branding</p>
            <div className="mt-4 grid gap-4 lg:grid-cols-2">
              <div>
                <label className="block text-sm font-medium text-slate-400">Rider App Title</label>
                <input value={settings.riderAppTitle} onChange={(e) => setSettings((prev) => ({ ...prev, riderAppTitle: e.target.value }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} placeholder="Rider Portal" />
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-400">Rider App Subtitle</label>
                <input value={settings.riderAppSubtitle} onChange={(e) => setSettings((prev) => ({ ...prev, riderAppSubtitle: e.target.value }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} placeholder="Fast delivery management for riders" />
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-400">Login Prompt</label>
                <input value={settings.riderAppLoginNote} onChange={(e) => setSettings((prev) => ({ ...prev, riderAppLoginNote: e.target.value }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} placeholder="Login to continue" />
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-400">Rider App Logo</label>
                <input type="file" accept="image/*" onChange={handleRiderAppLogoChange} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} />
                {settings.riderAppLogo && <img src={settings.riderAppLogo} alt="Rider App Logo preview" className="mt-3 h-20 w-20 rounded-full object-cover border border-slate-700" />}
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-400">Rider App Avatar</label>
                <input type="file" accept="image/*" onChange={handleRiderAppAvatarChange} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} />
                {settings.riderAppAvatar && <img src={settings.riderAppAvatar} alt="Rider App Avatar preview" className="mt-3 h-20 w-20 rounded-full object-cover border border-slate-700" />}
              </div>
            </div>
          </div>

          <div className="mt-6 rounded-[24px] border border-slate-300/40 bg-slate-50 p-4">
            <p className="text-sm font-semibold text-slate-700">Login Page Branding</p>
            <div className="mt-4 grid gap-4 lg:grid-cols-2">
              <div>
                <label className="block text-sm font-medium text-slate-400">Login Page Logo</label>
                <input type="file" accept="image/*" onChange={handleLoginAppLogoChange} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} />
                {settings.loginAppLogo && <img src={settings.loginAppLogo} alt="Login Logo preview" className="mt-3 h-20 w-20 rounded-full object-cover border border-slate-700" />}
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-400">Hotel Name (Login)</label>
                <input value={settings.hotelName} onChange={(e) => setSettings((prev) => ({ ...prev, hotelName: e.target.value }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} placeholder="Usman Hotel" />
              </div>
            </div>
          </div>

          <div className="mt-6 grid gap-4 lg:grid-cols-2">
            <div>
              <label className="block text-sm font-medium text-slate-400">Header Circle Photo</label>
              <input type="file" accept="image/*" onChange={handlePosHeaderPhotoChange} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} />
              {settings.posHeaderPhoto && <img src={settings.posHeaderPhoto} alt="Header Circle Preview" className="mt-3 h-20 w-20 rounded-full object-cover border border-slate-700" />}
            </div>
          </div>

          <div className="mt-6 grid gap-4 lg:grid-cols-3">
            <div>
              <label className="block text-sm font-medium text-slate-400">Receipt Logo</label>
              <input type="file" accept="image/png,image/jpeg" onChange={handleSettingsLogoChange} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} />
              {settings.logo && <img src={settings.logo} alt="Receipt Logo preview" className="mt-3 h-20 w-full object-contain rounded-3xl border border-slate-700" />}
            </div>
            <div>
              <label className="block text-sm font-medium text-slate-400">Logo Width (px)</label>
              <input type="number" value={settings.receiptLogoWidth} onChange={(e) => setSettings((prev) => ({ ...prev, receiptLogoWidth: e.target.value }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} />
            </div>
            <div>
              <label className="block text-sm font-medium text-slate-400">Receipt Counter Label</label>
              <input value={settings.receiptCounterLabel} onChange={(e) => setSettings((prev) => ({ ...prev, receiptCounterLabel: e.target.value }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} placeholder="e.g. Counter 01" />
            </div>
          </div>

          <div className="mt-6 grid gap-4 lg:grid-cols-2">
            <div>
              <label className="block text-sm font-medium text-slate-400">Farhan Sardar Photo</label>
              <input type="file" accept="image/*" onChange={handleDeveloperPhotoChange} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} />
              {settings.developerPhoto && <img src={settings.developerPhoto} alt="Farhan Sardar" className="mt-3 h-20 w-20 rounded-full object-cover border border-slate-700" />}
            </div>
          </div>

          <div className={`mt-6 rounded-[24px] border p-5 ${darkMode ? 'border-slate-800 bg-slate-900 text-slate-100' : 'border-slate-200 bg-slate-50 text-slate-900'}`}>
            <p className="text-base font-semibold">Application Quick Links</p>
            <p className={`text-xs ${darkMode ? 'text-slate-400' : 'text-slate-500'} mt-1`}>Copy links to different portals of the hotel POS system.</p>
            <div className="mt-4 flex flex-wrap gap-3">
              <button onClick={copyAppLink} className={`rounded-full border border-slate-500 bg-slate-500/10 px-4 py-2 text-sm font-semibold transition hover:bg-slate-500/20 ${darkMode ? 'text-slate-100' : 'text-slate-700'}`}>
                Copy App Link
              </button>
              <button onClick={copyHelperLink} className={`rounded-full border border-emerald-500 bg-emerald-500/10 px-4 py-2 text-sm font-semibold transition hover:bg-emerald-500/20 ${darkMode ? 'text-emerald-100' : 'text-emerald-700'}`}>
                Copy Helper Link
              </button>
              <button onClick={copyRiderAppLink} className={`rounded-full border border-emerald-500 bg-emerald-500/10 px-4 py-2 text-sm font-semibold transition hover:bg-emerald-500/20 ${darkMode ? 'text-emerald-100' : 'text-emerald-700'}`}>
                Copy Rider Link
              </button>
            </div>
          </div>

          <div className="mt-6 flex flex-wrap items-center gap-3">
            {[
              { id: 'app', label: 'App Settings' },
              { id: 'receipt', label: 'Receipt Layout' },
              { id: 'fonts', label: 'Receipt Fonts' },
              { id: 'bluetooth', label: 'Bluetooth Printer' }
            ].map((tab) => (
              <button key={tab.id} onClick={() => setReceiptSettingsSubTab(tab.id)} className={`rounded-full px-4 py-2 text-sm font-semibold transition ${receiptSettingsSubTab === tab.id ? 'bg-emerald-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}>
                {tab.label}
              </button>
            ))}
          </div>
        </div>

        {receiptSettingsSubTab === 'app' ? (
          renderRootSettings()
        ) : receiptSettingsSubTab === 'receipt' ? (
          <div className={`rounded-[32px] border p-6 shadow-soft ${darkMode ? 'border-slate-700 bg-slate-950' : 'border-slate-200 bg-white'}`}>
            <div className="grid gap-6 lg:grid-cols-2">
              <div>
                <label className="block text-sm font-medium text-slate-400">Receipt Template</label>
                <select value={settings.receiptTemplate} onChange={(e) => setSettings((prev) => ({ ...prev, receiptTemplate: e.target.value }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`}>
                  <option value="classic">Classic</option>
                  <option value="modern">Modern</option>
                  <option value="compact">Compact</option>
                  <option value="full">Full</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-400">Receipt Language</label>
                <select value={settings.receiptLanguage} onChange={(e) => setSettings((prev) => ({ ...prev, receiptLanguage: e.target.value }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`}>
                  <option value="English">English</option>
                  <option value="Urdu">Urdu</option>
                </select>
              </div>
            </div>

            <div className="mt-6 grid gap-4 lg:grid-cols-2">
              {receiptField('Receipt number', 'receiptShowReceiptNumber')}
              {receiptField('Date & time', 'receiptShowDateTime')}
              {receiptField('Customer name', 'receiptShowCustomerName')}
              {receiptField('Customer phone', 'receiptShowCustomerPhone')}
              {receiptField('Delivery address', 'receiptShowDeliveryAddress')}
              {receiptField('Delivery rider name', 'receiptShowRiderName')}
              {receiptField('Waiter name', 'receiptShowWaiterName')}
              {receiptField('Product item area', 'receiptShowProductArea')}
              {receiptField('Product qty', 'receiptShowProductQuantity')}
              {receiptField('Price per unit', 'receiptShowProductUnitPrice')}
              {receiptField('Subtotal', 'receiptShowSubtotal')}
              {receiptField('Delivery charges', 'receiptShowDeliveryCharge')}
              {receiptField('Service charge', 'receiptShowServiceCharge')}
              {receiptField('Tax', 'receiptShowTax')}
              {receiptField('Discount', 'receiptShowDiscount')}
              {receiptField('Total', 'receiptShowTotal')}
              {receiptField('Customer message', 'receiptShowCustomerMessage')}
              {receiptField('Notes', 'receiptShowNotes')}
            </div>

            <div className="mt-6 rounded-3xl border border-slate-700 bg-slate-950 p-4">
              <h4 className="text-base font-semibold text-slate-100">Token slip settings</h4>
              <div className="mt-4 grid gap-4 lg:grid-cols-2">
                <div>{receiptField('Enable token slip', 'tokenSlipEnabled')}</div>
                <div>
                  <label className="block text-sm font-medium text-slate-400">Token slip prefix</label>
                  <input value={settings.tokenSlipPrefix} onChange={(e) => setSettings((prev) => ({ ...prev, tokenSlipPrefix: e.target.value }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} placeholder="TS" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-400">Next token number</label>
                  <input type="number" min="1" value={settings.tokenSlipNextNumber} onChange={(e) => setSettings((prev) => ({ ...prev, tokenSlipNextNumber: Number(e.target.value) || 1 }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} />
                </div>
                <div className="lg:col-span-2">
                  <button type="button" onClick={async () => {
                      const nextTokenNumber = 1;
                      setSettings((prev) => ({ ...prev, tokenSlipNextNumber: nextTokenNumber }));
                      try {
                        await fetchJson(`${apiBase}/settings`, { method: 'PUT', body: JSON.stringify({ tokenSlipNextNumber }) });
                      } catch (error) {
                        console.warn('Unable to save token slip reset:', error.message);
                      }
                    }} className="rounded-3xl border border-emerald-500 bg-emerald-600 px-4 py-3 text-sm font-semibold text-slate-950 hover:bg-emerald-500 transition">
                    Reset token number to 1
                  </button>
                </div>
              </div>
            </div>
          </div>
        ) : receiptSettingsSubTab === 'bluetooth' ? (
          <div className={`rounded-[32px] border p-6 shadow-soft ${darkMode ? 'border-slate-700 bg-slate-950' : 'border-slate-200 bg-white'}`}>
            <h3 className={`text-lg font-semibold ${darkMode ? 'text-slate-100' : 'text-slate-900'}`}>Bluetooth Printer Settings</h3>
            <p className={`mt-1 text-sm ${darkMode ? 'text-slate-400' : 'text-slate-500'}`}>Configure your Speedx or other Bluetooth thermal printer.</p>

            <div className="mt-6 grid gap-6 lg:grid-cols-2">
              <div>
                <label className="block text-sm font-medium text-slate-400">Paper Width</label>
                <select value={settings.receiptPaperWidth || '58'} onChange={(e) => setSettings((prev) => ({ ...prev, receiptPaperWidth: e.target.value }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`}>
                  <option value="58">58mm (32 chars/line)</option>
                  <option value="80">80mm (42 chars/line)</option>
                </select>
              </div>
              <div className="flex items-end">
                <label className="flex items-center gap-3 rounded-3xl border border-slate-700 bg-slate-950 px-4 py-3 text-sm text-slate-200">
                  <input type="checkbox" checked={settings.btPrintEnabled} onChange={(e) => setSettings((prev) => ({ ...prev, btPrintEnabled: e.target.checked }))} className="h-4 w-4 rounded border-slate-600 bg-slate-900 text-emerald-500" />
                  Auto-enable Bluetooth printing
                </label>
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-400">Font Family</label>
                <select value={settings.btFontFamily || 'Noto Naskh Arabic, Segoe UI, Arial, sans-serif'} onChange={(e) => setSettings((prev) => ({ ...prev, btFontFamily: e.target.value }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`}>
                  <option value="Noto Naskh Arabic, Segoe UI, Arial, sans-serif">Auto (Urdu Support)</option>
                  <option value="Arial">Arial</option>
                  <option value="Helvetica">Helvetica</option>
                  <option value="Tahoma">Tahoma</option>
                  <option value="Courier New">Courier New</option>
                  <option value="Nastaliq">Nastaliq</option>
                  <option value="Nafees">Nafees</option>
                  <option value="Jameel Noori Nastaleeq">Jameel Noori Nastaleeq</option>
                  <option value="Alvi Nastaleeq">Alvi Nastaleeq</option>
                  <option value="Urdu Naskh">Urdu Naskh</option>
                  <option value="Noto Nastaliq Urdu">Noto Nastaliq Urdu</option>
                  <option value="Arial Unicode MS">Arial Unicode MS</option>
                  <option value="Times New Roman">Times New Roman</option>
                  <option value="Georgia">Georgia</option>
                  <option value="Verdana">Verdana</option>
                  <option value="Trebuchet MS">Trebuchet MS</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-400">Text Encoding</label>
                <select value={settings.btEncoding || 'bmp'} onChange={(e) => setSettings((prev) => ({ ...prev, btEncoding: e.target.value }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`}>
                  <option value="bmp">Bitmap/Raster (100% Urdu support)</option>
                </select>
                <p className={`mt-1 text-xs ${darkMode ? 'text-slate-500' : 'text-slate-400'}`}>Bitmap mode renders exact Urdu using browser fonts with larger text for clear receipts.</p>
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-400">Divider Style</label>
                <select value={settings.btDividerStyle || 'dashed'} onChange={(e) => setSettings((prev) => ({ ...prev, btDividerStyle: e.target.value }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`}>
                  <option value="dashed">Dashed (-)</option>
                  <option value="solid">Solid (=)</option>
                  <option value="double">Double (=)</option>
                  <option value="thick">Thick (#)</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-400">Text Alignment</label>
                <select value={settings.btTextAlign || 'left'} onChange={(e) => setSettings((prev) => ({ ...prev, btTextAlign: e.target.value }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`}>
                  <option value="left">Left</option>
                  <option value="center">Center</option>
                  <option value="right">Right</option>
                </select>
              </div>
            </div>

            <div className="mt-6 rounded-3xl border border-slate-700 bg-slate-950 p-4">
              <h4 className="text-base font-semibold text-slate-100">Connection</h4>
              <div className="mt-4 flex flex-wrap gap-3">
                <button type="button" onClick={() => {
                  handleBtConnect();
                }} className="rounded-3xl bg-emerald-600 px-4 py-3 text-sm font-semibold text-slate-950 hover:bg-emerald-500 transition">
                  {btConnected ? 'Disconnect Printer' : 'Connect Bluetooth Printer'}
                </button>
                {btConnected && btInfo && (
                  <div className="flex items-center gap-2 rounded-3xl bg-slate-900 px-4 py-3 text-sm text-slate-300 border border-slate-700">
                    <span className="inline-block h-2 w-2 rounded-full bg-emerald-500" />
                    Connected: {btInfo.name}
                  </div>
                )}
              </div>
            </div>

            <div className="mt-8 border-t border-slate-700 pt-8">
              <h4 className={`text-base font-semibold ${darkMode ? 'text-slate-100' : 'text-slate-900'}`}>Font Sizes</h4>
              <p className={`mt-1 text-sm ${darkMode ? 'text-slate-400' : 'text-slate-500'}`}>Customize font sizes for different receipt elements.</p>
              <div className="mt-6 grid gap-6 lg:grid-cols-3">
                <div>
                  <label className="block text-sm font-medium text-slate-400">Base Font Size (px)</label>
                  <input type="number" min="8" max="72" value={settings.btFontSize || 20} onChange={(e) => setSettings((prev) => ({ ...prev, btFontSize: Number(e.target.value) }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} />
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-400">Product Font Size (px)</label>
                  <input type="number" min="8" max="72" value={settings.btProductFontSize || 20} onChange={(e) => setSettings((prev) => ({ ...prev, btProductFontSize: Number(e.target.value) }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} />
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-400">Total Amount Font Size (px)</label>
                  <input type="number" min="8" max="72" value={settings.btTotalFontSize || 26} onChange={(e) => setSettings((prev) => ({ ...prev, btTotalFontSize: Number(e.target.value) }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} />
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-400">Order Type Font Size (px)</label>
                  <input type="number" min="8" max="72" value={settings.btOrderTypeFontSize || 18} onChange={(e) => setSettings((prev) => ({ ...prev, btOrderTypeFontSize: Number(e.target.value) }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} />
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-400">Service Type Font Size (px)</label>
                  <input type="number" min="8" max="72" value={settings.btServiceTypeFontSize || 16} onChange={(e) => setSettings((prev) => ({ ...prev, btServiceTypeFontSize: Number(e.target.value) }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} />
                </div>
                <div className="flex items-end">
                  <label className="flex items-center gap-3 rounded-3xl border border-slate-700 bg-slate-950 px-4 py-3 text-sm text-slate-200">
                    <input type="checkbox" checked={settings.btLogoEnabled !== false} onChange={(e) => setSettings((prev) => ({ ...prev, btLogoEnabled: e.target.checked }))} className="h-4 w-4 rounded border-slate-600 bg-slate-900 text-emerald-500" />
                    Show Logo on receipt
                  </label>
                </div>
              </div>
            </div>

            <div className="mt-8 border-t border-slate-700 pt-8">
              <h4 className={`text-base font-semibold ${darkMode ? 'text-slate-100' : 'text-slate-900'}`}>Header / Footer / Logo</h4>
              <p className={`mt-1 text-sm ${darkMode ? 'text-slate-400' : 'text-slate-500'}`}>Custom header, footer and logo for Bluetooth receipt.</p>
              <div className="mt-6 grid gap-6 lg:grid-cols-2">
                <div>
                  <label className="block text-sm font-medium text-slate-400">BT Receipt Header</label>
                  <input value={settings.btReceiptHeader ?? settings.receiptHeader ?? 'Usman Hotel'} onChange={(e) => setSettings((prev) => ({ ...prev, btReceiptHeader: e.target.value }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} placeholder="Usman Hotel" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-400">BT Receipt Footer</label>
                  <input value={settings.btReceiptFooter ?? settings.receiptFooter ?? 'Thank you for your business'} onChange={(e) => setSettings((prev) => ({ ...prev, btReceiptFooter: e.target.value }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} placeholder="Thank you for your business" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-400">Receipt Logo</label>
                  <input type="file" accept="image/png,image/jpeg" onChange={handleSettingsLogoChange} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} />
                  {settings.logo && <img src={settings.logo} alt="Logo preview" className="mt-3 h-16 w-full object-contain rounded-2xl border border-slate-700" />}
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-400">Logo Width (px)</label>
                  <input type="number" value={settings.receiptLogoWidth || 80} onChange={(e) => setSettings((prev) => ({ ...prev, receiptLogoWidth: e.target.value }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} />
                </div>
              </div>
              <div className="mt-4 grid gap-4 lg:grid-cols-2">
                <label className="flex items-center gap-3 rounded-3xl border border-slate-700 bg-slate-950 px-4 py-3 text-sm text-slate-200">
                  <input type="checkbox" checked={settings.btTokenOnReceipt !== false} onChange={(e) => setSettings((prev) => ({ ...prev, btTokenOnReceipt: e.target.checked }))} className="h-4 w-4 rounded border-slate-600 bg-slate-900 text-emerald-500" />
                  Show token number on receipt
                </label>
                <label className="flex items-center gap-3 rounded-3xl border border-slate-700 bg-slate-950 px-4 py-3 text-sm text-slate-200">
                  <input type="checkbox" checked={settings.btShowTotalOnToken !== false} onChange={(e) => setSettings((prev) => ({ ...prev, btShowTotalOnToken: e.target.checked }))} className="h-4 w-4 rounded border-slate-600 bg-slate-900 text-emerald-500" />
                  Show total amount on token slip
                </label>
              </div>
            </div>

            <div className="mt-8 border-t border-slate-700 pt-8">
              <h4 className={`text-base font-semibold ${darkMode ? 'text-slate-100' : 'text-slate-900'}`}>Margin Settings</h4>
              <p className={`mt-1 text-sm ${darkMode ? 'text-slate-400' : 'text-slate-500'}`}>Adjust top and bottom margins for the receipt.</p>
              <div className="mt-6 grid gap-6 lg:grid-cols-3">
                <div>
                  <label className="block text-sm font-medium text-slate-400">Top Margin (px) — Min: 0, Max: 50</label>
                  <input type="range" min="0" max="50" value={settings.btMarginTop ?? 10} onChange={(e) => setSettings((prev) => ({ ...prev, btMarginTop: Number(e.target.value) }))} className="mt-2 w-full accent-emerald-500" />
                  <div className="flex justify-between text-xs text-slate-500 mt-1">
                    <span>0</span>
                    <span className="font-semibold text-emerald-400">{settings.btMarginTop ?? 10}px</span>
                    <span>50</span>
                  </div>
                  <input type="number" min="0" max="50" value={settings.btMarginTop ?? 10} onChange={(e) => setSettings((prev) => ({ ...prev, btMarginTop: Number(e.target.value) }))} className="mt-1 w-full rounded-3xl border px-3 py-2 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-400">Bottom Margin (px) — Min: 0, Max: 50</label>
                  <input type="range" min="0" max="50" value={settings.btMarginBottom ?? 10} onChange={(e) => setSettings((prev) => ({ ...prev, btMarginBottom: Number(e.target.value) }))} className="mt-2 w-full accent-emerald-500" />
                  <div className="flex justify-between text-xs text-slate-500 mt-1">
                    <span>0</span>
                    <span className="font-semibold text-emerald-400">{settings.btMarginBottom ?? 10}px</span>
                    <span>50</span>
                  </div>
                  <input type="number" min="0" max="50" value={settings.btMarginBottom ?? 10} onChange={(e) => setSettings((prev) => ({ ...prev, btMarginBottom: Number(e.target.value) }))} className="mt-1 w-full rounded-3xl border px-3 py-2 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}" />
                </div>
                <div className="flex items-end">
                  <label className="flex items-center gap-3 rounded-3xl border border-slate-700 bg-slate-950 px-4 py-3 text-sm text-slate-200">
                    <input type="checkbox" checked={settings.btMarginCustom} onChange={(e) => setSettings((prev) => ({ ...prev, btMarginCustom: e.target.checked }))} className="h-4 w-4 rounded border-slate-600 bg-slate-900 text-emerald-500" />
                    Use custom margins
                  </label>
                </div>
              </div>
            </div>

            <div className="mt-8 border-t border-slate-700 pt-8">
              <h4 className={`text-base font-semibold ${darkMode ? 'text-slate-100' : 'text-slate-900'}`}>Receipt Layout</h4>
              <p className={`mt-1 text-sm ${darkMode ? 'text-slate-400' : 'text-slate-500'}`}>Configure which fields appear on Bluetooth printed receipts.</p>

              <div className="mt-6 grid gap-6 lg:grid-cols-2">
                <div>
                  <label className="block text-sm font-medium text-slate-400">Receipt Template</label>
                  <select value={settings.receiptTemplate} onChange={(e) => setSettings((prev) => ({ ...prev, receiptTemplate: e.target.value }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`}>
                    <option value="classic">Classic</option>
                    <option value="modern">Modern</option>
                    <option value="compact">Compact</option>
                    <option value="full">Full</option>
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-400">Receipt Language</label>
                  <select value={settings.receiptLanguage} onChange={(e) => setSettings((prev) => ({ ...prev, receiptLanguage: e.target.value }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`}>
                    <option value="English">English</option>
                    <option value="Urdu">Urdu</option>
                  </select>
                </div>
              </div>

              <div className="mt-6 grid gap-4 lg:grid-cols-2">
                {receiptField('Receipt number', 'receiptShowReceiptNumber')}
                {receiptField('Date & time', 'receiptShowDateTime')}
                {receiptField('Customer name', 'receiptShowCustomerName')}
                {receiptField('Customer phone', 'receiptShowCustomerPhone')}
                {receiptField('Delivery address', 'receiptShowDeliveryAddress')}
                {receiptField('Delivery rider name', 'receiptShowRiderName')}
                {receiptField('Waiter name', 'receiptShowWaiterName')}
                {receiptField('Product item area', 'receiptShowProductArea')}
                {receiptField('Product qty', 'receiptShowProductQuantity')}
                {receiptField('Price per unit', 'receiptShowProductUnitPrice')}
                {receiptField('Subtotal', 'receiptShowSubtotal')}
                {receiptField('Delivery charges', 'receiptShowDeliveryCharge')}
                {receiptField('Service charge', 'receiptShowServiceCharge')}
                {receiptField('Tax', 'receiptShowTax')}
                {receiptField('Discount', 'receiptShowDiscount')}
                {receiptField('Total', 'receiptShowTotal')}
                {receiptField('Customer message', 'receiptShowCustomerMessage')}
                {receiptField('Notes', 'receiptShowNotes')}
              </div>
            </div>

            <div className="mt-6 rounded-3xl border border-slate-700 bg-slate-950 p-4">
              <h4 className="text-base font-semibold text-slate-100">Token Slip Font Settings</h4>
              <p className={`mt-1 text-sm ${darkMode ? 'text-slate-400' : 'text-slate-500'}`}>Customize font sizes for the token slip so the token printout looks clean.</p>
              <div className="mt-4 grid gap-6 lg:grid-cols-2">
                <div>
                  <label className="block text-sm font-medium text-slate-400">Token Label Font Size (px)</label>
                  <input type="number" min="8" max="48" value={settings.btTokenLabelFontSize || 14} onChange={(e) => setSettings((prev) => ({ ...prev, btTokenLabelFontSize: Number(e.target.value) }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} />
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-400">Token Number Font Size (px)</label>
                  <input type="number" min="20" max="300" value={settings.btTokenFontSize || 44} onChange={(e) => setSettings((prev) => ({ ...prev, btTokenFontSize: Number(e.target.value) }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} />
                </div>
              </div>
            </div>

            <div className="mt-6 rounded-3xl border border-slate-700 bg-slate-950 p-4">
              <h4 className="text-base font-semibold text-slate-100">Token slip settings</h4>
              <div className="mt-4 grid gap-4 lg:grid-cols-2">
                <div>{receiptField('Enable token slip', 'tokenSlipEnabled')}</div>
                <div>
                  <label className="block text-sm font-medium text-slate-400">Token slip prefix</label>
                  <input value={settings.tokenSlipPrefix} onChange={(e) => setSettings((prev) => ({ ...prev, tokenSlipPrefix: e.target.value }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} placeholder="TS" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-400">Next token number</label>
                  <input type="number" min="1" value={settings.tokenSlipNextNumber} onChange={(e) => setSettings((prev) => ({ ...prev, tokenSlipNextNumber: Number(e.target.value) || 1 }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} />
                </div>
                <div className="lg:col-span-2">
                  <button type="button" onClick={async () => {
                      const nextTokenNumber = 1;
                      setSettings((prev) => ({ ...prev, tokenSlipNextNumber: nextTokenNumber }));
                      try {
                        await fetchJson(`${apiBase}/settings`, { method: 'PUT', body: JSON.stringify({ tokenSlipNextNumber }) });
                      } catch (error) {
                        console.warn('Unable to save token slip reset:', error.message);
                      }
                    }} className="rounded-3xl border border-emerald-500 bg-emerald-600 px-4 py-3 text-sm font-semibold text-slate-950 hover:bg-emerald-500 transition">
                    Reset token number to 1
                  </button>
                </div>
              </div>
            </div>

            <div className="mt-6 rounded-3xl border border-slate-700 bg-slate-950 p-4">
              <h4 className="text-base font-semibold text-slate-100">Receipt Preview</h4>
              <p className={`mt-1 text-sm ${darkMode ? 'text-slate-400' : 'text-slate-500'}`}>See how your receipt will look with current settings.</p>
              <div className="mt-4">
                <button type="button" onClick={() => {
                  const previewOrder = {
                    orderType: 'Dine-In',
                    orderNumber: '1234',
                    customerName: 'Guest',
                    tableNumber: '5',
                    waiter: 'Staff',
                    items: [
                      { name: 'Chicken Karahi', quantity: 1, price: 650 },
                      { name: 'Naan', quantity: 3, price: 30 },
                      { name: 'Salad', quantity: 1, price: 120 }
                    ],
                    subtotal: 860,
                    discount: 0,
                    tax: 0,
                    total: 860,
                    date: new Date().toISOString(),
                    status: 'Completed'
                  };
                  const canvas = renderReceiptToCanvas(previewOrder, settings);
                  const previewUrl = canvas.toDataURL();
                  const win = window.open('');
                  win.document.write('<img src="' + previewUrl + '" style="max-width:100%;" />');
                }} className="rounded-3xl bg-emerald-600 px-4 py-3 text-sm font-semibold text-slate-950 hover:bg-emerald-500 transition">
                  Open Receipt Preview
                </button>
              </div>
            </div>
          </div>
        ) : (
          <div className={`rounded-[32px] border p-6 shadow-soft ${darkMode ? 'border-slate-700 bg-slate-950' : 'border-slate-200 bg-white'}`}>
            <div className="grid gap-6 lg:grid-cols-2">
              <div>
                <label className="block text-sm font-medium text-slate-400">Receipt font family</label>
                <select value={settings.receiptFontFamily} onChange={(e) => setSettings((prev) => ({ ...prev, receiptFontFamily: e.target.value }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`}>
                  <option value="Arial">Arial</option>
                  <option value="Helvetica">Helvetica</option>
                  <option value="Tahoma">Tahoma</option>
                  <option value="Courier New">Courier New</option>
                  <option value="Nastaliq">Nastaliq</option>
                  <option value="Nafees">Nafees</option>
                  <option value="Jameel Noori Nastaleeq">Jameel Noori Nastaleeq</option>
                  <option value="Alvi Nastaleeq">Alvi Nastaleeq</option>
                  <option value="Urdu Naskh">Urdu Naskh</option>
                  <option value="Noto Nastaliq Urdu">Noto Nastaliq Urdu</option>
                  <option value="Arial Unicode MS">Arial Unicode MS</option>
                  <option value="Times New Roman">Times New Roman</option>
                  <option value="Georgia">Georgia</option>
                  <option value="Verdana">Verdana</option>
                  <option value="Trebuchet MS">Trebuchet MS</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-400">Receipt font size</label>
                <input type="number" value={settings.receiptFontSize} onChange={(e) => setSettings((prev) => ({ ...prev, receiptFontSize: Number(e.target.value) }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} />
              </div>
            </div>

            <div className="mt-6 grid gap-4 lg:grid-cols-2">
              <div>
                <label className="block text-sm font-medium text-slate-400">Title font size</label>
                <input type="number" value={receiptFontSizes.title} onChange={(e) => setSettings((prev) => ({ ...prev, receiptFontSizes: { ...prev.receiptFontSizes, title: Number(e.target.value) } }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} />
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-400">Section font size</label>
                <input type="number" value={receiptFontSizes.section} onChange={(e) => setSettings((prev) => ({ ...prev, receiptFontSizes: { ...prev.receiptFontSizes, section: Number(e.target.value) } }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} />
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-400">Product font size</label>
                <input type="number" value={receiptFontSizes.product} onChange={(e) => setSettings((prev) => ({ ...prev, receiptFontSizes: { ...prev.receiptFontSizes, product: Number(e.target.value) } }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} />
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-400">Customer/address font size</label>
                <input type="number" value={receiptFontSizes.customer} onChange={(e) => setSettings((prev) => ({ ...prev, receiptFontSizes: { ...prev.receiptFontSizes, customer: Number(e.target.value) } }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} />
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-400">Notes font size</label>
                <input type="number" value={receiptFontSizes.notes} onChange={(e) => setSettings((prev) => ({ ...prev, receiptFontSizes: { ...prev.receiptFontSizes, notes: Number(e.target.value) } }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} />
              </div>
            </div>
          </div>
        )}

        <div className="mt-6 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div className="flex gap-3">
            <button onClick={updateSettings} className="rounded-3xl bg-emerald-600 px-6 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-500">Save Settings</button>
          </div>
          <p className={`text-sm ${darkMode ? 'text-slate-400' : 'text-slate-500'}`}>Use these controls to define receipt layout, font styling and printing behavior.</p>
        </div>
      </div>
    );
  }

  const riderShift = settings?.riderShift || {};
  const riderShifts = settings?.riderShifts || (settings?.riderShift ? [settings.riderShift] : []);
  const shiftRiderOptions = useMemo(() => {
    return (staff || []).filter((member) => {
      const role = (member.role || '').toString().trim();
      const isRegularBiker = role === 'Biker';
      const isLoginEnabled = member.loginEnabled !== false;
      return isRegularBiker && isLoginEnabled;
    }).sort((a, b) => (a.name || a.username).localeCompare(b.name || b.username));
  }, [staff]);

  useEffect(() => {
    setShiftRiderId(settings?.riderShift?.riderId || '');
  }, [settings?.riderShift?.riderId]);

  const formatShiftDuration = (startedAt) => {
    if (!startedAt) return '00h 00m';
    const startedTime = new Date(startedAt).getTime();
    if (Number.isNaN(startedTime)) return '00h 00m';
    const diffMs = Math.max(Date.now() - startedTime, 0);
    const hours = Math.floor(diffMs / 3600000);
    const minutes = Math.floor((diffMs % 3600000) / 60000);
    return `${hours.toString().padStart(2, '0')}h ${minutes.toString().padStart(2, '0')}m`;
  };

  const formatShiftStartedAt = (startedAt) => {
    if (!startedAt) return 'Not started';
    try {
      return new Date(startedAt).toLocaleString();
    } catch {
      return 'Not started';
    }
  };

  async function saveShiftSettings(shiftData) {
    setShiftActionLoading(true);
    try {
      const updated = await fetchJson(`${apiBase}/settings`, {
        method: 'PUT',
        body: JSON.stringify(shiftData)
      });
      setSettings((prev) => ({ ...prev, ...updated }));
      return updated;
    } catch (error) {
      setMessage(error.message || 'Unable to update rider shift settings.');
      return null;
    } finally {
      setShiftActionLoading(false);
    }
  }

  async function handleStartShift() {
    if (!shiftRiderId) {
      setMessage('Select a biker before starting the shift.');
      return;
    }

    const selectedRider = shiftRiderOptions.find((rider) => rider.id === shiftRiderId);
    if (!selectedRider) {
      setMessage('Selected biker is unavailable. Please choose another.');
      return;
    }

    const assignedRiderId = selectedRider.riderId || selectedRider.id;

    // If a different shift is currently active, close it first
    const existingDifferentShiftIdx = riderShifts.findIndex(
      (sh) => sh?.active && sh?.riderId && sh?.riderId !== assignedRiderId
    );
    if (existingDifferentShiftIdx >= 0) {
      try {
        const updatedShifts = riderShifts.filter((_, i) => i !== existingDifferentShiftIdx);
        await saveShiftSettings({ riderShifts: updatedShifts });
      } catch (err) {
        // ignore errors from close; we'll still attempt to start the new shift
      }
    }
    const shiftData = {
      active: true,
      riderId: assignedRiderId,
      riderName: selectedRider.name || selectedRider.username || 'Assigned Rider',
      riderUsername: selectedRider.username || '',
      startedAt: new Date().toISOString(),
      startedBy: user?.name || 'Admin'
    };

    const updated = await saveShiftSettings({ riderShifts: [ ...(settings.riderShifts || []), shiftData ] });
    if (updated) {
      setMessage(`Shift started for ${selectedRider.name || selectedRider.username}.`);
    }
  }

  async function handleCloseShift(shiftIndex) {
    const allShifts = settings?.riderShifts || [];
    if (shiftIndex === undefined || shiftIndex < 0 || shiftIndex >= allShifts.length) {
      setMessage('Invalid shift to close.');
      return;
    }

    setShiftActionLoading(true);
    try {
      // Remove the shift at the given index
      const updatedShifts = allShifts.filter((_, i) => i !== shiftIndex);
      const updated = await saveShiftSettings({ riderShifts: updatedShifts });
      if (updated) {
        setMessage('Shift closed successfully.');
      }
    } catch (error) {
      // error message handled inside saveShiftSettings or fetchJson
    } finally {
      setShiftActionLoading(false);
    }
  }

  async function handleClearSelectedRiderOrders() {
    if (!shiftRiderId) {
      setMessage('Please select a rider first.');
      return;
    }

    const selectedRider = shiftRiderOptions.find((r) => r.id === shiftRiderId);
    if (!selectedRider) {
      setMessage('Selected rider not found.');
      return;
    }

    setShiftActionLoading(true);
    try {
      const searchName = selectedRider.name || selectedRider.username;
      const allOrders = await fetchJson(`${apiBase}/pos/orders`);
      
      const riderOrders = (allOrders || []).filter(
        (o) => (o.deliveryAgent === searchName) && o.status === 'Payment Collected'
      );

      let deletedCount = 0;
      for (const order of riderOrders) {
        try {
          await fetchJson(`${apiBase}/pos/orders/${order.id}`, { method: 'DELETE' });
          deletedCount++;
        } catch (e) {
          console.error('Error deleting order:', order.id, e);
        }
      }

      setMessage(`Cleared ${deletedCount} delivered orders (cash and online) for ${searchName}.`);
    } catch (error) {
      setMessage(`Error clearing orders: ${error.message}`);
    } finally {
      setShiftActionLoading(false);
    }
  }


  function renderRootSettings() {
    return (
      <div className="space-y-6">
        <div className={`rounded-[32px] border p-6 shadow-soft ${darkMode ? 'border-slate-700 bg-slate-950' : 'border-slate-200 bg-white'}`}>
          <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
            <div>
              <p className={`text-sm uppercase tracking-[0.2em] ${darkMode ? 'text-slate-400' : 'text-slate-500'}`}>Settings</p>
              <h3 className={`mt-2 text-2xl font-semibold ${darkMode ? 'text-slate-100' : 'text-slate-900'}`}>Manage Rider App configuration</h3>
            </div>
          </div>
          <div className="mt-6 grid gap-4 lg:grid-cols-2">
            <div>
              <label className="block text-sm font-medium text-slate-400">Rider App Title</label>
              <input value={settings.riderAppTitle} onChange={(e) => setSettings((prev) => ({ ...prev, riderAppTitle: e.target.value }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} placeholder="Rider Portal" />
            </div>
            <div>
              <label className="block text-sm font-medium text-slate-400">Rider App Subtitle</label>
              <input value={settings.riderAppSubtitle} onChange={(e) => setSettings((prev) => ({ ...prev, riderAppSubtitle: e.target.value }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} placeholder="Fast delivery management for riders" />
            </div>
            <div>
              <label className="block text-sm font-medium text-slate-400">Login Prompt</label>
              <input value={settings.riderAppLoginNote} onChange={(e) => setSettings((prev) => ({ ...prev, riderAppLoginNote: e.target.value }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} placeholder="Login to continue" />
            </div>
            <div>
              <label className="block text-sm font-medium text-slate-400">Rider App Logo URL</label>
              <input value={settings.riderAppLogo} onChange={(e) => setSettings((prev) => ({ ...prev, riderAppLogo: e.target.value }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} placeholder="Logo image URL" />
            </div>
            <div>
              <label className="block text-sm font-medium text-slate-400">Rider App Avatar URL</label>
              <input value={settings.riderAppAvatar} onChange={(e) => setSettings((prev) => ({ ...prev, riderAppAvatar: e.target.value }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} placeholder="Avatar image URL" />
            </div>
          </div>
        </div>
      </div>
    );
  }

  function renderCatalogueQrModule() {
    const catalogueUrl = getCatalogueUrl();
    const qrImageSrc = `https://api.qrserver.com/v1/create-qr-code/?size=280x280&data=${encodeURIComponent(catalogueUrl)}`;

    return (
      <div className="space-y-6">
        <div className={`rounded-[32px] border p-6 shadow-soft ${darkMode ? 'border-slate-700 bg-slate-950' : 'border-slate-200 bg-white'}`}>
          <div className="flex flex-wrap items-center gap-3">
            {['qr', 'layout'].map((tab) => (
              <button
                key={tab}
                onClick={() => setCatalogueQrSubTab(tab)}
                className={`rounded-full px-4 py-2 text-sm font-semibold transition ${catalogueQrSubTab === tab ? 'bg-emerald-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}>
                {tab === 'qr' ? 'Usman Hotel Catalogue QR Code' : 'Catalogue Layout Full'}
              </button>
            ))}
          </div>
        </div>

        {catalogueQrSubTab === 'qr' ? (
          <div className="grid gap-6 lg:grid-cols-[0.9fr_0.9fr]">
            <div className={`rounded-[32px] border p-6 shadow-soft ${darkMode ? 'border-slate-700 bg-slate-950' : 'border-slate-200 bg-white'}`}>
              <p className={`text-sm uppercase tracking-[0.2em] ${darkMode ? 'text-slate-400' : 'text-slate-500'}`}>Catalogue QR</p>
              <h3 className={`mt-2 text-2xl font-semibold ${darkMode ? 'text-slate-100' : 'text-slate-900'}`}>Usman Hotel menu QR</h3>
              <p className={`mt-3 text-sm leading-6 ${darkMode ? 'text-slate-400' : 'text-slate-500'}`}>Scan this QR to open the hotel catalogue menu instantly.</p>
              <div className="mt-6 rounded-[32px] border border-slate-800 bg-slate-900 p-6 text-center">
                <img src={qrImageSrc} alt="Catalogue QR Code" className="mx-auto h-56 w-56 rounded-3xl border border-slate-700 bg-white p-2" />
                <div className="mt-4 text-sm text-slate-300">Share this QR code with guests or print it for tabletop display.</div>
              </div>
              <div className="mt-6 rounded-3xl border border-slate-700 bg-slate-950 p-4 text-sm text-slate-300">
                <div className="font-semibold text-slate-100">Host for mobile QR</div>
                <input
                  value={catalogueHost}
                  onChange={(e) => setCatalogueHost(e.target.value)}
                  placeholder="Enter host like 192.168.1.20:5173"
                  className="mt-3 w-full rounded-3xl border border-slate-700 bg-slate-900 px-4 py-3 text-sm text-slate-100 outline-none"
                />
                <div className="mt-3 text-xs text-slate-400">Use your PC network IP or domain so phone scans open correctly.</div>
              </div>
              <div className="mt-6 rounded-3xl border border-slate-700 bg-slate-950 p-4 text-sm text-slate-300">
                <div className="font-semibold text-slate-100">QR path</div>
                <input
                  value={cataloguePath}
                  onChange={(e) => setCataloguePath(e.target.value)}
                  placeholder="catalogue or menu or qr"
                  className="mt-3 w-full rounded-3xl border border-slate-700 bg-slate-900 px-4 py-3 text-sm text-slate-100 outline-none"
                />
                <div className="mt-3 text-xs text-slate-400">Use a short alias like catalogue, menu, or qr for the scanned URL.</div>
              </div>
              <div className="mt-6 rounded-3xl border border-slate-700 bg-slate-950 p-4 text-sm text-slate-300">
                <div className="font-semibold text-slate-100">Menu URL</div>
                <div className="mt-3 flex flex-col gap-3 sm:flex-row">
                  <input readOnly value={catalogueUrl} className="min-w-0 flex-1 rounded-3xl border border-slate-700 bg-slate-900 px-4 py-3 text-sm text-slate-100 outline-none" />
                  <button onClick={() => navigator.clipboard.writeText(catalogueUrl)} className="rounded-3xl bg-emerald-600 px-4 py-3 text-sm font-semibold text-slate-950 hover:bg-emerald-500">Copy link</button>
                </div>
              </div>
            </div>
            <div className={`rounded-[32px] border p-6 shadow-soft ${darkMode ? 'border-slate-700 bg-slate-950' : 'border-slate-200 bg-white'}`}>
              <p className={`text-sm uppercase tracking-[0.2em] ${darkMode ? 'text-slate-400' : 'text-slate-500'}`}>Quick actions</p>
              <div className="mt-5 grid gap-4">
                <div className="rounded-3xl border border-slate-200/10 bg-slate-900 p-4">
                  <div className="text-sm text-slate-400">Use the button below to copy your current QR menu URL.</div>
                </div>
                <div className="rounded-3xl border border-slate-200/10 bg-slate-900 p-4">
                  <div className="text-sm text-slate-400">Preview the layout or update the QR catalogue settings in the layout tab.</div>
                </div>
              </div>
            </div>
          </div>
        ) : (
          <div className="grid gap-6 lg:grid-cols-[0.9fr_0.9fr]">
            <div className={`rounded-[32px] border p-6 shadow-soft ${darkMode ? 'border-slate-700 bg-slate-950' : 'border-slate-200 bg-white'}`}>
              <p className={`text-sm uppercase tracking-[0.2em] ${darkMode ? 'text-slate-400' : 'text-slate-500'}`}>Catalogue layout full</p>
              <h3 className={`mt-2 text-2xl font-semibold ${darkMode ? 'text-slate-100' : 'text-slate-900'}`}>Catalogue QR page settings</h3>
              <div className="mt-6 grid gap-4">
                <div>
                  <label className="block text-sm text-slate-400">Page title</label>
                  <input value={catalogueLayout.pageTitle} onChange={(e) => setCatalogueLayout((prev) => ({ ...prev, pageTitle: e.target.value }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} />
                </div>
                <div>
                  <label className="block text-sm text-slate-400">Page description</label>
                  <textarea value={catalogueLayout.pageDescription} onChange={(e) => setCatalogueLayout((prev) => ({ ...prev, pageDescription: e.target.value }))} rows={3} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} />
                </div>
                <div className="grid gap-3 sm:grid-cols-2">
                  <div>
                    <label className="block text-sm text-slate-400">Theme</label>
                    <select value={catalogueLayout.theme} onChange={(e) => setCatalogueLayout((prev) => ({ ...prev, theme: e.target.value }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`}>
                      <option value="dark">Dark</option>
                      <option value="light">Light</option>
                    </select>
                  </div>
                  <div>
                    <label className="block text-sm text-slate-400">Columns</label>
                    <select value={catalogueLayout.columns} onChange={(e) => setCatalogueLayout((prev) => ({ ...prev, columns: Number(e.target.value) }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`}>
                      {[2, 3, 4].map((count) => <option key={count} value={count}>{count}</option>)}
                    </select>
                  </div>
                </div>
                <div className="grid gap-3 sm:grid-cols-2">
                  <label className="flex items-center gap-3 rounded-3xl border border-slate-700 bg-slate-950 px-4 py-3">
                    <input type="checkbox" checked={catalogueLayout.showPrices} onChange={(e) => setCatalogueLayout((prev) => ({ ...prev, showPrices: e.target.checked }))} className="h-4 w-4 rounded border-slate-600 bg-slate-900 text-emerald-500" />
                    <span className="text-sm text-slate-200">Show prices</span>
                  </label>
                  <label className="flex items-center gap-3 rounded-3xl border border-slate-700 bg-slate-950 px-4 py-3">
                    <input type="checkbox" checked={catalogueLayout.showCategories} onChange={(e) => setCatalogueLayout((prev) => ({ ...prev, showCategories: e.target.checked }))} className="h-4 w-4 rounded border-slate-600 bg-slate-900 text-emerald-500" />
                    <span className="text-sm text-slate-200">Show categories</span>
                  </label>
                </div>
                <div>
                  <label className="block text-sm text-slate-400">Accent color</label>
                  <input type="color" value={catalogueLayout.accentColor} onChange={(e) => setCatalogueLayout((prev) => ({ ...prev, accentColor: e.target.value }))} className="mt-2 h-12 w-full rounded-3xl border border-slate-700 bg-slate-900 px-3 py-2 text-sm outline-none" />
                </div>
                <div>
                  <label className="block text-sm text-slate-400">Layout style</label>
                  <select value={catalogueLayout.layoutStyle} onChange={(e) => setCatalogueLayout((prev) => ({ ...prev, layoutStyle: e.target.value }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`}>
                    <option value="grid">Grid</option>
                    <option value="list">List</option>
                  </select>
                </div>
                <div className="rounded-3xl border border-slate-700 bg-slate-950 p-4">
                  <div className="text-sm uppercase tracking-[0.2em] text-slate-400">Assign categories</div>
                  <div className="mt-4 flex flex-wrap gap-3">
                    {posCategories.map((category) => {
                      const assigned = catalogueAssignedCategories.includes(category.name);
                      return (
                        <button
                          key={category.id || category.name}
                          onClick={() => toggleAssignedCategory(category.name)}
                          className={`rounded-full px-4 py-2 text-sm font-semibold transition ${assigned ? 'bg-emerald-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}>
                          {category.name}
                        </button>
                      );
                    })}
                  </div>
                  <div className="mt-3 text-xs text-slate-400">Click a category to add/remove it from the catalogue, then open it to choose products.</div>
                </div>
                {catalogueAssignCategory ? (
                  <div className="rounded-3xl border border-slate-700 bg-slate-950 p-4">
                    <div className="flex items-center justify-between gap-3">
                      <div>
                        <div className="text-sm uppercase tracking-[0.2em] text-slate-400">Assign products to {catalogueAssignCategory}</div>
                        <div className="mt-2 text-lg font-semibold text-white">{catalogueAssignCategory}</div>
                      </div>
                      <button onClick={() => setCatalogueAssignCategory('')} className="rounded-full border border-slate-600 px-3 py-2 text-sm text-slate-200 hover:bg-slate-800">Close</button>
                    </div>
                    <div className="mt-4">
                      <input
                        value={catalogueAssignSearch}
                        onChange={(e) => setCatalogueAssignSearch(e.target.value)}
                        placeholder="Search products in category"
                        className="w-full rounded-3xl border border-slate-700 bg-slate-900 px-4 py-3 text-sm text-slate-100 outline-none"
                      />
                    </div>
                    <div className="mt-4 grid gap-3 max-h-[320px] overflow-y-auto">
                      {posProducts.filter((product) => product.category === catalogueAssignCategory && (!catalogueAssignSearch || normalizeText(product.name).includes(normalizeText(catalogueAssignSearch)) || normalizeText(product.description).includes(normalizeText(catalogueAssignSearch)))).map((product) => {
                        const checked = (catalogueAssignedProducts[catalogueAssignCategory] || []).includes(product.id);
                        return (
                          <label key={product.id} className="flex items-center gap-3 rounded-3xl border border-slate-700 bg-slate-900 px-4 py-3">
                            <input type="checkbox" checked={checked} onChange={() => toggleAssignedProduct(catalogueAssignCategory, product.id)} className="h-5 w-5 rounded border-slate-600 bg-slate-900 text-emerald-500" />
                            <div className="min-w-0 flex-1 overflow-hidden">
                              <div className="truncate text-sm font-semibold text-white">{product.name}</div>
                              <div className="truncate text-xs text-slate-500">{product.price} PKR</div>
                            </div>
                          </label>
                        );
                      })}
                      {!posProducts.some((product) => product.category === catalogueAssignCategory) && (
                        <div className="rounded-3xl border border-dashed border-slate-700 bg-slate-950 p-4 text-sm text-slate-400">No products found in this category.</div>
                      )}
                    </div>
                  </div>
                ) : null}
                <button onClick={saveCatalogueLayoutSettings} className="rounded-3xl bg-emerald-600 px-4 py-3 text-sm font-semibold text-slate-950 hover:bg-emerald-500 transition">Save layout settings</button>
              </div>
            </div>
            <div className={`rounded-[32px] border p-6 shadow-soft ${darkMode ? 'border-slate-700 bg-slate-950' : 'border-slate-200 bg-white'}`}>
              <p className={`text-sm uppercase tracking-[0.2em] ${darkMode ? 'text-slate-400' : 'text-slate-500'}`}>Live layout preview</p>
              <div className="mt-5 rounded-[32px] border border-slate-200/10 bg-slate-900 p-5 text-slate-300">
                <div className="flex items-center justify-between gap-3">
                  <div>
                    <div className="text-xl font-semibold text-white">{catalogueLayout.pageTitle}</div>
                    <div className="text-sm text-slate-400">{catalogueLayout.pageDescription}</div>
                  </div>
                  <span className="rounded-full px-3 py-1 text-xs font-semibold text-white" style={{ backgroundColor: catalogueLayout.accentColor }}>{catalogueLayout.theme}</span>
                </div>
                <div className="mt-6 grid gap-3" style={{ gridTemplateColumns: catalogueLayout.layoutStyle === 'grid' ? `repeat(${catalogueLayout.columns}, minmax(0, 1fr))` : '1fr' }}>
                  {getCataloguePreviewProducts().length > 0 ? getCataloguePreviewProducts().map((product) => (
                    <div key={product.id} className="rounded-3xl border border-slate-700 bg-slate-950 p-4">
                      <div className="mb-2 text-lg font-semibold text-white">{product.name}</div>
                      {catalogueLayout.showCategories && <div className="text-xs uppercase tracking-[0.2em] text-slate-500">{product.category}</div>}
                      <div className="mt-2 text-sm text-slate-300">{product.description || 'A quick menu item description for guests.'}</div>
                      {catalogueLayout.showPrices && <div className="mt-4 text-sm font-semibold text-white">{product.price} PKR</div>}
                    </div>
                  )) : (
                    <div className="col-span-full rounded-3xl border border-slate-700 bg-slate-950 p-4 text-sm text-slate-400">No catalogue products assigned yet. Assign categories and products above to preview them here.</div>
                  )}
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    );
  }

  function renderCustomers() {
    const handleEditCustomer = (customer) => {
      setEditingCustomer(customer);
      setCustomerForm({ name: customer.name, phone: customer.phone, address: customer.address });
    };

    const handleSaveCustomer = async () => {
      if (!customerForm.address) {
        setMessage('Address is required.');
        return;
      }
      if (!editingCustomer) {
        setMessage('No customer selected for update.');
        return;
      }
      setLoading(true);
      setMessage('');
      try {
        const updated = await persistCustomer({ ...editingCustomer, ...customerForm });
        if (updated) {
          setCustomers((prev) => prev.map((c) => c.id === updated.id ? updated : c));
          setMessage('Customer updated successfully.');
        }
      } catch (error) {
        setMessage(error.message);
      } finally {
        setLoading(false);
      }
      setEditingCustomer(null);
      setCustomerForm({ name: '', phone: '', address: '', serviceType: '' });
    };

    const handleDeleteCustomer = async (customerId) => {
      if (!confirm('Are you sure you want to delete this customer?')) return;
      setLoading(true);
      setMessage('');
      try {
        const success = await deleteCustomerFromServer(customerId);
        if (success) {
          setCustomers((prev) => prev.filter((c) => c.id !== customerId));
          setMessage('Customer deleted.');
        }
      } catch (error) {
        setMessage(error.message);
      } finally {
        setLoading(false);
      }
    };

    const handleToggleSelect = (customerId) => {
      setSelectedCustomerIds((prev) => {
        const next = new Set(prev);
        if (next.has(customerId)) next.delete(customerId);
        else next.add(customerId);
        return next;
      });
    };

    const handleToggleSelectAll = () => {
      if (selectedCustomerIds.size === visibleCustomers.length) {
        setSelectedCustomerIds(new Set());
      } else {
        setSelectedCustomerIds(new Set(visibleCustomers.map((c) => c.id)));
      }
    };

    const handleDeleteSelected = async () => {
      if (!selectedCustomerIds.size) return;
      if (!confirm(`Delete ${selectedCustomerIds.size} selected customers?`)) return;
      setLoading(true);
      try {
        const ids = Array.from(selectedCustomerIds);
        await Promise.all(ids.map((id) => deleteCustomerFromServer(id).catch(() => null)));
        setCustomers((prev) => prev.filter((c) => !selectedCustomerIds.has(c.id)));
        setSelectedCustomerIds(new Set());
        setMessage('Selected customers deleted.');
      } catch (err) {
        console.warn(err);
      } finally {
        setLoading(false);
      }
    };

    const handleNewCustomerSave = async () => {
      if (!customerForm.address || !customerForm.serviceType) {
        setMessage('Address and service type are required.');
        return;
      }
      setLoading(true);
      try {
        const toCreate = { name: customerForm.name || '', phone: customerForm.phone || '', address: customerForm.address, serviceType: customerForm.serviceType };
        const created = await persistCustomer(toCreate);
        if (created) {
          // mark as just added for highlighting
          created._justAdded = true;
          setCustomers((prev) => [created, ...prev]);
          setMessage('Customer added.');
          setShowNewCustomerModal(false);
          setCustomerForm({ name: '', phone: '', address: '', serviceType: '' });
        }
      } catch (err) {
        console.warn(err);
      } finally {
        setLoading(false);
      }
    };

    const isCustomerNew = (c) => {
      if (!c) return false;
      if (c._justAdded) return true;
      if (!c.createdAt) return false;
      try {
        const created = new Date(c.createdAt).getTime();
        return Date.now() - created <= 24 * 60 * 60 * 1000;
      } catch (e) {
        return false;
      }
    };

    let filteredCustomers = customers.filter((c) =>
      (c.address && c.address.toLowerCase().includes(posSearch.toLowerCase())) ||
      (c.name && c.name.toLowerCase().includes(posSearch.toLowerCase())) ||
      (c.phone && c.phone.toLowerCase().includes(posSearch.toLowerCase()))
    );

    if (serviceTypeFilter && serviceTypeFilter !== 'all') {
      filteredCustomers = filteredCustomers.filter((c) => (c.serviceType || 'Unknown') === serviceTypeFilter);
    }

    // Sort: newly added (within 24h) first, then by createdAt desc
    filteredCustomers.sort((a, b) => {
      const aNew = isCustomerNew(a) ? 1 : 0;
      const bNew = isCustomerNew(b) ? 1 : 0;
      if (aNew !== bNew) return bNew - aNew; // new ones first
      const at = a.createdAt ? new Date(a.createdAt).getTime() : 0;
      const bt = b.createdAt ? new Date(b.createdAt).getTime() : 0;
      return bt - at;
    });

    const totalPages = Math.max(1, Math.ceil(filteredCustomers.length / pageSize));
    const visibleCustomers = filteredCustomers.slice(pageIndex * pageSize, (pageIndex + 1) * pageSize);
    const serviceTypeCounts = customers.reduce((acc, c) => { const k = c.serviceType || 'Unknown'; acc[k] = (acc[k] || 0) + 1; return acc; }, {});

    return (
      <div className="space-y-6">
        <div className={`rounded-[32px] border p-6 shadow-soft ${darkMode ? 'border-slate-700 bg-slate-950' : 'border-slate-200 bg-white'}`}>
          <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
            <div>
              <p className={`text-sm uppercase tracking-[0.2em] ${darkMode ? 'text-slate-400' : 'text-slate-500'}`}>Customer management</p>
              <h3 className={`mt-2 text-2xl font-semibold ${darkMode ? 'text-slate-100' : 'text-slate-900'}`}>Delivery customers</h3>
            </div>
            <div className="relative w-full sm:w-64">
              <input
                type="text"
                placeholder="Search by address, name, or phone..."
                value={posSearch}
                onChange={(e) => setPosSearch(e.target.value)}
                className="w-full rounded-full border border-slate-700 bg-slate-900 px-4 py-2 text-sm text-slate-100 placeholder-slate-500 outline-none focus:border-emerald-500"
              />
              <svg className="absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
              </svg>
            </div>
            <div className="flex items-center gap-3 mt-3">
              <div className="text-sm text-slate-300">Total: <span className="font-semibold text-white">{customers.length}</span></div>
              <div className="text-sm text-slate-300">Service types:</div>
              <div className="flex gap-2">
                <select value={serviceTypeFilter} onChange={(e) => { setServiceTypeFilter(e.target.value); setPageIndex(0); }} className="rounded-full border border-slate-700 bg-slate-900 px-3 py-1 text-sm text-slate-100">
                  <option value="all">All services</option>
                  {[...new Set(customers.map(c => (c.serviceType || 'Unknown')))].map((st) => (
                    <option key={st} value={st}>{st}</option>
                  ))}
                </select>
                <div className="flex items-center gap-2">
                  {Object.keys(serviceTypeCounts || {}).map((k) => (
                    <div key={k} className="rounded-full bg-slate-800 px-3 py-1 text-xs text-slate-200">{k}: <span className="font-semibold text-white">{serviceTypeCounts[k]}</span></div>
                  ))}
                </div>
              </div>
              <div className="ml-auto flex items-center gap-2">
                <button onClick={() => setShowNewCustomerModal(true)} className="rounded-full bg-emerald-600 px-3 py-1 text-sm font-semibold text-white">+ Add</button>
                <select value={pageSize} onChange={(e) => { setPageSize(Number(e.target.value)); setPageIndex(0); }} className="rounded-full border border-slate-700 bg-slate-900 px-3 py-1 text-sm text-slate-100">
                  <option value={20}>20</option>
                  <option value={50}>50</option>
                  <option value={500}>500</option>
                </select>
              </div>
            </div>
          </div>
        </div>

        <div className="overflow-x-auto rounded-3xl border border-slate-800 bg-slate-950 p-4">
          <table className="w-full min-w-[720px] divide-y divide-slate-700 text-left text-sm text-slate-300">
            <thead className="bg-slate-900 text-slate-200">
              <tr>
                <th className="px-3 py-3 w-12"><input type="checkbox" checked={selectedCustomerIds.size === visibleCustomers.length && visibleCustomers.length > 0} onChange={handleToggleSelectAll} /></th>
                <th className="px-4 py-3">Address</th>
                <th className="px-4 py-3">Phone</th>
                <th className="px-4 py-3">Service</th>
                <th className="px-4 py-3">Order #</th>
                <th className="px-4 py-3">Created</th>
                <th className="px-4 py-3">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800 bg-slate-950">
              {visibleCustomers.map((customer) => {
                const isNew = (customer._justAdded || (customer.createdAt && (Date.now() - new Date(customer.createdAt).getTime() <= 24 * 60 * 60 * 1000)));
                return (
                <tr key={customer.id} className={`${isNew ? 'bg-emerald-950/20' : ''}`}>
                  <td className="px-3 py-3"><input type="checkbox" checked={selectedCustomerIds.has(customer.id)} onChange={() => handleToggleSelect(customer.id)} /></td>
                  <td className="px-4 py-3 font-semibold text-white">{customer.address}</td>
                  <td className="px-4 py-3">{customer.phone || '-'}</td>
                  <td className="px-4 py-3">{customer.serviceType || '-'}</td>
                  <td className="px-4 py-3 text-slate-300">{customer.lastOrderNumber || '-'}</td>
                  <td className="px-4 py-3 text-slate-300">{customer.createdAt ? new Date(customer.createdAt).toLocaleString('en-US', { weekday: 'short', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hour12: true }) : '-'}</td>
                  <td className="px-4 py-3">
                    <div className="flex gap-2 items-center">
                      <button onClick={() => handleEditCustomer(customer)} className="rounded-full border border-slate-700 bg-slate-800 p-2 text-xs font-semibold text-white hover:bg-slate-700">Edit</button>
                      <button onClick={() => handleDeleteCustomer(customer.id)} title="Delete" className="rounded-full border border-slate-700 bg-rose-600 p-2 text-xs font-semibold text-white hover:bg-rose-500">
                        <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6M9 7V4a1 1 0 011-1h4a1 1 0 011 1v3" />
                        </svg>
                      </button>
                    </div>
                  </td>
                </tr>
                );
              })}
              {!filteredCustomers.length && (
                <tr>
                  <td colSpan={5} className="px-4 py-6 text-center text-sm text-slate-500">No customers found.</td>
                </tr>
              )}
            </tbody>
          </table>
          <div className="mt-3 flex items-center justify-between">
            <div className="flex items-center gap-2">
              <button onClick={handleDeleteSelected} className="rounded-full bg-rose-600 px-3 py-1 text-sm font-semibold text-white disabled:opacity-50" disabled={!selectedCustomerIds.size}>Delete selected</button>
              <div className="text-sm text-slate-400">Showing {pageIndex * pageSize + 1} - {Math.min((pageIndex + 1) * pageSize, filteredCustomers.length)} of {filteredCustomers.length}</div>
            </div>
            <div className="flex items-center gap-2">
              <button onClick={() => setPageIndex((p) => Math.max(0, p - 1))} className="rounded-full border px-3 py-1">Prev</button>
              <div className="text-sm text-slate-300">Page {pageIndex + 1} / {totalPages}</div>
              <button onClick={() => setPageIndex((p) => Math.min(totalPages - 1, p + 1))} className="rounded-full border px-3 py-1">Next</button>
            </div>
          </div>
        </div>

        {editingCustomer && (
          <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 px-4 py-6">
            <div className="w-full max-w-md rounded-[32px] border border-slate-700 bg-slate-950 p-6 shadow-[0_35px_120px_-30px_rgba(0,0,0,0.8)]">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-xs uppercase tracking-[0.2em] text-slate-500">Edit customer</p>
                  <h3 className="mt-2 text-xl font-semibold text-white">Update details</h3>
                </div>
                <button onClick={() => setEditingCustomer(null)} className="rounded-full border border-slate-700 bg-slate-900 px-3 py-2 text-sm text-slate-200 hover:bg-slate-800">✕</button>
              </div>
              <div className="mt-6 space-y-4">
                <div className="grid gap-3">
                  <label className="text-sm text-slate-400">Address <span className="text-rose-500">*</span></label>
                  <textarea value={customerForm.address} onChange={(e) => setCustomerForm((prev) => ({ ...prev, address: e.target.value }))} className="w-full rounded-3xl border border-slate-800 bg-slate-900 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" rows={3} />
                </div>
                <div className="grid gap-3">
                  <label className="text-sm text-slate-400">Name <span className="text-slate-500\">(optional)</span></label>
                  <input value={customerForm.name} onChange={(e) => setCustomerForm((prev) => ({ ...prev, name: e.target.value }))} className="w-full rounded-3xl border border-slate-800 bg-slate-900 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" />
                </div>
                <div className="grid gap-3">
                  <label className="text-sm text-slate-400">Phone <span className="text-slate-500\">(optional)</span></label>
                  <input value={customerForm.phone} onChange={(e) => setCustomerForm((prev) => ({ ...prev, phone: e.target.value }))} className="w-full rounded-3xl border border-slate-800 bg-slate-900 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" />
                </div>
                <div className="flex justify-end gap-3 pt-2">
                  <button onClick={() => setEditingCustomer(null)} className="rounded-3xl border border-slate-700 px-4 py-3 text-sm font-semibold text-slate-200 hover:bg-slate-800">Cancel</button>
                  <button onClick={handleSaveCustomer} className="rounded-3xl bg-emerald-600 px-4 py-3 text-sm font-semibold text-slate-950 hover:bg-emerald-500">Save</button>
                </div>
              </div>
            </div>
          </div>
        )}
        {showNewCustomerModal && (
          <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 px-4 py-6">
            <div className="w-full max-w-md rounded-[32px] border border-slate-700 bg-slate-950 p-6 shadow-[0_35px_120px_-30px_rgba(0,0,0,0.8)]">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-xs uppercase tracking-[0.2em] text-slate-500">New customer</p>
                  <h3 className="mt-2 text-xl font-semibold text-white">Add customer</h3>
                </div>
                <button onClick={() => setShowNewCustomerModal(false)} className="rounded-full border border-slate-700 bg-slate-900 px-3 py-2 text-sm text-slate-200 hover:bg-slate-800">✕</button>
              </div>
              <div className="mt-6 space-y-4">
                <div className="grid gap-3">
                  <label className="text-sm text-slate-400">Address <span className="text-rose-500">*</span></label>
                  <textarea value={customerForm.address} onChange={(e) => setCustomerForm((prev) => ({ ...prev, address: e.target.value }))} className="w-full rounded-3xl border border-slate-800 bg-slate-900 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" rows={3} />
                </div>
                <div className="grid gap-3">
                  <label className="text-sm text-slate-400">Service Type <span className="text-rose-500">*</span></label>
                  <input value={customerForm.serviceType} onChange={(e) => setCustomerForm((prev) => ({ ...prev, serviceType: e.target.value }))} className="w-full rounded-3xl border border-slate-800 bg-slate-900 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" placeholder="e.g., Delivery, Takeaway" />
                </div>
                <div className="grid gap-3">
                  <label className="text-sm text-slate-400">Phone <span className="text-slate-500">(optional)</span></label>
                  <input value={customerForm.phone} onChange={(e) => setCustomerForm((prev) => ({ ...prev, phone: e.target.value }))} className="w-full rounded-3xl border border-slate-800 bg-slate-900 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" />
                </div>
                <div className="flex justify-end gap-3 pt-2">
                  <button onClick={() => setShowNewCustomerModal(false)} className="rounded-3xl border border-slate-700 px-4 py-3 text-sm font-semibold text-slate-200 hover:bg-slate-800">Cancel</button>
                  <button onClick={handleNewCustomerSave} className="rounded-3xl bg-emerald-600 px-4 py-3 text-sm font-semibold text-slate-950 hover:bg-emerald-500">Save</button>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    );
  }

  function getCatalogueUrl() {
    const host = catalogueHost?.trim() || window.location.host;
    const normalizedHost = host.startsWith('http') ? host : `${window.location.protocol}//${host}`;
    const cleanedPath = cataloguePath.replace(/^\/+|\/+$/g, '') || 'catalogue';
    return `${normalizedHost.replace(/\/$/, '')}/${cleanedPath}`;
  }

  function getAssignedCatalogueProductIds() {
    return new Set(Object.values(catalogueAssignedProducts).flat());
  }

  function getCatalogueFilteredProducts() {
    const search = normalizeText(catalogueSearch);
    const assignedProductIds = getAssignedCatalogueProductIds();
    const hasAssignments = assignedProductIds.size > 0;

    return posProducts.filter((product) => {
      const matchesCategory = catalogueCategory === 'All' || product.category === catalogueCategory;
      const matchesSearch = !search ||
        normalizeText(product.name).includes(search) ||
        normalizeText(product.category).includes(search) ||
        normalizeText(product.description).includes(search) ||
        normalizeText(product.code).includes(search) ||
        normalizeText(product.sku).includes(search);
      const validCategory = !catalogueAssignedCategories.length || catalogueAssignedCategories.includes(product.category);
      const validAssignment = !hasAssignments || assignedProductIds.has(product.id);
      return matchesCategory && matchesSearch && validCategory && validAssignment;
    });
  }

  function toggleAssignedCategory(categoryName) {
    setCatalogueAssignedCategories((prev) => {
      if (prev.includes(categoryName)) {
        const next = prev.filter((name) => name !== categoryName);
        setCatalogueAssignedProducts((assignments) => {
          const { [categoryName]: _, ...rest } = assignments;
          return rest;
        });
        if (catalogueAssignCategory === categoryName) {
          setCatalogueAssignCategory('');
        }
        return next;
      }
      setCatalogueAssignCategory(categoryName);
      return [...prev, categoryName];
    });
  }

  function toggleAssignedProduct(categoryName, productId) {
    setCatalogueAssignedProducts((prev) => {
      const current = Array.isArray(prev[categoryName]) ? prev[categoryName] : [];
      const next = current.includes(productId)
        ? current.filter((id) => id !== productId)
        : [...current, productId];
      return { ...prev, [categoryName]: next };
    });
  }

  function openAssignCategory(categoryName) {
    setCatalogueAssignCategory(categoryName);
    setCatalogueAssignSearch('');
  }

  function getAssignedCategoriesForDropdown() {
    if (!catalogueAssignedCategories.length) return [{ name: 'All' }, ...posCategories];
    return [{ name: 'All' }, ...posCategories.filter((category) => catalogueAssignedCategories.includes(category.name))];
  }

  function getCataloguePreviewProducts() {
    const assignedProductIds = getAssignedCatalogueProductIds();
    const hasAssignments = assignedProductIds.size > 0 || catalogueAssignedCategories.length > 0;
    let products = posProducts;
    if (assignedProductIds.size > 0) {
      products = products.filter((product) => assignedProductIds.has(product.id));
    }
    if (catalogueAssignedCategories.length > 0) {
      products = products.filter((product) => catalogueAssignedCategories.includes(product.category));
    }
    return products.slice(0, Math.max(1, catalogueLayout.columns));
  }

  function addToCatalogueCart(product) {
    setCatalogueCart((prev) => {
      const existing = prev.find((item) => item.productId === product.id);
      if (existing) {
        return prev.map((item) => item.productId === product.id ? { ...item, quantity: item.quantity + 1 } : item);
      }
      return [...prev, { productId: product.id, name: product.name, price: Number(product.price) || 0, quantity: 1 }];
    });
  }

  function updateCatalogueCartItem(productId, change) {
    setCatalogueCart((prev) => prev
      .map((item) => item.productId === productId ? { ...item, quantity: Math.max(1, item.quantity + change) } : item)
      .filter((item) => item.quantity > 0)
    );
  }

  function getCatalogueCartSummary() {
    const subtotal = catalogueCart.reduce((sum, item) => sum + item.price * item.quantity, 0);
    return { subtotal, total: subtotal };
  }

  async function saveOnlineCatalogueOrder() {
    if (!catalogueCart.length) {
      setCatalogueMessage('Please add at least one item to cart.');
      return;
    }
    if (!catalogueCustomer.name || !catalogueCustomer.phone) {
      setCatalogueMessage('Customer name and phone are required to place an online order.');
      return;
    }

    const orderPayload = {
      items: catalogueCart,
      orderType: 'Online',
      customerName: catalogueCustomer.name,
      phone: catalogueCustomer.phone,
      address: catalogueCustomer.address,
      notes: catalogueOrderNote,
      status: 'Pending',
      paymentMethod: 'Online'
    };

    setLoading(true);
    setCatalogueMessage('');
    try {
      const order = await fetchJson(`${apiBase}/pos/orders`, {
        method: 'POST',
        body: JSON.stringify(orderPayload)
      });
      setCatalogueMessage(`Thank you! Order ${order.orderNumber || order.id} submitted successfully.`);
      setCatalogueCart([]);
      setCatalogueCustomer({ name: '', phone: '', address: '' });
      setCatalogueOrderNote('');
      await loadPosData();
    } catch (error) {
      setCatalogueMessage(error.message);
    } finally {
      setLoading(false);
    }
  }

  function renderCustomerCataloguePage() {
    const filteredProducts = getCatalogueFilteredProducts();
    const summary = getCatalogueCartSummary();
    const catalogueUrl = getCatalogueUrl();
    return (
      <div className={`min-h-screen ${darkMode ? 'bg-slate-950 text-slate-100' : 'bg-slate-50 text-slate-900'}`}>
        <div className="mx-auto max-w-6xl px-4 py-6 sm:px-6 lg:px-8">
          <div className="space-y-6">
            <div className={`rounded-[32px] border p-6 shadow-soft ${darkMode ? 'border-slate-700 bg-slate-950' : 'border-slate-200 bg-white'}`}>
              <div className="flex flex-wrap items-center justify-between gap-4">
                <div>
                  <p className={`text-xs uppercase tracking-[0.2em] ${darkMode ? 'text-slate-400' : 'text-slate-500'}`}>Usman Hotel Menu</p>
                  <h1 className={`mt-2 text-3xl font-semibold ${darkMode ? 'text-slate-100' : 'text-slate-900'}`}>{catalogueLayout.pageTitle}</h1>
                  <p className={`mt-3 max-w-2xl text-sm leading-6 ${darkMode ? 'text-slate-400' : 'text-slate-600'}`}>{catalogueLayout.pageDescription}</p>
                </div>
                <div className="rounded-3xl border border-emerald-500 bg-emerald-50 px-4 py-3 text-sm font-semibold text-emerald-900">
                  Online ordering
                </div>
              </div>
              <div className="mt-6 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                <div className="rounded-3xl border border-slate-200 bg-slate-100 p-4 text-sm text-slate-700">Scan to order now from your phone.</div>
                <div className="rounded-3xl border border-slate-200 bg-slate-100 p-4 text-sm text-slate-700 break-all">{catalogueUrl}</div>
              </div>
            </div>

            <div className="grid gap-6 xl:grid-cols-[1.45fr_0.55fr]">
              <div className="space-y-6">
                <div className={`rounded-[32px] border p-6 shadow-soft ${darkMode ? 'border-slate-700 bg-slate-950' : 'border-slate-200 bg-white'}`}>
                  <div className="flex flex-wrap items-center justify-between gap-3">
                    <div>
                      <p className={`text-sm uppercase tracking-[0.2em] ${darkMode ? 'text-slate-400' : 'text-slate-500'}`}>Menu</p>
                      <h2 className={`mt-2 text-2xl font-semibold ${darkMode ? 'text-slate-100' : 'text-slate-900'}`}>Add to cart</h2>
                    </div>
                    <div className="grid gap-2 sm:grid-cols-2">
                      <select value={catalogueCategory} onChange={(e) => setCatalogueCategory(e.target.value)} className={`rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`}>
                        {getAssignedCategoriesForDropdown().map((category) => (
                          <option key={category.id || category.name} value={category.name}>{category.name}</option>
                        ))}
                      </select>
                      <input value={catalogueSearch} onChange={(e) => setCatalogueSearch(e.target.value)} placeholder="Search menu" className={`rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} />
                    </div>
                  </div>

                  <div className="mt-5 grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
                    {filteredProducts.map((product) => (
                      <div key={product.id} className={`rounded-3xl border p-5 shadow-sm ${darkMode ? 'border-slate-700 bg-slate-900' : 'border-slate-200 bg-slate-50'}`}>
                        {product.photo && <img src={product.photo} alt={product.name} className="h-48 w-full rounded-3xl object-cover" />}
                        <div className="mt-4 flex items-center justify-between gap-3">
                          <div>
                            <h3 className={`text-lg font-semibold ${darkMode ? 'text-slate-100' : 'text-slate-900'}`}>{product.name}</h3>
                            <p className={`text-sm ${darkMode ? 'text-slate-400' : 'text-slate-600'}`}>{product.category}</p>
                          </div>
                          <span className="rounded-full bg-emerald-600 px-3 py-1 text-sm font-semibold text-slate-950">{product.price} PKR</span>
                        </div>
                        <p className={`mt-3 text-sm ${darkMode ? 'text-slate-400' : 'text-slate-600'}`}>{product.description || 'Delicious hotel item.'}</p>
                        <button onClick={() => addToCatalogueCart(product)} className="mt-4 w-full rounded-3xl bg-emerald-600 px-4 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-500">Add to cart</button>
                      </div>
                    ))}
                    {!filteredProducts.length && <div className="col-span-full rounded-3xl border border-dashed border-slate-300 bg-slate-50 p-6 text-center text-slate-500">No items found.</div>}
                  </div>
                </div>
              </div>

              <aside className={`space-y-6 rounded-[32px] border p-6 shadow-soft ${darkMode ? 'border-slate-700 bg-slate-950' : 'border-slate-200 bg-white'}`}>
                <div>
                  <p className="text-sm uppercase tracking-[0.2em] text-slate-500">Your cart</p>
                  <h2 className={`mt-2 text-2xl font-semibold ${darkMode ? 'text-slate-100' : 'text-slate-900'}`}>{catalogueCart.length} items</h2>
                </div>
                <div className="space-y-3">
                  {catalogueCart.map((item) => (
                    <div key={item.productId} className="rounded-3xl border border-slate-200 bg-slate-50 p-4">
                      <div className="flex items-center justify-between gap-3">
                        <div>
                          <div className="font-semibold text-slate-900">{item.name}</div>
                          <div className="text-sm text-slate-500">{item.price} PKR × {item.quantity}</div>
                        </div>
                        <div className="flex items-center gap-2">
                          <button onClick={() => updateCatalogueCartItem(item.productId, -1)} className="rounded-full bg-slate-800 px-3 py-1 text-white">-</button>
                          <button onClick={() => updateCatalogueCartItem(item.productId, 1)} className="rounded-full bg-slate-800 px-3 py-1 text-white">+</button>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
                <div className="rounded-3xl border border-slate-200 bg-slate-50 p-4">
                  <div className="flex justify-between text-sm text-slate-500"><span>Subtotal</span><span>{summary.subtotal} PKR</span></div>
                  <div className="mt-3 grid gap-3">
                    <label className="block text-sm text-slate-500">Name</label>
                    <input value={catalogueCustomer.name} onChange={(e) => setCatalogueCustomer((prev) => ({ ...prev, name: e.target.value }))} className="w-full rounded-3xl border px-4 py-3 text-sm outline-none" placeholder="Customer name" />
                    <label className="block text-sm text-slate-500">Phone</label>
                    <input value={catalogueCustomer.phone} onChange={(e) => setCatalogueCustomer((prev) => ({ ...prev, phone: e.target.value }))} className="w-full rounded-3xl border px-4 py-3 text-sm outline-none" placeholder="Phone number" />
                    <label className="block text-sm text-slate-500">Address</label>
                    <textarea value={catalogueCustomer.address} onChange={(e) => setCatalogueCustomer((prev) => ({ ...prev, address: e.target.value }))} rows={3} className="w-full rounded-3xl border px-4 py-3 text-sm outline-none" placeholder="Delivery address (optional)" />
                    <label className="block text-sm text-slate-500">Order note</label>
                    <textarea value={catalogueOrderNote} onChange={(e) => setCatalogueOrderNote(e.target.value)} rows={3} className="w-full rounded-3xl border px-4 py-3 text-sm outline-none" placeholder="Special instructions" />
                  </div>
                </div>
                <button onClick={saveOnlineCatalogueOrder} className="w-full rounded-3xl bg-emerald-600 px-4 py-3 text-sm font-semibold text-slate-950 hover:bg-emerald-500">Submit online order</button>
                {catalogueMessage && <div className="rounded-3xl border border-emerald-500 bg-emerald-100 p-4 text-sm text-emerald-900">{catalogueMessage}</div>}
              </aside>
            </div>
          </div>
        </div>
      </div>
    );
  }

  function renderOrders() {
    return (
      <div className="space-y-6">
        <div className="flex flex-wrap gap-3">
          <button onClick={() => setOrdersMainTab('delivery')} className={`rounded-full px-4 py-2 text-sm font-semibold transition ${ordersMainTab === 'delivery' ? 'bg-emerald-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}>Delivery Orders</button>
          <button onClick={() => setOrdersMainTab('takeaway')} className={`rounded-full px-4 py-2 text-sm font-semibold transition ${ordersMainTab === 'takeaway' ? 'bg-emerald-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}>Takeaway Orders</button>
          <button onClick={() => setOrdersMainTab('dinein')} className={`rounded-full px-4 py-2 text-sm font-semibold transition ${ordersMainTab === 'dinein' ? 'bg-emerald-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}>Dine-In Orders</button>
          <button onClick={() => setOrdersMainTab('online')} className={`rounded-full px-4 py-2 text-sm font-semibold transition ${ordersMainTab === 'online' ? 'bg-emerald-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}>Online Orders</button>
          <button onClick={() => setOrdersMainTab('deliverySettings')} className={`rounded-full px-4 py-2 text-sm font-semibold transition ${ordersMainTab === 'deliverySettings' ? 'bg-emerald-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}>Delivery Settings</button>
        </div>
        {ordersMainTab === 'delivery' && renderDeliveryOrders()}
        {ordersMainTab === 'takeaway' && renderTakeawayOrders()}
        {ordersMainTab === 'dinein' && renderDineinOrders()}
        {ordersMainTab === 'online' && renderOnlineOrders()}
        {ordersMainTab === 'deliverySettings' && renderDeliverySettings()}
      </div>
    );
  }

  function renderRecentOrders(popupMode) {
    const tabs = ['Delivery', 'Takeaway', 'Dine-In'];
    const selectedDate = (() => {
      const today = new Date();
      if (recentOrderDateFilter === 'today') return today;
      if (recentOrderDateFilter === 'yesterday') {
        const yesterday = new Date();
        yesterday.setDate(yesterday.getDate() - 1);
        return yesterday;
      }
      return new Date(recentOrderCustomDate);
    })();

    const formatLocalDate = (date) => {
      if (!date || Number.isNaN(date.getTime())) return '';
      return date.toLocaleDateString(undefined, { weekday: 'long', day: 'numeric', month: 'short', year: 'numeric' });
    };

    const getOrderDateString = (order) => {
      const raw = order.createdAt || order.date;
      if (!raw) return null;
      const date = new Date(raw);
      if (Number.isNaN(date.getTime())) return null;
      return date.toISOString().slice(0, 10);
    };

    const selectedDateString = Number.isNaN(selectedDate.getTime()) ? null : selectedDate.toISOString().slice(0, 10);
    const recentOrders = posOrders.filter((order) => {
      if (recentOrderTab === 'Delivery') return order.orderType === 'Delivery';
      if (recentOrderTab === 'Takeaway') return order.orderType === 'Takeaway';
      if (recentOrderTab === 'Dine-In') return order.orderType === 'Dine-In';
      return false;
    }).filter((order) => {
      const orderDateString = getOrderDateString(order);
      return orderDateString && selectedDateString ? orderDateString === selectedDateString : false;
    });
    const paginatedOrders = recentOrders.slice(recentOrderPageIndex * recentOrderPageSize, (recentOrderPageIndex + 1) * recentOrderPageSize);
    const pageCount = Math.max(1, Math.ceil(recentOrders.length / recentOrderPageSize));
    const isDelivery = recentOrderTab === 'Delivery';
    const isTakeaway = recentOrderTab === 'Takeaway';
    const isDinein = recentOrderTab === 'Dine-In';

    const innerContent = (
      <>
        {!popupMode && (
          <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
            <div>
              <p className="text-sm uppercase tracking-[0.2em] text-slate-400">Order history</p>
              <h3 className="mt-2 text-2xl font-semibold text-white">Recent POS orders</h3>
              <div className="mt-2 text-sm text-slate-400">
                Total orders:
                <span className="ml-1 font-semibold text-white">{posOrders.length}</span>
                <span className="mx-2 text-slate-500">|</span>
                {recentOrders.length} {recentOrderTab} orders
              </div>
            </div>
            <div className="flex flex-wrap gap-2">
              {tabs.map((tab) => (
                <button
                  key={tab}
                  type="button"
                  onClick={() => setRecentOrderTab(tab)}
                  className={`rounded-full px-4 py-2 text-sm font-semibold transition ${recentOrderTab === tab ? 'bg-emerald-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}
                >
                  {tab}
                </button>
              ))}
            </div>
          </div>
        )}
        <div className={`${popupMode ? '' : 'mt-6'} rounded-3xl border border-slate-800 bg-slate-950 p-4`}>
          <div className="flex flex-wrap items-center justify-between gap-3 pb-4">
            <div className="text-sm text-slate-400">Showing {paginatedOrders.length} of {recentOrders.length} orders</div>
            <div className="flex flex-wrap items-center gap-3">
              <label className="text-sm text-slate-400">Date</label>
              <select
                value={recentOrderDateFilter}
                onChange={(e) => setRecentOrderDateFilter(e.target.value)}
                className="rounded-full border border-slate-700 bg-slate-900 px-3 py-2 text-sm text-slate-100 outline-none focus:border-emerald-500"
              >
                <option value="today">Today</option>
                <option value="yesterday">Yesterday</option>
                <option value="custom">Custom</option>
              </select>
              {recentOrderDateFilter === 'custom' && (
                <input
                  type="date"
                  value={recentOrderCustomDate}
                  onChange={(e) => setRecentOrderCustomDate(e.target.value)}
                  className="rounded-full border border-slate-700 bg-slate-900 px-3 py-2 text-sm text-slate-100 outline-none focus:border-emerald-500"
                />
              )}
              <div className="rounded-full border border-slate-700 bg-slate-900 px-3 py-2 text-sm text-slate-100">
                {selectedDateString ? formatLocalDate(selectedDate) : 'Invalid date'}
              </div>
              <label className="text-sm text-slate-400">Rows</label>
              <select
                value={recentOrderPageSize}
                onChange={(e) => setRecentOrderPageSize(Number(e.target.value))}
                className="rounded-full border border-slate-700 bg-slate-900 px-3 py-2 text-sm text-slate-100 outline-none focus:border-emerald-500"
              >
                {[6, 12, 18, 24, 100].map((size) => (
                  <option key={size} value={size}>{size}</option>
                ))}
              </select>
            </div>
          </div>
          <div className="max-h-[420px] overflow-y-auto overflow-x-auto rounded-3xl border border-slate-800 bg-slate-950">
            <table className="w-full min-w-[900px] divide-y divide-slate-700 text-left text-sm text-slate-300">
              <thead className="bg-slate-950 text-slate-200">
                <tr>
                  <th className="px-4 py-3">Order #</th>
                  {isDelivery && <th className="px-4 py-3">Delivery address</th>}
                  {isDelivery && <th className="px-4 py-3">Phone</th>}
                  {isDelivery && <th className="px-4 py-3">Service type</th>}
                  {isTakeaway && <th className="px-4 py-3">Customer</th>}
                  {isTakeaway && <th className="px-4 py-3">Phone</th>}
                  {isDinein && <th className="px-4 py-3">Table</th>}
                  {isDinein && <th className="px-4 py-3">Customer</th>}
                  <th className="px-4 py-3">Items</th>
                  <th className="px-4 py-3">Total</th>
                  {isDelivery && <th className="px-4 py-3">Rider</th>}
                  {isDelivery && <th className="px-4 py-3">Payment</th>}
                  <th className="px-4 py-3">Status</th>
                  <th className="px-4 py-3">Date</th>
                  <th className="px-4 py-3">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800 bg-slate-950">
                {paginatedOrders.length ? paginatedOrders.map((order) => (
                  <tr key={order.id} className="hover:bg-slate-950/80 transition">
                    <td className="px-4 py-3 font-semibold text-white">{order.orderNumber || order.id}</td>
                    {isDelivery && <td className="px-4 py-3 text-slate-300">{order.address || '-'}</td>}
                    {isDelivery && <td className="px-4 py-3 text-slate-300">{order.phone || '-'}</td>}
                    {isDelivery && <td className="px-4 py-3 text-slate-300">{order.serviceType || '-'}</td>}
                    {isTakeaway && <td className="px-4 py-3 text-slate-300">{order.customerName || 'Pickup'}</td>}
                    {isTakeaway && <td className="px-4 py-3 text-slate-300">{order.phone || '-'}</td>}
                    {isDinein && <td className="px-4 py-3 text-slate-300">{order.tableNumber || '-'}</td>}
                    {isDinein && <td className="px-4 py-3 text-slate-300">{order.customerName || 'TABLE'}</td>}
                    <td className="px-4 py-3 text-slate-300">
                      <div className="flex items-center gap-2">
                        <span>{(order.items || []).length} item{(order.items || []).length === 1 ? '' : 's'}</span>
                        <button type="button" onClick={() => setOrderDetailsModal(order)} title="View items" className="inline-flex h-8 w-8 items-center justify-center rounded-full border border-slate-700 bg-slate-900 text-slate-200 hover:bg-slate-800">
                          <svg viewBox="0 0 24 24" className="h-4 w-4"><path d="M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5C21.27 7.61 17 4.5 12 4.5zm0 12c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5zm0-8.5a3.5 3.5 0 1 0 0 7 3.5 3.5 0 0 0 0-7z" fill="currentColor"/></svg>
                        </button>
                      </div>
                    </td>
                    <td className="px-4 py-3 font-semibold text-white">{order.total || order.amount || 0} PKR</td>
                    {isDelivery && <td className="px-4 py-3 text-slate-300">{order.deliveryAgent || 'Unassigned'}</td>}
                    {isDelivery && <td className="px-4 py-3 text-slate-300">{order.paymentStatus || order.paymentMethod || '-'}</td>}
                    <td className="px-4 py-3"><span className={`inline-flex rounded-full px-3 py-1 text-xs font-semibold text-white ${getStatusBadge(order.status)}`}>{order.status || 'Pending'}</span></td>
                    <td className="px-4 py-3 text-slate-400">{order.createdAt ? new Date(order.createdAt).toLocaleString() : order.date || 'N/A'}</td>
                    <td className="px-4 py-3">
                      <div className="flex flex-wrap gap-2">
                        {renderOrderEditButton(order)}
                        <button onClick={() => deleteOrder(order.id)} className="rounded-full border border-rose-600 bg-rose-600 px-3 py-1 text-xs font-semibold text-white hover:bg-rose-500">Delete</button>
                        <button onClick={() => printReceipt(order)} className="rounded-full border border-emerald-600 bg-emerald-600 px-3 py-1 text-xs font-semibold text-slate-950 hover:bg-emerald-500">Print</button>
                      </div>
                    </td>
                  </tr>
                )) : (
                  <tr>
                    <td colSpan={isDelivery ? 11 : isTakeaway ? 8 : 8} className="px-4 py-6 text-center text-sm text-slate-500">No orders found for {recentOrderTab}.</td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
          <div className="mt-4 flex flex-wrap items-center justify-between gap-3 rounded-3xl border border-slate-800 bg-slate-900 p-3 text-sm text-slate-300">
            <div>{recentOrders.length ? `Page ${recentOrderPageIndex + 1} of ${pageCount}` : 'No orders available'}</div>
            <div className="flex items-center gap-2">
              <button disabled={recentOrderPageIndex === 0} onClick={() => setRecentOrderPageIndex((prev) => Math.max(prev - 1, 0))} className="rounded-full border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-200 transition hover:bg-slate-800 disabled:opacity-50">Prev</button>
              <button disabled={recentOrderPageIndex >= pageCount - 1} onClick={() => setRecentOrderPageIndex((prev) => Math.min(prev + 1, pageCount - 1))} className="rounded-full border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-200 transition hover:bg-slate-800 disabled:opacity-50">Next</button>
            </div>
          </div>
        </div>
      </>
    );
    return popupMode ? innerContent : (
      <section className="rounded-[32px] border border-slate-800 bg-slate-900 p-6 shadow-soft">
        {innerContent}
      </section>
    );
  }

  function renderDeliveryOrders() {
    const deliveryOrders = posOrders.filter((o) => o.orderType === 'Delivery');
    const filteredOrders = deliveryOrders.filter((o) => {
      const status = String(o.status || '').toLowerCase();
      const hasRider = Boolean(o.deliveryAgent);
      const isNewOrdersTab = deliverySubTab === 'kitchen';
      let matchesDeliveryTab = true;
      if (isNewOrdersTab) {
        matchesDeliveryTab = !hasRider || status === 'kitchen';
      } else if (deliverySubTab === 'assigned') {
        matchesDeliveryTab = hasRider || status === 'riders assigned';
      }
      const matchesSearch = !orderSearch || 
        (String(o.orderNumber || o.id)).toLowerCase().includes(orderSearch.toLowerCase()) ||
        (o.customerName || '').toLowerCase().includes(orderSearch.toLowerCase()) ||
        (o.phone || '').toLowerCase().includes(orderSearch.toLowerCase()) ||
        (o.address || '').toLowerCase().includes(orderSearch.toLowerCase());

      const matchesRider = !orderFilterRider || o.deliveryAgent === orderFilterRider;
      const matchesPayment = !orderFilterPayment || o.paymentMethod === orderFilterPayment;
      let matchesDate = true;
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const getDateRange = () => {
        const from = new Date(today);
        const to = new Date(today.getTime() + 24 * 60 * 60 * 1000);
        if (deliveryDateFilter === 'today') return { from, to };
        if (deliveryDateFilter === 'yesterday') {
          const yesterday = new Date(today);
          yesterday.setDate(yesterday.getDate() - 1);
          return { from: yesterday, to };
        }
        if (deliveryDateFilter === 'previous-5-days') {
          const fiveDaysAgo = new Date(today);
          fiveDaysAgo.setDate(fiveDaysAgo.getDate() - 5);
          return { from: fiveDaysAgo, to };
        }
        if (deliveryDateFilter === 'custom') {
          return {
            from: new Date(deliveryCustomDateFrom + 'T00:00:00'),
            to: new Date(deliveryCustomDateTo + 'T23:59:59')
          };
        }
        return { from: null, to: null };
      };
      const { from, to } = getDateRange();
      if (from && to) {
        const orderDate = o.createdAt ? new Date(o.createdAt) : o.date ? new Date(o.date) : null;
        matchesDate = orderDate ? orderDate >= from && orderDate <= to : false;
      }
      return matchesDeliveryTab && matchesSearch && matchesRider && matchesPayment && matchesDate;
    });
    const pageCount = orderPageSize > 0 ? Math.max(1, Math.ceil(filteredOrders.length / orderPageSize)) : 1;
    const paginatedOrders = orderPageSize > 0 ? filteredOrders.slice(orderPageIndex * orderPageSize, (orderPageIndex + 1) * orderPageSize) : filteredOrders;
    return (
      <div className="space-y-6">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="flex items-center gap-3 flex-wrap">
            {['kitchen', 'assigned', 'all'].map((status) => (
              <button
                key={status}
                onClick={() => setDeliverySubTab(status)}
                className={`flex items-center gap-2 rounded-full px-3 py-2 text-sm font-semibold transition-transform transform hover:-translate-y-0.5 ${deliverySubTab === status ? 'bg-gradient-to-r from-emerald-500 to-cyan-500 text-white shadow-lg scale-105' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}
              >
                <span className="text-lg">{status === 'kitchen' ? '🆕' : status === 'assigned' ? '👤' : '📋'}</span>
                <span className="uppercase text-xs tracking-wide">{status === 'kitchen' ? 'New' : status === 'assigned' ? 'Assigned' : 'All'}</span>
              </button>
            ))}

            <div className="relative mt-1">
              <input
                type="text"
                placeholder="🔎 Search order#, address, phone..."
                value={orderSearch}
                onChange={(e) => setOrderSearch(e.target.value)}
                className="w-72 rounded-full border border-slate-800 bg-slate-900 px-4 py-2 text-sm text-slate-100 placeholder-slate-500 outline-none focus:border-emerald-500 transition-shadow shadow-sm"
              />
            </div>

            <div className="inline-flex items-center gap-2 rounded-full border border-slate-700 bg-slate-900 px-3 py-2 text-sm text-slate-200">
              <svg className="h-4 w-4 text-slate-400" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 7h18M3 12h18M3 17h18"/></svg>
              <select value={orderFilterRider} onChange={(e) => setOrderFilterRider(e.target.value)} className="bg-transparent outline-none text-sm px-2">
                <option value="">All Riders</option>
                {Array.from(new Set(deliveryOrders.map((order) => order.deliveryAgent).filter(Boolean))).map((rider) => (
                  <option key={rider} value={rider}>{rider}</option>
                ))}
              </select>
            </div>

            <div className="inline-flex items-center gap-2 rounded-full border border-slate-700 bg-slate-900 px-3 py-2 text-sm text-slate-200">
              <svg className="h-4 w-4 text-slate-400" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v8M8 12h8"/></svg>
              <select value={orderFilterPayment} onChange={(e) => setOrderFilterPayment(e.target.value)} className="bg-transparent outline-none text-sm px-2">
                <option value="">All Payments</option>
                {Array.from(new Set(deliveryOrders.map((order) => order.paymentMethod).filter(Boolean))).map((method) => (
                  <option key={method} value={method}>{method}</option>
                ))}
              </select>
            </div>
          </div>

          <div className="flex items-center gap-2 flex-wrap">
            <div className="text-xs uppercase tracking-[0.2em] text-slate-400">Filter by Date</div>
            {['today', 'yesterday', 'previous-5-days', 'custom'].map((filter) => (
              <button
                key={filter}
                onClick={() => {
                  setDeliveryDateFilter(filter);
                  setOrderPageIndex(0);
                }}
                className={`rounded-full px-3 py-1 text-xs font-semibold transition ${deliveryDateFilter === filter ? 'bg-cyan-500 text-white shadow-inner' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}
              >
                {filter === 'today' ? '📅 Today' : filter === 'yesterday' ? '📅 Yesterday' : filter === 'previous-5-days' ? '📅 Last 5 Days' : '📅 Custom'}
              </button>
            ))}
            {deliveryDateFilter === 'custom' && (
              <div className="flex items-center gap-2">
                <input type="date" value={deliveryCustomDateFrom} onChange={(e) => { setDeliveryCustomDateFrom(e.target.value); setOrderPageIndex(0); }} className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-xs text-slate-200" />
                <span className="text-slate-400">to</span>
                <input type="date" value={deliveryCustomDateTo} onChange={(e) => { setDeliveryCustomDateTo(e.target.value); setOrderPageIndex(0); }} className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-xs text-slate-200" />
              </div>
            )}
            <div className="inline-flex items-center gap-2 ml-2">
              <button type="button" onClick={() => setDeliveryViewMode('tile')} className={`inline-flex h-10 w-10 items-center justify-center rounded-full border border-slate-700 bg-slate-900 text-slate-200 transition ${deliveryViewMode === 'tile' ? 'bg-emerald-600 text-white' : 'hover:bg-slate-800'}`} title="Tile view">
                <svg viewBox="0 0 24 24" className="h-5 w-5"><path d="M4 4h7v7H4V4zm9 0h7v4h-7V4zM4 13h7v7H4v-7zm9 5h7v2h-7v-2z" fill="currentColor"/></svg>
              </button>
              <button type="button" onClick={() => setDeliveryViewMode('table')} className={`inline-flex h-10 w-10 items-center justify-center rounded-full border border-slate-700 bg-slate-900 text-slate-200 transition ${deliveryViewMode === 'table' ? 'bg-emerald-600 text-white' : 'hover:bg-slate-800'}`} title="Table view">
                <svg viewBox="0 0 24 24" className="h-5 w-5"><path d="M4 4h16v4H4V4zm0 6h16v4H4v-4zm0 6h16v4H4v-4z" fill="currentColor"/></svg>
              </button>
            </div>
          </div>
        </div>

        <div className={`transition-opacity duration-200 ${deliveryLoading ? 'opacity-40 blur-sm' : 'opacity-100'}`}>

        {deliverySubTab === 'kitchen' && selectedOrders.length > 0 && (
            <div className="flex flex-wrap items-center justify-between rounded-3xl border border-slate-800 bg-slate-900 p-4 gap-3">
              <div className="text-sm text-slate-300">
                {selectedOrders.length} order{selectedOrders.length > 1 ? 's' : ''} selected
              </div>
              <div className="flex flex-wrap gap-2">
                <button onClick={clearOrderSelection} className="rounded-3xl border border-slate-700 bg-slate-800 px-4 py-2 text-sm font-semibold text-slate-200 transition hover:bg-slate-700">Clear</button>
                <button onClick={openBulkRiderAssignmentModal} className="rounded-3xl border border-purple-600 bg-purple-600 px-4 py-2 text-sm font-semibold text-white transition hover:bg-purple-500">Assign Rider</button>
              </div>
            </div>
        )}

        {deliveryViewMode === 'table' ? (
          <div className="overflow-x-auto rounded-[32px] border border-slate-800 bg-slate-900 p-2 shadow-soft">
            <table className="w-full min-w-[900px] text-left text-xs text-slate-100">
              <thead className="border-b border-slate-800 text-slate-400">
                <tr>
                  <th className="px-2 py-2">
                    {deliverySubTab === 'kitchen' ? (
                      <input
                        type="checkbox"
                        checked={paginatedOrders.length > 0 && selectedOrders.length === paginatedOrders.length}
                        onChange={(e) => e.target.checked ? selectAllOrders(paginatedOrders) : clearOrderSelection()}
                        className="h-4 w-4 rounded border-slate-700 bg-slate-900 text-emerald-600 focus:ring-emerald-500"
                      />
                    ) : null}
                  </th>
                  <th className="px-2 py-2 text-[11px] font-semibold uppercase tracking-[0.12em] text-slate-300">Order #</th>
                  <th className="px-2 py-2 text-[11px] font-semibold uppercase tracking-[0.12em] text-slate-300">Delivery address</th>
                  <th className="px-2 py-2 text-[11px] font-semibold uppercase tracking-[0.12em] text-slate-300">Phone</th>
                  <th className="px-2 py-2 text-[11px] font-semibold uppercase tracking-[0.12em] text-slate-300">Service type</th>
                  <th className="px-2 py-2 text-[11px] font-semibold uppercase tracking-[0.12em] text-slate-300">Products</th>
                  <th className="px-2 py-2 text-[11px] font-semibold uppercase tracking-[0.12em] text-slate-300">Total</th>
                  <th className="px-2 py-2 text-[11px] font-semibold uppercase tracking-[0.12em] text-slate-300">Rider</th>
                  <th className="px-2 py-2 text-[11px] font-semibold uppercase tracking-[0.12em] text-slate-300">Payment</th>
                  <th className="px-2 py-2 text-[11px] font-semibold uppercase tracking-[0.12em] text-slate-300">Date</th>
                  <th className="px-2 py-2 text-[11px] font-semibold uppercase tracking-[0.12em] text-slate-300">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800">
                {paginatedOrders.map((order) => (
                  <tr key={order.id} className="hover:bg-slate-950/80 transition">
                    <td className="px-2 py-2">
                      {deliverySubTab === 'kitchen' ? (
                        <input
                          type="checkbox"
                          checked={selectedOrders.includes(order.id)}
                          onChange={() => toggleOrderSelection(order.id)}
                          className="h-4 w-4 rounded border-slate-700 bg-slate-900 text-emerald-600 focus:ring-emerald-500"
                        />
                      ) : null}
                    </td>
                    <td className="px-2 py-2 text-xs font-semibold text-white">{order.orderNumber || order.id}</td>
                    <td className="px-2 py-2 max-w-[150px] truncate text-slate-300 text-xs">{order.address || '-'}</td>
                    <td className="px-2 py-2 text-slate-300 text-xs">{order.phone || '-'}</td>
                    <td className="px-2 py-2 text-slate-300 text-xs">{order.serviceType || '-'}</td>
                    <td className="px-2 py-2 text-slate-300 text-xs">
                      <div className="flex items-center gap-2">
                        <span>{(order.items || []).length} item{(order.items || []).length === 1 ? '' : 's'}</span>
                        <button type="button" onClick={() => setOrderDetailsModal(order)} title="View items" className="inline-flex h-8 w-8 items-center justify-center rounded-full border border-slate-700 bg-slate-900 text-slate-200 hover:bg-slate-800">
                          <svg viewBox="0 0 24 24" className="h-4 w-4"><path d="M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5C21.27 7.61 17 4.5 12 4.5zm0 12c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5zm0-8.5a3.5 3.5 0 1 0 0 7 3.5 3.5 0 0 0 0-7z" fill="currentColor"/></svg>
                        </button>
                      </div>
                    </td>
                    <td className="px-2 py-2 font-semibold text-white text-xs">{order.total || order.amount || 0} Rs</td>
                    <td className="px-2 py-2 text-slate-300 text-xs">{order.deliveryAgent || 'Unassigned'}</td>
                    <td className="px-2 py-2">
                      <div className="inline-flex items-center gap-0.5 rounded-xl border border-slate-700 bg-slate-950 px-1.5 py-0.5 text-[10px] font-medium text-slate-200 group">
                        {order.paymentStatus ? (
                          <>
                            <span className="inline-block h-1.5 w-1.5 rounded-full bg-emerald-500 animate-pulse group-hover:animate-bounce"></span>
                            <span className="truncate">{order.paymentStatus}</span>
                          </>
                        ) : (
                          <span className="text-slate-500">-</span>
                        )}
                      </div>
                    </td>
                    <td className="px-2 py-2 text-slate-400 text-[10px]">{order.createdAt ? new Date(order.createdAt).toLocaleString() : '-'}</td>
                    <td className="px-2 py-2">
                      <div className="flex flex-wrap gap-2">
                        {renderOrderEditButton(order)}
                        <button type="button" title="Delete order" onClick={() => deleteOrder(order.id)} className="rounded-full border border-rose-600 bg-rose-600 px-3 py-2 text-white transition hover:bg-rose-500">
                          <svg viewBox="0 0 24 24" className="h-4 w-4"><path d="M3 6h18" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/><path d="M8 6V4h8v2" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/><path d="M19 6l-1 14H6L5 6" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/><path d="M10 11v6" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/><path d="M14 11v6" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/></svg>
                        </button>
                        <button type="button" title="Print order" onClick={() => printReceipt(order)} className="rounded-full border border-emerald-600 bg-emerald-600 px-3 py-2 text-slate-950 transition hover:bg-emerald-500">
                          <svg viewBox="0 0 24 24" className="h-4 w-4"><path d="M6 9V3h12v6" stroke="currentColor" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/><path d="M6 18h12v-6H6v6z" stroke="currentColor" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/><path d="M9 21h6" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/></svg>
                        </button>
                        {deliverySubTab === 'kitchen' && !order.deliveryAgent && (
                          <button type="button" title="Assign rider" onClick={() => openRiderAssignmentModal(order)} className="rounded-full border border-slate-700 bg-purple-600 px-3 py-2 text-white transition hover:bg-purple-500">
                            <svg viewBox="0 0 24 24" className="h-4 w-4"><path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" fill="currentColor"/></svg>
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="grid gap-4 lg:grid-cols-3">
            {paginatedOrders.map((order) => {
              const paidStatus = ['Completed', 'Payment Collected', 'Delivered'].includes(order.status) ? 'Paid' : 'Due';
              const isSelected = selectedOrders.includes(order.id);
              return (
                <div key={order.id} className="rounded-3xl border border-slate-800 bg-slate-900 p-5 shadow-soft hover:shadow-lg transition relative">
                  {isSelected && (
                    <div className="absolute -top-2 -right-2 z-10 h-6 w-6 rounded-full bg-emerald-600 flex items-center justify-center">
                      <svg className="h-4 w-4 text-white" fill="currentColor" viewBox="0 0 20 20">
                        <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                      </svg>
                    </div>
                  )}
                  <div className="flex items-start justify-between gap-3">
                    {deliverySubTab === 'kitchen' ? (
                      <div className="flex items-center gap-2">
                        <input
                          type="checkbox"
                          checked={isSelected}
                          onChange={() => toggleOrderSelection(order.id)}
                          className="h-4 w-4 rounded border-slate-700 bg-slate-900 text-emerald-600 focus:ring-emerald-500"
                        />
                        <div>
                          <div className="text-base font-semibold text-white">{order.orderNumber || order.id}</div>
                          {order.customerName && (
                            <div className="mt-1 text-xs uppercase tracking-[0.25em] text-slate-500">{order.customerName}</div>
                          )}
                        </div>
                      </div>
                    ) : (
                      <div className="flex items-center gap-2">
                        <div>
                          <div className="text-base font-semibold text-white">{order.orderNumber || order.id}</div>
                          {order.customerName && (
                            <div className="mt-1 text-xs uppercase tracking-[0.25em] text-slate-500">{order.customerName}</div>
                          )}
                        </div>
                      </div>
                    )}
                    <div className="space-y-2 text-right">
                      <span className={`inline-flex rounded-full px-2.5 py-1 text-[10px] font-semibold uppercase tracking-[0.2em] ${getStatusBadge(order.status)}`}>{order.status || 'Pending'}</span>
                      <span className={`inline-flex rounded-full px-2.5 py-1 text-[10px] font-semibold uppercase tracking-[0.2em] ${paidStatus === 'Paid' ? 'bg-emerald-500 text-slate-950' : 'bg-rose-500 text-white'}`}>{paidStatus}</span>
                      <div>
                        <div className="text-[10px] uppercase tracking-[0.22em] text-slate-400">Products</div>
                        <div className="text-sm font-semibold text-white">{(order.items || []).length} item{(order.items || []).length === 1 ? '' : 's'}</div>
                      </div>
                    </div>
                  </div>
                  <div className={`mt-4 space-y-3 divide-y ${darkMode ? 'divide-slate-800' : 'divide-slate-200'} text-sm ${darkMode ? 'text-slate-300' : 'text-slate-600'}`}>
                    <div className="flex items-center justify-between gap-2 pb-3"><span className={darkMode ? 'text-slate-400' : 'text-slate-500'}>Items</span><span>{(order.items || []).length}</span></div>
                    <div className="flex items-center justify-between gap-2 py-3"><span className={darkMode ? 'text-slate-400' : 'text-slate-500'}>Products</span><span>{(order.items || []).length} item{(order.items || []).length === 1 ? '' : 's'}</span></div>
                    <div className="flex items-center justify-between gap-2 pt-3"><span className={darkMode ? 'text-slate-400' : 'text-slate-500'}>Address</span><span className="truncate text-right">{order.address || '-'}</span></div>
                  </div>
                  <div className="space-y-4 pt-3">
                    <div className="rounded-[24px] border border-slate-800 bg-slate-950/60 p-4">
                      <p className="text-xs uppercase tracking-[0.24em] text-slate-400">Delivery address</p>
                      <div className="mt-2 text-sm font-semibold text-white">{order.address || '-'}</div>
                    </div>
                    <div className="grid gap-3 sm:grid-cols-2">
                      <div>
                        <p className="text-xs uppercase tracking-[0.24em] text-slate-400">Phone</p>
                        <div className="mt-2 text-sm text-slate-200">{order.phone || '-'}</div>
                      </div>
                      <div>
                        <p className="text-xs uppercase tracking-[0.24em] text-slate-400">Service type</p>
                        <div className="mt-2 text-sm text-slate-200">{order.serviceType || '-'}</div>
                      </div>
                    </div>
                    <div className="grid gap-3 sm:grid-cols-2">
                      <div>
                        <p className="text-xs uppercase tracking-[0.24em] text-slate-400">Products</p>
                        <div className="mt-2 text-sm text-slate-200">{(order.items || []).length} item{(order.items || []).length === 1 ? '' : 's'}</div>
                      </div>
                      <div>
                        <p className="text-xs uppercase tracking-[0.24em] text-slate-400">Total</p>
                        <div className="mt-2 text-sm font-semibold text-white">{order.total || order.amount || 0} Rs</div>
                      </div>
                    </div>
                    <div className="grid gap-3 sm:grid-cols-2">
                      <div>
                        <p className="text-xs uppercase tracking-[0.24em] text-slate-400">Rider</p>
                        <div className="mt-2 text-sm text-slate-200">{order.deliveryAgent || 'Unassigned'}</div>
                      </div>
                      <div>
                        <p className="text-xs uppercase tracking-[0.24em] text-slate-400">Date & time</p>
                        <div className="mt-2 text-sm text-slate-200">{order.createdAt ? new Date(order.createdAt).toLocaleString() : '-'}</div>
                      </div>
                    </div>
                    <div className="flex flex-wrap gap-2 pt-2">
                      <button type="button" title="Delete order" onClick={() => deleteOrder(order.id)} className={`inline-flex h-11 w-11 items-center justify-center rounded-full border border-rose-600 bg-rose-600 text-white shadow-[0_12px_18px_rgba(0,0,0,0.24)] transition hover:-translate-y-0.5 hover:bg-rose-500`}>
                        <svg viewBox="0 0 24 24" className="h-5 w-5"><path d="M3 6h18" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/><path d="M8 6V4h8v2" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/><path d="M19 6l-1 14H6L5 6" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/><path d="M10 11v6" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/><path d="M14 11v6" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/></svg>
                      </button>
                      <button type="button" title="Print order" onClick={() => printReceipt(order)} className={`inline-flex h-11 w-11 items-center justify-center rounded-full border border-emerald-600 bg-emerald-600 text-slate-950 shadow-[0_12px_18px_rgba(0,0,0,0.24)] transition hover:-translate-y-0.5 hover:bg-emerald-500`}>
                        <svg viewBox="0 0 24 24" className="h-5 w-5"><path d="M6 9V3h12v6" stroke="currentColor" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/><path d="M6 18h12v-6H6v6z" stroke="currentColor" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/><path d="M9 21h6" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/></svg>
                      </button>
                      {deliverySubTab === 'kitchen' && !order.deliveryAgent && (
                        <button type="button" title="Assign rider" onClick={() => openRiderAssignmentModal(order)} className="inline-flex h-11 w-11 items-center justify-center rounded-full border border-slate-700 bg-purple-600 text-white shadow-[0_12px_18px_rgba(0,0,0,0.24)] transition hover:-translate-y-0.5 hover:bg-purple-500">
                          <svg viewBox="0 0 24 24" className="h-5 w-5"><path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" fill="currentColor"/></svg>
                        </button>
                      )}
                      {renderOrderEditButton(order)}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
        <div className="flex flex-wrap items-center justify-between gap-4 rounded-3xl border border-slate-800 bg-slate-900 p-4 text-sm text-slate-300">
          <div>{filteredOrders.length ? (orderPageSize > 0 ? `Showing ${orderPageIndex * orderPageSize + 1}-${Math.min((orderPageIndex + 1) * orderPageSize, filteredOrders.length)} of ${filteredOrders.length} orders` : `Showing 1-${filteredOrders.length} of ${filteredOrders.length} orders`) : 'No orders available'}</div>
          <div className="flex flex-wrap items-center gap-2">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-400">Per page:</span>
            {[20, 50, 100, 'All'].map((size) => (
              <button
                key={size}
                onClick={() => {
                  setOrderPageSize(size === 'All' ? 0 : size);
                  setOrderPageIndex(0);
                }}
                className={`rounded-full px-3 py-1 text-xs font-semibold transition ${orderPageSize === (size === 'All' ? 0 : size) ? 'bg-cyan-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}
              >
                {size}
              </button>
            ))}
          </div>
          <div className="flex items-center gap-2">
            <button disabled={orderPageIndex === 0 || pageCount === 1} onClick={() => setOrderPageIndex((prev) => Math.max(prev - 1, 0))} className="rounded-full border border-slate-700 bg-slate-800 px-4 py-2 text-sm font-semibold text-slate-200 disabled:opacity-50 transition hover:bg-slate-700">← Prev</button>
            <span className="text-xs text-slate-400">Page {orderPageIndex + 1} of {pageCount}</span>
            <button disabled={orderPageIndex >= pageCount - 1 || pageCount === 1} onClick={() => setOrderPageIndex((prev) => Math.min(prev + 1, pageCount - 1))} className="rounded-full border border-slate-700 bg-slate-800 px-4 py-2 text-sm font-semibold text-slate-200 disabled:opacity-50 transition hover:bg-slate-700">Next →</button>
          </div>
        </div>
      </div>
    </div>
    );
  }

  function renderDeliverySettings() {
    return (
      <div className="space-y-6">
        <div className="flex flex-wrap gap-2">
          {['serviceTypes', 'locations'].map((tab) => (
            <button key={tab} onClick={() => setDeliverySettingsSubTab(tab)} className={`rounded-full px-4 py-2 text-sm font-semibold transition ${deliverySettingsSubTab === tab ? 'bg-emerald-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}>
              {tab === 'serviceTypes' ? 'Service Types' : 'Locations'}
            </button>
          ))}
        </div>
        {deliverySettingsSubTab === 'serviceTypes' && (
          <div className="grid gap-6 lg:grid-cols-[1fr_320px]">
            <div className="grid gap-4">
              {deliveryServiceTypes.map((type) => (
                <div key={type.id} className="rounded-3xl border border-slate-800 bg-slate-900 p-4 shadow-soft">
                  <div className="flex items-center justify-between gap-3">
                    <div>
                      <div className="text-lg font-semibold text-white">{type.name}</div>
                      <div className="text-sm text-slate-400">Charge: {type.charge} PKR</div>
                      {type.location && <div className="text-sm text-slate-500">Location: {type.location}</div>}
                    </div>
                    <div className="flex gap-2">
                      <button onClick={() => editDeliveryServiceType(type)} className="rounded-full border border-slate-700 bg-slate-800 p-3 text-slate-200 transition hover:bg-slate-700" title="Edit type">✏️</button>
                      <button onClick={() => deleteDeliveryServiceType(type.id)} className="rounded-full border border-slate-700 bg-rose-600 p-3 text-white transition hover:bg-rose-500" title="Delete type">🗑️</button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
            <div className="rounded-3xl border border-slate-800 bg-slate-900 p-5 shadow-soft">
              <div className="space-y-4">
                <div>
                  <p className="text-sm uppercase tracking-[0.2em] text-slate-400">Service Type</p>
                  <h3 className="mt-2 text-2xl font-semibold text-white">Add / Edit Type</h3>
                </div>
                <div className="grid gap-4">
                  <label className="block text-sm font-medium text-slate-200">Name</label>
                  <input value={deliveryServiceForm.name} onChange={(e) => setDeliveryServiceForm((prev) => ({ ...prev, name: e.target.value }))} className="rounded-3xl border border-slate-800 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" />
                  <label className="block text-sm font-medium text-slate-200">Charge</label>
                  <input type="number" value={deliveryServiceForm.charge} onChange={(e) => setDeliveryServiceForm((prev) => ({ ...prev, charge: Number(e.target.value) }))} className="rounded-3xl border border-slate-800 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" />
                  <label className="block text-sm font-medium text-slate-200">Location (optional)</label>
                  <input value={deliveryServiceForm.location} onChange={(e) => setDeliveryServiceForm((prev) => ({ ...prev, location: e.target.value }))} className="rounded-3xl border border-slate-800 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" />
                </div>
                <button onClick={saveDeliveryServiceType} className="w-full rounded-3xl bg-emerald-600 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-500">Save Service Type</button>
              </div>
            </div>
          </div>
        )}
        {deliverySettingsSubTab === 'locations' && (
          <div className="grid gap-6 lg:grid-cols-[1fr_320px]">
            <div className="grid gap-4">
              {deliveryLocations.map((location) => (
                <div key={location.id} className="rounded-3xl border border-slate-800 bg-slate-900 p-4 shadow-soft">
                  <div className="flex items-center justify-between gap-3">
                    <div>
                      <div className="text-lg font-semibold text-white">{location.name}</div>
                      <div className="text-sm text-slate-400">{location.description}</div>
                    </div>
                    <div className="flex gap-2">
                      <button onClick={() => editDeliveryLocation(location)} className="rounded-full border border-slate-700 bg-slate-800 p-3 text-slate-200 transition hover:bg-slate-700" title="Edit location">✏️</button>
                      <button onClick={() => deleteDeliveryLocation(location.id)} className="rounded-full border border-slate-700 bg-rose-600 p-3 text-white transition hover:bg-rose-500" title="Delete location">🗑️</button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
            <div className="rounded-3xl border border-slate-800 bg-slate-900 p-5 shadow-soft">
              <div className="space-y-4">
                <div>
                  <p className="text-sm uppercase tracking-[0.2em] text-slate-400">Delivery Location</p>
                  <h3 className="mt-2 text-2xl font-semibold text-white">Add / Edit Location</h3>
                </div>
                <div className="grid gap-4">
                  <label className="block text-sm font-medium text-slate-200">Name</label>
                  <input value={deliveryLocationForm.name} onChange={(e) => setDeliveryLocationForm((prev) => ({ ...prev, name: e.target.value }))} className="rounded-3xl border border-slate-800 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" />
                  <label className="block text-sm font-medium text-slate-200">Description</label>
                  <textarea value={deliveryLocationForm.description} onChange={(e) => setDeliveryLocationForm((prev) => ({ ...prev, description: e.target.value }))} rows={4} className="rounded-3xl border border-slate-800 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" />
                </div>
                <button onClick={saveDeliveryLocation} className="w-full rounded-3xl bg-emerald-600 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-500">Save Location</button>
              </div>
            </div>
          </div>
        )}
      </div>
    );
  }

  function renderOnlineOrders() {
    const onlineOrders = posOrders.filter((o) => o.orderType === 'Online');
    const filteredOrders = onlineOrders.filter((o) => {
      const matchesSearch = !orderSearch ||
        (o.orderNumber || o.id).toLowerCase().includes(orderSearch.toLowerCase()) ||
        (o.customerName || '').toLowerCase().includes(orderSearch.toLowerCase()) ||
        (o.phone || '').toLowerCase().includes(orderSearch.toLowerCase()) ||
        (o.address || '').toLowerCase().includes(orderSearch.toLowerCase());
      const matchesPayment = !orderFilterPayment || o.paymentMethod === orderFilterPayment;
      return matchesSearch && matchesPayment;
    });
    return (
      <div className="space-y-6">
        <div className="rounded-[32px] border border-slate-800 bg-slate-900 p-6 shadow-soft">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <p className="text-sm uppercase tracking-[0.2em] text-slate-400">Online orders</p>
              <h3 className="mt-2 text-2xl font-semibold text-white">Orders from catalogue scan</h3>
            </div>
            <div className="flex items-center gap-3">
              <input
                type="text"
                placeholder="Search online orders..."
                value={orderSearch}
                onChange={(e) => setOrderSearch(e.target.value)}
                className="w-64 rounded-full border border-slate-800 bg-slate-900 px-4 py-2 text-sm text-slate-100 outline-none focus:border-emerald-500"
              />
              <select value={orderFilterPayment} onChange={(e) => setOrderFilterPayment(e.target.value)} className="rounded-full border border-slate-800 bg-slate-900 px-4 py-2 text-sm text-slate-100 outline-none focus:border-emerald-500">
                <option value="">All payments</option>
                <option value="Online">Online</option>
                <option value="Cash">Cash</option>
                <option value="Card">Card</option>
              </select>
            </div>
          </div>
        </div>
        <div className="overflow-x-auto rounded-3xl border border-slate-800 bg-slate-950 p-4">
          <table className="w-full min-w-[720px] divide-y divide-slate-700 text-left text-sm text-slate-300">
            <thead className="bg-slate-900 text-slate-200">
              <tr>
                <th className="px-4 py-3">Order #</th>
                <th className="px-4 py-3">Customer</th>
                <th className="px-4 py-3">Phone</th>
                <th className="px-4 py-3">Total</th>
                <th className="px-4 py-3">Payment</th>
                <th className="px-4 py-3">Status</th>
                <th className="px-4 py-3">Date</th>
                <th className="px-4 py-3">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800 bg-slate-950">
              {filteredOrders.map((order) => (
                <tr key={order.id}>
                  <td className="px-4 py-3">{order.orderNumber || order.id}</td>
                  <td className="px-4 py-3">{order.customerName || 'Guest'}</td>
                  <td className="px-4 py-3">{order.phone || 'N/A'}</td>
                  <td className="px-4 py-3">{order.total || 0} PKR</td>
                  <td className="px-4 py-3">{order.paymentMethod || 'Online'}</td>
                  <td className="px-4 py-3"><span className={`inline-flex rounded-full px-3 py-1 text-xs font-semibold text-white ${getStatusBadge(order.status)}`}>{order.status}</span></td>
                  <td className="px-4 py-3">{order.createdAt || order.date || 'N/A'}{order.createdAt ? ` (${Math.max(0, Math.floor((Date.now() - new Date(order.createdAt).getTime()) / 60000))}m)` : ''}</td>
                  <td className="px-4 py-3">
                    <div className="flex flex-wrap gap-2">
                      {renderOrderEditButton(order)}
                      <button type="button" title="Delete order" onClick={() => requestDeleteOrder(order)} className="rounded-full border border-rose-600 bg-rose-600 px-3 py-1 text-xs font-semibold text-white hover:bg-rose-500">Delete</button>
                      <button type="button" title="Print order" onClick={() => printReceipt(order)} className="rounded-full border border-emerald-600 bg-emerald-600 px-3 py-1 text-xs font-semibold text-slate-950 hover:bg-emerald-500">Print</button>
                    </div>
                  </td>
                </tr>
              ))}
              {!filteredOrders.length && (
                <tr>
                  <td colSpan={7} className="px-4 py-6 text-center text-sm text-slate-500">No online orders found.</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    );
  }

  function renderTakeawayOrders() {
    const takeawayOrders = posOrders.filter((o) => o.orderType === 'Takeaway');
    
    // Filter logic for each tab
    const filteredTakeaway = takeawayOrders.filter((o) => {
      if (takeawaySubTab === 'all') return true;
      if (takeawaySubTab === 'paid') return o.status === 'Completed';
      if (takeawaySubTab === 'pay-later') return o.status === 'Pay Later';
      if (takeawaySubTab === 'due') return o.status === 'Due';
      return true;
    });

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const getDateRange = () => {
      const from = new Date(today);
      const to = new Date(today);

      if (takeawayDateFilter === 'today') {
        return { from: new Date(today), to: new Date(today.getTime() + 24 * 60 * 60 * 1000) };
      } else if (takeawayDateFilter === 'yesterday') {
        const yesterday = new Date(today);
        yesterday.setDate(yesterday.getDate() - 1);
        return { from: new Date(yesterday), to: new Date(today) };
      } else if (takeawayDateFilter === 'previous-5-days') {
        const fiveDaysAgo = new Date(today);
        fiveDaysAgo.setDate(fiveDaysAgo.getDate() - 5);
        return { from: new Date(fiveDaysAgo), to: new Date(today.getTime() + 24 * 60 * 60 * 1000) };
      } else if (takeawayDateFilter === 'custom') {
        return {
          from: new Date(takeawayCustomDateFrom + 'T00:00:00'),
          to: new Date(takeawayCustomDateTo + 'T23:59:59')
        };
      }
      return { from: null, to: null };
    };

    const { from, to } = getDateRange();
    const dateFilteredOrders = filteredTakeaway.filter((order) => {
      if (!from || !to) return true;
      const orderDate = order.createdAt ? new Date(order.createdAt) : order.date ? new Date(order.date) : null;
      return orderDate ? orderDate >= from && orderDate <= to : false;
    });

    const duePageCount = Math.max(1, Math.ceil(dateFilteredOrders.length / takeawayPageSize));
    const paginatedDueOrders = dateFilteredOrders.slice(takeawayPageIndex * takeawayPageSize, (takeawayPageIndex + 1) * takeawayPageSize);
    const displayOrders = takeawaySubTab === 'due' ? paginatedDueOrders : dateFilteredOrders;

    return (
      <div className="space-y-6">
        {/* Tab Navigation */}
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="flex flex-wrap gap-2">
            {['pay-later', 'all', 'paid', 'due'].map((status) => (
              <button
                key={status}
                onClick={() => {
                  setTakeawaySubTab(status);
                  setTakeawayPageIndex(0);
                  setSelectedTakeawayOrders([]);
                }}
                className={`rounded-full px-3 py-1 text-xs font-semibold transition ${takeawaySubTab === status ? 'bg-emerald-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}
              >
                {status === 'paid' ? '💳 Paid Orders' : status === 'pay-later' ? '⏳ Pay Later' : status === 'due' ? '📍 Due Payment' : '📋 All Orders'}
              </button>
            ))}
          </div>
          <div className="flex items-center gap-2 text-slate-300">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-500">View</span>
            <button type="button" onClick={() => setTakeawayViewMode('tile')} className={`inline-flex h-10 w-10 items-center justify-center rounded-full border border-slate-700 bg-slate-900 text-slate-200 transition ${takeawayViewMode === 'tile' ? 'bg-emerald-600 text-white' : 'hover:bg-slate-800'}`} title="Tile view">
              <svg viewBox="0 0 24 24" className="h-5 w-5"><path d="M4 4h7v7H4V4zm9 0h7v4h-7V4zM4 13h7v7H4v-7zm9 5h7v2h-7v-2z" fill="currentColor"/></svg>
            </button>
            <button type="button" onClick={() => setTakeawayViewMode('table')} className={`inline-flex h-10 w-10 items-center justify-center rounded-full border border-slate-700 bg-slate-900 text-slate-200 transition ${takeawayViewMode === 'table' ? 'bg-emerald-600 text-white' : 'hover:bg-slate-800'}`} title="Table view">
              <svg viewBox="0 0 24 24" className="h-5 w-5"><path d="M4 4h16v4H4V4zm0 6h16v4H4v-4zm0 6h16v4H4v-4z" fill="currentColor"/></svg>
            </button>
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-3 rounded-3xl border border-slate-800 bg-slate-900 p-4">
          <div className="flex flex-wrap items-center gap-2">
            <span className="text-xs uppercase tracking-[0.2em] text-slate-400">Filter by Date:</span>
            {['today', 'yesterday', 'previous-5-days', 'custom'].map((filter) => (
              <button
                key={filter}
                onClick={() => {
                  setTakeawayDateFilter(filter);
                  setTakeawayPageIndex(0);
                }}
                className={`rounded-full px-3 py-1 text-xs font-semibold transition ${takeawayDateFilter === filter ? 'bg-cyan-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}
              >
                {filter === 'today' ? '📅 Today' : filter === 'yesterday' ? '📅 Yesterday' : filter === 'previous-5-days' ? '📅 Last 5 Days' : '📅 Custom'}
              </button>
            ))}
          </div>
          {takeawayDateFilter === 'custom' && (
            <div className="flex flex-wrap items-center gap-2">
              <input
                type="date"
                value={takeawayCustomDateFrom}
                onChange={(e) => {
                  setTakeawayCustomDateFrom(e.target.value);
                  setTakeawayPageIndex(0);
                }}
                className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-xs text-slate-200 focus:outline-none"
              />
              <span className="text-slate-400">to</span>
              <input
                type="date"
                value={takeawayCustomDateTo}
                onChange={(e) => {
                  setTakeawayCustomDateTo(e.target.value);
                  setTakeawayPageIndex(0);
                }}
                className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-xs text-slate-200 focus:outline-none"
              />
            </div>
          )}
        </div>

        {/* Selection Toolbar */}
        {selectedTakeawayOrders.length > 0 && (
          <div className="flex items-center justify-between rounded-3xl border border-slate-800 bg-slate-900 p-4">
            <div className="text-sm text-slate-300">
              {selectedTakeawayOrders.length} takeaway order{selectedTakeawayOrders.length > 1 ? 's' : ''} selected
            </div>
            <div className="flex gap-2 flex-wrap">
              {takeawaySubTab === 'pay-later' && (
                <button onClick={markSelectedTakeawayOrdersDue} className="rounded-3xl border border-red-700 bg-red-600 px-4 py-2 text-sm font-semibold text-white transition hover:bg-red-500">
                  Mark Due
                </button>
              )}
              {takeawaySubTab === 'due' && (
                <button onClick={markSelectedTakeawayOrdersPaid} className="rounded-3xl border border-emerald-700 bg-emerald-600 px-4 py-2 text-sm font-semibold text-white transition hover:bg-emerald-500">
                  ✓ Mark Paid
                </button>
              )}
              <button onClick={clearTakeawaySelection} className="rounded-3xl border border-slate-700 bg-slate-800 px-4 py-2 text-sm font-semibold text-slate-200 transition hover:bg-slate-700">Clear</button>
              <button onClick={deleteMultipleTakeawayOrders} className="rounded-3xl border border-rose-700 bg-rose-600 px-4 py-2 text-sm font-semibold text-white transition hover:bg-rose-500">Delete Selected</button>
            </div>
          </div>
        )}

        {/* Table View */}
        {takeawayViewMode === 'table' ? (
          <div className="overflow-x-auto rounded-[32px] border border-slate-800 bg-slate-900 p-4 shadow-soft">
            <table className="w-full min-w-[950px] text-left text-sm text-slate-100">
              <thead className="border-b border-slate-800 text-slate-400">
                <tr>
                  <th className="px-4 py-3">
                    <input
                      type="checkbox"
                      checked={displayOrders.length > 0 && selectedTakeawayOrders.length === displayOrders.length && displayOrders.every(o => selectedTakeawayOrders.includes(o.id))}
                      onChange={(e) => e.target.checked ? selectAllTakeawayOrders(displayOrders) : clearTakeawaySelection()}
                      className="h-4 w-4 rounded border-slate-700 bg-slate-900 text-emerald-600 focus:ring-emerald-500"
                    />
                  </th>
                  <th className="px-4 py-3">Order #</th>
                  <th className="px-4 py-3">Customer</th>
                  <th className="px-4 py-3">Phone</th>
                  <th className="px-4 py-3">Items</th>
                  <th className="px-4 py-3">Total</th>
                  <th className="px-4 py-3">Status</th>
                  <th className="px-4 py-3">Date</th>
                  <th className="px-4 py-3">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800">
                {displayOrders.length > 0 ? (
                  displayOrders.map((order) => (
                    <tr key={order.id} className="hover:bg-slate-950/80 transition">
                      <td className="px-4 py-4">
                        <input
                          type="checkbox"
                          checked={selectedTakeawayOrders.includes(order.id)}
                          onChange={() => toggleTakeawaySelection(order.id)}
                          className="h-4 w-4 rounded border-slate-700 bg-slate-900 text-emerald-600 focus:ring-emerald-500"
                        />
                      </td>
                      <td className="px-4 py-4 font-semibold text-white">{order.orderNumber || order.id}</td>
                      <td className="px-4 py-4 text-slate-300">{order.customerName || 'PICK UP'}</td>
                      <td className="px-4 py-4 text-slate-300">{order.phone || '-'}</td>
                      <td className="px-4 py-4 text-slate-300">
                        <div className="flex items-center gap-2">
                          <span>{(order.items || []).length} item{(order.items || []).length === 1 ? '' : 's'}</span>
                          <button type="button" onClick={() => setOrderDetailsModal(order)} title="View items" className="inline-flex h-8 w-8 items-center justify-center rounded-full border border-slate-700 bg-slate-900 text-slate-200 hover:bg-slate-800">
                            <svg viewBox="0 0 24 24" className="h-4 w-4"><path d="M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5C21.27 7.61 17 4.5 12 4.5zm0 12c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5zm0-8.5a3.5 3.5 0 1 0 0 7 3.5 3.5 0 0 0 0-7z" fill="currentColor"/></svg>
                          </button>
                        </div>
                      </td>
                      <td className="px-4 py-4 font-semibold text-white">{order.total || order.amount || 0} Rs</td>
                      <td className="px-4 py-4"><span className={`inline-flex rounded-full px-3 py-1 text-xs font-semibold ${getStatusBadge(order.status)}`}>{order.status || 'Pending'}</span></td>
                      <td className="px-4 py-4 text-slate-400">{order.createdAt ? new Date(order.createdAt).toLocaleString() : '-'}</td>
                      <td className="px-4 py-4">
                        <div className="flex flex-wrap gap-2">
                          {order.status === 'Pay Later' && (
                            <button type="button" title="Mark Pay Later order as paid" onClick={() => markTakeawayOrderPaid(order.id)} className="rounded-full border border-amber-500 bg-amber-500 px-3 py-2 text-slate-950 transition hover:bg-amber-400">✓ Paid</button>
                          )}
                          {renderOrderEditButton(order)}
                          <button type="button" title="Delete order" onClick={() => deleteOrder(order.id)} className="rounded-full border border-rose-600 bg-rose-600 px-3 py-2 text-white transition hover:bg-rose-500">Delete</button>
                          <button type="button" title="Print order" onClick={() => printReceipt(order)} className="rounded-full border border-emerald-600 bg-emerald-600 px-3 py-2 text-slate-950 transition hover:bg-emerald-500">Print</button>
                        </div>
                      </td>
                    </tr>
                  ))
                ) : (
                  <tr>
                    <td colSpan="9" className="px-4 py-6 text-center text-sm text-slate-500">No orders found for this filter.</td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {displayOrders.length > 0 ? (
              displayOrders.map((order) => {
                const isSelected = selectedTakeawayOrders.includes(order.id);
                return (
                  <div key={order.id} className="rounded-3xl border border-slate-800 bg-slate-900 p-5 shadow-soft hover:shadow-lg transition relative">
                    <div className="absolute top-4 right-4">
                      <input
                        type="checkbox"
                        checked={isSelected}
                        onChange={() => toggleTakeawaySelection(order.id)}
                        className="h-4 w-4 rounded border-slate-700 bg-slate-900 text-emerald-600 focus:ring-emerald-500"
                      />
                    </div>
                    <div className="text-lg font-semibold text-white">{order.orderNumber || order.id}</div>
                    <div className="mt-3 text-sm text-slate-300">{order.customerName || 'PICK UP'}</div>
                    <div className="mt-2 text-sm text-slate-400">{order.phone || '-'}</div>
                    <div className="mt-4 rounded-3xl border border-slate-800 bg-slate-950 p-4 text-sm text-slate-200 max-h-32 overflow-y-auto">
                      <div className="mb-2 text-xs uppercase tracking-[0.24em] text-slate-500">Items</div>
                      {(order.items || []).slice(0, 4).map((item, index) => (
                        <div key={index} className="flex items-center justify-between py-1 border-b border-slate-800 last:border-b-0">
                          <span className="truncate">{item.name || 'Unknown'}</span>
                          <span className="ml-2 text-slate-400">x{item.quantity || 1}</span>
                        </div>
                      ))}
                      {(order.items || []).length > 4 && <div className="mt-2 text-xs text-slate-500">+{(order.items || []).length - 4} more</div>}
                    </div>
                    <div className="mt-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                      <div>
                        <p className="text-xs uppercase tracking-[0.24em] text-slate-400">Total</p>
                        <div className="text-xl font-semibold text-white">{order.total || order.amount || 0} Rs</div>
                      </div>
                      <div className="flex flex-wrap items-center gap-2">
                        {order.status === 'Pay Later' && (
                          <button onClick={() => markTakeawayOrderPaid(order.id)} className="rounded-3xl bg-amber-500 px-4 py-3 text-sm font-semibold text-slate-950 hover:bg-amber-400">✓ Paid</button>
                        )}
                        {renderOrderEditButton(order)}
                        <button onClick={() => deleteOrder(order.id)} className="inline-flex h-11 w-11 items-center justify-center rounded-full border border-slate-700 bg-rose-600 text-white hover:bg-rose-500" title="Delete order">
                          <svg viewBox="0 0 24 24" className="h-5 w-5"><path d="M3 6h18" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/><path d="M8 6V4h8v2" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/><path d="M19 6l-1 14H6L5 6" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/><path d="M10 11v6" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/><path d="M14 11v6" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/></svg>
                        </button>
                        <button onClick={() => printReceipt(order)} className="inline-flex h-11 w-11 items-center justify-center rounded-full border border-slate-700 bg-emerald-600 text-slate-950 hover:bg-emerald-500" title="Print order">
                          <svg viewBox="0 0 24 24" className="h-5 w-5"><path d="M6 9V3h12v6" stroke="currentColor" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/><path d="M6 18h12v-6H6v6z" stroke="currentColor" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/><path d="M9 21h6" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/></svg>
                        </button>
                      </div>
                    </div>
                  </div>
                );
              })
            ) : (
              <div className="col-span-full flex items-center justify-center rounded-3xl border border-slate-800 bg-slate-900 p-12">
                <p className="text-slate-400">No orders found for this filter.</p>
              </div>
            )}
          </div>
        )}

        {/* Due Payment Tab - Pagination */}
        {takeawaySubTab === 'due' && dateFilteredOrders.length > 0 && (
          <div className="flex flex-wrap items-center justify-between gap-4 rounded-3xl border border-slate-800 bg-slate-900 p-4">
            <div className="text-sm text-slate-300">
              Showing {takeawayPageIndex * takeawayPageSize + 1}-{Math.min((takeawayPageIndex + 1) * takeawayPageSize, dateFilteredOrders.length)} of {dateFilteredOrders.length} orders
            </div>
            <div className="flex flex-wrap items-center gap-2">
              <span className="text-xs uppercase tracking-[0.2em] text-slate-400">Per page:</span>
              {[10, 20, 100].map((size) => (
                <button
                  key={size}
                  onClick={() => {
                    setTakeawayPageSize(size);
                    setTakeawayPageIndex(0);
                  }}
                  className={`rounded-full px-3 py-1 text-xs font-semibold transition ${takeawayPageSize === size ? 'bg-cyan-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}
                >
                  {size}
                </button>
              ))}
            </div>
            <div className="flex items-center gap-2">
              <button
                onClick={() => setTakeawayPageIndex(Math.max(0, takeawayPageIndex - 1))}
                disabled={takeawayPageIndex === 0}
                className="rounded-full border border-slate-700 bg-slate-800 px-4 py-2 text-sm font-semibold text-slate-200 disabled:opacity-50 transition hover:bg-slate-700"
              >
                ← Prev
              </button>
              <span className="text-xs text-slate-400">Page {takeawayPageIndex + 1} of {duePageCount}</span>
              <button
                onClick={() => setTakeawayPageIndex(takeawayPageIndex + 1)}
                disabled={(takeawayPageIndex + 1) * takeawayPageSize >= dateFilteredOrders.length}
                className="rounded-full border border-slate-700 bg-slate-800 px-4 py-2 text-sm font-semibold text-slate-200 disabled:opacity-50 transition hover:bg-slate-700"
              >
                Next →
              </button>
            </div>
          </div>
        )}
      </div>
    );
  }

  function renderDineinOrders() {
    const dineinOrders = posOrders.filter((o) => o.orderType === 'Dine-In');
    const parsedOrders = dineinOrders.map((order) => ({
      ...order,
      orderDate: order.createdAt ? new Date(order.createdAt) : order.date ? new Date(order.date) : null
    }));

    const dateFrom = dineinDateFrom ? new Date(dineinDateFrom) : null;
    const dateTo = dineinDateTo ? new Date(dineinDateTo) : null;

    const filteredByDate = parsedOrders.filter((order) => {
      if (!order.orderDate) return true;
      if (dateFrom && order.orderDate < dateFrom) return false;
      if (dateTo && order.orderDate > dateTo) return false;
      return true;
    });

    const filteredBySearch = filteredByDate.filter((order) => {
      const search = dineinOrderSearch.trim().toLowerCase();
      if (!search) return true;
      return [order.orderNumber, order.customerName, order.phone, order.tableNumber, order.status, order.notes]
        .filter(Boolean)
        .some((value) => value.toString().toLowerCase().includes(search));
    });

    let statusFiltered;
    if (dineinSubTab === 'paid') {
      statusFiltered = filteredBySearch.filter((order) => ['Completed', 'Payment Collected'].includes(order.status));
    } else if (dineinSubTab === 'due') {
      statusFiltered = filteredBySearch.filter((order) => order.status === 'Payment Pending' || order.status === 'Pay Later' || order.paymentStatus === 'Due');
    } else {
      statusFiltered = dineinOrderStatusFilter === 'all'
        ? filteredBySearch
        : filteredBySearch.filter((order) => {
            if (dineinOrderStatusFilter === 'paid') {
              return ['Completed', 'Payment Collected'].includes(order.status);
            }
            if (dineinOrderStatusFilter === 'pending') {
              return !['Completed', 'Payment Collected'].includes(order.status);
            }
            return order.status === dineinOrderStatusFilter;
          });
    }

    const summary = {
      orderCount: statusFiltered.length,
      totalSales: statusFiltered.reduce((sum, order) => sum + Number(order.total || order.amount || 0), 0),
      itemCount: statusFiltered.reduce((sum, order) => sum + (order.items?.reduce((count, item) => count + Number(item.quantity || 0), 0) || 0), 0)
    };

    const totalDineinPages = Math.max(1, Math.ceil(statusFiltered.length / dineinPageSize));
    const pagedDineinOrders = statusFiltered.slice(dineinPageIndex * dineinPageSize, (dineinPageIndex + 1) * dineinPageSize);

    const floorTables = posTables.filter((table) => (table.section || 'Floor') === 'Floor');
    const outsideTables = posTables.filter((table) => (table.section || 'Floor') === 'Outside');

    return (
      <div className="space-y-6">
        <div className="flex flex-wrap items-center gap-3">
          {['tables', 'paid', 'due'].map((tab) => (
            <button
              key={tab}
              onClick={() => {
                setDineinSubTab(tab);
                if (tab === 'paid') setDineinOrderStatusFilter('paid');
                if (tab === 'due') setDineinOrderStatusFilter('pending');
              }}
              className={`rounded-full px-4 py-2 text-sm font-semibold transition ${dineinSubTab === tab ? 'bg-emerald-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}>
              {tab === 'tables' ? '🍽️ Table Management' : tab === 'paid' ? '💳 Paid Orders' : '📍 Due Orders'}
            </button>
          ))}
        </div>


        {dineinSubTab === 'tables' && (
          <div className="space-y-6">
            <div className="grid gap-4 lg:grid-cols-2">
              <div className="rounded-[32px] border border-slate-800 bg-slate-900 p-5 shadow-soft">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm uppercase tracking-[0.2em] text-slate-400">Floor tables</p>
                    <h4 className="mt-2 text-lg font-semibold text-white">In hotel floor</h4>
                  </div>
                  <span className="rounded-full bg-slate-800 px-3 py-1 text-xs text-slate-200">{floorTables.length}</span>
                </div>
                <div className="mt-4 grid gap-6 sm:grid-cols-1 md:grid-cols-2 lg:grid-cols-3">
                  {floorTables.map((table) => {
                    const tableLabel = getTableLabel(table);
                    const tableOrder = dineinOrders.find((o) => normalizeText(o.tableNumber) === normalizeText(tableLabel) && !['completed', 'payment collected'].includes(normalizeText(o.status)));
                    const waiters = staff.filter((member) => member.role === 'Waiter' && member.loginEnabled);
                    return (
                      <div key={table.id} className={`rounded-3xl border p-6 ${tableOrder ? 'border-amber-600 bg-amber-950' : 'border-slate-700 bg-slate-950'} min-h-[200px]`}>
                        <div className="flex items-center justify-between gap-3">
                          <div>
                            <div className="font-semibold text-white text-base">{table.label || table.name || `Table ${table.id}`}</div>
                            <div className="text-[11px] text-slate-400">{table.capacity || 4} seats</div>
                          </div>
                          <span className={`rounded-full px-3 py-1 text-sm font-semibold ${tableOrder ? 'bg-amber-500 text-slate-950' : 'bg-emerald-600 text-white'}`}>
                            {tableOrder ? 'Occupied' : 'Available'}
                          </span>
                        </div>
                        {tableOrder ? (
                          <div className="mt-4 space-y-3">
                            <div className="text-slate-300 text-sm">
                              <div className="font-medium text-sm">Order: {tableOrder.orderNumber}</div>
                              <div className="mt-1 text-sm">Status: {tableOrder.status}</div>
                              <div className="mt-1 text-sm">Customer: {tableOrder.customerName || 'TABLE'}</div>
                            </div>
                            <div className="text-slate-300 text-sm">
                              <div className="font-medium text-sm">Items:</div>
                              <div className="mt-2 max-h-28 overflow-y-auto space-y-1">
                                {(tableOrder.items || []).map((item, idx) => (
                                  <div key={idx} className="text-sm leading-6">{item.quantity}x {item.name}</div>
                                ))}
                              </div>
                              <div className="mt-2 font-semibold text-white">Total: {tableOrder.total || tableOrder.amount || 0} PKR</div>
                            </div>
                            <div className="flex items-center gap-2">
                              <label className="text-xs text-slate-400">Waiter:</label>
                              <select
                                value={tableOrder.waiter || ''}
                                onChange={(e) => assignWaiterToOrder(tableOrder.id, e.target.value)}
                                className="flex-1 rounded border border-slate-600 bg-slate-900 px-2 py-1 text-sm text-slate-100 outline-none"
                              >
                                <option value="">Select Waiter</option>
                                {waiters.map((waiter) => (
                                  <option key={waiter.id} value={waiter.name}>{waiter.name}</option>
                                ))}
                              </select>
                            </div>
                            <div className="flex flex-wrap gap-2 mt-3">
                              <button onClick={() => printReceipt(tableOrder)} className="rounded px-3 py-1 text-sm font-semibold bg-green-600 text-white hover:bg-green-500 transition">Print</button>
                              {renderOrderEditButton(tableOrder)}
                              <button onClick={() => deleteOrder(tableOrder.id)} className="rounded px-3 py-1 text-sm font-semibold bg-red-600 text-white hover:bg-red-500 transition">Delete</button>
                              {tableOrder.status !== 'Completed' && tableOrder.status !== 'Payment Collected' && (
                                <>
                                  <button onClick={() => confirmMarkPaid(tableOrder)} className="rounded px-3 py-1 text-sm font-semibold bg-amber-600 text-white hover:bg-amber-500 transition">Mark Paid</button>
                                  <button onClick={() => confirmMarkDue(tableOrder)} className="rounded px-3 py-1 text-sm font-semibold bg-rose-600 text-white hover:bg-rose-500 transition">Mark Due</button>
                                </>
                              )}
                            </div>
                          </div>
                        ) : (
                          <div className="mt-4 text-center text-slate-400 text-sm">
                            Table available
                          </div>
                        )}
                      </div>
                    );
                  })}
                </div>
              </div>
              <div className="rounded-[32px] border border-slate-800 bg-slate-900 p-5 shadow-soft">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm uppercase tracking-[0.2em] text-slate-400">Outside tables</p>
                    <h4 className="mt-2 text-lg font-semibold text-white">Outside hotel</h4>
                  </div>
                  <span className="rounded-full bg-slate-800 px-3 py-1 text-xs text-slate-200">{outsideTables.length}</span>
                </div>
                <div className="mt-4 grid gap-6 sm:grid-cols-1 md:grid-cols-2 lg:grid-cols-3">
                  {outsideTables.map((table) => {
                    const tableLabel = getTableLabel(table);
                    const tableOrder = dineinOrders.find((o) => normalizeText(o.tableNumber) === normalizeText(tableLabel) && !['completed', 'payment collected'].includes(normalizeText(o.status)));
                    const waiters = staff.filter((member) => member.role === 'Waiter' && member.loginEnabled);
                    return (
                      <div key={table.id} className={`rounded-3xl border p-6 ${tableOrder ? 'border-amber-600 bg-amber-950' : 'border-slate-700 bg-slate-950'} min-h-[200px]`}>
                        <div className="flex items-center justify-between gap-3">
                          <div>
                            <div className="font-semibold text-white text-base">{table.label || table.name || `Table ${table.id}`}</div>
                            <div className="text-[11px] text-slate-400">{table.capacity || 4} seats</div>
                          </div>
                          <span className={`rounded-full px-3 py-1 text-sm font-semibold ${tableOrder ? 'bg-amber-500 text-slate-950' : 'bg-emerald-600 text-white'}`}>
                            {tableOrder ? 'Occupied' : 'Available'}
                          </span>
                        </div>
                        {tableOrder ? (
                          <div className="mt-4 space-y-3">
                            <div className="text-slate-300 text-sm">
                              <div className="font-medium text-sm">Order: {tableOrder.orderNumber}</div>
                              <div className="mt-1 text-sm">Status: {tableOrder.status}</div>
                              <div className="mt-1 text-sm">Customer: {tableOrder.customerName || 'TABLE'}</div>
                            </div>
                            <div className="text-slate-300 text-sm">
                              <div className="font-medium text-sm">Items:</div>
                              <div className="mt-2 max-h-28 overflow-y-auto space-y-1">
                                {(tableOrder.items || []).map((item, idx) => (
                                  <div key={idx} className="text-sm leading-6">{item.quantity}x {item.name}</div>
                                ))}
                              </div>
                              <div className="mt-2 font-semibold text-white">Total: {tableOrder.total || tableOrder.amount || 0} PKR</div>
                            </div>
                            <div className="flex items-center gap-2">
                              <label className="text-xs text-slate-400">Waiter:</label>
                              <select
                                value={tableOrder.waiter || ''}
                                onChange={(e) => assignWaiterToOrder(tableOrder.id, e.target.value)}
                                className="flex-1 rounded border border-slate-600 bg-slate-900 px-2 py-1 text-sm text-slate-100 outline-none"
                              >
                                <option value="">Select Waiter</option>
                                {waiters.map((waiter) => (
                                  <option key={waiter.id} value={waiter.name}>{waiter.name}</option>
                                ))}
                              </select>
                            </div>
                            <div className="flex flex-wrap gap-2 mt-3">
                              <button onClick={() => printReceipt(tableOrder)} className="rounded px-3 py-1 text-sm font-semibold bg-green-600 text-white hover:bg-green-500 transition">Print</button>
                              {renderOrderEditButton(tableOrder)}
                              <button onClick={() => deleteOrder(tableOrder.id)} className="rounded px-3 py-1 text-sm font-semibold bg-red-600 text-white hover:bg-red-500 transition">Delete</button>
                              {tableOrder.status !== 'Completed' && tableOrder.status !== 'Payment Collected' && (
                                <>
                                  <button onClick={() => confirmMarkPaid(tableOrder)} className="rounded px-3 py-1 text-sm font-semibold bg-amber-600 text-white hover:bg-amber-500 transition">Mark Paid</button>
                                  <button onClick={() => confirmMarkDue(tableOrder)} className="rounded px-3 py-1 text-sm font-semibold bg-rose-600 text-white hover:bg-rose-500 transition">Mark Due</button>
                                </>
                              )}
                            </div>
                          </div>
                        ) : (
                          <div className="mt-4 text-center text-slate-400 text-sm">
                            Table available
                          </div>
                        )}
                      </div>
                    );
                  })}
                </div>
              </div>
            </div>
          </div>
        )}

        {dineinSubTab === 'paid' && (
          <div className="space-y-4">
            <div className="rounded-[32px] border border-slate-800 bg-slate-900 p-5 shadow-soft">
              <div className="flex flex-wrap items-center justify-between gap-3">
                <div className="flex items-center gap-3">
                  <button onClick={deleteSelectedDineinOrders} disabled={!selectedDineinOrders.length} className={`rounded-full px-4 py-2 text-sm font-semibold transition ${selectedDineinOrders.length ? 'bg-rose-600 text-white hover:bg-rose-500' : 'bg-slate-700 text-slate-400 cursor-not-allowed'}`}>
                    Delete Selected ({selectedDineinOrders.length})
                  </button>
                  <span className="text-sm text-slate-400">Showing {pagedDineinOrders.length} of {statusFiltered.length}</span>
                </div>
                <div className="flex items-center gap-3">
                  <label className="text-sm text-slate-400">Per page</label>
                  <select value={dineinPageSize} onChange={(e) => { setDineinPageSize(Number(e.target.value)); setDineinPageIndex(0); }} className="rounded-3xl border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-100 outline-none">
                    {[8, 12, 16, 20].map((size) => <option key={size} value={size}>{size}</option>)}
                  </select>
                </div>
              </div>
            </div>
            <div className="grid gap-4">
              <div className="overflow-x-auto rounded-3xl border border-slate-800 bg-slate-950 p-4">
                <table className="w-full min-w-[900px] divide-y divide-slate-700 text-left text-sm text-slate-300">
                  <thead className="bg-slate-900 text-slate-200">
                    <tr>
                      <th className="px-4 py-3">Select</th>
                      <th className="px-4 py-3">Order #</th>
                      <th className="px-4 py-3">Table</th>
                      <th className="px-4 py-3">Waiter</th>
                      <th className="px-4 py-3">Customer</th>
                      <th className="px-4 py-3">Items</th>
                      <th className="px-4 py-3">Total</th>
                      <th className="px-4 py-3">Payment</th>
                      <th className="px-4 py-3">Status</th>
                      <th className="px-4 py-3">Date</th>
                      <th className="px-4 py-3">Actions</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-800 bg-slate-950">
                    {pagedDineinOrders.map((order) => (
                      <tr key={order.id}>
                        <td className="px-4 py-3"><input type="checkbox" checked={selectedDineinOrders.includes(order.id)} onChange={() => toggleDineinOrderSelection(order.id)} className="h-4 w-4 rounded border-slate-600 bg-slate-950 text-emerald-500" /></td>
                        <td className="px-4 py-3">{order.orderNumber || order.id}</td>
                        <td className="px-4 py-3">{order.tableNumber || 'N/A'}</td>
                        <td className="px-4 py-3">{order.waiter || '-'}</td>
                        <td className="px-4 py-3">{order.customerName || 'TABLE'}</td>
                        <td className="px-4 py-3">{(order.items || []).reduce((c, it) => c + Number(it.quantity || 0), 0)}</td>
                        <td className="px-4 py-3">{order.total || order.amount || 0} PKR</td>
                        <td className="px-4 py-3">{order.paymentMethod || order.paymentStatus || '-'}</td>
                        <td className="px-4 py-3"><span className={`inline-flex rounded-full px-3 py-1 text-xs font-semibold text-white ${getStatusBadge(order.status)}`}>{order.status || 'Pending'}</span></td>
                        <td className="px-4 py-3">{order.orderDate ? order.orderDate.toLocaleString() : order.createdAt || order.date || 'N/A'}</td>
                        <td className="px-4 py-3">
                          <div className="flex items-center gap-2">
                            <button onClick={() => openOrderForEditInPos(order)} className="rounded px-2 py-1 bg-violet-500 text-white text-xs">Edit</button>
                            <button onClick={() => deleteOrder(order.id)} className="rounded px-2 py-1 bg-rose-600 text-white text-xs">Delete</button>
                            <button onClick={() => printReceipt(order)} className="rounded px-2 py-1 bg-emerald-600 text-white text-xs">Print</button>
                            {order.status !== 'Completed' && order.status !== 'Payment Collected' ? (
                              <>
                                <button onClick={() => confirmMarkPaid(order)} className="rounded px-2 py-1 bg-amber-600 text-slate-950 text-xs">Mark Paid</button>
                                <button onClick={() => confirmMarkDue(order)} className="rounded px-2 py-1 bg-rose-600 text-white text-xs">Mark Due</button>
                              </>
                            ) : null}
                          </div>
                        </td>
                      </tr>
                    ))}
                    {!pagedDineinOrders.length && (
                      <tr>
                        <td colSpan={11} className="px-4 py-6 text-center text-sm text-slate-500">No orders found.</td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </div>
              <div className="flex items-center justify-between gap-3 rounded-3xl border border-slate-800 bg-slate-950 p-4 text-sm text-slate-400">
                <span>Page {dineinPageIndex + 1} of {totalDineinPages}</span>
                <div className="flex items-center gap-2">
                  <button disabled={dineinPageIndex <= 0} onClick={() => setDineinPageIndex((prev) => Math.max(prev - 1, 0))} className="rounded-full border border-slate-700 bg-slate-900 px-3 py-2 text-xs font-semibold text-white disabled:cursor-not-allowed disabled:opacity-50">Previous</button>
                  <button disabled={dineinPageIndex >= totalDineinPages - 1} onClick={() => setDineinPageIndex((prev) => Math.min(prev + 1, totalDineinPages - 1))} className="rounded-full border border-slate-700 bg-slate-900 px-3 py-2 text-xs font-semibold text-white disabled:cursor-not-allowed disabled:opacity-50">Next</button>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    );
  }

  if (isMobileRiderRoute) {
    return (
      <div className="min-h-screen bg-slate-950 text-slate-100">
        <RidersApp />
      </div>
    );
  }

  if (!token || !user) {
    const getGreeting = () => {
      const now = new Date();
      const pkTime = new Date(now.toLocaleString('en-US', { timeZone: 'Asia/Karachi' }));
      const hour = pkTime.getHours();
      if (hour >= 5 && hour < 12) return 'Good Morning';
      if (hour >= 12 && hour < 17) return 'Good Afternoon';
      if (hour >= 17 && hour < 21) return 'Good Evening';
      return 'Good Night';
    };

    const greeting = getGreeting();
    const greetingEmoji = greeting === 'Good Morning' ? '🌅' : greeting === 'Good Afternoon' ? '☀️' : greeting === 'Good Evening' ? '🌆' : '🌙';

    const bbqImages = [
      'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=400&h=400&fit=crop',
      'https://images.unsplash.com/photo-1544025162-d76694265947?w=400&h=400&fit=crop',
      'https://images.unsplash.com/photo-1529193591184-b1d58069ecdd?w=400&h=400&fit=crop',
      'https://images.unsplash.com/photo-1559847844-5315695dadae?w=400&h=400&fit=crop',
      'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=400&h=400&fit=crop',
      'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=400&h=400&fit=crop',
      'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400&h=400&fit=crop',
      'https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?w=400&h=400&fit=crop',
      'https://images.unsplash.com/photo-1565958011703-44f9829ba187?w=400&h=400&fit=crop',
      'https://images.unsplash.com/photo-1482049016688-2d3e1b311543?w=400&h=400&fit=crop',
      'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=400&h=400&fit=crop',
      'https://images.unsplash.com/photo-1476224203421-9ac39bcb3327?w=400&h=400&fit=crop',
    ];

    const loginLogo = settings.loginAppLogo || settings.riderAppLogo || settings.logo || '';

    return (
      <div className="min-h-screen bg-gradient-to-br from-slate-900 via-red-950 to-slate-900 flex items-center justify-center px-4 overflow-hidden relative">
        <style>{`
          @keyframes loginFadeInUp {
            0% { opacity: 0; transform: translateY(30px); }
            100% { opacity: 1; transform: translateY(0); }
          }
          @keyframes loginFadeIn {
            0% { opacity: 0; }
            100% { opacity: 1; }
          }
          @keyframes loginFloat {
            0%, 100% { transform: translateY(0) rotate(0deg); }
            33% { transform: translateY(-10px) rotate(1deg); }
            66% { transform: translateY(5px) rotate(-1deg); }
          }
          @keyframes loginPulseGlow {
            0%, 100% { box-shadow: 0 0 20px rgba(220,38,38,0.4), 0 0 40px rgba(220,38,38,0.2); }
            50% { box-shadow: 0 0 30px rgba(220,38,38,0.6), 0 0 60px rgba(220,38,38,0.3); }
          }
          @keyframes loginShimmer {
            0% { background-position: -200% center; }
            100% { background-position: 200% center; }
          }
          @keyframes loginScaleIn {
            0% { opacity: 0; transform: scale(0.9); }
            100% { opacity: 1; transform: scale(1); }
          }
          @keyframes loginBgDrift {
            0% { transform: translate(0, 0) scale(1); }
            50% { transform: translate(20px, -20px) scale(1.05); }
            100% { transform: translate(0, 0) scale(1); }
          }
          .login-animate-form { animation: loginScaleIn 0.6s ease-out forwards; }
          .login-animate-logo { animation: loginFadeInUp 0.8s ease-out forwards; }
          .login-animate-greeting { animation: loginFadeInUp 0.6s ease-out 0.2s both; }
          .login-animate-subtitle { animation: loginFadeInUp 0.6s ease-out 0.3s both; }
          .login-animate-field { animation: loginFadeInUp 0.5s ease-out forwards; }
          .login-animate-btn { animation: loginFadeInUp 0.5s ease-out 0.4s both; }
          .login-animate-error { animation: loginFadeIn 0.3s ease-out forwards; }
          .bbq-img-container { animation: loginFloat 6s ease-in-out infinite; }
          .bbq-img-container:nth-child(2) { animation-delay: -1s; }
          .bbq-img-container:nth-child(3) { animation-delay: -2s; }
          .bbq-img-container:nth-child(4) { animation-delay: -3s; }
          .bbq-img-container:nth-child(5) { animation-delay: -4s; }
          .bbq-img-container:nth-child(6) { animation-delay: -5s; }
          .bbq-img-container:nth-child(7) { animation-delay: -1.5s; }
          .bbq-img-container:nth-child(8) { animation-delay: -2.5s; }
          .bbq-img-container:nth-child(9) { animation-delay: -3.5s; }
          .bbq-img-container:nth-child(10) { animation-delay: -4.5s; }
          .bbq-img-container:nth-child(11) { animation-delay: -0.5s; }
          .bbq-img-container:nth-child(12) { animation-delay: -5.5s; }
          .login-bg-circle {
            position: absolute;
            border-radius: 50%;
            filter: blur(80px);
            opacity: 0.15;
            animation: loginBgDrift 12s ease-in-out infinite;
          }
          .login-input:focus {
            border-color: #dc2626;
            box-shadow: 0 0 0 3px rgba(220,38,38,0.15);
          }
        `}</style>

        {/* Animated Background Circles */}
        <div className="login-bg-circle w-96 h-96 bg-red-500 -top-20 -left-20" style={{animationDelay: '0s'}} />
        <div className="login-bg-circle w-80 h-80 bg-orange-500 -bottom-20 -right-20" style={{animationDelay: '-4s'}} />
        <div className="login-bg-circle w-64 h-64 bg-rose-600 top-1/2 left-1/2" style={{animationDelay: '-8s'}} />

        {/* Main Container */}
        <div className="w-full max-w-5xl grid grid-cols-1 lg:grid-cols-2 gap-0 rounded-[40px] overflow-hidden shadow-2xl bg-white/95 backdrop-blur-sm relative z-10 login-animate-form">
          
          {/* Left Side - Login Form */}
          <div className="flex flex-col justify-center p-6 sm:p-10 relative">
            {/* Logo */}
            <div className="mb-6 flex items-center gap-3 login-animate-logo">
              {loginLogo ? (
                <img src={loginLogo} alt="Logo" className="h-12 w-12 rounded-full object-cover border-2 border-red-200 shadow-lg" />
              ) : (
                <div className="inline-flex h-12 w-12 items-center justify-center rounded-full bg-gradient-to-br from-red-500 to-rose-600 text-white text-lg font-bold shadow-lg">
                  🍽️
                </div>
              )}
              <span className="text-lg font-bold text-slate-900">{settings.hotelName || 'Usman Hotel'}</span>
            </div>

            {/* Greeting */}
            <h1 className="text-3xl font-bold text-slate-900 mb-1 login-animate-greeting">
              {greeting}! <span className="inline-block">{greetingEmoji}</span>
            </h1>
            <p className="text-slate-500 text-xs mb-6 login-animate-subtitle">
              Welcome back! Sign in to continue
            </p>

            {/* Error Message */}
            {authMessage && (
              <div className="mb-4 rounded-2xl border border-rose-200 bg-rose-50 px-4 py-2 text-xs text-rose-700 login-animate-error">
                {authMessage}
              </div>
            )}

            {/* Form Fields */}
            <div className="space-y-4 mb-6">
              {/* Name Field */}
              <div className="login-animate-field" style={{animationDelay: '0.1s'}}>
                <label className="block text-xs font-medium text-slate-700 mb-1.5">Full Name</label>
                <input 
                  type="text"
                  value={authForm.name || ''} 
                  onChange={(e) => setAuthForm({ ...authForm, name: e.target.value })}
                  placeholder="Type your full name"
                  className="login-input w-full rounded-xl border border-slate-300 bg-white px-3 py-2 text-xs text-slate-900 placeholder-slate-400 outline-none transition"
                />
              </div>

              {/* Email Field */}
              <div className="login-animate-field" style={{animationDelay: '0.15s'}}>
                <label className="block text-xs font-medium text-slate-700 mb-1.5">Email Address</label>
                <input 
                  type="email"
                  value={authForm.email} 
                  onChange={(e) => setAuthForm({ ...authForm, email: e.target.value })}
                  placeholder="Type your email address"
                  className="login-input w-full rounded-xl border border-slate-300 bg-white px-3 py-2 text-xs text-slate-900 placeholder-slate-400 outline-none transition"
                />
              </div>

              {/* Password Field */}
              <div className="login-animate-field" style={{animationDelay: '0.2s'}}>
                <label className="block text-xs font-medium text-slate-700 mb-1.5">Password</label>
                <div className="relative">
                  <input 
                    type={showAuthPassword ? 'text' : 'password'} 
                    value={authForm.password} 
                    onChange={(e) => setAuthForm({ ...authForm, password: e.target.value })}
                    placeholder="Type your password"
                    className="login-input w-full rounded-xl border border-slate-300 bg-white px-3 py-2 text-xs text-slate-900 placeholder-slate-400 outline-none transition"
                  />
                  <button 
                    type="button" 
                    onClick={() => setShowAuthPassword((s) => !s)} 
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-slate-500 hover:text-slate-700 transition font-medium"
                  >
                    {showAuthPassword ? '🙈' : '👁️'}
                  </button>
                </div>
              </div>
            </div>

            {/* Sign In Button - Red */}
            <button 
              onClick={login} 
              className="login-animate-btn w-full rounded-xl bg-gradient-to-r from-red-600 to-rose-600 text-white py-2.5 text-xs font-bold transition hover:from-red-700 hover:to-rose-700 active:scale-95 shadow-lg hover:shadow-xl"
              style={{animation: 'loginPulseGlow 2s ease-in-out infinite'}}
            >
              Sign In
            </button>
          </div>

          {/* Right Side - BBQ Food Image Grid */}
          <div className="hidden lg:grid grid-cols-3 gap-3 p-5 bg-gradient-to-br from-slate-100 to-red-50 relative overflow-hidden">
            {bbqImages.map((img, index) => (
              <div 
                key={index}
                className="bbq-img-container aspect-square rounded-2xl overflow-hidden shadow-md hover:shadow-xl transition-all duration-500 transform hover:scale-105 border-2 border-white/60 group"
                style={{animationDelay: `${-index * 0.5}s`}}
              >
                <div className="w-full h-full group-hover:scale-110 transition-transform duration-700">
                  <img 
                    src={img} 
                    alt="BBQ Food" 
                    className="w-full h-full object-cover"
                    loading="lazy"
                  />
                </div>
              </div>
            ))}
            {/* Overlay gradient at bottom */}
            <div className="absolute inset-x-0 bottom-0 h-32 bg-gradient-to-t from-red-50/80 to-transparent pointer-events-none" />
          </div>
        </div>
      </div>
    );
  }

  const isSidebarOpen = !isMobile && sidebarExpanded;
  const appStyle = {
    background: darkMode ? '#020617' : '#ffffff'
  };

  const riderRevenueSummary = (() => {
    const parseFilterDate = (v, isEnd = false) => {
      if (!v) return null;
      if (/^\d{4}-\d{2}-\d{2}$/.test(v)) {
        return new Date(v + (isEnd ? 'T23:59:59.999Z' : 'T00:00:00.000Z'));
      }
      return new Date(v);
    };

    const filterStart = parseFilterDate(dashboardFilters.start, false);
    const filterEnd = parseFilterDate(dashboardFilters.end, true);

    const filteredOrders = (posOrders || []).filter(order => {
      if (!filterStart && !filterEnd) return true;
      const dateVal = order.createdAt || order.date || order.orderDate;
      if (!dateVal) return false;
      const t = new Date(dateVal);
      if (filterStart && t < filterStart) return false;
      if (filterEnd && t > filterEnd) return false;
      return true;
    });

    const byRider = filteredOrders.reduce((acc, order) => {
      const riderName = String(order.deliveryAgent || order.deliveryAgentName || order.rider || '').trim();
      if (!riderName) return acc;
      const revenue = Math.max(0, (Number(order.total || order.amount || 0) || 0) - getOrderExtrasAmount(order) - getOrderServiceTypeCharge(order));
      const deliveryFee = order.orderType === 'Delivery' ? Number(order.deliveryFee || 0) : 0;
      const existing = acc[riderName] || { riderName, revenue: 0, orderCount: 0, deliveryFee: 0 };
      existing.revenue += revenue;
      existing.orderCount += 1;
      existing.deliveryFee += deliveryFee;
      acc[riderName] = existing;
      return acc;
    }, {});
    const rows = Object.values(byRider).sort((a, b) => b.revenue - a.revenue);
    const totalRevenue = rows.reduce((sum, item) => sum + item.revenue, 0);
    const totalOrders = rows.reduce((sum, item) => sum + item.orderCount, 0);
    const avgRevenue = rows.length ? totalRevenue / rows.length : 0;
    return rows.map((item) => ({
      ...item,
      trend: item.revenue >= avgRevenue ? 'up' : 'down',
      orderPercentage: totalOrders ? Math.round((item.orderCount / totalOrders) * 100) : 0,
      revenuePercentage: totalRevenue ? Math.round((item.revenue / totalRevenue) * 100) : 0
    }));
  })();
  const riderRevenueTotal = riderRevenueSummary.reduce((sum, item) => sum + item.revenue, 0);
  const riderOrderTotal = riderRevenueSummary.reduce((sum, item) => sum + item.orderCount, 0);
  const activeRidersCount = riderRevenueSummary.length;
  const riderTopList = riderRevenueSummary.slice(0, 5);
  const topDeliveryFeeRiders = [...riderRevenueSummary].sort((a, b) => b.deliveryFee - a.deliveryFee).slice(0, 3);
  const riderBottomList = riderRevenueSummary.length > 5 ? riderRevenueSummary.slice(-3).reverse() : [];

  if (cataloguePage) {
    return renderCustomerCataloguePage();
  }

  return (
    <div className={`min-h-screen ${darkMode ? 'bg-slate-950 text-slate-100' : 'bg-white text-slate-900'}`} style={appStyle}>
      <style>{`
        @keyframes pulse-slow { 0%,100% { transform: translateY(0); } 50% { transform: translateY(-2px); } }
        @keyframes pos-float { 0%,100% { transform: translateY(0); } 50% { transform: translateY(-8px); } }
        @keyframes pos-rainbow { 0% { box-shadow: 0 0 18px rgba(59,130,246,0.8), 0 0 40px rgba(59,130,246,0.2); } 25% { box-shadow: 0 0 18px rgba(16,185,129,0.8), 0 0 40px rgba(16,185,129,0.2); } 50% { box-shadow: 0 0 18px rgba(249,115,22,0.8), 0 0 40px rgba(249,115,22,0.2); } 75% { box-shadow: 0 0 18px rgba(168,85,247,0.8), 0 0 40px rgba(168,85,247,0.2); } 100% { box-shadow: 0 0 18px rgba(14,165,233,0.8), 0 0 40px rgba(14,165,233,0.2); } }
        @keyframes header-float { 0%,100% { transform: translateY(0); } 50% { transform: translateY(-4px); } }
        @keyframes logo-glow { 0%,100% { filter: hue-rotate(0deg); } 50% { filter: hue-rotate(30deg); } }
        @keyframes rainbow-bg { 0% { background-color: rgba(59,130,246,0.25); box-shadow: 0 0 18px rgba(59,130,246,0.4), 0 0 40px rgba(59,130,246,0.1); } 20% { background-color: rgba(16,185,129,0.25); box-shadow: 0 0 18px rgba(16,185,129,0.4), 0 0 40px rgba(16,185,129,0.1); } 40% { background-color: rgba(249,115,22,0.25); box-shadow: 0 0 18px rgba(249,115,22,0.4), 0 0 40px rgba(249,115,22,0.1); } 60% { background-color: rgba(168,85,247,0.25); box-shadow: 0 0 18px rgba(168,85,247,0.4), 0 0 40px rgba(168,85,247,0.1); } 80% { background-color: rgba(236,72,153,0.25); box-shadow: 0 0 18px rgba(236,72,153,0.4), 0 0 40px rgba(236,72,153,0.1); } 100% { background-color: rgba(59,130,246,0.25); box-shadow: 0 0 18px rgba(59,130,246,0.4), 0 0 40px rgba(59,130,246,0.1); } }
        @keyframes rainbow-icon { 0% { background: linear-gradient(135deg, #3b82f6, #60a5fa); box-shadow: 0 0 14px rgba(59,130,246,0.6); transform: translateY(0) scale(1) rotateX(0deg); } 20% { background: linear-gradient(135deg, #10b981, #34d399); box-shadow: 0 0 14px rgba(16,185,129,0.6); transform: translateY(-4px) scale(1.08) rotateX(8deg); } 40% { background: linear-gradient(135deg, #f59e0b, #fbbf24); box-shadow: 0 0 14px rgba(249,115,22,0.6); transform: translateY(-6px) scale(1.1) rotateX(12deg); } 60% { background: linear-gradient(135deg, #a855f7, #c084fc); box-shadow: 0 0 14px rgba(168,85,247,0.6); transform: translateY(-4px) scale(1.08) rotateX(8deg); } 80% { background: linear-gradient(135deg, #ec4899, #f472b6); box-shadow: 0 0 14px rgba(236,72,153,0.6); transform: translateY(-2px) scale(1.04) rotateX(4deg); } 100% { background: linear-gradient(135deg, #3b82f6, #60a5fa); box-shadow: 0 0 14px rgba(59,130,246,0.6); transform: translateY(0) scale(1) rotateX(0deg); } }
        @keyframes rainbow-text { 0% { color: #60a5fa; text-shadow: 0 0 8px rgba(59,130,246,0.5); } 20% { color: #34d399; text-shadow: 0 0 8px rgba(16,185,129,0.5); } 40% { color: #fbbf24; text-shadow: 0 0 8px rgba(249,115,22,0.5); } 60% { color: #c084fc; text-shadow: 0 0 8px rgba(168,85,247,0.5); } 80% { color: #f472b6; text-shadow: 0 0 8px rgba(236,72,153,0.5); } 100% { color: #60a5fa; text-shadow: 0 0 8px rgba(59,130,246,0.5); } }
        .animate-pos-hover:hover { animation: pos-float 0.6s ease infinite, pos-rainbow 1.5s linear infinite; }
        .pos-tab-icon, .sidebar-glow-icon, .developer-photo { transition: transform 0.15s ease, box-shadow 0.15s ease; }
        .pos-tab-group:hover .pos-tab-icon,
        .sidebar-glow-item:hover .sidebar-glow-icon,
        .developer-photo:hover { animation: pos-float 0.6s ease infinite, pos-rainbow 1.5s linear infinite; }
        .pos-header-icon { position: relative; overflow: hidden; }
        .pos-header-icon:hover { animation: pos-float 0.5s ease infinite, pos-rainbow 1.2s linear infinite !important; }
        .pos-header-icon::before { content: ''; position: absolute; inset: 0; border-radius: 9999px; opacity: 0.55; background: linear-gradient(135deg, rgba(249,115,22,0.7), rgba(16,185,129,0.7), rgba(59,130,246,0.7), rgba(168,85,247,0.7)); filter: blur(16px); transform: scale(1.1); transition: opacity 0.2s ease; }
        .pos-header-icon:hover::before { opacity: 1; transform: scale(1.3); }
        .header-btn-3d { position: relative; overflow: hidden; transform-style: preserve-3d; perspective: 400px; }
        .header-btn-3d::after { content: ''; position: absolute; inset: -2px; border-radius: 9999px; opacity: 0; background: linear-gradient(135deg, #f59e0b, #10b981, #3b82f6, #a855f7); filter: blur(12px); transition: opacity 0.3s ease; z-index: -1; }
        .header-btn-3d:hover::after { opacity: 0.8; }
        .header-btn-3d:hover { transform: translateY(-3px) scale(1.05); box-shadow: 0 8px 30px rgba(16,185,129,0.25); }
        .header-btn-3d:active { transform: translateY(0) scale(0.98); }
        .rainbow-active { animation: rainbow-bg 3s ease-in-out infinite, rainbow-text 3s ease-in-out infinite; }
        .rainbow-icon-glow { animation: rainbow-icon 3s ease-in-out infinite; transform-style: preserve-3d; perspective: 600px; }
        .sidebar-tab-btn { transform-style: preserve-3d; perspective: 400px; }
        .sidebar-tab-btn:hover .sidebar-icon { transform: translateY(-2px) scale(1.05); }
        .sidebar-scrollbar::-webkit-scrollbar { width: 4px; }
        .sidebar-scrollbar::-webkit-scrollbar-track { background: transparent; }
        .sidebar-scrollbar::-webkit-scrollbar-thumb { background-color: rgba(148,163,184,0.3); border-radius: 9999px; }
        .sidebar-scrollbar::-webkit-scrollbar-thumb:hover { background-color: rgba(148,163,184,0.5); }
        .no-scrollbar::-webkit-scrollbar { display: none; } .no-scrollbar { -ms-overflow-style: none; scrollbar-width: none; }
        .sidebar-notch { position: absolute; z-index: 20; border-radius: 50%; pointer-events: none; }
        .sidebar-neumorph { position: relative; overflow: hidden; }
        .sidebar-neumorph::before { content: ''; position: absolute; inset: 0; border-radius: inherit; opacity: 0.5; }
        @keyframes star-burst { 0% { transform: scale(0.3) rotate(-20deg); opacity: 0; } 30% { transform: scale(1.2) rotate(5deg); opacity: 1; } 60% { transform: scale(1) rotate(0deg); opacity: 1; } 100% { transform: scale(1.5) rotate(20deg); opacity: 0; } }
        .animate-star-burst { animation: star-burst 1.2s ease-out forwards; }
        @keyframes float-up { 0% { transform: translateY(20px) scale(0.8); opacity: 0; } 15% { transform: translateY(-8px) scale(1.05); opacity: 1; } 30% { transform: translateY(0) scale(1); opacity: 1; } 80% { opacity: 1; } 100% { transform: translateY(-30px); opacity: 0; } }
        .animate-float-up { animation: float-up 2.5s ease-out forwards; }
      `}</style>
      {!isMobile && (
      <aside className={`fixed left-0 top-3 bottom-3 z-50 flex h-[calc(100vh-24px)] flex-col transition-all duration-300 ${
        darkMode
          ? 'bg-gradient-to-b from-[#0f172a] via-[#1e293b] to-[#0f172a] text-slate-100 border-r border-slate-800/50'
          : 'bg-gradient-to-b from-[#dc2626] via-[#b91c1c] to-[#991b1b] text-white'
      }`}
        style={{
          width: isSidebarOpen ? '280px' : '80px',
          borderRadius: '0 28px 28px 0',
          boxShadow: darkMode
            ? '8px 0 32px rgba(0,0,0,0.4), 0 8px 32px rgba(0,0,0,0.2), inset 0 1px 0 rgba(255,255,255,0.05)'
            : '8px 0 32px rgba(220,38,38,0.15), 0 8px 32px rgba(220,38,38,0.08), inset 0 1px 0 rgba(255,255,255,0.15)'
        }}>
        <button
          onClick={() => setSidebarExpanded(prev => !prev)}
          className={`absolute -right-3.5 z-50 flex h-8 w-8 items-center justify-center rounded-full shadow-lg transition-all duration-200 ${
            darkMode
              ? 'bg-slate-800 text-slate-300 hover:bg-slate-700 border border-slate-700'
              : 'bg-white text-red-600 hover:bg-red-50'
          }`}
          style={{
            top: '50%',
            transform: 'translateY(-50%)',
            boxShadow: darkMode
              ? '0 2px 12px rgba(0,0,0,0.4)'
              : '0 2px 12px rgba(220,38,38,0.2)'
          }}
        >
          {sidebarExpanded ? '◀' : '▶'}
        </button>

        {/* Top section - neumorphic */}
        <div className={`sidebar-neumorph ${isSidebarOpen ? 'rounded-b-[24px]' : 'rounded-b-[16px]'} ${
          darkMode
            ? 'bg-slate-900/60 shadow-[inset_0_2px_8px_rgba(0,0,0,0.3),0_4px_16px_rgba(0,0,0,0.15)]'
            : 'bg-black/10 shadow-[inset_0_2px_8px_rgba(0,0,0,0.08),0_4px_16px_rgba(0,0,0,0.05)]'
        }`}>
          <div className={`flex items-center gap-3 px-4 pt-5 pb-4 ${isSidebarOpen ? 'flex-row' : 'flex-col'}`}>
            <div className={`flex h-10 w-10 shrink-0 items-center justify-center overflow-hidden rounded-full text-base font-bold ${
              darkMode
                ? 'bg-gradient-to-br from-indigo-500 to-purple-600 text-white shadow-[0_0_14px_rgba(99,102,241,0.4)]'
                : 'bg-white/20 text-white'
            }`}>
              {(user?.name || user?.email || 'U').toString().split(' ').map((p) => p[0]).join('').slice(0, 2).toUpperCase()}
            </div>
            {isSidebarOpen && (
              <div className="min-w-0">
                <div className={`text-[10px] uppercase tracking-[0.2em] ${darkMode ? 'text-slate-400' : 'text-white/60'}`}>{user?.role || 'User'}</div>
                <div className="text-sm font-semibold truncate">{user?.name || user?.email || 'Guest'}</div>
              </div>
            )}
          </div>
        </div>

        <nav className="flex-1 space-y-0 px-2 overflow-y-auto overflow-x-hidden sidebar-scrollbar">
          {tabs.filter(tab => canAccessTab(tab)).map((tab) => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              className={`flex w-full items-center gap-0 rounded-[10px] px-2 py-2 text-sm font-medium transition-all duration-200 sidebar-tab-btn ${
                activeTab === tab
                  ? 'text-white rainbow-active shadow-[0_0_20px_rgba(168,85,247,0.3)]'
                  : `${darkMode ? 'text-slate-400 hover:bg-slate-800/50 hover:text-slate-200' : 'text-white/80 hover:bg-white/15 hover:text-white'}`
              } ${isSidebarOpen ? 'justify-start' : 'justify-center'}`}
            >
              <span className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-[10px] text-base transition-all duration-300 sidebar-icon ${
                activeTab === tab
                  ? 'rainbow-icon-glow'
                  : `${darkMode ? 'text-slate-400' : 'text-white/90'}`
              }`}>
                {tabIcons[tab] || '•'}
              </span>
              {isSidebarOpen && (
                <span className="ml-3 min-w-0 truncate">{formatTabName(tab)}</span>
              )}
            </button>
          ))}
        </nav>

        {/* Bottom section - neumorphic (same style as top) */}
        <div className={`sidebar-neumorph ${isSidebarOpen ? 'rounded-t-[24px]' : 'rounded-t-[16px]'} ${
          darkMode
            ? 'bg-slate-900/60 shadow-[inset_0_-2px_8px_rgba(0,0,0,0.3),0_-4px_16px_rgba(0,0,0,0.15)]'
            : 'bg-black/10 shadow-[inset_0_-2px_8px_rgba(0,0,0,0.08),0_-4px_16px_rgba(0,0,0,0.05)]'
        }`}>
          <div className={`px-3 py-4 ${isSidebarOpen ? 'flex items-center justify-center' : 'flex justify-center'}`}>
            <button onClick={logout} className={`flex items-center justify-center rounded-[10px] text-sm font-medium transition ${
              darkMode
                ? 'text-slate-400 hover:bg-slate-800/50 hover:text-slate-200'
                : 'text-white/80 hover:bg-white/15 hover:text-white'
            } ${isSidebarOpen ? 'w-full gap-2 px-3 py-2' : 'h-9 w-9'}`}>
              {isSidebarOpen ? (
                <>
                  <span className="text-base">🚪</span>
                  <span>Logout</span>
                </>
              ) : (
                <span className="text-base">🚪</span>
              )}
            </button>
          </div>
        </div>
      </aside>
      )}
      <div className="mx-auto flex min-h-screen flex-col gap-2 px-3 py-2 pb-28 sm:px-6 lg:px-8"
        style={{
          marginLeft: isSidebarOpen ? '280px' : '80px',
          transition: 'margin-left 0.3s ease'
        }}>
        <div className="flex items-center justify-between gap-3">
          <div className="flex items-center gap-3">
            {!isSidebarOpen && !isMobile && (
              <button
                onClick={() => setSidebarExpanded(true)}
                className={`flex h-9 w-9 items-center justify-center rounded-full text-base transition-all duration-200 ${
                  darkMode
                    ? 'text-slate-400 hover:bg-slate-800 hover:text-slate-200'
                    : 'text-slate-600 hover:bg-slate-100 hover:text-slate-800'
                }`}
                title="Open sidebar"
              >
                ☰
              </button>
            )}
            <div className="flex h-9 w-9 items-center justify-center overflow-hidden rounded-full bg-gradient-to-br from-emerald-500 via-sky-500 to-indigo-500 text-white shadow-[0_0_20px_rgba(16,185,129,0.3)] text-lg" style={{animation: 'header-float 3s ease-in-out infinite, logo-glow 4s linear infinite'}}>
              {settings.posHeaderPhoto ? (
                <img src={settings.posHeaderPhoto} alt="POS Header" className="h-full w-full object-cover" />
              ) : (
                '🛒'
              )}
            </div>
            <div>
              <p className={`text-[9px] uppercase tracking-[0.24em] ${darkMode ? 'text-slate-400' : 'text-slate-500'}`}>{settings.posHeaderSubtitle || 'POS Header'}</p>
              <h1 className={`text-sm font-semibold ${darkMode ? 'text-white' : 'text-slate-900'}`}>{settings.posHeaderTitle || 'POS Counter'}</h1>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={() => setActiveTab('dashboard')}
              className={`flex h-8 w-8 items-center justify-center rounded-full text-sm transition-all duration-200 header-btn-3d ${
                activeTab === 'dashboard'
                  ? 'rainbow-icon-glow'
                  : darkMode
                    ? 'text-slate-400 hover:bg-slate-800'
                    : 'text-slate-500 hover:bg-slate-100'
              }`}
              title="Dashboard"
            >
              📊
            </button>
            <button
              onClick={() => setActiveTab('pos')}
              className={`flex h-8 w-8 items-center justify-center rounded-full text-sm transition-all duration-200 header-btn-3d ${
                activeTab === 'pos'
                  ? 'rainbow-icon-glow'
                  : darkMode
                    ? 'text-slate-400 hover:bg-slate-800'
                    : 'text-slate-500 hover:bg-slate-100'
              }`}
              title="POS"
            >
              🛒
            </button>
            <button
              onClick={() => setShowRecentOrdersPopup(true)}
              className={`flex h-8 w-8 items-center justify-center rounded-full text-sm transition-all duration-200 header-btn-3d ${
                darkMode
                  ? 'text-slate-400 hover:bg-slate-800'
                  : 'text-slate-500 hover:bg-slate-100'
              }`}
              title="Recent Orders"
            >
              🕐
            </button>
            <div className="w-px h-5 bg-slate-600/30 mx-1" />
            <button onClick={() => setDarkMode((prev) => !prev)} className={`header-btn-3d rounded-full px-2.5 py-1 text-[10px] font-semibold shadow-[0_2px_8px_rgba(0,0,0,0.15)] transition-all duration-200 ${
              darkMode
                ? 'bg-gradient-to-br from-slate-700 via-slate-600 to-slate-800 text-slate-200'
                : 'bg-gradient-to-br from-slate-200 via-slate-100 to-white text-slate-600'
            }`}>
              {darkMode ? '☀️' : '🌙'}
            </button>
          </div>
        </div>

        <main className="space-y-6">

            {message && <div className="rounded-[24px] border border-emerald-500 bg-emerald-900/40 px-4 py-3 text-sm text-emerald-200">{message}</div>}

            {activeTab === 'dashboard' && !isMobile && (
              <section className="space-y-6">
                <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
                  <div className="space-y-2">
                    <div className="text-sm uppercase tracking-[0.2em] text-slate-400">Dashboard</div>
                    <h2 className="text-3xl font-semibold text-white">Restaurant Sales & Order Overview</h2>
                  </div>
                  <div className="flex flex-wrap items-center gap-3">
                    <div className="relative" ref={dateDropdownRef}>
                      <button
                        onClick={() => setShowDatePickerDropdown(!showDatePickerDropdown)}
                        className="flex items-center gap-2 rounded-full border border-slate-700 bg-slate-950 px-4 py-2.5 text-sm font-semibold text-slate-200 transition hover:bg-slate-900 hover:border-slate-600 focus:outline-none shadow-md"
                      >
                        <span className="text-base leading-none">📅</span>
                        <span>
                          {datePreset === 'today' && 'Today'}
                          {datePreset === 'yesterday' && 'Yesterday'}
                          {datePreset === '5days' && 'Last 5 Days'}
                          {datePreset === 'custom' && (
                            dashboardFilters.start && dashboardFilters.end
                              ? `${dashboardFilters.start} to ${dashboardFilters.end}`
                              : 'Custom Range'
                          )}
                        </span>
                        <span className="text-[10px] text-slate-400">▼</span>
                      </button>

                      {showDatePickerDropdown && (
                        <div className="absolute right-0 top-full z-50 mt-2 w-52 rounded-2xl border border-slate-800 bg-slate-950 p-1.5 shadow-2xl backdrop-blur-md">
                          <button
                            onClick={() => {
                              handlePresetSelect('today');
                              setShowDatePickerDropdown(false);
                            }}
                            className={`flex w-full items-center rounded-xl px-3 py-2 text-left text-xs font-semibold transition ${datePreset === 'today' ? 'bg-emerald-600 text-slate-950' : 'text-slate-300 hover:bg-slate-900'}`}
                          >
                            Today
                          </button>
                          <button
                            onClick={() => {
                              handlePresetSelect('yesterday');
                              setShowDatePickerDropdown(false);
                            }}
                            className={`flex w-full items-center rounded-xl px-3 py-2 text-left text-xs font-semibold transition ${datePreset === 'yesterday' ? 'bg-emerald-600 text-slate-950' : 'text-slate-300 hover:bg-slate-900'}`}
                          >
                            Yesterday
                          </button>
                          <button
                            onClick={() => {
                              handlePresetSelect('5days');
                              setShowDatePickerDropdown(false);
                            }}
                            className={`flex w-full items-center rounded-xl px-3 py-2 text-left text-xs font-semibold transition ${datePreset === '5days' ? 'bg-emerald-600 text-slate-950' : 'text-slate-300 hover:bg-slate-900'}`}
                          >
                            Last 5 Days
                          </button>
                          <button
                            onClick={() => {
                              setDatePreset('custom');
                              setShowDatePickerDropdown(false);
                            }}
                            className={`flex w-full items-center rounded-xl px-3 py-2 text-left text-xs font-semibold transition ${datePreset === 'custom' ? 'bg-emerald-600 text-slate-950' : 'text-slate-300 hover:bg-slate-900'}`}
                          >
                            Custom Range
                          </button>
                        </div>
                      )}
                    </div>

                    {datePreset === 'custom' && (
                      <div className="flex flex-wrap items-center gap-2">
                        <div className="flex items-center gap-2 rounded-full border border-slate-700 bg-slate-950 px-3 py-2">
                          <label className="text-xs text-slate-400">From</label>
                          <input
                            type="date"
                            value={dashboardFilters.start || ''}
                            onChange={(e) => setDashboardFilters({ ...dashboardFilters, start: e.target.value })}
                            className="bg-transparent text-xs text-slate-100 outline-none w-28 [color-scheme:dark]"
                          />
                        </div>
                        <div className="flex items-center gap-2 rounded-full border border-slate-700 bg-slate-950 px-3 py-2">
                          <label className="text-xs text-slate-400">To</label>
                          <input
                            type="date"
                            value={dashboardFilters.end || ''}
                            onChange={(e) => setDashboardFilters({ ...dashboardFilters, end: e.target.value })}
                            className="bg-transparent text-xs text-slate-100 outline-none w-28 [color-scheme:dark]"
                          />
                        </div>
                        <button
                          onClick={() => loadTab('dashboard')}
                          className="rounded-full bg-emerald-600 px-4 py-2 text-xs font-semibold text-slate-950 transition hover:bg-emerald-500 shadow-md"
                        >
                          Apply
                        </button>
                      </div>
                    )}
                  </div>
                </div>

                <div className="grid gap-3 grid-cols-1 sm:grid-cols-2 lg:grid-cols-4">
                  {/* Block 1: Total Revenue + Total Orders */}
                  <div className="rounded-[24px] border border-slate-800 bg-slate-950 p-3 shadow-soft">
                    <div className="flex items-start justify-between gap-2">
                      <div>
                        <p className="text-xs uppercase tracking-[0.24em] text-slate-500">Total Revenue</p>
                        <p className="mt-2 text-2xl font-semibold text-white">{dashboard?.totalRevenue ?? 0}</p>
                      </div>
                      <div className="inline-flex h-9 w-9 items-center justify-center rounded-full bg-slate-900 text-xs font-semibold text-slate-300">R</div>
                    </div>
                    <div className="mt-3 text-xs text-slate-400">
                      <p className="text-slate-500">{dashboard?.totalOrders ?? 0} Total Orders</p>
                    </div>
                  </div>

                  {/* Block 2: Delivery Revenue + Orders */}
                  <div className="rounded-[24px] border border-slate-800 bg-slate-950 p-3 shadow-soft">
                    <div className="flex items-start justify-between gap-2">
                      <div>
                        <p className="text-xs uppercase tracking-[0.24em] text-sky-500">Delivery</p>
                        <p className="mt-2 text-2xl font-semibold text-white">{dashboard?.orderTypeSummary?.Delivery?.revenue ?? 0}</p>
                      </div>
                      <div className="inline-flex h-9 w-9 items-center justify-center rounded-full bg-sky-900/40 text-sky-300">
                        <svg className="h-5 w-5 animate-bounce" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                          <polyline points="12 19 12 5 5 12"></polyline>
                          <polyline points="12 5 19 12"></polyline>
                        </svg>
                      </div>
                    </div>
                    <div className="mt-3 flex items-center justify-between text-xs">
                      <span className="text-sky-300">{dashboard?.orderTypeSummary?.Delivery?.count ?? 0} orders</span>
                      <span className="text-slate-400">{dashboard?.totalRevenue ? Math.round(((dashboard?.orderTypeSummary?.Delivery?.revenue || 0) / dashboard.totalRevenue) * 100) : 0}%</span>
                    </div>
                  </div>

                  {/* Block 3: Takeaway Revenue + Orders */}
                  <div className="rounded-[24px] border border-slate-800 bg-slate-950 p-3 shadow-soft">
                    <div className="flex items-start justify-between gap-2">
                      <div>
                        <p className="text-xs uppercase tracking-[0.24em] text-amber-500">Takeaway</p>
                        <p className="mt-2 text-2xl font-semibold text-white">{dashboard?.orderTypeSummary?.Takeaway?.revenue ?? 0}</p>
                      </div>
                      <div className="inline-flex h-9 w-9 items-center justify-center rounded-full bg-amber-900/40 text-amber-300">
                        {(dashboard?.orderTypeSummary?.Takeaway?.revenue || 0) >= (dashboard?.orderTypeSummary?.Delivery?.revenue || 0) ? (
                          <svg className="h-5 w-5 animate-bounce" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                            <polyline points="12 19 12 5 5 12"></polyline>
                            <polyline points="12 5 19 12"></polyline>
                          </svg>
                        ) : (
                          <svg className="h-5 w-5 animate-pulse" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                            <polyline points="12 5 12 19 5 12"></polyline>
                            <polyline points="12 19 19 12"></polyline>
                          </svg>
                        )}
                      </div>
                    </div>
                    <div className="mt-3 flex items-center justify-between text-xs">
                      <span className="text-amber-300">{dashboard?.orderTypeSummary?.Takeaway?.count ?? 0} orders</span>
                      <span className="text-slate-400">{dashboard?.totalRevenue ? Math.round(((dashboard?.orderTypeSummary?.Takeaway?.revenue || 0) / dashboard.totalRevenue) * 100) : 0}%</span>
                    </div>
                  </div>

                  {/* Block 4: Dine Revenue + Orders */}
                  <div className="rounded-[24px] border border-slate-800 bg-slate-950 p-3 shadow-soft">
                    <div className="flex items-start justify-between gap-2">
                      <div>
                        <p className="text-xs uppercase tracking-[0.24em] text-emerald-500">Dine In</p>
                        <p className="mt-2 text-2xl font-semibold text-white">{dashboard?.orderTypeSummary?.Dine?.revenue ?? 0}</p>
                      </div>
                      <div className="inline-flex h-9 w-9 items-center justify-center rounded-full bg-emerald-900/40 text-emerald-300">
                        {(dashboard?.orderTypeSummary?.Dine?.revenue || 0) >= (dashboard?.orderTypeSummary?.Delivery?.revenue || 0) ? (
                          <svg className="h-5 w-5 animate-bounce" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                            <polyline points="12 19 12 5 5 12"></polyline>
                            <polyline points="12 5 19 12"></polyline>
                          </svg>
                        ) : (
                          <svg className="h-5 w-5 animate-pulse" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                            <polyline points="12 5 12 19 5 12"></polyline>
                            <polyline points="12 19 19 12"></polyline>
                          </svg>
                        )}
                      </div>
                    </div>
                    <div className="mt-3 flex items-center justify-between text-xs">
                      <span className="text-emerald-300">{dashboard?.orderTypeSummary?.Dine?.count ?? 0} orders</span>
                      <span className="text-slate-400">{dashboard?.totalRevenue ? Math.round(((dashboard?.orderTypeSummary?.Dine?.revenue || 0) / dashboard.totalRevenue) * 100) : 0}%</span>
                    </div>
                  </div>
                </div>

                <div className="grid gap-4 xl:grid-cols-[1.45fr_0.95fr]">
                  <div className="grid gap-4 sm:grid-cols-2">
                    <div className="rounded-[32px] border border-slate-800 bg-slate-900 p-5 shadow-soft">
                      <div className="flex items-start justify-between gap-4">
                        <div>
                          <p className="text-sm uppercase tracking-[0.18em] text-slate-400">Revenue Trend</p>
                          <h3 className="mt-3 text-xl font-semibold text-white">Daily Sales</h3>
                        </div>
                        <span className="rounded-3xl bg-slate-950 px-3 py-2 text-xs uppercase tracking-[0.15em] text-slate-400">{dashboard?.salesSeries?.dates?.length || 0} days</span>
                      </div>
                      <div className="mt-5">
                        <MiniLineChart lines={[
                          dashboard?.salesSeries?.Delivery || [],
                          dashboard?.salesSeries?.Takeaway || [],
                          dashboard?.salesSeries?.Dine || []
                        ]} />
                      </div>
                      <div className="mt-5 grid grid-cols-3 gap-3">
                        {['Delivery', 'Takeaway', 'Dine'].map((type, index) => (
                          <div key={type} className="rounded-3xl bg-slate-950 p-3">
                            <p className="text-xs uppercase tracking-[0.18em] text-slate-400">{type}</p>
                            <p className="mt-2 text-lg font-semibold text-white">{dashboard?.orderTypeSummary?.[type]?.revenue ?? 0}</p>
                            <div className="mt-2 h-2 rounded-full bg-slate-800">
                              <div className="h-full rounded-full" style={{ width: `${Math.min(100, Math.max(0, [65, 53, 46][index]))}%`, background: ['#60A5FA', '#F59E0B', '#34D399'][index] }} />
                            </div>
                          </div>
                        ))}
                      </div>
                    </div>

                    <div className="rounded-[32px] border border-slate-800 bg-slate-900 p-5 shadow-soft">
                      <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
                        <div>
                          <p className="text-sm uppercase tracking-[0.18em] text-slate-400">Rider Performance</p>
                          <h3 className="mt-3 text-xl font-semibold text-white">Rider Summary</h3>
                        </div>
                      </div>

                      <div className="mt-6 overflow-x-auto rounded-[24px] border border-slate-800 bg-slate-950">
                        <table className="min-w-full text-left text-sm text-slate-200">
                          <thead className="border-b border-slate-800 bg-slate-900 text-slate-300">
                            <tr>
                              <th className="px-4 py-3">Rider</th>
                              <th className="px-4 py-3">Orders</th>
                              <th className="px-4 py-3">% of orders</th>
                              <th className="px-4 py-3">Revenue</th>
                            </tr>
                          </thead>
                          <tbody>
                            {riderTopList.map((rider, index) => (
                              <tr key={rider.riderName} className="border-b border-slate-800 hover:bg-slate-900/80">
                                <td className="px-4 py-4 font-semibold text-white">{index + 1}. {rider.riderName}</td>
                                <td className="px-4 py-4 text-slate-300">{rider.orderCount}</td>
                                <td className="px-4 py-4 text-slate-300">{rider.orderPercentage}%</td>
                                <td className="px-4 py-4 text-slate-300">{rider.revenue}</td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>

                      <div className="mt-5 rounded-3xl border border-slate-800 bg-slate-950 p-4">
                        <p className="text-xs uppercase tracking-[0.18em] text-slate-400">Top Rider Delivery Fees</p>
                        <div className="mt-4 space-y-3">
                          {topDeliveryFeeRiders.length ? topDeliveryFeeRiders.map((rider) => (
                            <div key={rider.riderName} className="flex items-center justify-between rounded-3xl border border-slate-800 bg-slate-900 p-3">
                              <div>
                                <div className="text-sm font-semibold text-white">{rider.riderName}</div>
                                <div className="text-xs text-slate-400">{rider.orderCount} orders</div>
                              </div>
                              <div className="text-right text-sm font-semibold text-white">{rider.deliveryFee}</div>
                            </div>
                          )) : (
                            <div className="text-sm text-slate-500">No delivery fee data available.</div>
                          )}
                        </div>
                      </div>
                    </div>
                  </div>

                  <div className="rounded-[32px] border border-slate-800 bg-slate-900 p-5 shadow-soft">
                    <div className="flex items-center justify-between gap-3">
                      <div>
                        <p className="text-sm uppercase tracking-[0.18em] text-slate-400">Top Products</p>
                        <h3 className="mt-2 text-xl font-semibold text-white">10 Best Sellers</h3>
                      </div>
                      <span className="rounded-full bg-slate-950 px-3 py-2 text-xs uppercase tracking-[0.15em] text-slate-400">Ranked</span>
                    </div>
                    <div className="mt-5 space-y-3 max-h-[460px] overflow-y-auto pr-1">
                      {dashboard?.topProducts?.length > 0 ? (
                        dashboard.topProducts.map((p, index) => (
                          <div key={p.productId} className="rounded-3xl border border-slate-800 bg-slate-950 p-4">
                            <div className="flex items-start justify-between gap-3">
                              <div className="min-w-0">
                                <div className="text-sm font-semibold text-white truncate">{index + 1}. {p.name}</div>
                                <div className="mt-1 text-xs text-slate-400">{p.totalQuantity} items • {p.totalRevenue} {dashboard?.settings?.currency || settings.currency}</div>
                              </div>
                              <div className="text-xs font-semibold uppercase tracking-[0.15em] text-slate-400">#{index + 1}</div>
                            </div>
                            <div className="mt-3"><DashboardProgress value={p.totalQuantity > 0 ? Math.min(100, (p.totalQuantity / (dashboard.topProducts[0]?.totalQuantity || 1)) * 100) : 0} /></div>
                          </div>
                        ))
                      ) : (
                        <div className="text-sm text-slate-500 p-4">No product data for selected date range</div>
                      )}
                    </div>
                  </div>
                </div>

                <div className="rounded-[32px] border border-slate-800 bg-slate-900 p-5 shadow-soft">
                  <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                    <div>
                      <p className="text-sm uppercase tracking-[0.18em] text-slate-400">Order Activity</p>
                      <h3 className="mt-2 text-xl font-semibold text-white">Recent Orders</h3>
                    </div>
                    <span className="text-sm text-slate-400">Showing latest 6 orders</span>
                  </div>
                  <div className="mt-5 overflow-x-auto">
                    <table className="min-w-full border-collapse text-left text-sm">
                      <thead>
                        <tr className="text-slate-400">
                          <th className="py-3 pr-6 font-semibold">Order</th>
                          <th className="py-3 pr-6 font-semibold">Type</th>
                          <th className="py-3 pr-6 font-semibold">Amount</th>
                          <th className="py-3 pr-6 font-semibold">Status</th>
                          <th className="py-3 pr-6 font-semibold">Date</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-slate-800 text-slate-300">
                        {(posOrders || []).slice().sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt)).slice(0, 6).map((order) => (
                          <tr key={order.id}>
                            <td className="py-4 pr-6 font-medium text-white">{order.orderNumber || order.id}</td>
                            <td className="py-4 pr-6">{order.orderType || 'N/A'}</td>
                            <td className="py-4 pr-6">{order.total || 0} {dashboard?.settings?.currency || settings.currency}</td>
                            <td className="py-4 pr-6"><span className="inline-flex rounded-full bg-slate-950 px-3 py-1 text-xs font-semibold uppercase tracking-[0.18em] text-slate-400">{order.status || 'Unknown'}</span></td>
                            <td className="py-4 pr-6">{new Date(order.createdAt).toLocaleDateString()}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              </section>
            )}

            {activeTab === 'pos' && renderPos()}
            {activeTab === 'catalogue-qr' && renderCatalogueQrModule()}
            {activeTab === 'customers' && renderCustomers()}
            {activeTab === 'riders-app' && <RidersApp />}
            {activeTab === 'settings' && renderSettings()}
            {activeTab === 'orders' && renderOrders()}
            {activeTab === 'rider-book' && renderRiderBook()}
            {activeTab === 'rider-order-requests' && renderRiderOrderRequests()}

            {(activeTab === 'tables' || activeTab === 'inventory' || activeTab === 'staff' || activeTab === 'sales') && (
              <section className="rounded-[32px] border border-slate-800 bg-slate-900 p-6 shadow-soft">
                <div>{renderTable()}</div>
              </section>
            )}

          </main>
          {orderModalOpen && (
            <div className="fixed inset-0 z-50 overflow-y-auto bg-slate-950/92 p-4 backdrop-blur-sm flex items-center justify-center">
              <div className="relative w-full max-w-6xl max-h-[90vh] flex flex-col overflow-hidden rounded-[32px] border border-white/10 bg-white/10 shadow-2xl shadow-emerald-500/10 backdrop-blur-xl">
                <div className="absolute inset-x-0 top-0 h-1 bg-gradient-to-r from-emerald-400 via-cyan-400 to-blue-500 opacity-80" />
                <div className="flex h-full flex-col overflow-hidden">
                  <div className="flex-shrink-0 border-b border-white/10 p-6 pb-4">
                    <div className="flex items-center justify-between">
                      <div>
                        <h2 className="text-2xl font-semibold text-white">Edit Order: {editingOrder?.orderNumber || editingOrder?.id}</h2>
                        <p className="text-sm text-slate-400">Modify products, quantities, and order details</p>
                      </div>
                      <button onClick={() => { setOrderModalOpen(false); setEditingOrderCart([]); }} className="inline-flex h-11 w-11 items-center justify-center rounded-full border border-slate-700 bg-slate-900 text-slate-200 transition hover:bg-slate-800">
                        <svg viewBox="0 0 24 24" className="h-6 w-6"><path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12 19 6.41z" fill="currentColor"/></svg>
                      </button>
                    </div>
                  </div>
                  <div className="flex-1 overflow-y-auto min-h-0">
                    <div className="grid gap-6 p-6 lg:grid-cols-[1fr_320px_300px] h-max">
                      <div className="space-y-4">
                        <div className="flex flex-col gap-3">
                          <p className="text-sm uppercase tracking-[0.2em] text-slate-400">Products</p>
                          <input value={editingProductSearch} onChange={(e) => setEditingProductSearch(e.target.value)} placeholder="Search products" className="rounded-3xl border border-slate-700 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" />
                        </div>
                        <div className="grid gap-3 max-h-[350px] overflow-y-auto">
                          {posProducts.filter((product) => {
                            const search = editingProductSearch.toLowerCase();
                            return !search ||
                              String(product.name || '').toLowerCase().includes(search) ||
                              String(product.code || '').toLowerCase().includes(search);
                          }).map((product) => (
                            <div key={product.id} className="rounded-3xl border border-slate-800 bg-slate-950 p-3 shadow-soft hover:border-emerald-600/50 transition">
                              <div className="flex items-start justify-between gap-3">
                                <div className="flex-1 min-w-0">
                                  <div className="font-semibold text-white truncate">{product.name}</div>
                                  <div className="text-sm text-slate-400">{product.price} PKR</div>
                                </div>
                                <button onClick={() => addToEditingCart(product)} className="inline-flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-full bg-emerald-600 text-white shadow-[0_8px_16px_rgba(0,0,0,0.25)] transition hover:bg-emerald-500 hover:-translate-y-0.5">
                                  <svg viewBox="0 0 24 24" className="h-5 w-5"><path d="M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z" fill="currentColor"/></svg>
                                </button>
                              </div>
                            </div>
                          ))}
                        </div>
                      </div>

                      <div className="space-y-4">
                        <p className="text-sm uppercase tracking-[0.2em] text-slate-400">Items</p>
                        <div className="rounded-3xl border border-slate-800 bg-slate-950 p-4 shadow-soft max-h-[350px] overflow-y-auto">
                          {editingOrderCart.length === 0 ? (
                            <div className="text-center text-sm text-slate-500 py-8">No items added</div>
                          ) : (
                            <div className="space-y-3">
                              {editingOrderCart.map((item) => (
                                <div key={item.productId} className="rounded-3xl border border-slate-700 bg-slate-900 p-3">
                                  <div className="flex items-start justify-between gap-2 mb-2">
                                    <div className="flex-1 min-w-0">
                                      <div className="font-semibold text-white text-sm truncate">{item.name}</div>
                                      <div className="text-xs text-slate-400">{item.price} PKR</div>
                                    </div>
                                    <button onClick={() => removeFromEditingCart(item.productId)} className="inline-flex h-7 w-7 flex-shrink-0 items-center justify-center rounded-full border border-slate-700 bg-rose-600 text-white text-xs font-bold transition hover:bg-rose-500">−</button>
                                  </div>
                                  <div className="flex items-center justify-between gap-2">
                                    <div className="flex items-center gap-2 bg-slate-800 rounded-full px-2 py-1">
                                      <button onClick={() => updateEditingCartItem(item.productId, -1)} className="h-6 w-6 rounded-full bg-slate-900 text-slate-200 text-xs font-bold hover:bg-slate-800">−</button>
                                      <span className="w-6 text-center text-sm text-white">{item.quantity}</span>
                                      <button onClick={() => updateEditingCartItem(item.productId, 1)} className="h-6 w-6 rounded-full bg-slate-900 text-slate-200 text-xs font-bold hover:bg-slate-800">+</button>
                                    </div>
                                    <span className="text-xs font-semibold text-emerald-400">{item.total || item.price * item.quantity} PKR</span>
                                  </div>
                                </div>
                              ))}
                            </div>
                          )}
                        </div>
                      </div>

                      <div className="space-y-4">
                        <p className="text-sm uppercase tracking-[0.2em] text-slate-400">Details</p>
                        <div className="rounded-3xl border border-slate-800 bg-slate-950 p-4 shadow-soft space-y-3 max-h-[350px] overflow-y-auto">
                          <div>
                            <label className="block text-xs font-medium text-slate-300 mb-1">Phone</label>
                            <input value={orderEditForm.phone} onChange={(e) => setOrderEditForm({ ...orderEditForm, phone: e.target.value })} className="w-full rounded-2xl border border-slate-800 bg-slate-900 px-3 py-2 text-xs text-slate-100 outline-none focus:border-emerald-500" />
                          </div>
                          {orderEditForm.orderType === 'Delivery' && (
                            <>
                              <div>
                                <label className="block text-xs font-medium text-slate-300 mb-1">Address</label>
                                <input value={orderEditForm.address} onChange={(e) => setOrderEditForm({ ...orderEditForm, address: e.target.value })} className="w-full rounded-2xl border border-slate-800 bg-slate-900 px-3 py-2 text-xs text-slate-100 outline-none focus:border-emerald-500" />
                              </div>
                              <div>
                                <label className="block text-xs font-medium text-slate-300 mb-1">Service Type</label>
                                <select value={orderEditForm.serviceType} onChange={(e) => { const type = getDeliveryServiceTypeById(e.target.value); setOrderEditForm({ ...orderEditForm, serviceType: e.target.value, deliveryFee: type?.charge || 0 }); }} className="w-full rounded-2xl border border-slate-800 bg-slate-900 px-3 py-2 text-xs text-slate-100 outline-none focus:border-emerald-500">
                                  <option value="">Select type</option>
                                  {deliveryServiceTypes.map((type) => (
                                    <option key={type.id} value={type.id}>{type.name}</option>
                                  ))}
                                </select>
                              </div>
                            </>
                          )}
                        </div>
                      </div>
                    </div>
                  </div>

                  <div className="flex-shrink-0 border-t border-white/10 p-6 bg-slate-950/50 backdrop-blur-sm">
                    <div className="grid gap-4 mb-4">
                      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 text-xs sm:text-sm">
                        <div><span className="text-slate-400">Subtotal:</span><span className="ml-1 font-semibold text-white">{getEditingOrderSummary().subtotal} PKR</span></div>
                        <div><span className="text-slate-400">Discount:</span><span className="ml-1 font-semibold text-white">-{getEditingOrderSummary().discount} PKR</span></div>
                        <div><span className="text-slate-400">Tax:</span><span className="ml-1 font-semibold text-white">+{getEditingOrderSummary().tax} PKR</span></div>
                        <div><span className="text-slate-400">Delivery:</span><span className="ml-1 font-semibold text-white">+{getEditingOrderSummary().deliveryFee} PKR</span></div>
                        <div className="col-span-2 sm:col-span-4 pt-2 border-t border-white/10 text-base"><span className="text-slate-300">Total:</span><span className="ml-2 font-bold text-emerald-400">{getEditingOrderSummary().total} PKR</span></div>
                      </div>
                    </div>
                    <div className="flex gap-3 justify-end">
                      <button onClick={() => { setOrderModalOpen(false); setEditingOrderCart([]); }} className="rounded-3xl border border-slate-700 bg-slate-800 px-4 py-2 text-sm font-semibold text-slate-200 transition hover:bg-slate-700">Cancel</button>
                      <button onClick={saveOrderEdit} className="rounded-3xl bg-emerald-600 px-4 py-2 text-sm font-semibold text-slate-950 transition hover:bg-emerald-500">Save Changes</button>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}

          {riderAssignmentModal && (
            <div className="fixed inset-0 z-50 overflow-y-auto bg-slate-950/92 p-4 backdrop-blur-sm flex items-center justify-center">
              <div className="relative w-full max-w-md max-h-[90vh] flex flex-col overflow-hidden rounded-[32px] border border-white/10 bg-white/10 shadow-2xl shadow-purple-500/10 backdrop-blur-xl">
                <div className="absolute inset-x-0 top-0 h-1 bg-gradient-to-r from-purple-400 via-pink-400 to-red-500 opacity-80" />
                <div className="flex h-full flex-col overflow-hidden">
                  <div className="flex-shrink-0 border-b border-white/10 p-6 pb-4">
                    <div className="flex items-center justify-between">
                      <div>
                        <h2 className="text-2xl font-semibold text-white">Assign Rider</h2>
                        <p className="text-sm text-slate-400">Assign a delivery rider to order #{riderAssignmentModal.orderNumber || riderAssignmentModal.id}</p>
                      </div>
                      <button onClick={() => setRiderAssignmentModal(null)} className="inline-flex h-11 w-11 items-center justify-center rounded-full border border-slate-700 bg-slate-900 text-slate-200 transition hover:bg-slate-800">
                        <svg viewBox="0 0 24 24" className="h-6 w-6"><path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12 19 6.41z" fill="currentColor"/></svg>
                      </button>
                    </div>
                  </div>
                  <div className="flex-1 overflow-y-auto min-h-0 p-6">
                    <div className="space-y-4">
                      <div>
                        <label className="block text-sm font-medium text-slate-300 mb-2">Select Rider</label>
                        <select value={selectedRider} onChange={(e) => setSelectedRider(e.target.value)} className="w-full rounded-3xl border border-slate-700 bg-slate-900 px-4 py-3 text-sm text-slate-100 outline-none focus:border-purple-500">
                          <option value="">Choose a rider...</option>
                          {getBikers().map((biker) => (
                            <option key={biker.id} value={biker.name}>{biker.name}</option>
                          ))}
                        </select>
                      </div>
                      <div className="flex items-center gap-3">
                        <button onClick={() => assignRiderToOrder(riderAssignmentModal.id, selectedRider)} disabled={!selectedRider} className="flex-1 rounded-3xl bg-purple-600 px-4 py-3 text-sm font-semibold text-white transition hover:bg-purple-500 disabled:cursor-not-allowed disabled:opacity-50">Assign Rider</button>
                        <button onClick={() => { setRiderAssignmentModal(null); setSelectedRider(''); }} className="flex-1 rounded-3xl border border-slate-700 bg-slate-900 px-4 py-3 text-sm font-semibold text-slate-200 transition hover:bg-slate-800">Cancel</button>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}

          {bulkRiderAssignmentOpen && (
            <div className="fixed inset-0 z-50 overflow-y-auto bg-slate-950/92 p-4 backdrop-blur-sm flex items-center justify-center">
              <div className="relative w-full max-w-md max-h-[90vh] flex flex-col overflow-hidden rounded-[32px] border border-white/10 bg-white/10 shadow-2xl shadow-purple-500/10 backdrop-blur-xl">
                <div className="absolute inset-x-0 top-0 h-1 bg-gradient-to-r from-purple-400 via-fuchsia-400 to-pink-500 opacity-80" />
                <div className="flex h-full flex-col overflow-hidden">
                  <div className="flex-shrink-0 border-b border-white/10 p-6 pb-4">
                    <div className="flex items-center justify-between">
                      <div>
                        <h2 className="text-2xl font-semibold text-white">Assign Rider to {selectedOrders.length} Orders</h2>
                        <p className="text-sm text-slate-400">Assign a rider to all selected delivery orders.</p>
                      </div>
                      <button onClick={() => { setBulkRiderAssignmentOpen(false); setSelectedRider(''); }} className="inline-flex h-11 w-11 items-center justify-center rounded-full border border-slate-700 bg-slate-900 text-slate-200 transition hover:bg-slate-800">
                        <svg viewBox="0 0 24 24" className="h-6 w-6"><path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12 19 6.41z" fill="currentColor"/></svg>
                      </button>
                    </div>
                  </div>
                  <div className="flex-1 overflow-y-auto min-h-0 p-6">
                    <div className="space-y-4">
                      <div>
                        <label className="block text-sm font-medium text-slate-300 mb-2">Select Rider</label>
                        <select value={selectedRider} onChange={(e) => setSelectedRider(e.target.value)} className="w-full rounded-3xl border border-slate-700 bg-slate-900 px-4 py-3 text-sm text-slate-100 outline-none focus:border-purple-500">
                          <option value="">Choose a rider...</option>
                          {getBikers().map((biker) => (
                            <option key={biker.id} value={biker.name}>{biker.name}</option>
                          ))}
                        </select>
                      </div>
                      <div className="flex items-center gap-3">
                        <button onClick={assignRiderToSelectedOrders} disabled={!selectedRider} className="flex-1 rounded-3xl bg-purple-600 px-4 py-3 text-sm font-semibold text-white transition hover:bg-purple-500 disabled:cursor-not-allowed disabled:opacity-50">Assign Rider</button>
                        <button onClick={() => { setBulkRiderAssignmentOpen(false); setSelectedRider(''); }} className="flex-1 rounded-3xl border border-slate-700 bg-slate-900 px-4 py-3 text-sm font-semibold text-slate-200 transition hover:bg-slate-800">Cancel</button>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}

          {markPaidOrder && (
            <div className="fixed inset-0 z-50 overflow-y-auto bg-slate-950/92 p-4 backdrop-blur-sm flex items-center justify-center">
              <div className="relative w-full max-w-lg rounded-[32px] border border-white/10 bg-slate-900 p-6 shadow-2xl shadow-emerald-500/10">
                <div className="flex items-start justify-between gap-4">
                  <div>
                    <h2 className="text-2xl font-semibold text-white">Mark Order Paid</h2>
                    <p className="mt-1 text-sm text-slate-400">Collect payment and mark the dine-in order as paid.</p>
                  </div>
                  <button onClick={cancelMarkPaid} className="inline-flex h-11 w-11 items-center justify-center rounded-full border border-slate-700 bg-slate-800 text-slate-200 transition hover:bg-slate-700">
                    <svg viewBox="0 0 24 24" className="h-6 w-6"><path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12 19 6.41z" fill="currentColor"/></svg>
                  </button>
                </div>
                <div className="mt-6 space-y-4">
                  <div className="rounded-3xl border border-slate-700 bg-slate-950 p-4">
                    <div className="text-sm text-slate-400">Order</div>
                    <div className="mt-2 text-lg font-semibold text-white">{markPaidOrder.orderNumber || markPaidOrder.id}</div>
                    <div className="text-sm text-slate-400">Table: {markPaidOrder.tableNumber || 'N/A'}</div>
                    <div className="text-sm text-slate-400">Customer: {markPaidOrder.customerName || 'TABLE'}</div>
                  </div>
                  <div className="grid gap-4 sm:grid-cols-2">
                    <div>
                      <label className="block text-sm text-slate-300 mb-2">Amount collected</label>
                      <input type="number" value={markPaidAmount} onChange={(e) => setMarkPaidAmount(e.target.value)} className="w-full rounded-3xl border border-slate-700 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" />
                    </div>
                    <div>
                      <label className="block text-sm text-slate-300 mb-2">Payment method</label>
                      <select value={markPaidMethod} onChange={(e) => setMarkPaidMethod(e.target.value)} className="w-full rounded-3xl border border-slate-700 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500">
                        {['Cash', 'Card', 'Transfer', 'Other'].map((method) => <option key={method} value={method}>{method}</option>)}
                      </select>
                    </div>
                  </div>
                </div>
                <div className="mt-6 flex justify-end gap-3">
                  <button onClick={cancelMarkPaid} className="rounded-3xl border border-slate-700 bg-slate-800 px-4 py-3 text-sm font-semibold text-slate-200 transition hover:bg-slate-700">Cancel</button>
                  <button onClick={handleMarkPaid} className="rounded-3xl bg-emerald-600 px-4 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-500">Confirm Paid</button>
                </div>
              </div>
            </div>
          )}

          {orderDetailsModal && (
            <div className="fixed inset-0 z-50 overflow-y-auto bg-slate-950/92 p-4 backdrop-blur-sm flex items-center justify-center">
              <div className="relative w-full max-w-2xl max-h-[90vh] flex flex-col overflow-hidden rounded-[32px] border border-white/10 bg-white/10 shadow-2xl shadow-emerald-500/10 backdrop-blur-xl">
                <div className="absolute inset-x-0 top-0 h-1 bg-gradient-to-r from-emerald-400 via-cyan-400 to-blue-500 opacity-80" />
                <div className="flex h-full flex-col overflow-hidden">
                  <div className="flex-shrink-0 border-b border-white/10 p-6 pb-4">
                    <div className="flex items-center justify-between">
                      <div>
                        <h2 className="text-2xl font-semibold text-white">Order Details: {orderDetailsModal.orderNumber || orderDetailsModal.id}</h2>
                        <p className="text-sm text-slate-400">Order information and items</p>
                      </div>
                      <button onClick={() => setOrderDetailsModal(null)} className="inline-flex h-11 w-11 items-center justify-center rounded-full border border-slate-700 bg-slate-900 text-slate-200 transition hover:bg-slate-800">
                        <svg viewBox="0 0 24 24" className="h-6 w-6"><path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12 19 6.41z" fill="currentColor"/></svg>
                      </button>
                    </div>
                  </div>
                  <div className="flex-1 overflow-y-auto p-6">
                    <div className="space-y-6">
                      <div className="grid gap-4 sm:grid-cols-2">
                        <div className="rounded-3xl border border-slate-800 bg-slate-950 p-4">
                          <h3 className="text-lg font-semibold text-white mb-3">Customer Information</h3>
                          <div className="space-y-2 text-sm">
                            <div className="flex justify-between"><span className="text-slate-400">Name:</span><span className="text-white">{orderDetailsModal.customerName || (orderDetailsModal.orderType === 'Dine-In' ? 'TABLE' : 'Walk-In')}</span></div>
                            <div className="flex justify-between"><span className="text-slate-400">Phone:</span><span className="text-white">{orderDetailsModal.phone || '-'}</span></div>
                            <div className="flex justify-between"><span className="text-slate-400">Address:</span><span className="text-white truncate">{orderDetailsModal.address || '-'}</span></div>
                          </div>
                        </div>
                        <div className="rounded-3xl border border-slate-800 bg-slate-950 p-4">
                          <h3 className="text-lg font-semibold text-white mb-3">Order Information</h3>
                          <div className="space-y-2 text-sm">
                            <div className="flex justify-between"><span className="text-slate-400">Status:</span><span className={`px-2 py-1 rounded-full text-xs font-semibold ${getStatusBadge(orderDetailsModal.status)}`}>{orderDetailsModal.status || 'Pending'}</span></div>
                            <div className="flex justify-between"><span className="text-slate-400">Type:</span><span className="text-white">{orderDetailsModal.orderType || 'Dine-In'}</span></div>
                            <div className="flex justify-between"><span className="text-slate-400">Rider:</span><span className="text-white">{orderDetailsModal.deliveryAgent || 'Unassigned'}</span></div>
                            <div className="flex justify-between"><span className="text-slate-400">Payment:</span><span className="text-white">{orderDetailsModal.paymentMethod || 'Cash'}</span></div>
                          </div>
                        </div>
                      </div>

                      <div className="rounded-3xl border border-slate-800 bg-slate-950 p-4">
                        <h3 className="text-lg font-semibold text-white mb-3">Order Items</h3>
                        <div className="space-y-3">
                          {(orderDetailsModal.items || []).map((item, index) => (
                            <div key={index} className="flex items-center justify-between py-2 border-b border-slate-800 last:border-b-0">
                              <div className="flex-1">
                                <div className="font-medium text-white">{item.name || 'Unknown Item'}</div>
                                <div className="text-sm text-slate-400">Qty: {item.quantity || 1}</div>
                                {item.notes && <div className="text-xs text-slate-500 mt-1">{item.notes}</div>}
                              </div>
                              <div className="text-right">
                                <div className="font-semibold text-white">{item.price || 0} Rs</div>
                                <div className="text-sm text-slate-400">Subtotal: {(item.price || 0) * (item.quantity || 1)} Rs</div>
                              </div>
                            </div>
                          ))}
                        </div>
                      </div>

                      <div className="rounded-3xl border border-slate-800 bg-slate-950 p-4">
                        <h3 className="text-lg font-semibold text-white mb-3">Order Summary</h3>
                        <div className="grid grid-cols-2 gap-4 text-sm">
                          <div className="flex justify-between"><span className="text-slate-400">Subtotal:</span><span className="text-white">{orderDetailsModal.subtotal || orderDetailsModal.amount || 0} Rs</span></div>
                          <div className="flex justify-between"><span className="text-slate-400">Discount:</span><span className="text-white">-{orderDetailsModal.discount || 0} Rs</span></div>
                          <div className="flex justify-between"><span className="text-slate-400">Tax:</span><span className="text-white">+{orderDetailsModal.tax || 0} Rs</span></div>
                          <div className="flex justify-between"><span className="text-slate-400">Service type:</span><span className="text-white">{orderDetailsModal.serviceType || '-'}</span></div>
                          <div className="flex justify-between"><span className="text-slate-400">Service charge:</span><span className="text-white">+{orderDetailsModal.serviceCharge || 0} Rs</span></div>
                          <div className="flex justify-between"><span className="text-slate-400">Delivery Fee:</span><span className="text-white">+{orderDetailsModal.deliveryFee || 0} Rs</span></div>
                          <div className="col-span-2 pt-2 border-t border-white/10 flex justify-between text-base font-bold">
                            <span className="text-slate-300">Total:</span><span className="text-emerald-400">{orderDetailsModal.total || orderDetailsModal.amount || 0} Rs</span></div>
                        </div>
                      </div>

                      {orderDetailsModal.notes && (
                        <div className="rounded-3xl border border-slate-800 bg-slate-950 p-4">
                          <h3 className="text-lg font-semibold text-white mb-3">Notes</h3>
                          <p className="text-sm text-slate-300">{orderDetailsModal.notes}</p>
                        </div>
                      )}
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}
          {deleteConfirmOpen && (
            <div className="fixed inset-0 z-50 overflow-y-auto bg-slate-950/92 p-4 backdrop-blur-sm flex items-center justify-center">
              <div className="relative w-full max-w-md max-h-[90vh] flex flex-col overflow-hidden rounded-[24px] border border-white/10 bg-white/10 shadow-2xl">
                <div className="flex-shrink-0 border-b border-white/10 p-6">
                  <div className="flex items-center justify-between">
                    <div>
                      <h2 className="text-xl font-semibold text-white">Confirm Delete</h2>
                      <p className="text-sm text-slate-400">Are you sure you want to delete this order?</p>
                    </div>
                    <button onClick={() => { setDeleteConfirmOpen(false); setOrderToDelete(null); }} className="inline-flex h-10 w-10 items-center justify-center rounded-full border border-slate-700 bg-slate-900 text-slate-200 transition hover:bg-slate-800">
                      <svg viewBox="0 0 24 24" className="h-5 w-5"><path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12 19 6.41z" fill="currentColor"/></svg>
                    </button>
                  </div>
                </div>
                <div className="flex-1 overflow-y-auto p-6">
                  <div className="space-y-4">
                    <div className="rounded-2xl border border-slate-800 bg-slate-950 p-4 text-sm text-slate-300">
                      <div className="flex justify-between"><span className="text-slate-400">Order</span><span className="text-white">{orderToDelete ? (orderToDelete.orderNumber || orderToDelete.id) : '-'}</span></div>
                      <div className="flex justify-between mt-2"><span className="text-slate-400">Customer</span><span className="text-white">{orderToDelete ? (orderToDelete.customerName || orderToDelete.phone || '-') : '-'}</span></div>
                    </div>
                  </div>
                </div>
                <div className="flex-shrink-0 p-4 border-t border-white/10 flex justify-end gap-3">
                  <button onClick={() => { setDeleteConfirmOpen(false); setOrderToDelete(null); }} className="rounded-3xl border border-slate-700 bg-slate-800 px-4 py-2 text-sm font-semibold text-slate-200 transition hover:bg-slate-700">Cancel</button>
                  <button onClick={handleConfirmDelete} className="rounded-3xl bg-rose-600 px-4 py-2 text-sm font-semibold text-white transition hover:bg-rose-500">Delete Order</button>
                </div>
              </div>
            </div>
          )}
      </div>
      {isMobile && (
        <div className="fixed inset-x-0 bottom-0 z-50 border-t border-slate-800 bg-slate-950/95 px-2 py-2 backdrop-blur-xl sm:hidden">
          <div className="mx-auto flex max-w-[1400px] items-center gap-2 overflow-x-auto whitespace-nowrap px-2">
            {tabs.filter(t => t !== 'dashboard' && t !== 'pos' && canAccessTab(t)).map((tab) => (
              <button
                key={tab}
                type="button"
                onClick={() => setActiveTab(tab)}
                className={`inline-flex min-w-[80px] items-center justify-center rounded-3xl px-3 py-2 text-center text-[11px] font-semibold transition ${activeTab === tab ? 'bg-emerald-500 text-white' : 'bg-slate-900 text-slate-300 hover:bg-slate-800'}`}
              >
                <span className="block text-lg">{tabIcons[tab] || (tab === 'riders-app' ? '🚴' : '•')}</span>
                <span className="mt-1 block truncate">{tabLabels[tab] || formatTabName(tab)}</span>
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

export default App;

