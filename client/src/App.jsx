import { useEffect, useMemo, useState } from 'react';

const apiBase = '/api';
const tabs = ['dashboard', 'tables', 'inventory', 'staff', 'sales', 'pos', 'orders', 'rider-book', 'invoices', 'settings'];

function App() {
  const [activeTab, setActiveTab] = useState('dashboard');
  const [loading, setLoading] = useState(false);
  const [dashboard, setDashboard] = useState(null);
  const [items, setItems] = useState([]);
  const [settings, setSettings] = useState({
    hotelName: '',
    currency: '',
    location: '',
    taxRate: 0,
    logo: '',
    receiptLogoWidth: '120',
    receiptHeader: '',
    receiptFooter: '',
    receiptFontSize: '12',
    receiptFontStyle: 'Arial',
    receiptLineStyle: 'dashed',
    receiptShowRiderName: true,
    receiptShowCustomerName: true,
    receiptDateTimeFormat: 'DD/MM/YYYY HH:mm',
    slipPrefix: 'usmanhotel',
    printDeliveryAddress: true,
    printCustomerMobile: true,
    printSubtotal: true,
    printTotal: true,
    printTax: true,
    holdAutoRefreshSeconds: 24,
    holdDefaultViewMode: 'table',
    holdShowAutoRefresh: true
  });
  const [form, setForm] = useState({});
  const [message, setMessage] = useState('');
  const [authMessage, setAuthMessage] = useState('');
  const [token, setToken] = useState(localStorage.getItem('posToken') || '');
  const [user, setUser] = useState(null);
  const [authForm, setAuthForm] = useState({ email: 'admin@usmanhotel.com', password: '' });
  const [posCategories, setPosCategories] = useState([]);
  const [posProducts, setPosProducts] = useState([]);
  const [posTables, setPosTables] = useState([]);
  const [posDeliveryAgents, setPosDeliveryAgents] = useState([]);
  const [posOrders, setPosOrders] = useState([]);
  const [selectedCategory, setSelectedCategory] = useState('All');
  const [posSearch, setPosSearch] = useState('');
  const [cart, setCart] = useState([]);
  const [orderType, setOrderType] = useState('Dine-In');
  const [paymentMethod, setPaymentMethod] = useState('Cash');
  const [orderDetails, setOrderDetails] = useState({
    customerName: '',
    phone: '',
    address: '',
    tableNumber: '',
    deliveryAgent: '',
    serviceType: '',
    deliveryFee: 50,
    discount: 0,
    taxPercent: settings.taxRate || 0,
    serviceCharge: 0,
    notes: ''
  });
  const [orderModalOpen, setOrderModalOpen] = useState(false);
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
    deliveryFee: 50,
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
  const [productForm, setProductForm] = useState({ name: '', category: '', price: '', purchasePrice: '', unit: 'PKR', photo: '', code: '', stock: '' });
  const [ordersMainTab, setOrdersMainTab] = useState('delivery');
  const [deliverySubTab, setDeliverySubTab] = useState('all');
  const [takeawaySubTab, setTakeawaySubTab] = useState('all');
  const [dineinSubTab, setDineinSubTab] = useState('tables');
  const [deliverySettingsSubTab, setDeliverySettingsSubTab] = useState('serviceTypes');
  const [deliveryViewMode, setDeliveryViewMode] = useState('tile');
  const [selectedRider, setSelectedRider] = useState('');
  const [orderFilterRider, setOrderFilterRider] = useState('');
  const [orderFilterPayment, setOrderFilterPayment] = useState('');
  const [orderPageIndex, setOrderPageIndex] = useState(0);
  const [orderPageSize, setOrderPageSize] = useState(6);
  const [darkMode, setDarkMode] = useState(false);
  const [riderAssignmentOrderId, setRiderAssignmentOrderId] = useState(null);
  const [deliveryServiceTypes, setDeliveryServiceTypes] = useState([
    { id: 'standard', name: 'Standard Delivery', charge: 50, location: 'City', active: true },
    { id: 'express', name: 'Express Delivery', charge: 120, location: '', active: true }
  ]);
  const [deliveryLocations, setDeliveryLocations] = useState([
    { id: 'city', name: 'City Area', description: 'Standard city delivery zone' },
    { id: 'suburbs', name: 'Suburbs', description: 'Extended suburb delivery zone' }
  ]);
  const [deliveryServiceForm, setDeliveryServiceForm] = useState({ id: null, name: '', charge: 50, location: '', active: true });
  const [deliveryLocationForm, setDeliveryLocationForm] = useState({ id: null, name: '', description: '' });
  const [selectedOrders, setSelectedOrders] = useState([]);
  const [orderSearch, setOrderSearch] = useState('');
  const [viewOrderModal, setViewOrderModal] = useState(null);
  const [orderDetailsModal, setOrderDetailsModal] = useState(null);

  useEffect(() => {
    setOrderPageIndex(0);
  }, [deliverySubTab, orderSearch, orderFilterRider, orderFilterPayment, orderPageSize]);
  const [riderBookSubTab, setRiderBookSubTab] = useState('all');
  const [riderBookFilterRider, setRiderBookFilterRider] = useState('');
  const [riderBookSelectedOrders, setRiderBookSelectedOrders] = useState([]);
  const [riderBookSearch, setRiderBookSearch] = useState('');
  const [riderBookPageSize, setRiderBookPageSize] = useState(15);
  const [riderBookPageIndex, setRiderBookPageIndex] = useState(0);
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
  const [roles, setRoles] = useState([
    { name: 'Admin', permissions: { dashboard: true, tables: true, inventory: true, staff: true, sales: true, pos: true, orders: true, invoices: true, settings: true, login: true } },
    { name: 'Cashier', permissions: { dashboard: false, tables: false, inventory: false, staff: false, sales: false, pos: true, orders: true, invoices: false, settings: false, login: true } },
    { name: 'Manager', permissions: { dashboard: true, tables: true, inventory: true, staff: false, sales: true, pos: true, orders: true, invoices: true, settings: true, login: true } },
    { name: 'Biker', permissions: { dashboard: false, tables: false, inventory: false, staff: false, sales: false, pos: false, orders: true, invoices: false, settings: false, login: true } },
    { name: 'Waiter', permissions: { dashboard: false, tables: false, inventory: false, staff: false, sales: false, pos: false, orders: true, invoices: false, settings: false, login: true } },
    { name: 'Helper', permissions: { dashboard: false, tables: false, inventory: false, staff: false, sales: false, pos: false, orders: false, invoices: false, settings: false, login: true } },
    { name: 'Tandoor Staff', permissions: { dashboard: false, tables: false, inventory: false, staff: false, sales: false, pos: false, orders: false, invoices: false, settings: false, login: true } },
    { name: 'BS', permissions: { dashboard: false, tables: false, inventory: false, staff: false, sales: false, pos: false, orders: false, invoices: false, settings: false, login: true } }
  ]);

  useEffect(() => {
    const storedServiceTypes = localStorage.getItem('deliveryServiceTypes');
    const storedLocations = localStorage.getItem('deliveryLocations');
    if (storedServiceTypes) {
      try {
        setDeliveryServiceTypes(JSON.parse(storedServiceTypes));
      } catch (error) {
        console.error('Invalid stored service types', error);
      }
    }
    if (storedLocations) {
      try {
        setDeliveryLocations(JSON.parse(storedLocations));
      } catch (error) {
        console.error('Invalid stored locations', error);
      }
    }
  }, []);

  useEffect(() => {
    localStorage.setItem('deliveryServiceTypes', JSON.stringify(deliveryServiceTypes));
  }, [deliveryServiceTypes]);

  useEffect(() => {
    localStorage.setItem('deliveryLocations', JSON.stringify(deliveryLocations));
  }, [deliveryLocations]);

  useEffect(() => {
    if (token) {
      validateToken();
    }
  }, [token]);

  useEffect(() => {
    if (user) {
      loadTab(activeTab);
    }
  }, [activeTab, user]);

  useEffect(() => {
    setOrderDetails((prev) => ({ ...prev, taxPercent: settings.taxRate || 0 }));
  }, [settings.taxRate]);

  useEffect(() => {
    setRiderBookPageIndex(0);
  }, [riderBookFilterRider, riderBookSubTab, riderBookSearch, riderBookPageSize]);

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
      case 'invoices':
        return 'Invoice Center';
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

    if (!response.ok) {
      const errorBody = await response.json().catch(() => ({}));
      throw new Error(errorBody.error || response.statusText);
    }
    return response.json();
  }

  async function validateToken() {
    setLoading(true);
    setAuthMessage('');
    try {
      const data = await fetchJson(`${apiBase}/auth/me`);
      setUser(data);
      setAuthMessage('');
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
      setActiveTab('dashboard');
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
    setAuthForm({ email: 'admin@usmanhotel.com', password: '' });
    setMessage('Logged out');
  }

  async function loadTab(tab) {
    setLoading(true);
    setMessage('');
    try {
      if (tab === 'dashboard') {
        const data = await fetchJson(`${apiBase}/dashboard`);
        setDashboard(data);
      } else if (tab === 'settings') {
        const data = await fetchJson(`${apiBase}/settings`);
        setSettings(data);
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
      } else if (tab === 'pos') {
        await loadPosData();
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
    } catch (error) {
      setMessage(error.message);
    } finally {
      setLoading(false);
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
      const [categories, products, tables, agents, staff, orders] = await Promise.all([
        fetchJson(`${apiBase}/pos/categories`),
        fetchJson(`${apiBase}/pos/products`),
        fetchJson(`${apiBase}/pos/tables`),
        fetchJson(`${apiBase}/pos/delivery-agents`),
        fetchJson(`${apiBase}/staff`),
        fetchJson(`${apiBase}/pos/orders`)
      ]);

      setPosCategories(categories);
      setPosProducts(products);
      setPosTables(tables);
      setPosDeliveryAgents([
        ...(agents || []),
        ...((staff || []).filter((member) => member.role === 'Biker' && member.loginEnabled))
      ]);
      setPosOrders(orders);
      setSelectedCategory('All');
      setPosSearch('');
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
    document.body.style.overflow = (holdModalOpen || orderModalOpen || orderDetailsModal || markPaidOrder || showTableModal) ? 'hidden' : '';
    return () => {
      document.body.style.overflow = '';
    };
  }, [holdModalOpen, orderModalOpen, orderDetailsModal, markPaidOrder, showTableModal]);

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
      await fetchJson(`${apiBase}/pos/products`, {
        method: 'POST',
        body: JSON.stringify(productForm)
      });
      setProductForm({ name: '', category: '', price: '', purchasePrice: '', unit: 'PKR', photo: '', code: '', stock: '' });
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
        stock: product.stock || ''
      });
    } else {
      setEditingProduct(null);
      setProductForm({ name: '', category: '', price: '', purchasePrice: '', unit: 'PKR', photo: '', code: '', stock: '' });
    }
    setShowProductModal(true);
  };

  async function saveProduct() {
    if (!editingProduct) {
      return addProduct();
    }
    setLoading(true);
    setMessage('');
    try {
      await fetchJson(`${apiBase}/pos/products/${editingProduct.id}`, {
        method: 'PUT',
        body: JSON.stringify(productForm)
      });
      setProductForm({ name: '', category: '', price: '', purchasePrice: '', unit: 'PKR', photo: '', code: '', stock: '' });
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
    return posProducts.filter((product) => {
      const matchesCategory = selectedCategory === 'All' || product.category === selectedCategory;
      const searchTerm = posSearch.toLowerCase();
      const matchesSearch = product.name.toLowerCase().includes(searchTerm) || product.category.toLowerCase().includes(searchTerm);
      return matchesCategory && (!searchTerm || matchesSearch);
    });
  }

  function addToCart(product) {
    setMessage('');
    setCart((prev) => {
      const existing = prev.find((item) => item.productId === product.id);
      if (existing) {
        return prev.map((item) => (item.productId === product.id ? { ...item, quantity: item.quantity + 1 } : item));
      }
      return [...prev, { productId: product.id, name: product.name, price: product.price, quantity: 1, notes: '' }];
    });
  }

  function updateCartItem(productId, delta) {
    setCart((prev) =>
      prev
        .map((item) => (item.productId === productId ? { ...item, quantity: Math.max(1, item.quantity + delta) } : item))
        .filter((item) => item.quantity > 0)
    );
  }

  function removeCartItem(productId) {
    setCart((prev) => prev.filter((item) => item.productId !== productId));
  }

  function updateCartNotes(productId, notes) {
    setCart((prev) => prev.map((item) => (item.productId === productId ? { ...item, notes } : item)));
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
    if (orderType === 'Delivery' && (!orderDetails.customerName || !orderDetails.phone || !orderDetails.address || !orderDetails.serviceType)) {
      return 'Delivery orders require customer name, phone, address and service type.';
    }
    if (orderType === 'Dine-In' && !orderDetails.tableNumber) {
      return 'Please select a table or room for Dine-In orders.';
    }
    return '';
  }

  async function savePosOrder(orderStatus = 'Pending') {
    const error = validatePosOrder();
    if (error) {
      setMessage(error);
      return null;
    }

    setLoading(true);
    setMessage('');
    try {
      const payload = {
        items: cart,
        orderType,
        customerName: orderDetails.customerName,
        phone: orderDetails.phone,
        address: orderDetails.address,
        tableNumber: orderDetails.tableNumber,
        deliveryAgent: orderDetails.deliveryAgent,
        serviceType: orderDetails.serviceType,
        deliveryFee: Number(orderDetails.deliveryFee) || 0,
        discount: Number(orderDetails.discount) || 0,
        taxPercent: Number(orderDetails.taxPercent) || 0,
        serviceCharge: Number(orderDetails.serviceCharge) || 0,
        paymentMethod,
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
      setCurrentSavedOrder(order);
      setCart([]);
      setOrderDetails((prev) => ({ ...prev, customerName: '', phone: '', address: '', tableNumber: '', deliveryAgent: '' }));
      setEditingOrder(null);
      await loadPosData();
      return order;
    } catch (error) {
      setMessage(error.message);
      return null;
    } finally {
      setLoading(false);
    }
  }

  async function completePayment() {
    const order = await savePosOrder('Completed');
    if (!order) return;

    setLoading(true);
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
      await loadPosData();
    } catch (error) {
      setMessage(error.message);
    } finally {
      setLoading(false);
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
      setRiderAssignmentOrderId(null);
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
      address: order.address || '',
      tableNumber: order.tableNumber || '',
      deliveryAgent: order.deliveryAgent || '',
      serviceType: order.serviceType || '',
      deliveryFee: order.deliveryFee || 0,
      discount: order.discount || 0,
      taxPercent: order.taxPercent || settings.taxRate || 0,
      serviceCharge: order.serviceCharge || 0,
      paymentMethod: order.paymentMethod || 'Cash',
      notes: order.notes || '',
      status: order.status || ''
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
      address: order.address || '',
      tableNumber: order.tableNumber || '',
      deliveryAgent: order.deliveryAgent || '',
      serviceType: order.serviceType || '',
      deliveryFee: order.deliveryFee || 0,
      discount: order.discount || 0,
      taxPercent: order.taxPercent || settings.taxRate || 0,
      serviceCharge: order.serviceCharge || 0,
      notes: order.notes || ''
    });
    setEditingOrder(order);
    setCurrentSavedOrder(order);
    setMessage('Loaded order for editing in POS. Adjust items and save to update.');
  };

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
        address: orderEditForm.address,
        tableNumber: orderEditForm.tableNumber,
        deliveryAgent: orderEditForm.deliveryAgent,
        serviceType: orderEditForm.serviceType,
        deliveryFee: Number(orderEditForm.deliveryFee) || 0,
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
  }

  async function handleMarkPaid() {
    if (!markPaidOrder) return;
    setLoading(true);
    setMessage('');
    try {
      await fetchJson(`${apiBase}/pos/orders/${markPaidOrder.id}/status`, {
        method: 'PUT',
        body: JSON.stringify({ status: 'Payment Collected' })
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

  function cancelMarkPaid() {
    setMarkPaidOrder(null);
    setMarkPaidAmount('');
    setMarkPaidMethod('Cash');
  }

  function printReceipt(order) {
    const header = settings.receiptHeader || 'Usman Hotel';
    const footer = settings.receiptFooter || 'Thank you for your business';
    const slipNumber = `${settings.slipPrefix || 'UH'}-${order.orderNumber || order.id || Date.now()}`;
    const dateText = formatReceiptDate(order.date || new Date().toISOString(), settings.receiptDateTimeFormat || 'DD/MM/YYYY HH:mm');
    const lineStyle = settings.receiptLineStyle === 'solid' ? '1px solid #444' : settings.receiptLineStyle === 'dashed' ? '1px dashed #444' : 'none';
    const items = (order.items || []).map((item) => `<div class="item"><span>${item.name} x${item.quantity}</span><span>${item.total || item.price * item.quantity || 0} ${settings.currency || 'PKR'}</span></div>`).join('');
    const customerNameLine = settings.receiptShowCustomerName ? `<div class="meta">Customer: ${order.customerName || 'Walk-in'}</div>` : '';
    const phoneHtml = settings.printCustomerMobile ? `<div>Phone: ${order.phone || '-'}</div>` : '';
    const riderHtml = settings.receiptShowRiderName && order.deliveryAgent ? `<div>Rider: ${order.deliveryAgent}</div>` : '';
    const contactLine = (phoneHtml || riderHtml) ? `<div class="meta-row">${phoneHtml}${riderHtml}</div>` : '';
    const addressLine = settings.printDeliveryAddress ? `<div class="meta">Address: ${order.address || '-'}</div>` : '';
    const subtotalLine = settings.printSubtotal ? `<div class="item"><span>Subtotal</span><span>${order.subtotal || 0} ${settings.currency || 'PKR'}</span></div>` : '';
    const taxLine = settings.printTax ? `<div class="item"><span>Tax</span><span>${order.taxPercent || 0} %</span></div>` : '';
    const totalLine = settings.printTotal ? `<div class="item total"><span>Total</span><span>${order.total || 0} ${settings.currency || 'PKR'}</span></div>` : '';
    const logoHtml = settings.logo ? `<div class="logo"><img src="${settings.logo}" alt="Logo" style="max-width: ${settings.receiptLogoWidth || 120}px; width: auto; height: auto; display: block; margin: 0 auto;" /></div>` : '';
    const fontSize = `${settings.receiptFontSize || 12}px`;
    const fontFamily = settings.receiptFontStyle || 'Arial';

    const content = `
      <html>
        <head>
          <style>
            body { font-family: ${fontFamily}, Arial, sans-serif; padding: 10px 20px 10px; color: #000; }
            .receipt { max-width: 320px; margin: auto; padding: 0; }
            .header { text-align: center; margin-bottom: 6px; }
            .header > * { margin: 0; padding: 0; }
            .header img { margin: 0 auto 0; display: block; }
            .line { border-bottom: ${lineStyle}; margin: 6px 0; }
            .item { display: flex; justify-content: space-between; font-size: ${fontSize}; }
            .total { font-weight: bold; margin-top: 10px; font-size: ${fontSize}; }
            .meta { font-size: ${fontSize}; margin-bottom: 6px; }
            .meta-row { display: flex; justify-content: space-between; gap: 16px; font-size: ${fontSize}; margin-bottom: 6px; }
            .small-meta { font-size: 10px; color: #444; }
          </style>
        </head>
        <body>
          <div class="receipt">
            <div class="header">
              ${logoHtml}
              <h2>${header}</h2>
              <div>${settings.location || ''}</div>
            </div>
            <div class="meta-row">
              <div class="small-meta">Slip: ${slipNumber}</div>
              <div class="small-meta">${dateText}</div>
            </div>
            ${customerNameLine}
            ${contactLine}
            ${addressLine}
            <div class="line"></div>
            ${items}
            <div class="line"></div>
            ${subtotalLine}
            <div class="item"><span>Discount</span><span>${order.discount || 0} ${settings.currency || 'PKR'}</span></div>
            ${taxLine}
            <div class="item"><span>Service</span><span>${order.serviceCharge || 0} ${settings.currency || 'PKR'}</span></div>
            <div class="line"></div>
            ${totalLine}
            <div class="footer">${footer}</div>
          </div>
        </body>
      </html>
    `;
    const printWindow = window.open('', '_blank');
    printWindow.document.write(content);
    printWindow.document.close();
    printWindow.focus();
    printWindow.print();
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

  const openViewOrderModal = (order) => {
    setOrderDetailsModal(order);
  };

  const openRiderAssignmentModal = (order) => {
    setRiderAssignmentOrderId(order.id);
    setSelectedRider(order.deliveryAgent || '');
  };

  const getProductById = (productId) => posProducts.find((product) => product.id === productId) || {};
  const getOrderItemCategory = (item) => (getProductById(item.productId).category || '').toLowerCase();
  const calculateOrderAmountByCategories = (order, categories) => {
    return (order.items || []).reduce((sum, item) => {
      const category = getOrderItemCategory(item);
      const matches = categories.some((cat) => category === cat.toLowerCase() || category.includes(cat.toLowerCase()));
      return matches ? sum + (Number(item.price) || 0) * (Number(item.quantity) || 0) : sum;
    }, 0);
  };

  const getOrderExtrasAmount = (order) => calculateOrderAmountByCategories(order, ['Extras']);
  const getOrderBbqTandoorAmount = (order) => calculateOrderAmountByCategories(order, ['BBQ', 'Tandoor']);
  const getOrderServiceTypeCharge = (order) => {
    const fee = Number(order.deliveryFee || 0);
    if (order.serviceType) {
      const type = deliveryServiceTypes.find((type) => type.name === order.serviceType);
      return type ? Number(type.charge || fee) : fee;
    }
    return fee;
  };

  const riderBookAssignedOrders = posOrders.filter((order) => order.deliveryAgent);
  const riderBookFilteredByRider = riderBookFilterRider
    ? riderBookAssignedOrders.filter((order) => order.deliveryAgent === riderBookFilterRider)
    : riderBookAssignedOrders;
  const riderBookFilteredBySubTab = riderBookFilteredByRider.filter((order) => {
    if (riderBookSubTab === 'cash') {
      return String(order.paymentMethod || '').toLowerCase() === 'cash';
    }
    if (riderBookSubTab === 'online') {
      return String(order.paymentMethod || '').toLowerCase() === 'online';
    }
    if (riderBookSubTab === 'pending') {
      return order.status === 'Payment Pending';
    }
    if (riderBookSubTab === 'paid') {
      return ['Payment Collected', 'Completed'].includes(order.status);
    }
    return true;
  });
  const riderBookSearchFiltered = riderBookFilteredBySubTab.filter((order) => {
    const search = riderBookSearch.trim().toLowerCase();
    if (!search) return true;
    return [order.orderNumber, order.customerName, order.phone, order.address, order.deliveryAgent, order.serviceType]
      .filter(Boolean)
      .some((value) => value.toLowerCase().includes(search));
  });

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

  const riderBookRiders = Array.from(new Set(riderBookAssignedOrders.map((order) => order.deliveryAgent).filter(Boolean)));

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

  async function updateRiderBookOrdersStatus(orderIds, status, paymentMethod = null) {
    if (!orderIds.length) {
      setMessage('Please select at least one order to update.');
      return;
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
            paymentMethod: paymentMethod || order.paymentMethod
          })
        });
      }));
      setMessage(`Updated ${orderIds.length} rider order(s) to ${status}.`);
      setRiderBookSelectedOrders([]);
      await loadOrdersData();
    } catch (error) {
      setMessage(error.message);
    } finally {
      setLoading(false);
    }
  }

  const markRiderPaid = (method) => updateRiderBookOrdersStatus(riderBookSelectedOrders, 'Payment Collected', method);
  const markCustomerPending = () => updateRiderBookOrdersStatus(riderBookSelectedOrders, 'Payment Pending');

  const renderRiderBook = () => {
    const displayTotals = riderBookSelectedOrdersList.length ? selectedTotals : riderBookTotals;
    const pageStart = riderBookPageIndex * riderBookPageSize + 1;
    const pageEnd = Math.min((riderBookPageIndex + 1) * riderBookPageSize, riderBookVisibleOrders.length);

    return (
      <div className="space-y-6">
        <div className="rounded-[32px] border border-slate-800 bg-slate-900 p-6 shadow-soft">
          <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
            <div>
              <p className="text-sm uppercase tracking-[0.2em] text-slate-400">Rider Book</p>
              <h2 className="mt-2 text-3xl font-semibold text-white">Assigned rider order summary</h2>
              <p className="mt-2 max-w-2xl text-sm text-slate-400">Track assigned orders, extras, service charges, and rider receipts in one place.</p>
            </div>
            <div className="rounded-3xl border border-slate-700 bg-slate-950 px-4 py-3 text-sm font-semibold text-white">
              {riderBookFilteredByRider.length} assigned order{riderBookFilteredByRider.length === 1 ? '' : 's'}
            </div>
          </div>

          <div className="mt-6 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <div className="rounded-3xl border border-slate-800 bg-slate-950 p-3">
              <p className="text-[11px] uppercase tracking-[0.24em] text-slate-500">Total amount</p>
              <p className="mt-2 text-xl font-semibold text-white">{displayTotals.total} Rs</p>
            </div>
            <div className="rounded-3xl border border-slate-800 bg-slate-950 p-3">
              <p className="text-[11px] uppercase tracking-[0.24em] text-slate-500">Extras total</p>
              <p className="mt-2 text-xl font-semibold text-white">{displayTotals.extras} Rs</p>
            </div>
            <div className="rounded-3xl border border-slate-800 bg-slate-950 p-3">
              <p className="text-[11px] uppercase tracking-[0.24em] text-slate-500">Service charges</p>
              <p className="mt-2 text-xl font-semibold text-white">{displayTotals.serviceType} Rs</p>
            </div>
            <div className="rounded-3xl border border-slate-800 bg-slate-950 p-3">
              <p className="text-[11px] uppercase tracking-[0.24em] text-slate-500">BBQ / Tandoor</p>
              <p className="mt-2 text-xl font-semibold text-white">{displayTotals.bbqTandoor} Rs</p>
            </div>
          </div>

          <div className="mt-6 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <div className="rounded-3xl border border-emerald-500/20 bg-slate-950/80 p-3">
              <p className="text-[11px] uppercase tracking-[0.24em] text-slate-500">Total excluding extras & service</p>
              <p className="mt-2 text-xl font-semibold text-emerald-300">{displayTotals.excluded} Rs</p>
            </div>
            <div className="rounded-3xl border border-slate-800 bg-slate-950 p-3">
              <p className="text-[11px] uppercase tracking-[0.24em] text-slate-500">Visible orders</p>
              <p className="mt-2 text-xl font-semibold text-white">{riderBookVisibleOrders.length}</p>
            </div>
            <div className="rounded-3xl border border-slate-800 bg-slate-950 p-3">
              <p className="text-[11px] uppercase tracking-[0.24em] text-slate-500">Page size</p>
              <p className="mt-2 text-xl font-semibold text-white">{riderBookPageSize}</p>
            </div>
            <div className="rounded-3xl border border-slate-800 bg-slate-950 p-3">
              <p className="text-[11px] uppercase tracking-[0.24em] text-slate-500">Selection</p>
              <p className="mt-2 text-xl font-semibold text-white">{riderBookSelectedOrders.length || 0}</p>
            </div>
          </div>
        </div>

        <div className="rounded-[32px] border border-slate-800 bg-slate-900 p-5 shadow-soft">
          <div className="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
            <div>
              <p className="text-sm uppercase tracking-[0.2em] text-slate-400">Filter Rider</p>
              <h3 className="mt-2 text-xl font-semibold text-white">Select rider</h3>
            </div>
            <div className="rounded-3xl bg-slate-950 px-3 py-2 text-sm text-slate-300">{riderBookRiders.length} riders assigned</div>
          </div>
          <select value={riderBookFilterRider} onChange={(e) => setRiderBookFilterRider(e.target.value)} className="mt-4 w-full rounded-3xl border border-slate-800 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500">
            <option value="">All Riders</option>
            {riderBookRiders.map((rider) => (
              <option key={rider} value={rider}>{rider}</option>
            ))}
          </select>
          <div className="mt-4 text-sm leading-6 text-slate-400">Filter by rider and use the tabs below to quickly switch between order groups.</div>
        </div>

        <div className="rounded-[32px] border border-slate-800 bg-slate-900 p-5 shadow-soft">
          <div className="flex flex-wrap items-center justify-between gap-3 mb-4">
            <div className="flex flex-wrap items-center gap-2">
              <button onClick={() => selectAllRiderBookOrders(riderBookVisibleOrders)} className="rounded-full bg-slate-800 px-4 py-2 text-sm text-slate-200 transition hover:bg-slate-700">Select All</button>
              <button onClick={clearRiderBookSelection} className="rounded-full bg-slate-800 px-4 py-2 text-sm text-slate-200 transition hover:bg-slate-700">Clear</button>
              <span className="text-sm text-slate-400">{riderBookSelectedOrders.length} selected</span>
            </div>
            <div className="flex flex-wrap items-center gap-3">
              <div className="rounded-full border border-slate-800 bg-slate-950 px-3 py-2 text-sm text-slate-300">
                {riderBookSubTab === 'all' ? 'All Orders' : riderBookSubTab === 'paid' ? 'Paid Orders' : riderBookSubTab === 'cash' ? 'Cash Orders' : riderBookSubTab === 'online' ? 'Online Orders' : 'Pending Orders'}
              </div>
              <input
                type="text"
                value={riderBookSearch}
                onChange={(e) => setRiderBookSearch(e.target.value)}
                placeholder="Search rider orders..."
                className="min-w-[240px] rounded-full border border-slate-800 bg-slate-900 px-4 py-2 text-sm text-slate-100 outline-none focus:border-emerald-500"
              />
            </div>
          </div>

          <div className="flex flex-wrap gap-3 mb-3">
            {['all', 'paid', 'cash', 'online', 'pending'].map((tab) => (
              <button
                key={tab}
                onClick={() => setRiderBookSubTab(tab)}
                className={`rounded-full px-3 py-2 text-sm font-semibold transition ${riderBookSubTab === tab ? 'bg-emerald-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}
              >
                {tab === 'all' ? 'All' : tab === 'paid' ? 'Paid Orders' : tab === 'cash' ? 'Cash' : tab === 'online' ? 'Online' : 'Pending'}
              </button>
            ))}
          </div>

          <div className="flex flex-wrap items-center justify-between gap-3 mb-4">
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
            <div className="flex flex-wrap gap-3">
              <button onClick={() => markRiderPaid('Cash')} className="rounded-full bg-slate-800 px-4 py-2 text-sm font-semibold text-slate-200 transition hover:bg-slate-700">Mark Cash</button>
              <button onClick={() => markRiderPaid('Online')} className="rounded-full bg-slate-800 px-4 py-2 text-sm font-semibold text-slate-200 transition hover:bg-slate-700">Mark Online</button>
              <button onClick={() => markRiderPaid()} className="rounded-full bg-slate-800 px-4 py-2 text-sm font-semibold text-slate-200 transition hover:bg-slate-700">Mark Paid</button>
              <button onClick={markCustomerPending} className="rounded-full bg-slate-800 px-4 py-2 text-sm font-semibold text-slate-200 transition hover:bg-slate-700">Mark Pending Due</button>
            </div>
          </div>
        </div>

        <div className="rounded-[32px] border border-slate-800 bg-slate-950 p-4 shadow-soft">
          <div className="hidden md:grid grid-cols-[40px_1.5fr_1.2fr_1.2fr_1.2fr_1fr_1fr] gap-3 text-xs uppercase tracking-[0.18em] text-slate-400 border-b border-slate-800 pb-3">
            <span></span>
            <span>Order / Customer</span>
            <span>Rider</span>
            <span>Service</span>
            <span>Status</span>
            <span className="text-right">Amount</span>
            <span></span>
          </div>
          <div className="space-y-2">
            {riderBookPaginatedOrders.map((order) => {
              const extrasAmount = getOrderExtrasAmount(order);
              const serviceCharge = getOrderServiceTypeCharge(order);
              const bbqTandoorAmount = getOrderBbqTandoorAmount(order);
              const isSelected = riderBookSelectedOrders.includes(order.id);
              return (
                <div key={order.id} className="grid grid-cols-[40px_1.5fr_1.2fr_1.2fr_1.2fr_1fr_1fr] gap-3 rounded-3xl border border-slate-800 bg-slate-900 p-3 text-sm text-slate-200 items-center">
                  <input type="checkbox" checked={isSelected} onChange={() => toggleRiderBookOrderSelection(order.id)} className="h-4 w-4 rounded border-slate-700 bg-slate-900 text-emerald-600 focus:ring-emerald-500" />
                  <div className="space-y-1">
                    <div className="font-semibold text-white">{order.orderNumber || order.id}</div>
                    <div className="text-xs text-slate-500">{order.customerName || 'Walk-In'} · {order.phone || 'No Phone'}</div>
                  </div>
                  <div className="text-sm text-slate-100">{order.deliveryAgent || '-'}</div>
                  <div className="text-sm text-slate-100">{order.serviceType || '-'}</div>
                  <div className="text-sm font-semibold text-white">{order.status || 'Pending'}</div>
                  <div className="text-right font-semibold text-white">{Number(order.total || order.amount || 0)} Rs</div>
                  <button onClick={() => openViewOrderModal(order)} className="rounded-full border border-slate-700 bg-slate-950 p-2 text-slate-200 transition hover:bg-slate-800" title="View details">
                    <svg viewBox="0 0 24 24" className="h-4 w-4"><path d="M12 7a5 5 0 100 10 5 5 0 000-10zm0-5C7 2 2.7 4.4 1 8.5 2.7 12.6 7 15 12 15s9.3-2.4 11-6.5C21.3 4.4 17 2 12 2zm0 11a4 4 0 110-8 4 4 0 010 8z" fill="currentColor"/></svg>
                  </button>
                </div>
              );
            })}
            {!riderBookPaginatedOrders.length && (
              <div className="rounded-3xl border border-slate-800 bg-slate-900 p-8 text-center text-slate-400">No rider orders found for the selected filters.</div>
            )}
          </div>
        </div>

        <div className="flex flex-wrap items-center justify-between gap-3 text-sm text-slate-400">
          <div>{riderBookVisibleOrders.length ? `Showing ${pageStart}-${pageEnd} of ${riderBookVisibleOrders.length}` : 'No orders to display'}</div>
          <div className="flex items-center gap-2">
            <button onClick={() => setRiderBookPageIndex((prev) => Math.max(prev - 1, 0))} disabled={riderBookPageIndex === 0} className="rounded-full bg-slate-800 px-3 py-2 text-sm text-slate-200 transition hover:bg-slate-700 disabled:opacity-50">Prev</button>
            <button onClick={() => setRiderBookPageIndex((prev) => Math.min(prev + 1, riderBookPageCount - 1))} disabled={riderBookPageIndex >= riderBookPageCount - 1} className="rounded-full bg-slate-800 px-3 py-2 text-sm text-slate-200 transition hover:bg-slate-700 disabled:opacity-50">Next</button>
          </div>
        </div>
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

  async function saveStaff() {
    if (!staffForm.name || !staffForm.username || !staffForm.password || !staffForm.role) {
      setMessage('Please fill all required fields');
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
      if (editingStaff) {
        await fetchJson(`${apiBase}/staff/${editingStaff.id}`, {
          method: 'PUT',
          body: JSON.stringify(payload)
        });
        setMessage('Staff updated successfully');
      } else {
        await fetchJson(`${apiBase}/staff`, {
          method: 'POST',
          body: JSON.stringify(payload)
        });
        setMessage('Staff added successfully');
      }
      setShowStaffModal(false);
      await loadTab('staff');
    } catch (error) {
      setMessage(error.message);
    } finally {
      setLoading(false);
    }
  }

  const updateRolePermissions = (roleName, permission, value) => {
    setRoles(roles.map(role =>
      role.name === roleName
        ? { ...role, permissions: { ...role.permissions, [permission]: value } }
        : role
    ));
  };

  const getBikers = () => {
    const bikers = (posDeliveryAgents || []).filter((agent) => agent.role === 'Biker' && agent.loginEnabled);
    if (bikers.length > 0) return bikers;
    return items.filter((staff) => staff.role === 'Biker' && staff.loginEnabled);
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

  const saveDeliveryServiceType = () => {
    if (!deliveryServiceForm.name.trim()) {
      setMessage('Service type name is required.');
      return;
    }
    const payload = {
      ...deliveryServiceForm,
      id: deliveryServiceForm.id || `stype-${Date.now()}`
    };
    setDeliveryServiceTypes((prev) => {
      const existing = prev.find((type) => type.id === payload.id);
      if (existing) {
        return prev.map((type) => (type.id === payload.id ? payload : type));
      }
      return [...prev, payload];
    });
    setDeliveryServiceForm({ id: null, name: '', charge: 50, location: '', active: true });
    setMessage('Service type saved.');
  };

  const deleteDeliveryServiceType = (id) => {
    setDeliveryServiceTypes((prev) => prev.filter((type) => type.id !== id));
    setMessage('Service type deleted.');
  };

  const editDeliveryServiceType = (type) => {
    setDeliveryServiceForm({ ...type });
  };

  const saveDeliveryLocation = () => {
    if (!deliveryLocationForm.name.trim()) {
      setMessage('Location name is required.');
      return;
    }
    const payload = {
      ...deliveryLocationForm,
      id: deliveryLocationForm.id || `loc-${Date.now()}`
    };
    setDeliveryLocations((prev) => {
      const existing = prev.find((loc) => loc.id === payload.id);
      if (existing) {
        return prev.map((loc) => (loc.id === payload.id ? payload : loc));
      }
      return [...prev, payload];
    });
    setDeliveryLocationForm({ id: null, name: '', description: '' });
    setMessage('Location saved.');
  };

  const deleteDeliveryLocation = (id) => {
    setDeliveryLocations((prev) => prev.filter((loc) => loc.id !== id));
    setMessage('Location deleted.');
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
      Completed: 'bg-slate-600',
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
    if (activeTab === 'invoices') return renderInvoices();
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
      </div>
    );
  }

  function renderInventory() {
    return (
      <div className="space-y-6">
        <div className="flex gap-3">
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
        </div>
        {inventorySubTab === 'categories' && renderCategories()}
        {inventorySubTab === 'products' && renderProducts()}
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
              <div className="mt-1 text-slate-400">Stock: {(product.stock != null ? product.stock : (product.availableStock != null ? product.availableStock : 'Unlimited'))}</div>
            </div>
          ))}
        </div>
        {showProductModal && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
            <div className="bg-slate-900 rounded-3xl p-6 w-full max-w-md">
              <h3 className="text-lg font-semibold text-white mb-4">{editingProduct ? 'Edit Product' : 'Add New Product'}</h3>
              <div className="space-y-4">
                <input value={productForm.name} onChange={(e) => setProductForm({ ...productForm, name: e.target.value })} placeholder="Product Name" className="w-full rounded-3xl border border-slate-800 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" />
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
              </div>
              <div className="flex gap-3 mt-6">
                <button onClick={editingProduct ? saveProduct : addProduct} className="flex-1 rounded-3xl bg-emerald-600 px-4 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-500">{editingProduct ? 'Save Product' : 'Add Product'}</button>
                <button onClick={() => { setShowProductModal(false); setEditingProduct(null); }} className="flex-1 rounded-3xl bg-slate-800 px-4 py-3 text-sm font-semibold text-white transition hover:bg-slate-700">Cancel</button>
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
                  <div className="text-slate-400">{member.role}</div>
                  <div className="text-sm text-slate-400 mt-1">{member.username}</div>
                  {member.phone && <div className="text-sm text-slate-400">{member.phone}</div>}
                </div>
                <span className={`rounded-full px-3 py-1 text-sm text-slate-100 ${member.status === 'active' ? 'bg-emerald-600' : 'bg-slate-700'}`}>{member.status}</span>
              </div>
              {member.facePhoto && <img src={member.facePhoto} alt={member.name} className="w-16 h-16 rounded-full mt-3 object-cover" />}
              <div className="flex gap-2 mt-4">
                <button onClick={() => openStaffModal(member)} className="flex-1 rounded-full bg-blue-600 px-3 py-2 text-sm text-white transition hover:bg-blue-700">Edit</button>
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
                <input type="password" value={staffForm.password} onChange={(e) => setStaffForm({ ...staffForm, password: e.target.value })} placeholder="Password *" className="rounded-3xl border border-slate-800 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" required />
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

  function renderRoles() {
    return (
      <div className="space-y-4">
        {roles.map((role) => (
          <div key={role.name} className="rounded-3xl border border-slate-800 bg-slate-900 p-5">
            <h4 className="text-lg font-semibold text-white mb-4">{role.name}</h4>
            <div className="grid gap-3 md:grid-cols-2 lg:grid-cols-3">
              {Object.entries(role.permissions).map(([perm, value]) => (
                <label key={perm} className="flex items-center gap-2">
                  <input
                    type="checkbox"
                    checked={value}
                    onChange={(e) => updateRolePermissions(role.name, perm, e.target.checked)}
                    className="rounded border-slate-600"
                  />
                  <span className="text-sm text-slate-300 capitalize">{perm.replace(/([A-Z])/g, ' $1')}</span>
                </label>
              ))}
            </div>
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

  function renderInvoices() {
    return (
      <div className="overflow-x-auto rounded-3xl border border-slate-800 bg-slate-900 shadow-soft">
        <table className="w-full min-w-[700px] divide-y divide-slate-700 text-left text-sm text-slate-300">
          <thead className="bg-slate-950 text-slate-200">
            <tr>
              <th className="px-4 py-3">Invoice ID</th>
              <th className="px-4 py-3">Guest</th>
              <th className="px-4 py-3">Amount</th>
              <th className="px-4 py-3">Date</th>
              <th className="px-4 py-3">Status</th>
              <th className="px-4 py-3">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-800 bg-slate-950">
            {items.map((invoice) => (
              <tr key={invoice.id}>
                <td className="px-4 py-3">{invoice.id}</td>
                <td className="px-4 py-3">{invoice.guestName || invoice.description || 'N/A'}</td>
                <td className="px-4 py-3">{invoice.amount}</td>
                <td className="px-4 py-3">{invoice.date}</td>
                <td className="px-4 py-3">{invoice.status || 'paid'}</td>
                <td className="px-4 py-3">
                  <button onClick={() => deleteRecord(invoice.id)} className="rounded-full bg-rose-600 px-3 py-1 text-xs text-white transition hover:bg-rose-700">Remove</button>
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

    return (
      <div className="space-y-6">
        <div className={`rounded-[32px] border p-4 shadow-soft ${darkMode ? 'border-slate-700 bg-slate-950' : 'border-slate-200 bg-white'}`}>
          <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
            <div className="flex items-center gap-3">
              <div className="flex h-12 w-12 items-center justify-center rounded-full bg-emerald-100 text-emerald-900 font-bold">UH</div>
              <div>
                <p className={`text-xs uppercase tracking-[0.2em] ${darkMode ? 'text-slate-400' : 'text-slate-500'}`}>Usman Hotel</p>
                <h2 className={`text-lg font-semibold ${darkMode ? 'text-slate-100' : 'text-slate-900'}`}>POS Counter</h2>
              </div>
            </div>
            <button onClick={() => setDarkMode((prev) => !prev)} className={`rounded-full border px-3 py-2 text-xs font-semibold transition ${darkMode ? 'border-slate-600 bg-slate-900 text-slate-100 hover:bg-slate-800' : 'border-slate-300 bg-white text-slate-900 hover:bg-slate-100'}`}>
              {darkMode ? 'Light Mode' : 'Dark Mode'}
            </button>
          </div>
        </div>

        <section className="grid gap-6 xl:grid-cols-[1.4fr_0.6fr]">
          <div className={`rounded-[32px] border p-4 shadow-soft ${darkMode ? 'border-slate-700 bg-slate-950' : 'border-slate-200 bg-white'}`}>
            <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
              <div>
                <p className={`text-xs uppercase tracking-[0.2em] ${darkMode ? 'text-slate-400' : 'text-slate-500'}`}>POS Catalog</p>
                <h3 className={`mt-2 text-xl font-semibold ${darkMode ? 'text-slate-100' : 'text-slate-900'}`}>Select products</h3>
              </div>
              <div className="grid gap-3 sm:grid-cols-2">
                <select value={selectedCategory} onChange={(e) => setSelectedCategory(e.target.value)} className={`rounded-3xl border px-4 py-3 outline-none focus:border-emerald-500 ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`}>
                  <option value="All">All Categories</option>
                  {posCategories.map((category) => (
                    <option key={category.id || category.name} value={category.name}>{category.name}</option>
                  ))}
                </select>
                <input value={posSearch} onChange={(e) => setPosSearch(e.target.value)} placeholder="Search products" className={`rounded-3xl border px-4 py-3 outline-none focus:border-emerald-500 ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} />
              </div>
            </div>
            <div className="mt-5 grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
              {filteredProducts.map((product) => (
                <div key={product.id} className={`rounded-3xl border p-4 shadow-soft ${darkMode ? 'border-slate-700 bg-slate-900' : 'border-slate-200 bg-slate-50'}`}>
                  {product.photo && <img src={product.photo} alt={product.name} className="w-full h-28 object-cover rounded-3xl mb-3" />}
                  <div className="flex items-center justify-between gap-3">
                    <div>
                      <div className={`text-base font-semibold ${darkMode ? 'text-slate-100' : 'text-slate-900'}`}>{product.name}</div>
                      <div className={`text-sm ${darkMode ? 'text-slate-400' : 'text-slate-500'}`}>{product.category}</div>
                    </div>
                    <span className="rounded-full bg-slate-800 px-3 py-1 text-xs text-slate-100">{product.price} PKR</span>
                  </div>
                  <div className={`mt-3 text-sm ${darkMode ? 'text-slate-400' : 'text-slate-600'}`}>Stock: {product.availableStock || product.stock || 0}</div>
                  <button onClick={() => addToCart(product)} className="mt-4 w-full rounded-3xl bg-emerald-600 px-4 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-500">Add</button>
                </div>
              ))}
            </div>
          </div>

          <div className={`rounded-[32px] border p-4 shadow-soft ${darkMode ? 'border-slate-700 bg-slate-950' : 'border-slate-200 bg-white'}`}>
            <div className="mb-4">
              <p className={`text-xs uppercase tracking-[0.2em] ${darkMode ? 'text-slate-400' : 'text-slate-500'}`}>Cart summary</p>
              <h3 className={`mt-2 text-xl font-semibold ${darkMode ? 'text-slate-100' : 'text-slate-900'}`}>{cart.length} items</h3>
            </div>
            <div className="space-y-4">
              {cart.map((item) => (
                <div key={item.productId} className={`rounded-3xl border p-4 ${darkMode ? 'border-slate-700 bg-slate-900' : 'border-slate-200 bg-slate-50'}`}>
                  <div className="flex items-center justify-between gap-3">
                    <div>
                      <div className={`text-sm font-semibold ${darkMode ? 'text-slate-100' : 'text-slate-900'}`}>{item.name}</div>
                      <div className={`text-xs ${darkMode ? 'text-slate-400' : 'text-slate-500'}`}>{item.quantity} × {item.price} PKR</div>
                    </div>
                    <div className="flex items-center gap-2">
                      <button onClick={() => updateCartItem(item.productId, -1)} className="rounded-full bg-slate-800 px-2 py-1 text-xs text-slate-100">-</button>
                      <button onClick={() => updateCartItem(item.productId, 1)} className="rounded-full bg-slate-800 px-2 py-1 text-xs text-slate-100">+</button>
                    </div>
                  </div>
                  <textarea value={item.notes} onChange={(e) => updateCartNotes(item.productId, e.target.value)} placeholder="Notes..." className={`mt-3 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} rows={2} />
                </div>
              ))}
            </div>
            <div className={`mt-5 space-y-3 rounded-3xl border p-4 ${darkMode ? 'border-slate-700 bg-slate-900' : 'border-slate-200 bg-slate-50'}`}>
              <div className="flex justify-between text-sm text-slate-400"><span>Subtotal</span><span>{summary.subtotal} PKR</span></div>
              <div className="flex justify-between text-sm text-slate-400"><span>Discount</span><span>{summary.discount} PKR</span></div>
              <div className="flex justify-between text-sm text-slate-400"><span>Tax</span><span>{summary.tax} PKR</span></div>
              <div className="flex justify-between text-sm text-slate-400"><span>Delivery</span><span>{summary.deliveryFee} PKR</span></div>
              <div className="flex justify-between text-sm text-slate-400"><span>Service</span><span>{summary.serviceCharge} PKR</span></div>
              <div className={`flex justify-between text-lg font-semibold ${darkMode ? 'text-slate-100' : 'text-slate-900'}`}><span>Total</span><span>{summary.total} PKR</span></div>
            </div>
          </div>
        </section>

        <section className="rounded-[32px] border border-slate-800 bg-slate-900 p-6 shadow-soft">
          <div className="grid gap-6 xl:grid-cols-[1fr_0.8fr]">
            <div className="space-y-4">
              <div>
                <p className="text-sm uppercase tracking-[0.2em] text-slate-400">Order type</p>
                <div className="mt-4 flex flex-wrap gap-3">
                  {['Dine-In', 'Takeaway', 'Delivery'].map((type) => (
                    <button key={type} onClick={() => setOrderType(type)} className={`rounded-full px-4 py-2 text-sm font-semibold transition ${orderType === type ? 'bg-emerald-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}>
                      {type}
                    </button>
                  ))}
                </div>
              </div>

              <div className="grid gap-4 md:grid-cols-2">
                <label className="block text-sm font-medium text-slate-200">Customer Name</label>
                <input value={orderDetails.customerName} onChange={(e) => updateOrderDetail('customerName', e.target.value)} className="rounded-3xl border border-slate-800 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" />
                <label className="block text-sm font-medium text-slate-200">Phone</label>
                <input value={orderDetails.phone} onChange={(e) => updateOrderDetail('phone', e.target.value)} className="rounded-3xl border border-slate-800 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" />
                {orderType === 'Delivery' && (
                  <>
                    <label className="block text-sm font-medium text-slate-200">Delivery Service Type</label>
                    <select value={orderDetails.serviceType || ''} onChange={(e) => handleDeliveryServiceTypeChange(e.target.value)} className="rounded-3xl border border-slate-800 bg-slate-950 px-4 py-3 text-slate-100 outline-none focus:border-emerald-500">
                      <option value="">Select service type</option>
                      {deliveryServiceTypes.map((type) => (
                        <option key={type.id} value={type.id}>{type.name}{type.location ? ` (${type.location})` : ''}</option>
                      ))}
                    </select>
                    <label className="block text-sm font-medium text-slate-200">Delivery Address</label>
                    <input value={orderDetails.address} onChange={(e) => updateOrderDetail('address', e.target.value)} className="rounded-3xl border border-slate-800 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" />
                    <label className="block text-sm font-medium text-slate-200">Delivery Charge</label>
                    <input type="number" value={orderDetails.deliveryFee} readOnly className="rounded-3xl border border-slate-800 bg-slate-900 px-4 py-3 text-sm text-slate-100 outline-none" />
                  </>
                )}
                {orderType === 'Dine-In' && (
                  <>
                    <label className="block text-sm font-medium text-slate-200">Table / Room</label>
                    <select value={orderDetails.tableNumber} onChange={(e) => updateOrderDetail('tableNumber', e.target.value)} className="rounded-3xl border border-slate-800 bg-slate-950 px-4 py-3 text-slate-100 outline-none focus:border-emerald-500">
                      <option value="">Select table or room</option>
                      {posTables.map((table) => {
                        const tableLabel = table.label || table.name || table.number || `Table ${table.id}`;
                        return (
                          <option key={table.id} value={tableLabel}>{tableLabel}</option>
                        );
                      })}
                    </select>
                  </>
                )}
              </div>
            </div>

            <div className="rounded-[32px] border border-slate-800 bg-slate-950 p-6">
              <div className="space-y-4">
                <div>
                  <p className="text-sm uppercase tracking-[0.2em] text-slate-500">Payment</p>
                  <div className="mt-4 flex flex-wrap gap-3">
                    {['Cash', 'Card', 'Online'].map((method) => (
                      <button key={method} onClick={() => setPaymentMethod(method)} className={`rounded-full px-4 py-2 text-sm font-semibold transition ${paymentMethod === method ? 'bg-emerald-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}>
                        {method}
                      </button>
                    ))}
                  </div>
                </div>

                <div className="grid gap-4">
                  <label className="block text-sm font-medium text-slate-700">Discount</label>
                  <input type="number" value={orderDetails.discount} onChange={(e) => updateOrderDetail('discount', e.target.value)} className="rounded-3xl border border-slate-800 bg-slate-900 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" />
                  <label className="block text-sm font-medium text-slate-700">Tax %</label>
                  <input type="number" value={orderDetails.taxPercent} onChange={(e) => updateOrderDetail('taxPercent', e.target.value)} className="rounded-3xl border border-slate-800 bg-slate-900 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" />
                  <label className="block text-sm font-medium text-slate-700">Service Charge</label>
                  <input type="number" value={orderDetails.serviceCharge} onChange={(e) => updateOrderDetail('serviceCharge', e.target.value)} className="rounded-3xl border border-slate-800 bg-slate-900 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" />
                  <label className="block text-sm font-medium text-slate-700">Special Notes</label>
                  <textarea value={orderDetails.notes} onChange={(e) => updateOrderDetail('notes', e.target.value)} className="rounded-3xl border border-slate-800 bg-slate-900 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500" rows={3} />
                </div>
              </div>
              <div className="mt-6 flex flex-col gap-3">
                <button onClick={() => savePosOrder('New')} className="rounded-3xl bg-emerald-600 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-500">Save Order</button>
                {currentSavedOrder && (
                  <button onClick={() => printReceipt(currentSavedOrder)} className="rounded-3xl bg-sky-600 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-sky-500">Print Saved Order</button>
                )}
                <button onClick={completePayment} className="rounded-3xl bg-slate-800 px-5 py-3 text-sm font-semibold text-white transition hover:bg-slate-700">Complete Payment</button>
              </div>
            </div>
          </div>
        </section>

        <section className="rounded-[32px] border border-slate-800 bg-slate-900 p-6 shadow-soft">
          <div className="flex items-center justify-between gap-4">
            <div>
              <p className="text-sm uppercase tracking-[0.2em] text-slate-400">Order history</p>
              <h3 className="mt-2 text-2xl font-semibold text-white">Recent POS orders</h3>
            </div>
          </div>
          <div className="mt-6 overflow-x-auto rounded-3xl border border-slate-800 bg-slate-950">
            <table className="w-full min-w-[720px] divide-y divide-slate-700 text-left text-sm text-slate-300">
              <thead className="bg-slate-950 text-slate-200">
                <tr>
                  <th className="px-4 py-3">Order #</th>
                  <th className="px-4 py-3">Type</th>
                  <th className="px-4 py-3">Customer</th>
                  <th className="px-4 py-3">Total</th>
                  <th className="px-4 py-3">Status</th>
                  <th className="px-4 py-3">Date</th>
                  <th className="px-4 py-3">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800 bg-slate-950">
                {posOrders.map((order) => (
                  <tr key={order.id}>
                    <td className="px-4 py-3">{order.orderNumber || order.id}</td>
                    <td className="px-4 py-3">{order.orderType}</td>
                    <td className="px-4 py-3">{order.customerName || 'Walk-in'}</td>
                    <td className="px-4 py-3">{order.total || order.amount || 0} PKR</td>
                    <td className="px-4 py-3"><span className={`inline-flex rounded-full px-3 py-1 text-xs font-semibold text-white ${getStatusBadge(order.status)}`}>{order.status}</span></td>
                    <td className="px-4 py-3">{order.createdAt || order.date || 'N/A'}</td>
                    <td className="px-4 py-3">
                      <div className="flex flex-wrap gap-2">
                        <button onClick={() => openOrderModal(order)} className="rounded-full border border-slate-700 bg-slate-800 px-3 py-1 text-xs font-semibold text-white hover:bg-slate-700">Edit</button>
                        <button onClick={() => deleteOrder(order.id)} className="rounded-full border border-slate-700 bg-rose-600 px-3 py-1 text-xs font-semibold text-white hover:bg-rose-500">Delete</button>
                        <button onClick={() => printReceipt(order)} className="rounded-full border border-slate-700 bg-emerald-600 px-3 py-1 text-xs font-semibold text-slate-950 hover:bg-emerald-500">Print</button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      </div>
    );
  }

  function renderSettings() {
    return (
      <div className="space-y-6">
        <div className={`rounded-[32px] border p-6 shadow-soft ${darkMode ? 'border-slate-700 bg-slate-950' : 'border-slate-200 bg-white'}`}>
          <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
            <div>
              <p className={`text-sm uppercase tracking-[0.2em] ${darkMode ? 'text-slate-400' : 'text-slate-500'}`}>Hotel Settings</p>
              <h3 className={`mt-2 text-2xl font-semibold ${darkMode ? 'text-slate-100' : 'text-slate-900'}`}>Branding and receipts</h3>
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
              <label className="block text-sm font-medium text-slate-400">Receipt Logo</label>
              <input type="file" accept="image/*" onChange={handleSettingsLogoChange} className="mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none border-slate-700 bg-slate-900 text-slate-100" />
              {settings.logo && <img src={settings.logo} alt="Logo" className="mt-3 h-20 w-auto rounded-3xl object-contain" />}
            </div>
            <div>
              <label className="block text-sm font-medium text-slate-400">Receipt Font Size</label>
              <input type="number" value={settings.receiptFontSize} onChange={(e) => setSettings((prev) => ({ ...prev, receiptFontSize: Number(e.target.value) }))} className={`mt-2 w-full rounded-3xl border px-4 py-3 text-sm outline-none ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`} />
            </div>
          </div>

          <div className="mt-6 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <button onClick={updateSettings} className="rounded-3xl bg-emerald-600 px-6 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-500">Save Settings</button>
            <p className={`text-sm ${darkMode ? 'text-slate-400' : 'text-slate-500'}`}>Use this page to keep branding, currency, and receipt settings updated.</p>
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
          <button onClick={() => setOrdersMainTab('deliverySettings')} className={`rounded-full px-4 py-2 text-sm font-semibold transition ${ordersMainTab === 'deliverySettings' ? 'bg-emerald-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}>Delivery Settings</button>
        </div>
        {ordersMainTab === 'delivery' && renderDeliveryOrders()}
        {ordersMainTab === 'takeaway' && renderTakeawayOrders()}
        {ordersMainTab === 'dinein' && renderDineinOrders()}
        {ordersMainTab === 'deliverySettings' && renderDeliverySettings()}
      </div>
    );
  }

  function renderDeliveryOrders() {
    const deliveryOrders = posOrders.filter((o) => o.orderType === 'Delivery');
    const filteredOrders = deliveryOrders.filter((o) => {
      const matchesStatus = deliverySubTab === 'all' || o.status === deliverySubTab;
      const matchesSearch = !orderSearch || 
        (o.orderNumber || o.id).toLowerCase().includes(orderSearch.toLowerCase()) ||
        (o.customerName || '').toLowerCase().includes(orderSearch.toLowerCase()) ||
        (o.phone || '').toLowerCase().includes(orderSearch.toLowerCase()) ||
        (o.address || '').toLowerCase().includes(orderSearch.toLowerCase());
      const matchesRider = !orderFilterRider || o.deliveryAgent === orderFilterRider;
      const matchesPayment = !orderFilterPayment || o.paymentMethod === orderFilterPayment;
      return matchesStatus && matchesSearch && matchesRider && matchesPayment;
    });
    const paginatedOrders = filteredOrders.slice(orderPageIndex * orderPageSize, (orderPageIndex + 1) * orderPageSize);
    const pageCount = Math.max(1, Math.ceil(filteredOrders.length / orderPageSize));
    return (
      <div className="space-y-6">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="flex flex-wrap gap-2">
            {['all', 'New', 'Kitchen', 'Riders Assigned', 'Delivered', 'Payment Collected', 'Payment Pending'].map((status) => (
              <button
                key={status}
                onClick={() => setDeliverySubTab(status)}
                className={`rounded-full px-3 py-1 text-xs font-semibold transition ${deliverySubTab === status ? 'bg-emerald-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}
              >
                {status === 'Kitchen' ? 'On Kitchen' : status}
              </button>
            ))}
          </div>
          <div className="flex flex-wrap items-center gap-3">
            <div className="relative">
              <input
                type="text"
                placeholder="Search orders..."
                value={orderSearch}
                onChange={(e) => setOrderSearch(e.target.value)}
                className="w-64 rounded-full border border-slate-800 bg-slate-900 px-4 py-2 text-sm text-slate-100 placeholder-slate-400 outline-none focus:border-emerald-500"
              />
              <svg className="absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
              </svg>
            </div>
            <div className="flex items-center gap-2 text-slate-300">
              <span className="text-xs uppercase tracking-[0.2em] text-slate-500">View</span>
              <button type="button" onClick={() => setDeliveryViewMode('tile')} className={`inline-flex h-10 w-10 items-center justify-center rounded-full border border-slate-700 bg-slate-900 text-slate-200 transition ${deliveryViewMode === 'tile' ? 'bg-emerald-600 text-white' : 'hover:bg-slate-800'}`} title="Tile view">
                <svg viewBox="0 0 24 24" className="h-5 w-5"><path d="M4 4h7v7H4V4zm9 0h7v4h-7V4zM4 13h7v7H4v-7zm9 5h7v2h-7v-2z" fill="currentColor"/></svg>
              </button>
              <button type="button" onClick={() => setDeliveryViewMode('table')} className={`inline-flex h-10 w-10 items-center justify-center rounded-full border border-slate-700 bg-slate-900 text-slate-200 transition ${deliveryViewMode === 'table' ? 'bg-emerald-600 text-white' : 'hover:bg-slate-800'}`} title="Table view">
                <svg viewBox="0 0 24 24" className="h-5 w-5"><path d="M4 4h16v4H4V4zm0 6h16v4H4v-4zm0 6h16v4H4v-4z" fill="currentColor"/></svg>
              </button>
            </div>
          </div>
          <div className="flex flex-wrap items-center gap-3">
            <div className="rounded-full border border-slate-700 bg-slate-900 px-3 py-2 text-sm text-slate-200">
              <label className="mr-2 text-slate-400">Rider</label>
              <select value={orderFilterRider} onChange={(e) => setOrderFilterRider(e.target.value)} className="rounded-full border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-100 outline-none focus:border-emerald-500">
                <option value="">All Riders</option>
                {Array.from(new Set(deliveryOrders.map((order) => order.deliveryAgent).filter(Boolean))).map((rider) => (
                  <option key={rider} value={rider}>{rider}</option>
                ))}
              </select>
            </div>
            <div className="rounded-full border border-slate-700 bg-slate-900 px-3 py-2 text-sm text-slate-200">
              <label className="mr-2 text-slate-400">Payment</label>
              <select value={orderFilterPayment} onChange={(e) => setOrderFilterPayment(e.target.value)} className="rounded-full border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-100 outline-none focus:border-emerald-500">
                <option value="">All</option>
                {Array.from(new Set(deliveryOrders.map((order) => order.paymentMethod).filter(Boolean))).map((method) => (
                  <option key={method} value={method}>{method}</option>
                ))}
              </select>
            </div>
            <div className="rounded-full border border-slate-700 bg-slate-900 px-3 py-2 text-sm text-slate-200">
              <label className="mr-2 text-slate-400">Page</label>
              <select value={orderPageSize} onChange={(e) => setOrderPageSize(Number(e.target.value))} className="rounded-full border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-100 outline-none focus:border-emerald-500">
                {[6, 12, 18].map((size) => (
                  <option key={size} value={size}>{size}</option>
                ))}
              </select>
            </div>
          </div>
        </div>

        {selectedOrders.length > 0 && (
          <div className="flex items-center justify-between rounded-3xl border border-slate-800 bg-slate-900 p-4">
            <div className="text-sm text-slate-300">
              {selectedOrders.length} order{selectedOrders.length > 1 ? 's' : ''} selected
            </div>
            <div className="flex gap-2">
              <button onClick={clearOrderSelection} className="rounded-3xl border border-slate-700 bg-slate-800 px-4 py-2 text-sm font-semibold text-slate-200 transition hover:bg-slate-700">Clear</button>
              <button onClick={deleteMultipleOrders} className="rounded-3xl border border-rose-700 bg-rose-600 px-4 py-2 text-sm font-semibold text-white transition hover:bg-rose-500">Delete Selected</button>
            </div>
          </div>
        )}

        {deliveryViewMode === 'table' ? (
          <div className="overflow-x-auto rounded-[32px] border border-slate-800 bg-slate-900 p-4 shadow-soft">
            <table className="w-full min-w-[900px] text-left text-sm text-slate-100">
              <thead className="border-b border-slate-800 text-slate-400">
                <tr>
                  <th className="px-4 py-3">Order #</th>
                  <th className="px-4 py-3">Type</th>
                  <th className="px-4 py-3">Customer</th>
                  <th className="px-4 py-3">Total</th>
                  <th className="px-4 py-3">Status</th>
                  <th className="px-4 py-3">Date</th>
                  <th className="px-4 py-3">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800">
                {paginatedOrders.map((order) => (
                  <tr key={order.id} className="hover:bg-slate-950/80 transition">
                    <td className="px-4 py-4 font-semibold text-white">{order.orderNumber || order.id}</td>
                    <td className="px-4 py-4 text-slate-300">{order.orderType}</td>
                    <td className="px-4 py-4 text-slate-300">{order.customerName || 'Walk-In'}</td>
                    <td className="px-4 py-4 font-semibold text-white">{order.total || order.amount || 0} Rs</td>
                    <td className="px-4 py-4"><span className={`inline-flex rounded-full px-3 py-1 text-xs font-semibold ${getStatusBadge(order.status)}`}>{order.status || 'Pending'}</span></td>
                    <td className="px-4 py-4 text-slate-400">{order.createdAt ? new Date(order.createdAt).toLocaleString() : '-'}</td>
                    <td className="px-4 py-4">
                      <div className="flex flex-wrap gap-2">
                        <button type="button" title="View order details" onClick={() => openViewOrderModal(order)} className="rounded-full border border-slate-700 bg-slate-950 px-3 py-2 text-slate-200 transition hover:bg-slate-800">View</button>
                        <button type="button" title="Assign rider" onClick={() => openRiderAssignmentModal(order)} className="rounded-full border border-slate-700 bg-purple-600 px-3 py-2 text-white transition hover:bg-purple-500">Assign</button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <div className={`grid gap-4 ${deliveryViewMode === 'tile' ? 'lg:grid-cols-3' : 'lg:grid-cols-2'}`}>
            {paginatedOrders.map((order) => {
              const paidStatus = ['Completed', 'Payment Collected', 'Delivered'].includes(order.status) ? 'Paid' : 'Due';
              const isSelected = selectedOrders.includes(order.id);
              return (
                <div key={order.id} className={`group relative rounded-[28px] border ${darkMode ? 'border-slate-800 bg-slate-950 text-slate-100' : 'border-slate-200 bg-white text-slate-900'} p-5 shadow-[0_18px_40px_rgba(0,0,0,0.12)] transition hover:-translate-y-1 hover:shadow-[0_24px_48px_rgba(0,0,0,0.18)]`}>
                  {isSelected && (
                    <div className="absolute -top-2 -right-2 z-10 h-6 w-6 rounded-full bg-emerald-600 flex items-center justify-center">
                      <svg className="h-4 w-4 text-white" fill="currentColor" viewBox="0 0 20 20">
                        <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                      </svg>
                    </div>
                  )}
                  <div className="flex items-start justify-between gap-3">
                    <div className="flex items-center gap-2">
                      <input
                        type="checkbox"
                        checked={isSelected}
                        onChange={() => toggleOrderSelection(order.id)}
                        className="h-4 w-4 rounded border-slate-700 bg-slate-900 text-emerald-600 focus:ring-emerald-500"
                      />
                      <div>
                        <div className="text-base font-semibold text-white">{order.orderNumber || order.id}</div>
                        <div className="mt-1 text-xs uppercase tracking-[0.25em] text-slate-500">{order.customerName || 'Walk-In'}</div>
                      </div>
                    </div>
                    <div className="space-y-2 text-right">
                      <span className={`inline-flex rounded-full px-2.5 py-1 text-[10px] font-semibold uppercase tracking-[0.2em] ${getStatusBadge(order.status)}`}>{order.status || 'Pending'}</span>
                      <span className={`inline-flex rounded-full px-2.5 py-1 text-[10px] font-semibold uppercase tracking-[0.2em] ${paidStatus === 'Paid' ? 'bg-emerald-500 text-slate-950' : 'bg-rose-500 text-white'}`}>{paidStatus}</span>
                    </div>
                  </div>
                  <div className={`mt-4 space-y-3 divide-y ${darkMode ? 'divide-slate-800' : 'divide-slate-200'} text-sm ${darkMode ? 'text-slate-300' : 'text-slate-600'}`}>
                    <div className="flex items-center justify-between gap-2 pb-3"><span className={darkMode ? 'text-slate-400' : 'text-slate-500'}>Items</span><span>{(order.items || []).length}</span></div>
                    <div className="flex items-center justify-between gap-2 py-3"><span className={darkMode ? 'text-slate-400' : 'text-slate-500'}>Rider</span><span>{order.deliveryAgent || 'Unassigned'}</span></div>
                    <div className="flex items-center justify-between gap-2 pt-3"><span className={darkMode ? 'text-slate-400' : 'text-slate-500'}>Address</span><span className="truncate text-right">{order.address || '-'}</span></div>
                  </div>
                  <div className="mt-4 flex items-center justify-between gap-2">
                    <div>
                      <div className="text-sm text-slate-400">Total</div>
                      <div className="text-xl font-semibold text-white">{order.total || order.amount || 0} Rs</div>
                    </div>
                    <div className="flex gap-2">
                      <button type="button" title="View order details" onClick={() => openViewOrderModal(order)} className={`inline-flex h-11 w-11 items-center justify-center rounded-full border ${darkMode ? 'border-slate-700 bg-slate-900 text-slate-200 hover:bg-slate-800' : 'border-slate-200 bg-slate-100 text-slate-900 hover:bg-slate-200'} shadow-[0_12px_18px_rgba(0,0,0,0.12)] transition hover:-translate-y-0.5`}>
                        <svg viewBox="0 0 24 24" className="h-5 w-5"><path d="M12 7a5 5 0 100 10 5 5 0 000-10zm0-5C7 2 2.7 4.4 1 8.5 2.7 12.6 7 15 12 15s9.3-2.4 11-6.5C21.3 4.4 17 2 12 2zm0 11a4 4 0 110-8 4 4 0 010 8z" fill="currentColor"/></svg>
                      </button>
                      <button type="button" title="Assign rider" onClick={() => openRiderAssignmentModal(order)} className="inline-flex h-11 w-11 items-center justify-center rounded-full border border-slate-700 bg-purple-600 text-white shadow-[0_12px_18px_rgba(0,0,0,0.24)] transition hover:-translate-y-0.5 hover:bg-purple-500">
                        <svg viewBox="0 0 24 24" className="h-5 w-5"><path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" fill="currentColor"/></svg>
                      </button>
                    </div>
                  </div>
                  <div className="mt-4">
                    {order.id === riderAssignmentOrderId && (
                      <div className="space-y-3">
                        <select value={selectedRider} onChange={(e) => setSelectedRider(e.target.value)} className="w-full rounded-3xl border border-slate-800 bg-slate-900 px-4 py-3 text-sm text-slate-100 outline-none focus:border-emerald-500">
                          <option value="">Assign Rider</option>
                          {getBikers().map((biker) => <option key={biker.id} value={biker.name}>{biker.name}</option>)}
                        </select>
                        <div className="flex items-center gap-2">
                          <button onClick={() => assignRiderToOrder(order.id, selectedRider)} disabled={!selectedRider} className="flex-1 rounded-3xl bg-purple-600 px-4 py-3 text-sm font-semibold text-white transition hover:bg-purple-500 disabled:cursor-not-allowed disabled:opacity-50">Assign</button>
                          <button onClick={() => { setRiderAssignmentOrderId(null); setSelectedRider(''); }} className="flex-1 rounded-3xl border border-slate-700 bg-slate-900 px-4 py-3 text-sm font-semibold text-slate-200 transition hover:bg-slate-800">Cancel</button>
                        </div>
                      </div>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        )}
        <div className="flex flex-wrap items-center justify-between gap-3 rounded-3xl border border-slate-800 bg-slate-900 p-3 text-sm text-slate-300">
          <div>{filteredOrders.length ? `Page ${orderPageIndex + 1} of ${pageCount}` : 'No orders available'}</div>
          <div className="flex items-center gap-2">
            <button disabled={orderPageIndex === 0} onClick={() => setOrderPageIndex((prev) => Math.max(prev - 1, 0))} className="rounded-full border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-200 transition hover:bg-slate-800 disabled:opacity-50">Prev</button>
            <button disabled={orderPageIndex >= pageCount - 1} onClick={() => setOrderPageIndex((prev) => Math.min(prev + 1, pageCount - 1))} className="rounded-full border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-200 transition hover:bg-slate-800 disabled:opacity-50">Next</button>
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

  function renderTakeawayOrders() {
    const takeawayOrders = posOrders.filter((o) => o.orderType === 'Takeaway');
    return (
      <div className="space-y-6">
        <div className="flex flex-wrap gap-2">
          {['all', 'New', 'Done'].map((status) => (
            <button
              key={status}
              onClick={() => setTakeawaySubTab(status)}
              className={`rounded-full px-3 py-1 text-xs font-semibold transition ${takeawaySubTab === status ? 'bg-emerald-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}
            >
              {status}
            </button>
          ))}
        </div>
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {takeawayOrders.filter((o) => takeawaySubTab === 'all' || (takeawaySubTab === 'New' && o.status === 'New') || (takeawaySubTab === 'Done' && o.status === 'Completed')).map((order) => (
            <div key={order.id} className="rounded-3xl border border-slate-800 bg-slate-900 p-5 shadow-soft hover:shadow-lg transition">
              <div className="text-lg font-semibold text-white">{order.orderNumber || order.id}</div>
              <div className="text-sm text-slate-400 mt-2">Total: {order.total} PKR</div>
              <span className={`inline-flex rounded-full px-3 py-1 text-xs font-semibold text-white mt-3 ${getStatusBadge(order.status)}`}>{order.status}</span>
              <div className="mt-4 flex flex-wrap gap-2">
                <button onClick={() => openOrderModal(order)} className="rounded-full border border-slate-700 bg-slate-800 px-3 py-1 text-xs font-semibold text-white hover:bg-slate-700">Edit</button>
                <button onClick={() => deleteOrder(order.id)} className="rounded-full border border-slate-700 bg-rose-600 px-3 py-1 text-xs font-semibold text-white hover:bg-rose-500">Delete</button>
                <button onClick={() => printReceipt(order)} className="rounded-full border border-slate-700 bg-emerald-600 px-3 py-1 text-xs font-semibold text-slate-950 hover:bg-emerald-500">Print</button>
              </div>
              {order.status === 'New' && (
                <button onClick={() => updateOrderStatus(order.id, 'Completed')} className="w-full rounded-3xl bg-emerald-600 px-4 py-3 text-sm font-semibold text-white transition hover:bg-emerald-500 mt-4">Mark Ready</button>
              )}
            </div>
          ))}
        </div>
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

    const statusFiltered = dineinOrderStatusFilter === 'all'
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
          {['tables', 'paid'].map((tab) => (
            <button
              key={tab}
              onClick={() => {
                setDineinSubTab(tab);
                if (tab === 'paid') setDineinOrderStatusFilter('paid');
              }}
              className={`rounded-full px-4 py-2 text-sm font-semibold transition ${dineinSubTab === tab ? 'bg-emerald-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}>
              {tab === 'tables' ? 'Table Management' : 'Paid Orders'}
            </button>
          ))}
        </div>

        {dineinSubTab === 'paid' && (
          <div className="rounded-[32px] border border-slate-800 bg-slate-900 p-5 shadow-soft">
            <div className="grid gap-4 lg:grid-cols-3">
              <div className="rounded-3xl border border-slate-700 bg-slate-950 p-4">
                <div className="text-sm text-slate-400">Orders</div>
                <div className="mt-2 text-2xl font-semibold text-white">{summary.orderCount}</div>
              </div>
              <div className="rounded-3xl border border-slate-700 bg-slate-950 p-4">
                <div className="text-sm text-slate-400">Sales Total</div>
                <div className="mt-2 text-2xl font-semibold text-white">{summary.totalSales} PKR</div>
              </div>
              <div className="rounded-3xl border border-slate-700 bg-slate-950 p-4">
                <div className="text-sm text-slate-400">Items Sold</div>
                <div className="mt-2 text-2xl font-semibold text-white">{summary.itemCount}</div>
              </div>
            </div>

            <div className="mt-5 grid gap-4 lg:grid-cols-3">
              <input type="date" value={dineinDateFrom} onChange={(e) => setDineinDateFrom(e.target.value)} className="rounded-3xl border border-slate-700 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none" placeholder="From" />
              <input type="date" value={dineinDateTo} onChange={(e) => setDineinDateTo(e.target.value)} className="rounded-3xl border border-slate-700 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none" placeholder="To" />
              <input value={dineinOrderSearch} onChange={(e) => setDineinOrderSearch(e.target.value)} placeholder="Search orders" className="rounded-3xl border border-slate-700 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none" />
            </div>

            <div className="mt-4 rounded-3xl border border-slate-700 bg-slate-950 p-4">
              <div className="flex flex-wrap items-center gap-2">
                {['all', 'pending', 'paid'].map((status) => (
                  <button key={status} onClick={() => setDineinOrderStatusFilter(status)} className={`rounded-full px-3 py-2 text-sm font-semibold transition ${dineinOrderStatusFilter === status ? 'bg-emerald-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'}`}>
                    {status === 'all' ? 'All' : status === 'pending' ? 'Pending' : 'Paid'}
                  </button>
                ))}
              </div>
            </div>

            <div className="mt-5 flex flex-wrap items-center justify-between gap-3">
              <div className="flex items-center gap-3">
                <button onClick={deleteSelectedDineinOrders} disabled={!selectedDineinOrders.length} className={`rounded-full px-4 py-2 text-sm font-semibold transition ${selectedDineinOrders.length ? 'bg-rose-600 text-white hover:bg-rose-500' : 'bg-slate-700 text-slate-400 cursor-not-allowed'}`}>
                  Delete Selected ({selectedDineinOrders.length})
                </button>
                <span className="text-sm text-slate-400">Showing {Math.min(1, pagedDineinOrders.length)} - {Math.min(statusFiltered.length, dineinPageSize)} of {statusFiltered.length} orders</span>
              </div>
              <div className="flex items-center gap-3">
                <label className="text-sm text-slate-400">Per page</label>
                <select value={dineinPageSize} onChange={(e) => { setDineinPageSize(Number(e.target.value)); setDineinPageIndex(0); }} className="rounded-3xl border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-100 outline-none">
                  {[8, 12, 16, 20].map((size) => <option key={size} value={size}>{size}</option>)}
                </select>
              </div>
            </div>
          </div>
        )}

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
                <div className="mt-4 grid gap-4 sm:grid-cols-2">
                  {floorTables.map((table) => {
                    const tableOrder = dineinOrders.find((o) => o.tableNumber === (table.label || table.name || table.number || `Table ${table.id}`));
                    return (
                      <div key={table.id} className={`rounded-3xl border p-4 ${tableOrder ? 'border-amber-600 bg-amber-950' : 'border-slate-700 bg-slate-950'}`}>
                        <div className="flex items-center justify-between gap-3">
                          <div>
                            <div className="font-semibold text-white">{table.label || table.name || `Table ${table.id}`}</div>
                            <div className="text-xs text-slate-400">{table.capacity || 4} seats</div>
                          </div>
                          <span className={`rounded-full px-2 py-1 text-[11px] font-semibold ${tableOrder ? 'bg-amber-500 text-slate-950' : 'bg-emerald-600 text-white'}`}>
                            {tableOrder ? 'Occupied' : 'Available'}
                          </span>
                        </div>
                        {tableOrder && (
                          <div className="mt-3 text-slate-300 text-sm">
                            <div>Order: {tableOrder.orderNumber}</div>
                            <div className="mt-1">Status: {tableOrder.status}</div>
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
                <div className="mt-4 grid gap-4 sm:grid-cols-2">
                  {outsideTables.map((table) => {
                    const tableOrder = dineinOrders.find((o) => o.tableNumber === (table.label || table.name || table.number || `Table ${table.id}`));
                    return (
                      <div key={table.id} className={`rounded-3xl border p-4 ${tableOrder ? 'border-amber-600 bg-amber-950' : 'border-slate-700 bg-slate-950'}`}>
                        <div className="flex items-center justify-between gap-3">
                          <div>
                            <div className="font-semibold text-white">{table.label || table.name || `Table ${table.id}`}</div>
                            <div className="text-xs text-slate-400">{table.capacity || 4} seats</div>
                          </div>
                          <span className={`rounded-full px-2 py-1 text-[11px] font-semibold ${tableOrder ? 'bg-amber-500 text-slate-950' : 'bg-emerald-600 text-white'}`}>
                            {tableOrder ? 'Occupied' : 'Available'}
                          </span>
                        </div>
                        {tableOrder && (
                          <div className="mt-3 text-slate-300 text-sm">
                            <div>Order: {tableOrder.orderNumber}</div>
                            <div className="mt-1">Status: {tableOrder.status}</div>
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
              {pagedDineinOrders.map((order) => (
                <div key={order.id} className="rounded-3xl border border-slate-800 bg-slate-900 p-5 shadow-soft">
                  <div className="flex flex-wrap items-start justify-between gap-4">
                    <div className="flex items-center gap-3">
                      <input type="checkbox" checked={selectedDineinOrders.includes(order.id)} onChange={() => toggleDineinOrderSelection(order.id)} className="h-4 w-4 rounded border-slate-600 bg-slate-950 text-emerald-500" />
                      <div>
                        <div className="text-lg font-semibold text-white">{order.orderNumber || order.id}</div>
                        <div className="text-sm text-slate-400">Table: {order.tableNumber || 'N/A'}</div>
                        <div className="text-sm text-slate-400">Customer: {order.customerName || 'Walk-in'}</div>
                      </div>
                    </div>
                    <div className="space-y-2 text-right">
                      <span className={`inline-flex rounded-full px-3 py-1 text-xs font-semibold text-white ${getStatusBadge(order.status)}`}>{order.status || 'Pending'}</span>
                      <div className="text-sm text-slate-400">Total: {order.total || order.amount || 0} PKR</div>
                      <div className="text-sm text-slate-400">Items: {(order.items || []).reduce((count, item) => count + Number(item.quantity || 0), 0)}</div>
                    </div>
                  </div>
                  <div className="mt-4 grid gap-3 sm:grid-cols-2">
                    <div className="rounded-3xl border border-slate-700 bg-slate-950 p-4 text-sm text-slate-300">
                      <div className="font-semibold text-slate-100">Notes</div>
                      <div className="mt-2">{order.notes || 'No special notes'}</div>
                    </div>
                    <div className="rounded-3xl border border-slate-700 bg-slate-950 p-4 text-sm text-slate-300">
                      <div className="font-semibold text-slate-100">Details</div>
                      <div className="mt-2">Service: {order.serviceType || 'N/A'}</div>
                      <div>Payment: {order.paymentMethod || 'Cash'}</div>
                      <div>Date: {order.orderDate ? order.orderDate.toLocaleString() : 'N/A'}</div>
                    </div>
                  </div>
                  <div className="mt-4 flex flex-wrap gap-2">
                    <button onClick={() => openOrderModal(order)} className="rounded-full border border-slate-700 bg-slate-800 px-3 py-1 text-xs font-semibold text-white hover:bg-slate-700">Edit</button>
                    <button onClick={() => deleteOrder(order.id)} className="rounded-full border border-rose-600 bg-rose-600 px-3 py-1 text-xs font-semibold text-white hover:bg-rose-500">Delete</button>
                    <button onClick={() => printReceipt(order)} className="rounded-full border border-emerald-600 bg-emerald-600 px-3 py-1 text-xs font-semibold text-slate-950 hover:bg-emerald-500">Print</button>
                    {order.status !== 'Completed' && order.status !== 'Payment Collected' && (
                      <button onClick={() => confirmMarkPaid(order)} className="rounded-full border border-amber-600 bg-amber-600 px-3 py-1 text-xs font-semibold text-slate-950 hover:bg-amber-500">Mark Paid</button>
                    )}
                  </div>
                </div>
              ))}
            </div>
            <div className="flex items-center justify-between gap-3 rounded-3xl border border-slate-800 bg-slate-950 p-4 text-sm text-slate-400">
              <span>Page {dineinPageIndex + 1} of {totalDineinPages}</span>
              <div className="flex items-center gap-2">
                <button disabled={dineinPageIndex <= 0} onClick={() => setDineinPageIndex((prev) => Math.max(prev - 1, 0))} className="rounded-full border border-slate-700 bg-slate-900 px-3 py-2 text-xs font-semibold text-white disabled:cursor-not-allowed disabled:opacity-50">Previous</button>
                <button disabled={dineinPageIndex >= totalDineinPages - 1} onClick={() => setDineinPageIndex((prev) => Math.min(prev + 1, totalDineinPages - 1))} className="rounded-full border border-slate-700 bg-slate-900 px-3 py-2 text-xs font-semibold text-white disabled:cursor-not-allowed disabled:opacity-50">Next</button>
              </div>
            </div>
          </div>
        )}
      </div>
    );
  }

  if (!token || !user) {
    return (
      <div className="grid min-h-screen place-items-center bg-slate-950 px-4 text-slate-100">
        <div className="w-full max-w-md rounded-[32px] border border-slate-800 bg-slate-900 p-8 shadow-soft">
          <div className="mb-6 text-center">
            <h1 className="text-3xl font-semibold text-white">Usman Hotel POS</h1>
            <p className="mt-2 text-sm text-slate-400">Login to manage reservations, invoices, and hotel operations.</p>
          </div>
          {authMessage && <div className="mb-4 rounded-3xl border border-rose-700 bg-rose-950/30 px-4 py-3 text-sm text-rose-300">{authMessage}</div>}
          <div className="space-y-4">
            <label className="block text-sm font-medium text-slate-200">Email</label>
            <input value={authForm.email} onChange={(e) => setAuthForm({ ...authForm, email: e.target.value })} className="w-full rounded-3xl border border-slate-800 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none focus:border-slate-500" />
            <label className="block text-sm font-medium text-slate-200">Password</label>
            <input type="password" value={authForm.password} onChange={(e) => setAuthForm({ ...authForm, password: e.target.value })} className="w-full rounded-3xl border border-slate-800 bg-slate-950 px-4 py-3 text-sm text-slate-100 outline-none focus:border-slate-500" />
            <button onClick={login} className="w-full rounded-3xl bg-emerald-600 px-4 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-500">Sign In</button>
          </div>
          <p className="mt-5 text-center text-sm text-slate-400">Use <strong className="text-white">admin@usmanhotel.com</strong> / <strong className="text-white">admin123</strong></p>
        </div>
      </div>
    );
  }

  const appStyle = {
    background: darkMode ? '#020617' : '#ffffff'
  };
  return (
    <div className={`min-h-screen ${darkMode ? 'bg-slate-950 text-slate-100' : 'bg-white text-slate-900'}`} style={appStyle}>
      <style>{`
        @keyframes pulse-slow { 0%,100% { transform: translateY(0); } 50% { transform: translateY(-2px); } }
        .animate-pulse-slow { animation: pulse-slow 4s ease-in-out infinite; }
      `}</style>
      <div className="mx-auto flex min-h-screen max-w-[1400px] flex-col gap-6 px-4 py-6 sm:px-6 lg:px-8">
        {activeTab !== 'orders' && activeTab !== 'pos' && (
          <header className={`rounded-[32px] border px-6 py-5 shadow-soft ${darkMode ? 'border-slate-700 bg-slate-950' : 'border-slate-200 bg-white'}`}>
            <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
              <div>
                <div className="text-sm uppercase tracking-[0.2em] text-slate-500">Usman Hotel POS</div>
                <h1 className="mt-2 text-3xl font-semibold text-slate-900">Hotel Management System</h1>
              </div>
              <div className="flex flex-wrap items-center gap-3 text-sm text-slate-600">
                <div>Signed in as <strong className="text-slate-900">{user.name}</strong></div>
                <span className="h-1 w-1 rounded-full bg-slate-300" />
                <button onClick={logout} className="rounded-full border border-slate-200 bg-slate-50 px-4 py-2 text-sm text-slate-900 transition hover:bg-slate-100">Logout</button>
              </div>
            </div>
          </header>
        )}

        <div className="grid gap-6 xl:grid-cols-[260px_1fr]">
          <aside className={`rounded-[32px] border p-5 shadow-soft ${darkMode ? 'border-slate-700 bg-slate-950 text-slate-100' : 'border-slate-200 bg-white text-slate-900'}`}>
            <div className="mb-6 flex items-center justify-between gap-3">
              <div className="text-slate-500 text-sm font-semibold uppercase tracking-[0.2em]">Navigation</div>
              <button onClick={() => setDarkMode((prev) => !prev)} className={`rounded-full border px-3 py-2 text-xs font-semibold transition ${darkMode ? 'border-slate-600 bg-slate-900 text-slate-100 hover:bg-slate-800' : 'border-slate-200 bg-white text-slate-900 hover:bg-slate-100'}`}>
                {darkMode ? 'Light Mode' : 'Dark Mode'}
              </button>
            </div>
            <div className={`rounded-[28px] border p-4 mb-6 flex items-center gap-3 ${darkMode ? 'border-slate-700 bg-slate-800 text-slate-100' : 'border-slate-200 bg-amber-50 text-slate-900'}`}>
              <div className="bg-emerald-100 text-emerald-700 flex h-14 w-14 items-center justify-center rounded-3xl font-bold text-lg animate-pulse-slow">
                {settings.logo ? <img src={settings.logo} alt="Usman Hotel" className="h-10 w-10 object-contain" /> : 'UH'}
              </div>
              <div>
                <div className={`${darkMode ? 'text-slate-400' : 'text-slate-500'} text-xs uppercase tracking-[0.2em]`}>Usman Hotel</div>
                <div className={`${darkMode ? 'text-white' : 'text-slate-900'} text-lg font-semibold`}>POS Dashboard</div>
              </div>
            </div>
            <div className="space-y-2">
              {tabs.map((tab) => (
                <button
                  key={tab}
                  onClick={() => setActiveTab(tab)}
                  className={`flex w-full items-center justify-between rounded-3xl px-4 py-3 text-left text-sm font-medium transition ${activeTab === tab ? 'bg-emerald-600 text-white' : 'bg-white text-slate-900 hover:bg-slate-100'}`}>
                  <span>{tab.replace('-', ' ').replace(/\b\w/g, (l) => l.toUpperCase())}</span>
                </button>
              ))}
            </div>
          </aside>

          <main className="space-y-6">
            <section className="rounded-[32px] border border-slate-800 bg-slate-900 p-6 shadow-soft">
              <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                <div>
                  <p className="text-sm uppercase tracking-[0.2em] text-slate-400">{header}</p>
                  <h2 className="mt-2 text-2xl font-semibold text-white">Manage hotel operations from one screen.</h2>
                </div>
                <div className="flex flex-wrap items-center gap-3">
                  <div className="text-sm text-slate-400">{loading ? 'Loading...' : 'Ready'}</div>
                </div>
              </div>
            </section>

            {message && <div className="rounded-[24px] border border-emerald-500 bg-emerald-900/40 px-4 py-3 text-sm text-emerald-200">{message}</div>}

            {activeTab === 'dashboard' && dashboard && (
              <section className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
                {[
                  { label: 'Total Rooms', value: dashboard.totalRooms },
                  { label: 'Occupied Rooms', value: dashboard.occupiedRooms },
                  { label: 'Total Reservations', value: dashboard.totalReservations },
                  { label: 'Revenue', value: `${dashboard.revenue} ${dashboard.settings.currency}` }
                ].map((item) => (
                  <div key={item.label} className="rounded-[32px] border border-slate-800 bg-slate-900 p-6 shadow-soft">
                    <p className="text-sm text-slate-400">{item.label}</p>
                    <p className="mt-3 text-3xl font-semibold text-white">{item.value}</p>
                  </div>
                ))}
              </section>
            )}

            {activeTab === 'pos' && renderPos()}
            {activeTab === 'settings' && renderSettings()}
            {activeTab === 'orders' && renderOrders()}
            {activeTab === 'rider-book' && renderRiderBook()}

            {(activeTab === 'tables' || activeTab === 'inventory' || activeTab === 'staff' || activeTab === 'sales' || activeTab === 'invoices') && (
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
                          {posProducts.filter((product) => !editingProductSearch || product.name.toLowerCase().includes(editingProductSearch.toLowerCase())).map((product) => (
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
                            <label className="block text-xs font-medium text-slate-300 mb-1">Type</label>
                            <input value={orderEditForm.orderType} disabled className="w-full rounded-2xl border border-slate-800 bg-slate-900 px-3 py-2 text-xs text-slate-400" />
                          </div>
                          <div>
                            <label className="block text-xs font-medium text-slate-300 mb-1">Status</label>
                            <select value={orderEditForm.status} onChange={(e) => setOrderEditForm({ ...orderEditForm, status: e.target.value })} className="w-full rounded-2xl border border-slate-800 bg-slate-900 px-3 py-2 text-xs text-slate-100 outline-none focus:border-emerald-500">
                              {['New', 'Kitchen', 'Ready', 'Riders Assigned', 'Delivered', 'Payment Collected', 'Payment Pending', 'Completed'].map((status) => (
                                <option key={status} value={status}>{status}</option>
                              ))}
                            </select>
                          </div>
                          <div>
                            <label className="block text-xs font-medium text-slate-300 mb-1">Customer Name</label>
                            <input value={orderEditForm.customerName} onChange={(e) => setOrderEditForm({ ...orderEditForm, customerName: e.target.value })} className="w-full rounded-2xl border border-slate-800 bg-slate-900 px-3 py-2 text-xs text-slate-100 outline-none focus:border-emerald-500" />
                          </div>
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
                              <div>
                                <label className="block text-xs font-medium text-slate-300 mb-1">Rider</label>
                                <select value={orderEditForm.deliveryAgent} onChange={(e) => setOrderEditForm({ ...orderEditForm, deliveryAgent: e.target.value })} className="w-full rounded-2xl border border-slate-800 bg-slate-900 px-3 py-2 text-xs text-slate-100 outline-none focus:border-emerald-500">
                                  <option value="">Assign Rider</option>
                                  {getBikers().map((biker) => (
                                    <option key={biker.id} value={biker.name}>{biker.name}</option>
                                  ))}
                                </select>
                              </div>
                            </>
                          )}
                          {orderEditForm.orderType === 'Dine-In' && (
                            <div>
                              <label className="block text-xs font-medium text-slate-300 mb-1">Table</label>
                              <select value={orderEditForm.tableNumber} onChange={(e) => setOrderEditForm({ ...orderEditForm, tableNumber: e.target.value })} className="w-full rounded-2xl border border-slate-800 bg-slate-900 px-3 py-2 text-xs text-slate-100 outline-none focus:border-emerald-500">
                                <option value="">Select table</option>
                                {posTables.map((table) => {
                                  const tableLabel = table.label || table.name || table.number || `Table ${table.id}`;
                                  return (
                                    <option key={table.id} value={tableLabel}>{tableLabel}</option>
                                  );
                                })}
                              </select>
                            </div>
                          )}
                          <div>
                            <label className="block text-xs font-medium text-slate-300 mb-1">Discount</label>
                            <input type="number" value={orderEditForm.discount} onChange={(e) => setOrderEditForm({ ...orderEditForm, discount: Number(e.target.value) })} className="w-full rounded-2xl border border-slate-800 bg-slate-900 px-3 py-2 text-xs text-slate-100 outline-none focus:border-emerald-500" />
                          </div>
                          <div>
                            <label className="block text-xs font-medium text-slate-300 mb-1">Tax %</label>
                            <input type="number" value={orderEditForm.taxPercent} onChange={(e) => setOrderEditForm({ ...orderEditForm, taxPercent: Number(e.target.value) })} className="w-full rounded-2xl border border-slate-800 bg-slate-900 px-3 py-2 text-xs text-slate-100 outline-none focus:border-emerald-500" />
                          </div>
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
                    <div className="text-sm text-slate-400">Customer: {markPaidOrder.customerName || 'Walk-in'}</div>
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
                            <div className="flex justify-between"><span className="text-slate-400">Name:</span><span className="text-white">{orderDetailsModal.customerName || 'Walk-In'}</span></div>
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
                          <div className="flex justify-between"><span className="text-slate-400">Delivery Fee:</span><span className="text-white">+{orderDetailsModal.deliveryFee || 0} Rs</span></div>
                          <div className="col-span-2 pt-2 border-t border-white/10 flex justify-between text-base font-bold">
                            <span className="text-slate-300">Total:</span><span className="text-emerald-400">{orderDetailsModal.total || orderDetailsModal.amount || 0} Rs</span>
                          </div>
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
        </div>
      </div>
    </div>
  );
}

export default App;

