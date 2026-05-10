import React, { useState } from 'react';
import TableManagement from './components/TableManagement';
import OrdersPanel from './components/OrdersPanel';
import './App.css';

function App() {
  const [activeTab, setActiveTab] = useState('tables');

  return (
    <div className="app-container">
      {/* Header */}
      <header className="app-header">
        <h1>🍽️ Usman Hotel POS System</h1>
        <p>Restaurant Management & Orders Dashboard</p>
      </header>

      {/* Navigation Tabs */}
      <nav className="tab-navigation">
        <button
          className={`tab-btn ${activeTab === 'tables' ? 'active' : ''}`}
          onClick={() => setActiveTab('tables')}
        >
          📊 Table Management
        </button>
        <button
          className={`tab-btn ${activeTab === 'orders' ? 'active' : ''}`}
          onClick={() => setActiveTab('orders')}
        >
          📋 Orders & Sales
        </button>
      </nav>

      {/* Main Content */}
      <main className="app-main">
        {activeTab === 'tables' && <TableManagement />}
        {activeTab === 'orders' && <OrdersPanel />}
      </main>

      {/* Footer */}
      <footer className="app-footer">
        <p>&copy; 2026 Usman Hotel POS System. All rights reserved.</p>
      </footer>
    </div>
  );
}

export default App;
