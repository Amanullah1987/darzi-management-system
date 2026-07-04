import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('darzi_management.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (!kIsWeb) {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }
    }
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 5, // Updated version for expenses module with suit tracking
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onDowngrade: onDatabaseDowngradeDelete,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await _createAllTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    for (int version = oldVersion; version < newVersion; version++) {
      await _migrate(db, version, version + 1);
    }
  }

  Future<void> _migrate(Database db, int fromVersion, int toVersion) async {
    if (fromVersion == 1 && toVersion == 2) {
      await db.execute('ALTER TABLE orders ADD COLUMN total_amount INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE orders ADD COLUMN remaining_amount INTEGER DEFAULT 0');
    } else if (fromVersion == 2 && toVersion == 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_id INTEGER NOT NULL,
          order_id INTEGER NOT NULL,
          payment_date TEXT NOT NULL,
          amount INTEGER NOT NULL,
          payment_method TEXT DEFAULT 'Cash',
          notes TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE,
          FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE
        )
      ''');
    } else if (fromVersion == 1 && toVersion == 3) {
      await db.execute('ALTER TABLE orders ADD COLUMN total_amount INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE orders ADD COLUMN remaining_amount INTEGER DEFAULT 0');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_id INTEGER NOT NULL,
          order_id INTEGER NOT NULL,
          payment_date TEXT NOT NULL,
          amount INTEGER NOT NULL,
          payment_method TEXT DEFAULT 'Cash',
          notes TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE,
          FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE
        )
      ''');
    } else if (fromVersion == 3 && toVersion == 4) {
      // ===== EXPENSES MODULE MIGRATION =====
      await db.execute('''
        CREATE TABLE IF NOT EXISTS expense_categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          icon TEXT DEFAULT 'receipt_long',
          color TEXT DEFAULT '#6B7280'
        )
      ''');

      // Insert default categories
      final count = await db.rawQuery('SELECT COUNT(*) as cnt FROM expense_categories');
      if ((count.first['cnt'] as int? ?? 0) == 0) {
        final defaultCategories = [
          {'name': 'Karigar Payment', 'icon': 'person', 'color': '#3B82F6'},
          {'name': 'Materials', 'icon': 'inventory_2', 'color': '#10B981'},
          {'name': 'Fabrics', 'icon': 'checkroom', 'color': '#F59E0B'},
          {'name': 'Food & Tea', 'icon': 'coffee', 'color': '#EF4444'},
          {'name': 'Electricity Bill', 'icon': 'bolt', 'color': '#8B5CF6'},
          {'name': 'Shop Rent', 'icon': 'store', 'color': '#EC4899'},
          {'name': 'Transport', 'icon': 'local_shipping', 'color': '#06B6D4'},
          {'name': 'Other Expenses', 'icon': 'more_horiz', 'color': '#6B7280'},
        ];
        for (final cat in defaultCategories) {
          await db.insert('expense_categories', cat);
        }
      }

      await db.execute('''
        CREATE TABLE IF NOT EXISTS expenses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          category_id INTEGER NOT NULL,
          title TEXT NOT NULL,
          amount REAL NOT NULL,
          expense_date TEXT NOT NULL,
          description TEXT,
          payment_method TEXT DEFAULT 'Cash',
          image_path TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (category_id) REFERENCES expense_categories (id)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS workers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          phone TEXT,
          rate_per_suit REAL DEFAULT 0,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS karigar_payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          worker_id INTEGER NOT NULL,
          number_of_suits INTEGER NOT NULL,
          rate_per_suit REAL NOT NULL,
          total_amount REAL NOT NULL,
          paid_amount REAL DEFAULT 0,
          payment_date TEXT NOT NULL,
          status TEXT DEFAULT 'Unpaid',
          notes TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (worker_id) REFERENCES workers (id)
        )
      ''');
    } else if (fromVersion == 2 && toVersion == 4) {
      // Direct migration from v2 to v4
      await db.execute('''
        CREATE TABLE IF NOT EXISTS expense_categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          icon TEXT DEFAULT 'receipt_long',
          color TEXT DEFAULT '#6B7280'
        )
      ''');
      final count = await db.rawQuery('SELECT COUNT(*) as cnt FROM expense_categories');
      if ((count.first['cnt'] as int? ?? 0) == 0) {
        final defaultCategories = [
          {'name': 'Karigar Payment', 'icon': 'person', 'color': '#3B82F6'},
          {'name': 'Materials', 'icon': 'inventory_2', 'color': '#10B981'},
          {'name': 'Fabrics', 'icon': 'checkroom', 'color': '#F59E0B'},
          {'name': 'Food & Tea', 'icon': 'coffee', 'color': '#EF4444'},
          {'name': 'Electricity Bill', 'icon': 'bolt', 'color': '#8B5CF6'},
          {'name': 'Shop Rent', 'icon': 'store', 'color': '#EC4899'},
          {'name': 'Transport', 'icon': 'local_shipping', 'color': '#06B6D4'},
          {'name': 'Other Expenses', 'icon': 'more_horiz', 'color': '#6B7280'},
        ];
        for (final cat in defaultCategories) {
          await db.insert('expense_categories', cat);
        }
      }
      await db.execute('''
        CREATE TABLE IF NOT EXISTS expenses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          category_id INTEGER NOT NULL,
          title TEXT NOT NULL,
          amount REAL NOT NULL,
          expense_date TEXT NOT NULL,
          description TEXT,
          payment_method TEXT DEFAULT 'Cash',
          image_path TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (category_id) REFERENCES expense_categories (id)
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS workers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          phone TEXT,
          rate_per_suit REAL DEFAULT 0,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS karigar_payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          worker_id INTEGER NOT NULL,
          number_of_suits INTEGER NOT NULL,
          rate_per_suit REAL NOT NULL,
          total_amount REAL NOT NULL,
          paid_amount REAL DEFAULT 0,
          payment_date TEXT NOT NULL,
          status TEXT DEFAULT 'Unpaid',
          notes TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (worker_id) REFERENCES workers (id)
        )
      ''');
    } else if (fromVersion == 1 && toVersion == 4) {
      // Direct migration from v1 to v4
      await db.execute('ALTER TABLE orders ADD COLUMN total_amount INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE orders ADD COLUMN remaining_amount INTEGER DEFAULT 0');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_id INTEGER NOT NULL,
          order_id INTEGER NOT NULL,
          payment_date TEXT NOT NULL,
          amount INTEGER NOT NULL,
          payment_method TEXT DEFAULT 'Cash',
          notes TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE,
          FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS expense_categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          icon TEXT DEFAULT 'receipt_long',
          color TEXT DEFAULT '#6B7280'
        )
      ''');
      final count = await db.rawQuery('SELECT COUNT(*) as cnt FROM expense_categories');
      if ((count.first['cnt'] as int? ?? 0) == 0) {
        final defaultCategories = [
          {'name': 'Karigar Payment', 'icon': 'person', 'color': '#3B82F6'},
          {'name': 'Materials', 'icon': 'inventory_2', 'color': '#10B981'},
          {'name': 'Fabrics', 'icon': 'checkroom', 'color': '#F59E0B'},
          {'name': 'Food & Tea', 'icon': 'coffee', 'color': '#EF4444'},
          {'name': 'Electricity Bill', 'icon': 'bolt', 'color': '#8B5CF6'},
          {'name': 'Shop Rent', 'icon': 'store', 'color': '#EC4899'},
          {'name': 'Transport', 'icon': 'local_shipping', 'color': '#06B6D4'},
          {'name': 'Other Expenses', 'icon': 'more_horiz', 'color': '#6B7280'},
        ];
        for (final cat in defaultCategories) {
          await db.insert('expense_categories', cat);
        }
      }
      await db.execute('''
        CREATE TABLE IF NOT EXISTS expenses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          category_id INTEGER NOT NULL,
          title TEXT NOT NULL,
          amount REAL NOT NULL,
          expense_date TEXT NOT NULL,
          description TEXT,
          payment_method TEXT DEFAULT 'Cash',
          image_path TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (category_id) REFERENCES expense_categories (id)
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS workers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          phone TEXT,
          rate_per_suit REAL DEFAULT 0,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS karigar_payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          worker_id INTEGER NOT NULL,
          number_of_suits INTEGER NOT NULL,
          rate_per_suit REAL NOT NULL,
          total_amount REAL NOT NULL,
          paid_amount REAL DEFAULT 0,
          payment_date TEXT NOT NULL,
          status TEXT DEFAULT 'Unpaid',
          notes TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (worker_id) REFERENCES workers (id)
        )
      ''');
    } else if (fromVersion == 4 && toVersion == 5) {
      // v5: Add suit tracking columns to workers and suits_range to karigar_payments
      try {
        await db.execute('ALTER TABLE workers ADD COLUMN total_suits INTEGER DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE workers ADD COLUMN paid_suits INTEGER DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE karigar_payments ADD COLUMN suits_range TEXT');
      } catch (_) {}
    }
  }

  Future<void> _createAllTables(Database db) async {
    // ===== BUSINESS INFO =====
    await db.execute('''
      CREATE TABLE IF NOT EXISTS business_info (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        address TEXT NOT NULL
      )
    ''');

    // ===== SILAI TYPES =====
    await db.execute('''
      CREATE TABLE IF NOT EXISTS silai_types (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');

    // ===== NAAP TYPES =====
    await db.execute('''
      CREATE TABLE IF NOT EXISTS naap_types (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        silai_id INTEGER NOT NULL,
        name TEXT NOT NULL
      )
    ''');

    // ===== NAAP EXTRA INFO =====
    await db.execute('''
      CREATE TABLE IF NOT EXISTS naap_extra_info (
        id INTEGER PRIMARY KEY AUTOINCREMENT,       
        title TEXT NOT NULL,
        value TEXT NOT NULL
      )
    ''');

    // ===== CUSTOMERS =====
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        address TEXT,
        total_purchases REAL DEFAULT 0,
        total_payments REAL DEFAULT 0,
        balance REAL DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // ===== CUSTOMER MEASUREMENTS =====
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customer_measurements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        silai_id INTEGER NOT NULL,
        naap_type_id INTEGER NOT NULL,
        value TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE,
        FOREIGN KEY (silai_id) REFERENCES silai_types (id) ON DELETE CASCADE,
        FOREIGN KEY (naap_type_id) REFERENCES naap_types (id) ON DELETE CASCADE
      )
    ''');

    // ===== ORDERS =====
    await db.execute('''
      CREATE TABLE IF NOT EXISTS orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        silai_id INTEGER NOT NULL,
        order_date TEXT NOT NULL,
        delivery_date TEXT NOT NULL,
        status TEXT DEFAULT 'Pending',
        price INTEGER DEFAULT 0,
        fabric_cost INTEGER DEFAULT 0,
        extra_cost INTEGER DEFAULT 0,
        advance INTEGER DEFAULT 0,
        total_amount INTEGER DEFAULT 0,
        remaining_amount INTEGER DEFAULT 0,
        notes TEXT,
        image_path TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE,
        FOREIGN KEY (silai_id) REFERENCES silai_types (id)
      )
    ''');

    // ===== PAYMENTS =====
    await db.execute('''
      CREATE TABLE IF NOT EXISTS payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        order_id INTEGER NOT NULL,
        payment_date TEXT NOT NULL,
        amount INTEGER NOT NULL,
        payment_method TEXT DEFAULT 'Cash',
        notes TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE,
        FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE
      )
    ''');

    // ===== EXPENSE CATEGORIES =====
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expense_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT DEFAULT 'receipt_long',
        color TEXT DEFAULT '#6B7280'
      )
    ''');

    // Insert default expense categories if empty
    final catCount = await db.rawQuery('SELECT COUNT(*) as cnt FROM expense_categories');
    if ((catCount.first['cnt'] as int? ?? 0) == 0) {
      final defaultCategories = [
        {'name': 'Karigar Payment', 'icon': 'person', 'color': '#3B82F6'},
        {'name': 'Materials', 'icon': 'inventory_2', 'color': '#10B981'},
        {'name': 'Fabrics', 'icon': 'checkroom', 'color': '#F59E0B'},
        {'name': 'Food & Tea', 'icon': 'coffee', 'color': '#EF4444'},
        {'name': 'Electricity Bill', 'icon': 'bolt', 'color': '#8B5CF6'},
        {'name': 'Shop Rent', 'icon': 'store', 'color': '#EC4899'},
        {'name': 'Transport', 'icon': 'local_shipping', 'color': '#06B6D4'},
        {'name': 'Other Expenses', 'icon': 'more_horiz', 'color': '#6B7280'},
      ];
      for (final cat in defaultCategories) {
        await db.insert('expense_categories', cat);
      }
    }

    // ===== EXPENSES =====
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        expense_date TEXT NOT NULL,
        description TEXT,
        payment_method TEXT DEFAULT 'Cash',
        image_path TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (category_id) REFERENCES expense_categories (id)
      )
    ''');

    // ===== WORKERS (with suit tracking) =====
    await db.execute('''
      CREATE TABLE IF NOT EXISTS workers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        rate_per_suit REAL DEFAULT 0,
        total_suits INTEGER DEFAULT 0,
        paid_suits INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // ===== KARIGAR PAYMENTS =====
    await db.execute('''
      CREATE TABLE IF NOT EXISTS karigar_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        worker_id INTEGER NOT NULL,
        number_of_suits INTEGER NOT NULL,
        rate_per_suit REAL NOT NULL,
        total_amount REAL NOT NULL,
        paid_amount REAL DEFAULT 0,
        payment_date TEXT NOT NULL,
        status TEXT DEFAULT 'Unpaid',
        notes TEXT,
        suits_range TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (worker_id) REFERENCES workers (id)
      )
    ''');
  }

  // ═══════════════════════════════════════════════════════════════
  //  YOUR EXISTING METHODS - ALL PRESERVED EXACTLY AS-IS
  // ═══════════════════════════════════════════════════════════════

  // Business Info Methods
  Future<Map<String, dynamic>?> getBusinessInfo() async {
    final db = await database;
    final result = await db.query('business_info', limit: 1);
    return result.isNotEmpty ? result.first : null;
  }

  Future<void> insertBusinessInfo(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('business_info', data);
  }

  Future<void> updateBusinessInfo(Map<String, dynamic> data) async {
    final db = await database;
    final existing = await db.query('business_info', limit: 1);
    if (existing.isNotEmpty) {
      await db.update('business_info', data, where: 'id = ?', whereArgs: [existing.first['id']]);
    } else {
      await db.insert('business_info', data);
    }
  }

  // Silai Types Methods
  Future<List<Map<String, dynamic>>> getSilaiTypes() async {
    final db = await database;
    return await db.query('silai_types', orderBy: 'id ASC');
  }

  Future<int> insertSilaiType(String name) async {
    final db = await database;
    return await db.insert('silai_types', {'name': name});
  }

  Future<void> updateSilaiType(int id, String name) async {
    final db = await database;
    await db.update('silai_types', {'name': name}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteSilaiType(int id) async {
    final db = await database;
    await db.delete('silai_types', where: 'id = ?', whereArgs: [id]);
  }

  // Naap Types Methods
  Future<List<Map<String, dynamic>>> getNaapTypes() async {
    final db = await database;
    return await db.query('naap_types', orderBy: 'id ASC');
  }

  Future<List<Map<String, dynamic>>> getNaapTypesBySilai(int silaiId) async {
    final db = await database;
    return await db.query('naap_types', where: 'silai_id = ?', whereArgs: [silaiId], orderBy: 'id ASC');
  }

  Future<int> insertNaapType(int silaiId, String name) async {
    final db = await database;
    return await db.insert('naap_types', {'silai_id': silaiId, 'name': name});
  }

  Future<void> updateNaapType(int id, int silaiId, String name) async {
    final db = await database;
    await db.update('naap_types', {'silai_id': silaiId, 'name': name}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteNaapType(int id) async {
    final db = await database;
    await db.delete('naap_types', where: 'id = ?', whereArgs: [id]);
  }

  // Naap Extra Info Methods
  Future<List<Map<String, dynamic>>> getNaapExtraInfo() async {
    final db = await database;
    return await db.query('naap_extra_info');
  }

  Future<List<Map<String, dynamic>>> getNaapExtraInfoBySilai() async {
    final db = await database;
    return await db.rawQuery('SELECT nei.id, nei.title, nei.value FROM naap_extra_info nei');
  }

  Future<int> insertNaapExtraInfo(String title, String value) async {
    final db = await database;
    return await db.insert('naap_extra_info', {'title': title, 'value': value});
  }

  Future<void> updateNaapExtraInfo(int id, String title, String value) async {
    final db = await database;
    await db.update('naap_extra_info', {'title': title, 'value': value}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteNaapExtraInfo(int id) async {
    final db = await database;
    await db.delete('naap_extra_info', where: 'id = ?', whereArgs: [id]);
  }

  // Customer Methods
  Future<List<Map<String, dynamic>>> getCustomers() async {
    final db = await database;
    return await db.query('customers', orderBy: 'id DESC');
  }

  Future<Map<String, dynamic>?> getCustomerById(int id) async {
    final db = await database;
    final result = await db.query('customers', where: 'id = ?', whereArgs: [id], limit: 1);
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> insertCustomer(String name, String phone, String address) async {
    final db = await database;
    return await db.insert('customers', {'name': name, 'phone': phone, 'address': address});
  }

  Future<void> updateCustomer(int id, String name, String phone, String address) async {
    final db = await database;
    await db.update('customers', {'name': name, 'phone': phone, 'address': address}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteCustomer(int id) async {
    final db = await database;
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  // Customer Measurements Methods
  Future<void> saveMeasurement(int customerId, int silaiId, int naapTypeId, String value) async {
    final db = await database;
    final result = await db.query('customer_measurements', where: 'customer_id = ? AND silai_id = ? AND naap_type_id = ?', whereArgs: [customerId, silaiId, naapTypeId]);
    if (result.isNotEmpty) {
      await db.update('customer_measurements', {'value': value}, where: 'id = ?', whereArgs: [result.first['id']]);
    } else {
      await db.insert('customer_measurements', {'customer_id': customerId, 'silai_id': silaiId, 'naap_type_id': naapTypeId, 'value': value});
    }
  }

  Future<Map<int, String>> getCustomerMeasurements(int customerId, int silaiId) async {
    final db = await database;
    final result = await db.query('customer_measurements', where: 'customer_id = ? AND silai_id = ?', whereArgs: [customerId, silaiId]);
    Map<int, String> data = {};
    for (var row in result) {
      data[row['naap_type_id'] as int] = row['value'] as String;
    }
    return data;
  }

  Future<void> deleteCustomerMeasurements(int customerId, int silaiId) async {
    final db = await database;
    await db.delete('customer_measurements', where: 'customer_id = ? AND silai_id = ?', whereArgs: [customerId, silaiId]);
  }

  // Order Methods
  Future<int> createOrder(Map<String, dynamic> orderData) async {
    final db = await database;
    int price = orderData['price'] ?? 0;
    int fabricCost = orderData['fabric_cost'] ?? 0;
    int extraCost = orderData['extra_cost'] ?? 0;
    int advance = orderData['advance'] ?? 0;
    int totalAmount = price + fabricCost + extraCost;
    int remainingAmount = totalAmount - advance;
    orderData['total_amount'] = totalAmount;
    orderData['remaining_amount'] = remainingAmount;
    int orderId = await db.insert('orders', orderData);
    int customerId = orderData['customer_id'];
    await _updateCustomerBalance(customerId);
    return orderId;
  }

  Future<List<Map<String, dynamic>>> getAllOrders() async {
    final db = await database;
    return await db.query('orders', orderBy: 'id DESC');
  }

  Future<List<Map<String, dynamic>>> getCustomerOrders(int customerId) async {
    final db = await database;
    return await db.query('orders', where: 'customer_id = ?', whereArgs: [customerId], orderBy: 'id DESC');
  }

  Future<Map<String, dynamic>?> getOrderById(int id) async {
    final db = await database;
    final result = await db.query('orders', where: 'id = ?', whereArgs: [id], limit: 1);
    return result.isNotEmpty ? result.first : null;
  }

  Future<void> updateOrderStatus(int orderId, String status) async {
    final db = await database;
    await db.update('orders', {'status': status}, where: 'id = ?', whereArgs: [orderId]);
  }

  Future<void> updateOrder(int orderId, Map<String, dynamic> data) async {
    final db = await database;
    if (data.containsKey('price') || data.containsKey('fabric_cost') || data.containsKey('extra_cost') || data.containsKey('advance')) {
      final order = await getOrderById(orderId);
      if (order != null) {
        int price = data['price'] ?? order['price'] ?? 0;
        int fabricCost = data['fabric_cost'] ?? order['fabric_cost'] ?? 0;
        int extraCost = data['extra_cost'] ?? order['extra_cost'] ?? 0;
        int advance = data['advance'] ?? order['advance'] ?? 0;
        int totalAmount = price + fabricCost + extraCost;
        int remainingAmount = totalAmount - advance;
        data['total_amount'] = totalAmount;
        data['remaining_amount'] = remainingAmount;
      }
    }
    await db.update('orders', data, where: 'id = ?', whereArgs: [orderId]);
    final order = await getOrderById(orderId);
    if (order != null) {
      await _updateCustomerBalance(order['customer_id'] as int);
    }
  }

  Future<void> deleteOrder(int id) async {
    final db = await database;
    final order = await getOrderById(id);
    if (order != null) {
      int customerId = order['customer_id'] as int;
      await db.delete('orders', where: 'id = ?', whereArgs: [id]);
      await _updateCustomerBalance(customerId);
    }
  }

  Future<List<Map<String, dynamic>>> getOrdersByStatus(String status) async {
    final db = await database;
    return await db.query('orders', where: 'status = ?', whereArgs: [status], orderBy: 'delivery_date ASC');
  }

  Future<int> getPendingOrdersCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM orders WHERE status = ?', ['Pending']);
    final count = result.first['count'] as int?;
    return count ?? 0;
  }

  Future<List<Map<String, dynamic>>> getOrdersWithCustomerDetails() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT orders.*, customers.name as customer_name, customers.phone as customer_phone,
      customers.balance as customer_balance, silai_types.name as silai_name
      FROM orders
      LEFT JOIN customers ON orders.customer_id = customers.id
      LEFT JOIN silai_types ON orders.silai_id = silai_types.id
      ORDER BY orders.id DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getOrdersWithPayments(int customerId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT orders.*, COALESCE(SUM(payments.amount), 0) as total_paid,
      (orders.total_amount - COALESCE(SUM(payments.amount), 0)) as pending_amount
      FROM orders
      LEFT JOIN payments ON orders.id = payments.order_id
      WHERE orders.customer_id = ?
      GROUP BY orders.id
      ORDER BY orders.id DESC
    ''', [customerId]);
  }

  // Payment Methods
  Future<int> addPayment(Map<String, dynamic> paymentData) async {
    final db = await database;
    int paymentId = await db.insert('payments', paymentData);
    int orderId = paymentData['order_id'];
    int paymentAmount = paymentData['amount'];
    final order = await getOrderById(orderId);
    if (order != null) {
      int currentRemaining = order['remaining_amount'] ?? 0;
      int newRemaining = currentRemaining - paymentAmount;
      if (newRemaining < 0) newRemaining = 0;
      await db.update('orders', {'remaining_amount': newRemaining}, where: 'id = ?', whereArgs: [orderId]);
      int customerId = order['customer_id'] as int;
      await _updateCustomerBalance(customerId);
    }
    return paymentId;
  }

  Future<List<Map<String, dynamic>>> getPaymentsByCustomer(int customerId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT payments.*, customers.name as customer_name, orders.total_amount, orders.remaining_amount
      FROM payments
      LEFT JOIN customers ON payments.customer_id = customers.id
      LEFT JOIN orders ON payments.order_id = orders.id
      WHERE payments.customer_id = ?
      ORDER BY payments.payment_date DESC
    ''', [customerId]);
  }

  Future<List<Map<String, dynamic>>> getPaymentsByOrder(int orderId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT payments.*, customers.name as customer_name
      FROM payments
      LEFT JOIN customers ON payments.customer_id = customers.id
      WHERE payments.order_id = ?
      ORDER BY payments.payment_date DESC
    ''', [orderId]);
  }

  Future<List<Map<String, dynamic>>> getPaymentHistory() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT payments.*, customers.name as customer_name, orders.total_amount, orders.remaining_amount
      FROM payments
      LEFT JOIN customers ON payments.customer_id = customers.id
      LEFT JOIN orders ON payments.order_id = orders.id
      ORDER BY payments.payment_date DESC
    ''');
  }

  Future<Map<String, dynamic>> getCustomerPaymentSummary(int customerId) async {
    final db = await database;
    final purchasesResult = await db.rawQuery('SELECT COALESCE(SUM(total_amount), 0) as total_purchases FROM orders WHERE customer_id = ?', [customerId]);
    final paymentsResult = await db.rawQuery('SELECT COALESCE(SUM(amount), 0) as total_payments FROM payments WHERE customer_id = ?', [customerId]);
    dynamic purchasesValue = purchasesResult.first['total_purchases'];
    dynamic paymentsValue = paymentsResult.first['total_payments'];
    double totalPurchases = (purchasesValue as num).toDouble();
    double totalPayments = (paymentsValue as num).toDouble();
    double balance = totalPurchases - totalPayments;
    return {'total_purchases': totalPurchases, 'total_payments': totalPayments, 'balance': balance};
  }

  Future<void> updatePayment(int paymentId, Map<String, dynamic> data) async {
    final db = await database;
    final oldPayment = await db.query('payments', where: 'id = ?', whereArgs: [paymentId], limit: 1);
    if (oldPayment.isNotEmpty) {
      int orderId = oldPayment.first['order_id'] as int;
      int oldAmount = oldPayment.first['amount'] as int;
      int newAmount = data['amount'] ?? oldAmount;
      await db.update('payments', data, where: 'id = ?', whereArgs: [paymentId]);
      final order = await getOrderById(orderId);
      if (order != null) {
        int currentRemaining = order['remaining_amount'] ?? 0;
        int difference = oldAmount - newAmount;
        int newRemaining = currentRemaining + difference;
        if (newRemaining < 0) newRemaining = 0;
        await db.update('orders', {'remaining_amount': newRemaining}, where: 'id = ?', whereArgs: [orderId]);
        int customerId = order['customer_id'] as int;
        await _updateCustomerBalance(customerId);
      }
    }
  }

  Future<void> deletePayment(int paymentId) async {
    final db = await database;
    final payment = await db.query('payments', where: 'id = ?', whereArgs: [paymentId], limit: 1);
    if (payment.isNotEmpty) {
      int orderId = payment.first['order_id'] as int;
      int amount = payment.first['amount'] as int;
      await db.delete('payments', where: 'id = ?', whereArgs: [paymentId]);
      final order = await getOrderById(orderId);
      if (order != null) {
        int currentRemaining = order['remaining_amount'] ?? 0;
        int newRemaining = currentRemaining + amount;
        await db.update('orders', {'remaining_amount': newRemaining}, where: 'id = ?', whereArgs: [orderId]);
        int customerId = order['customer_id'] as int;
        await _updateCustomerBalance(customerId);
      }
    }
  }

  // Customer Balance Methods
  Future<void> _updateCustomerBalance(int customerId) async {
    final db = await database;
    final purchasesResult = await db.rawQuery('SELECT COALESCE(SUM(total_amount), 0) as total_purchases FROM orders WHERE customer_id = ?', [customerId]);
    final paymentsResult = await db.rawQuery('SELECT COALESCE(SUM(amount), 0) as total_payments FROM payments WHERE customer_id = ?', [customerId]);
    dynamic purchasesValue = purchasesResult.first['total_purchases'];
    dynamic paymentsValue = paymentsResult.first['total_payments'];
    double totalPurchases = (purchasesValue as num).toDouble();
    double totalPayments = (paymentsValue as num).toDouble();
    double balance = totalPurchases - totalPayments;
    await db.update('customers', {'total_purchases': totalPurchases, 'total_payments': totalPayments, 'balance': balance}, where: 'id = ?', whereArgs: [customerId]);
  }

  Future<Map<String, dynamic>> getCustomerFinancialSummary(int customerId) async {
    final db = await database;
    final customer = await getCustomerById(customerId);
    if (customer == null) {
      return {'total_purchases': 0.0, 'total_payments': 0.0, 'balance': 0.0, 'orders': [], 'payments': []};
    }
    final orders = await getOrdersWithPayments(customerId);
    final payments = await getPaymentsByCustomer(customerId);
    dynamic purchasesValue = customer['total_purchases'];
    dynamic paymentsValue = customer['total_payments'];
    dynamic balanceValue = customer['balance'];
    return {
      'total_purchases': (purchasesValue as num).toDouble(),
      'total_payments': (paymentsValue as num).toDouble(),
      'balance': (balanceValue as num).toDouble(),
      'orders': orders,
      'payments': payments,
    };
  }

  // Database Management Methods
  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('payments');
    await db.delete('orders');
    await db.delete('customer_measurements');
    await db.delete('customers');
    await db.delete('naap_extra_info');
    await db.delete('naap_types');
    await db.delete('silai_types');
    await db.delete('business_info');
  }

  Future<Map<String, int>> getDatabaseStats() async {
    final db = await database;
    final customersResult = await db.rawQuery('SELECT COUNT(*) as count FROM customers');
    final customersCount = customersResult.first['count'] as int? ?? 0;
    final ordersResult = await db.rawQuery('SELECT COUNT(*) as count FROM orders');
    final ordersCount = ordersResult.first['count'] as int? ?? 0;
    final silaiTypesResult = await db.rawQuery('SELECT COUNT(*) as count FROM silai_types');
    final silaiTypesCount = silaiTypesResult.first['count'] as int? ?? 0;
    final paymentsResult = await db.rawQuery('SELECT COUNT(*) as count FROM payments');
    final paymentsCount = paymentsResult.first['count'] as int? ?? 0;
    return {'customers': customersCount, 'orders': ordersCount, 'silai_types': silaiTypesCount, 'payments': paymentsCount};
  }

  // ═══════════════════════════════════════════════════════════════
  //  NEW: EXPENSE CATEGORY METHODS
  // ═══════════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> getExpenseCategories() async {
    final db = await database;
    return await db.query('expense_categories', orderBy: 'id ASC');
  }

  Future<Map<String, dynamic>?> getExpenseCategoryById(int id) async {
    final db = await database;
    final result = await db.query('expense_categories', where: 'id = ?', whereArgs: [id], limit: 1);
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> addExpenseCategory(String name, String icon, String color) async {
    final db = await database;
    return await db.insert('expense_categories', {'name': name, 'icon': icon, 'color': color});
  }

  Future<void> updateExpenseCategory(int id, String name, String icon, String color) async {
    final db = await database;
    await db.update('expense_categories', {'name': name, 'icon': icon, 'color': color}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteExpenseCategory(int id) async {
    final db = await database;
    await db.delete('expense_categories', where: 'id = ?', whereArgs: [id]);
  }

  // ═══════════════════════════════════════════════════════════════
  //  NEW: EXPENSE METHODS
  // ═══════════════════════════════════════════════════════════════
  Future<int> addExpense(Map<String, dynamic> expenseData) async {
    final db = await database;
    return await db.insert('expenses', expenseData);
  }

  Future<void> updateExpense(int id, Map<String, dynamic> data) async {
    final db = await database;
    await db.update('expenses', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteExpense(int id) async {
    final db = await database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getExpenses({
    String? startDate,
    String? endDate,
    int? categoryId,
    String? searchQuery,
  }) async {
    final db = await database;
    String sql = '''
      SELECT e.*, ec.name as category_name, ec.icon as category_icon, ec.color as category_color
      FROM expenses e
      LEFT JOIN expense_categories ec ON e.category_id = ec.id
      WHERE 1=1
    ''';
    List<dynamic> args = [];

    if (startDate != null) {
      sql += ' AND e.expense_date >= ?';
      args.add(startDate);
    }
    if (endDate != null) {
      sql += ' AND e.expense_date <= ?';
      args.add(endDate);
    }
    if (categoryId != null) {
      sql += ' AND e.category_id = ?';
      args.add(categoryId);
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      sql += ' AND (e.title LIKE ? OR e.description LIKE ?)';
      args.add('%$searchQuery%');
      args.add('%$searchQuery%');
    }
    sql += ' ORDER BY e.expense_date DESC, e.id DESC';
    return await db.rawQuery(sql, args);
  }

  Future<Map<String, dynamic>?> getExpenseById(int id) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT e.*, ec.name as category_name, ec.icon as category_icon, ec.color as category_color
      FROM expenses e
      LEFT JOIN expense_categories ec ON e.category_id = ec.id
      WHERE e.id = ?
    ''', [id]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<double> getTotalExpenses({String? startDate, String? endDate}) async {
    final db = await database;
    String sql = 'SELECT COALESCE(SUM(amount), 0) as total FROM expenses WHERE 1=1';
    List<dynamic> args = [];
    if (startDate != null) {
      sql += ' AND expense_date >= ?';
      args.add(startDate);
    }
    if (endDate != null) {
      sql += ' AND expense_date <= ?';
      args.add(endDate);
    }
    final result = await db.rawQuery(sql, args);
    return (result.first['total'] as num).toDouble();
  }

  Future<Map<String, double>> getExpensesByCategory({String? startDate, String? endDate}) async {
    final db = await database;
    String sql = '''
      SELECT ec.name, COALESCE(SUM(e.amount), 0) as total
      FROM expense_categories ec
      LEFT JOIN expenses e ON ec.id = e.category_id
    ''';
    List<dynamic> args = [];
    bool hasDateFilter = false;
    if (startDate != null || endDate != null) {
      sql += ' AND ';
      List<String> conditions = [];
      if (startDate != null) {
        conditions.add('e.expense_date >= ?');
        args.add(startDate);
      }
      if (endDate != null) {
        conditions.add('e.expense_date <= ?');
        args.add(endDate);
      }
      sql += conditions.join(' AND ');
    }
    sql += ' GROUP BY ec.id ORDER BY total DESC';
    final result = await db.rawQuery(sql, args);
    Map<String, double> summary = {};
    for (var row in result) {
      summary[row['name'] as String] = (row['total'] as num).toDouble();
    }
    return summary;
  }

  Future<List<Map<String, dynamic>>> getExpensesByDateRange(String startDate, String endDate) async {
    return await getExpenses(startDate: startDate, endDate: endDate);
  }

  Future<double> getTotalExpensesForMonth(int year, int month) async {
    final startDate = '$year-${month.toString().padLeft(2, '0')}-01';
    final endDate = '$year-${month.toString().padLeft(2, '0')}-31';
    return await getTotalExpenses(startDate: startDate, endDate: endDate);
  }

  // ═══════════════════════════════════════════════════════════════
  //  NEW: WORKER METHODS
  // ═══════════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> getWorkers() async {
    final db = await database;
    return await db.query('workers', orderBy: 'name ASC');
  }

  Future<Map<String, dynamic>?> getWorkerById(int id) async {
    final db = await database;
    final result = await db.query('workers', where: 'id = ?', whereArgs: [id], limit: 1);
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> addWorker(Map<String, dynamic> workerData) async {
    final db = await database;
    return await db.insert('workers', workerData);
  }

  Future<void> updateWorker(int id, Map<String, dynamic> data) async {
    final db = await database;
    await db.update('workers', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteWorker(int id) async {
    final db = await database;
    await db.delete('workers', where: 'id = ?', whereArgs: [id]);
  }

  // ═══════════════════════════════════════════════════════════════
  //  NEW: WORKER SUIT TRACKING METHODS
  // ═══════════════════════════════════════════════════════════════
  Future<void> updateWorkerSuits(int workerId, int suitsToAdd) async {
    final db = await database;
    final worker = await getWorkerById(workerId);
    if (worker != null) {
      int currentTotal = (worker['total_suits'] as int?) ?? 0;
      await db.update('workers',
          {'total_suits': currentTotal + suitsToAdd},
          where: 'id = ?',
          whereArgs: [workerId]);
    }
  }

  Future<void> updateWorkerPaidSuits(int workerId, int suitsPaid) async {
    final db = await database;
    final worker = await getWorkerById(workerId);
    if (worker != null) {
      int currentPaid = (worker['paid_suits'] as int?) ?? 0;
      await db.update('workers',
          {'paid_suits': currentPaid + suitsPaid},
          where: 'id = ?',
          whereArgs: [workerId]);
    }
  }

  Future<List<Map<String, dynamic>>> getWorkersWithPendingSuits() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT *, (total_suits - paid_suits) as pending_suits
      FROM workers
      WHERE (total_suits - paid_suits) > 0
      ORDER BY name ASC
    ''');
  }

  // ═══════════════════════════════════════════════════════════════
  //  NEW: KARIGAR PAYMENT METHODS
  // ═══════════════════════════════════════════════════════════════
  Future<int> addKarigarPayment(Map<String, dynamic> paymentData) async {
    final db = await database;
    int workerId = paymentData['worker_id'] as int;
    int suitsPaid = paymentData['number_of_suits'] as int? ?? 0;

    // Calculate suit range for tracking which suits are paid
    final worker = await getWorkerById(workerId);
    int startSuit = 1;
    if (worker != null) {
      int paidSoFar = (worker['paid_suits'] as int?) ?? 0;
      startSuit = paidSoFar + 1;
    }
    int endSuit = startSuit + suitsPaid - 1;
    paymentData['suits_range'] = '$startSuit-$endSuit';

    int paymentId = await db.insert('karigar_payments', paymentData);

    // Update worker's paid suits count
    await updateWorkerPaidSuits(workerId, suitsPaid);

    return paymentId;
  }

  Future<void> updateKarigarPayment(int id, Map<String, dynamic> data) async {
    final db = await database;
    await db.update('karigar_payments', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteKarigarPayment(int id) async {
    final db = await database;
    final payment = await db.query('karigar_payments', where: 'id = ?', whereArgs: [id], limit: 1);
    if (payment.isNotEmpty) {
      int workerId = payment.first['worker_id'] as int;
      int suits = payment.first['number_of_suits'] as int? ?? 0;
      await db.delete('karigar_payments', where: 'id = ?', whereArgs: [id]);

      // Revert worker's paid suits count
      final worker = await getWorkerById(workerId);
      if (worker != null) {
        int currentPaid = (worker['paid_suits'] as int?) ?? 0;
        int newPaid = currentPaid - suits;
        if (newPaid < 0) newPaid = 0;
        await db.update('workers', {'paid_suits': newPaid}, where: 'id = ?', whereArgs: [workerId]);
      }
    }
  }

  Future<List<Map<String, dynamic>>> getKarigarPayments({int? workerId, String? status}) async {
    final db = await database;
    String sql = '''
      SELECT kp.*, w.name as worker_name, w.phone as worker_phone
      FROM karigar_payments kp
      LEFT JOIN workers w ON kp.worker_id = w.id
      WHERE 1=1
    ''';
    List<dynamic> args = [];
    if (workerId != null) {
      sql += ' AND kp.worker_id = ?';
      args.add(workerId);
    }
    if (status != null) {
      sql += ' AND kp.status = ?';
      args.add(status);
    }
    sql += ' ORDER BY kp.payment_date DESC, kp.id DESC';
    return await db.rawQuery(sql, args);
  }

  Future<Map<String, dynamic>?> getKarigarPaymentById(int id) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT kp.*, w.name as worker_name, w.phone as worker_phone
      FROM karigar_payments kp
      LEFT JOIN workers w ON kp.worker_id = w.id
      WHERE kp.id = ?
    ''', [id]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<double> getTotalKarigarPayments({String? startDate, String? endDate}) async {
    final db = await database;
    String sql = 'SELECT COALESCE(SUM(paid_amount), 0) as total FROM karigar_payments WHERE 1=1';
    List<dynamic> args = [];
    if (startDate != null) {
      sql += ' AND payment_date >= ?';
      args.add(startDate);
    }
    if (endDate != null) {
      sql += ' AND payment_date <= ?';
      args.add(endDate);
    }
    final result = await db.rawQuery(sql, args);
    return (result.first['total'] as num).toDouble();
  }

  Future<double> getPendingKarigarPayments() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(total_amount - paid_amount), 0) as total FROM karigar_payments WHERE status = ? OR status = ?',
      ['Unpaid', 'Partial'],
    );
    return (result.first['total'] as num).toDouble();
  }

  Future<int> getPendingKarigarPaymentsCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM karigar_payments WHERE status = ? OR status = ?',
      ['Unpaid', 'Partial'],
    );
    return result.first['cnt'] as int? ?? 0;
  }
}