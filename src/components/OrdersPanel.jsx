import React, { useState, useMemo } from 'react';
import { Eye } from 'lucide-react';
import './OrdersPanel.css';

const menuCategories = [
  {
    id: 'breakfast',
    title: 'ناشتے کی آئٹمز',
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
    items: [
      { id: 'leg-piece', name: 'لیگ پیس', price: 370 },
      { id: 'chest-piece', name: 'چیسٹ پیس', price: 400 },
    ],
  },
  {
    id: 'naan-roti',
    title: 'نان اور روٹی',
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

const OrdersPanel = () => {
  const [orders, setOrders] = useState([
    { id: 1, orderNum: 'ORD-001', table: 1, items: 'Biryani (2), Karahi (1)', category: 'Biryani', total: 2500, status: 'paid', date: '2026-05-10', time: '12:30 PM' },
    { id: 2, orderNum: 'ORD-002', table: 2, items: 'Karahi Chicken (1)', category: 'Karahi', total: 1800, status: 'completed', date: '2026-05-10', time: '01:15 PM' },
    { id: 3, orderNum: 'ORD-003', table: 3, items: 'Nihari (3), Naan (3)', category: 'Nihari', total: 3200, status: 'paid', date: '2026-05-10', time: '02:00 PM' },
    { id: 4, orderNum: 'ORD-004', table: 5, items: 'Tikka Masala (2)', category: 'Tikka', total: 2200, status: 'completed', date: '2026-05-10', time: '02:45 PM' },
    { id: 5, orderNum: 'ORD-005', table: 1, items: 'Kebab (4), Salad (1)', category: 'Kebab', total: 1600, status: 'paid', date: '2026-05-10', time: '03:30 PM' },
    { id: 6, orderNum: 'ORD-006', table: 4, items: 'Haleem (2)', category: 'Haleem', total: 2000, status: 'completed', date: '2026-05-09', time: '06:15 PM' },
  ]);

  const [ordersTab, setOrdersTab] = useState('live');
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

  const categories = ['Biryani', 'Karahi', 'Nihari', 'Tikka', 'Kebab', 'Haleem', 'Tandoori', 'Raita', 'Naan'];

  const activeMenu = menuCategories.find(category => category.id === activeMenuCategory) || menuCategories[0];

  const activeSearch = ordersTab === 'live' ? liveSearch : salesSearch;
  const activeDateFilter = ordersTab === 'live' ? liveDateFilter : salesDateFilter;
  const activeCustomFrom = ordersTab === 'live' ? liveCustomFrom : salesCustomFrom;
  const activeCustomTo = ordersTab === 'live' ? liveCustomTo : salesCustomTo;

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
      const matchesSearch = !searchTerm || [order.orderNum, order.table?.toString(), order.items, order.category, order.status]
        .some(value => String(value || '').toLowerCase().includes(searchTerm));
      const [fromDate, toDate] = dateRange;
      const matchesDate = !fromDate || (order.date >= fromDate && order.date <= toDate);
      const categoryMatch = !categoryFilter || order.category === categoryFilter;
      return matchesSearch && matchesDate && categoryMatch;
    });
  }, [orders, activeSearch, dateRange, categoryFilter]);

  const stats = useMemo(() => {
    return {
      totalOrders: filteredOrders.length,
      totalSales: filteredOrders.reduce((sum, order) => sum + order.total, 0),
      averageOrder: filteredOrders.length > 0
        ? Math.round(filteredOrders.reduce((sum, order) => sum + order.total, 0) / filteredOrders.length)
        : 0,
    };
  }, [filteredOrders]);

  const handleClearFilters = () => {
    setLiveSearch('');
    setSalesSearch('');
    setLiveDateFilter('today');
    setSalesDateFilter('today');
    setCategoryFilter('');
  };

  const handleExportCSV = () => {
    const headers = ['Order #', 'Table', 'Items', 'Category', 'Total', 'Status', 'Date', 'Time'];
    const csv = [
      headers.join(','),
      ...filteredOrders.map(order =>
        `${order.orderNum},${order.table},"${order.items}",${order.category},${order.total},${order.status},${order.date},${order.time}`
      ),
    ].join('\n');

    const blob = new Blob([csv], { type: 'text/csv' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `orders_${new Date().toISOString().split('T')[0]}.csv`;
    a.click();
    window.URL.revokeObjectURL(url);
  };

  const handleViewOrder = (orderId) => {
    const order = orders.find(o => o.id === orderId);
    alert(`Order Details:\n\nOrder #: ${order.orderNum}\nTable: ${order.table}\nItems: ${order.items}\nTotal: Rs. ${order.total}\nStatus: ${order.status}\nTime: ${order.time}`);
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
  };

  const handleAddExtrasToCart = () => {
    // Placeholder - no longer used
  };

  const handleCancelExtrasModal = () => {
    // Placeholder - no longer used
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
  };

  const handleClearCart = () => {
    setCartItems([]);
  };

  const cartTotal = cartItems.reduce((sum, item) => sum + item.price * item.quantity, 0);

  return (
    <div className="orders-panel">
      <h2>Orders & Sales</h2>

      <div className="stats-container">
        <div className="stat-card">
          <div className="stat-label">Total Orders</div>
          <div className="stat-value">{stats.totalOrders}</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">Total Sales</div>
          <div className="stat-value">Rs. {stats.totalSales.toLocaleString()}</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">Average Order</div>
          <div className="stat-value">Rs. {stats.averageOrder.toLocaleString()}</div>
        </div>
      </div>

      <div className="toolbar-container">
        <div className="toolbar-panel toolbar-tabs-panel">
          <div className="toolbar-label">Tabs</div>
          <button
            className={`tab-pill ${ordersTab === 'live' ? 'active' : ''}`}
            onClick={() => setOrdersTab('live')}
          >
            Live
          </button>
          <button
            className={`tab-pill ${ordersTab === 'sales' ? 'active' : ''}`}
            onClick={() => setOrdersTab('sales')}
          >
            Sales
          </button>
        </div>

        <div className="toolbar-panel toolbar-search-panel">
          <label htmlFor="orders-search" className="toolbar-label">Search</label>
          <input
            id="orders-search"
            type="text"
            className="toolbar-search-input"
            placeholder={ordersTab === 'live' ? 'Search live orders...' : 'Search sales orders...'}
            value={activeSearch}
            onChange={(e) => ordersTab === 'live' ? setLiveSearch(e.target.value) : setSalesSearch(e.target.value)}
          />
        </div>

        <div className="toolbar-panel toolbar-date-panel">
          <div className="toolbar-label">Date</div>
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
              <option key={cat} value={cat}>
                {cat}
              </option>
            ))}
          </select>
        </div>

        <button className="clear-btn" onClick={handleClearFilters}>
          Clear Filters
        </button>

        <button className="clear-btn" style={{ background: '#27ae60' }} onClick={handleExportCSV}>
          📥 Export to CSV
        </button>
      </div>

      <div className="menu-cart-layout">
        <section className="product-section">
          <div className="section-header">
            <div>
              <h3>مینو</h3>
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
                {item.image && (
                  <div className="menu-card-image-wrapper">
                    <img src={item.image} alt={item.name} className="menu-card-image" />
                  </div>
                )}

                <div className="menu-card-header">
                  <h4>{item.name}</h4>
                  <span className="menu-price">
                    {item.options ? `${item.options[0].price} / ${item.options[1]?.price || ''}` : item.price} تومان
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

                <div className="menu-card-action-note">کسی بھی جگہ پر ٹچ کریں، آئٹم فوری طور پر کارٹ میں چلا جائے گا</div>
              </div>
            ))}
          </div>
        </section>

        <aside className="cart-section">
          <div className="section-header cart-header">
            <div>
              <h3>کارٹ</h3>
              <p>منتخب آئٹمز یہاں دکھیں</p>
            </div>
            <span className="cart-badge">{cartItems.length} آئٹمز</span>
          </div>

          {cartItems.length === 0 ? (
            <div className="cart-empty">
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
                        <button className="save-edit-btn" onClick={handleSaveEdit}>✓</button>
                        <button className="cancel-edit-btn" onClick={handleCancelEdit}>✕</button>
                      </div>
                    </div>
                  ) : (
                    <>
                      <div>
                        <div className="cart-item-name">{item.label}</div>
                        <div className="cart-item-price">Rs. {item.price.toLocaleString()}</div>
                      </div>
                      <div className="cart-item-controls">
                        <button onClick={() => handleQuantityChange(index, -1)}>−</button>
                        <span>{item.quantity}</span>
                        <button onClick={() => handleQuantityChange(index, 1)}>+</button>
                      </div>
                      <div className="cart-item-actions">
                        <button className="edit-item-btn" onClick={() => handleEditCartItem(index)} title="Edit">
                          ✎ Edit
                        </button>
                        <button className="remove-item-btn" onClick={() => handleRemoveCartItem(index)}>
                          ×
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
              کارٹ خالی کریں
            </button>
          </div>
        </aside>
      </div>

      <div className="table-wrapper">
        <table className="orders-table">
          <thead>
            <tr>
              <th>Order #</th>
              <th>Table</th>
              <th>Items</th>
              <th>Category</th>
              <th>Total</th>
              <th>Status</th>
              <th>Date</th>
              <th>Time</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {filteredOrders.length > 0 ? (
              filteredOrders.map(order => (
                <tr key={order.id} className={`status-${order.status}`}>
                  <td className="order-number">{order.orderNum}</td>
                  <td><span className="table-num">T-{order.table}</span></td>
                  <td className="items">{order.items}</td>
                  <td><span className="category">{order.category}</span></td>
                  <td className="total">Rs. {order.total}</td>
                  <td>
                    <span className={`status-badge ${order.status}`}>
                      {order.status}
                    </span>
                  </td>
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
                  </td>
                </tr>
              ))
            ) : (
              <tr>
                <td colSpan="9" className="no-data">
                  No orders found for the selected filters.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default OrdersPanel;
