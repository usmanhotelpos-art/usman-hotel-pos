import React, { useState, useMemo } from 'react';
import { Eye, Download } from 'lucide-react';
import './OrdersPanel.css';

const OrdersPanel = () => {
  const [orders, setOrders] = useState([
    { id: 1, orderNum: 'ORD-001', table: 1, items: 'Biryani (2), Karahi (1)', category: 'Biryani', total: 2500, status: 'paid', date: '2026-05-10', time: '12:30 PM' },
    { id: 2, orderNum: 'ORD-002', table: 2, items: 'Karahi Chicken (1)', category: 'Karahi', total: 1800, status: 'completed', date: '2026-05-10', time: '01:15 PM' },
    { id: 3, orderNum: 'ORD-003', table: 3, items: 'Nihari (3), Naan (3)', category: 'Nihari', total: 3200, status: 'paid', date: '2026-05-10', time: '02:00 PM' },
    { id: 4, orderNum: 'ORD-004', table: 5, items: 'Tikka Masala (2)', category: 'Tikka', total: 2200, status: 'completed', date: '2026-05-10', time: '02:45 PM' },
    { id: 5, orderNum: 'ORD-005', table: 1, items: 'Kebab (4), Salad (1)', category: 'Kebab', total: 1600, status: 'paid', date: '2026-05-10', time: '03:30 PM' },
    { id: 6, orderNum: 'ORD-006', table: 4, items: 'Haleem (2)', category: 'Haleem', total: 2000, status: 'completed', date: '2026-05-09', time: '06:15 PM' },
  ]);

  const [dateFilter, setDateFilter] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('');
  const [timeFilter, setTimeFilter] = useState('');

  const categories = ['Biryani', 'Karahi', 'Nihari', 'Tikka', 'Kebab', 'Haleem', 'Tandoori', 'Raita', 'Naan'];

  // Filter orders based on selected filters
  const filteredOrders = useMemo(() => {
    return orders.filter(order => {
      const dateMatch = !dateFilter || order.date === dateFilter;
      const categoryMatch = !categoryFilter || order.category === categoryFilter;
      return dateMatch && categoryMatch;
    });
  }, [orders, dateFilter, categoryFilter]);

  // Calculate statistics
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
    setDateFilter('');
    setCategoryFilter('');
    setTimeFilter('');
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

  return (
    <div className="orders-panel">
      <h2>Orders & Sales</h2>

      {/* Statistics */}
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

      {/* Filters */}
      <div className="filters-container">
        <div className="filter-group">
          <label htmlFor="date-filter">📅 Date:</label>
          <input
            id="date-filter"
            type="date"
            className="filter-input"
            value={dateFilter}
            onChange={(e) => setDateFilter(e.target.value)}
          />
        </div>

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

      {/* Orders Table */}
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
