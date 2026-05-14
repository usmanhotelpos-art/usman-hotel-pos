import React, { useState } from 'react';
import { Edit, Printer, Trash2, User, Check } from 'lucide-react';
import './TableManagement.css';

const TableManagement = () => {
  const [tables, setTables] = useState([
    { id: 1, number: 1, status: 'occupied', waiter: 'Ahmed', total: 5000, customers: 4 },
    { id: 2, number: 2, status: 'occupied', waiter: 'Ali', total: 3500, customers: 2 },
    { id: 3, number: 3, status: 'occupied', waiter: 'Hassan', total: 7200, customers: 6 },
    { id: 4, number: 4, status: 'empty', waiter: null, total: 0, customers: 0 },
    { id: 5, number: 5, status: 'occupied', waiter: 'Fatima', total: 4100, customers: 3 },
    { id: 6, number: 6, status: 'empty', waiter: null, total: 0, customers: 0 },
  ]);

  const waiters = ['Ahmed', 'Ali', 'Hassan', 'Fatima', 'Sara', 'Omar'];
  const [editingTableId, setEditingTableId] = useState(null);

  const handleEdit = (tableId) => {
    console.log('Edit table:', tableId);
    setEditingTableId(tableId);
  };

  const handlePrint = (tableId) => {
    console.log('Print bill for table:', tableId);
    alert(`Printing bill for Table ${tableId}`);
  };

  const handleMarkPaid = (tableId) => {
    const updatedTables = tables.map(table =>
      table.id === tableId ? { ...table, status: 'empty', waiter: null, total: 0 } : table
    );
    setTables(updatedTables);
    alert(`Table ${tableId} marked as paid and cleared`);
  };

  const handleDelete = (tableId) => {
    const updatedTables = tables.filter(table => table.id !== tableId);
    setTables(updatedTables);
  };

  const handleAssignWaiter = (tableId, waiterName) => {
    const updatedTables = tables.map(table =>
      table.id === tableId ? { ...table, waiter: waiterName } : table
    );
    setTables(updatedTables);
  };

  return (
    <div className="table-management">
      <h2>Table Management</h2>
      
      {/* Tables Grid */}
      <div className="tables-container">
        <div className="section-title">Occupied Tables</div>
        <div className="tables-grid">
          {tables.map(table => (
            <div
              key={table.id}
              className={`table-square ${table.status}`}
            >
              <div className="table-header">
                <span className="table-number">Table {table.number}</span>
              </div>

              <div className="table-info">
                <p><strong>Customers:</strong> {table.customers}</p>
                <p><strong>Total:</strong> Rs. {table.total}</p>
              </div>

              {table.status === 'occupied' && (
                <>
                  {/* Waiter Assignment Dropdown */}
                  <div className="waiter-section">
                    <select
                      className="waiter-select"
                      value={table.waiter || ''}
                      onChange={(e) => handleAssignWaiter(table.id, e.target.value)}
                    >
                      <option value="">Select Waiter</option>
                      {waiters.map(waiter => (
                        <option key={waiter} value={waiter}>
                          {waiter}
                        </option>
                      ))}
                    </select>
                    {table.waiter && <p className="assigned-waiter">👨‍💼 {table.waiter}</p>}
                  </div>

                  {/* Action Icons */}
                  <div className="actions-grid">
                    <button
                      className="action-btn edit-btn"
                      onClick={() => handleEdit(table.id)}
                      title="Edit"
                    >
                      <Edit size={20} />
                      <span>Edit</span>
                    </button>

                    <button
                      className="action-btn print-btn"
                      onClick={() => handlePrint(table.id)}
                      title="Print"
                    >
                      <Printer size={20} />
                      <span>Print</span>
                    </button>

                    <button
                      className="action-btn paid-btn"
                      onClick={() => handleMarkPaid(table.id)}
                      title="Mark Paid"
                    >
                      <Check size={20} />
                      <span>Paid</span>
                    </button>

                    <button
                      className="action-btn delete-btn"
                      onClick={() => handleDelete(table.id)}
                      title="Delete"
                    >
                      <Trash2 size={20} />
                      <span>Delete</span>
                    </button>
                  </div>
                </>
              )}

              {table.status === 'empty' && (
                <div className="table-empty">
                  <p>Available</p>
                </div>
              )}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

export default TableManagement;
