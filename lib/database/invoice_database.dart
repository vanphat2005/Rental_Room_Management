// lib/database/invoice_database.dart

import 'package:idb_shim/idb.dart' as idb;
import 'package:idb_shim/idb_browser.dart';

import '../models/invoice.dart';

class InvoiceDatabase {
  InvoiceDatabase._();

  static final InvoiceDatabase instance = InvoiceDatabase._();

  static idb.Database? _database;

  Future<idb.Database> get database async {
    if (_database != null) return _database!;

    final factory = idbFactoryBrowser;

    _database = await factory.open(
      'rental_invoices_web',
      version: 1,
      onUpgradeNeeded: (idb.VersionChangeEvent event) {
        final db = event.database;

        if (!db.objectStoreNames.contains('invoices')) {
          db.createObjectStore(
            'invoices',
            keyPath: 'id',
            autoIncrement: true,
          );
        }
      },
    );

    await _seedSampleData();

    return _database!;
  }


  Future<void> _seedSampleData() async {
    final list = await getAllInvoices();
    if (list.isEmpty) {
      final db = _database!;
      final txn = db.transaction('invoices', idb.idbModeReadWrite);
      final store = txn.objectStore('invoices');

      await store.add(const Invoice(
        roomNumber: 'Phòng 101',
        monthYear: 'Tháng 10/2026',
        roomPrice: 2500000,
        electricityCost: 400000,
        waterCost: 150000,
        otherCost: 0,
        status: 'unpaid',
        note: 'Tiền phòng và điện nước kỳ tháng 10/2026',
      ).toMap()..remove('id'));

      await store.add(const Invoice(
        roomNumber: 'Phòng 102',
        monthYear: 'Tháng 10/2026',
        roomPrice: 2800000,
        electricityCost: 480000,
        waterCost: 160000,
        otherCost: 50000,
        status: 'paid',
        note: 'Đã thanh toán chuyển khoản ngày 05/10/2026',
      ).toMap()..remove('id'));

      await store.add(const Invoice(
        roomNumber: 'Phòng 201',
        monthYear: 'Tháng 10/2026',
        roomPrice: 3000000,
        electricityCost: 350000,
        waterCost: 140000,
        otherCost: 0,
        status: 'unpaid',
        note: 'Hạn đóng tiền trước ngày 15/10/2026',
      ).toMap()..remove('id'));

      await txn.completed;
    }
  }

  Future<List<Invoice>> getAllInvoices() async {
    final db = _database ?? await database;
    final txn = db.transaction('invoices', idb.idbModeReadOnly);
    final records = await txn.objectStore('invoices').getAll();
    await txn.completed;

    return records.map((record) {
      return Invoice.fromMap(
        Map<String, dynamic>.from(record as Map),
      );
    }).toList();
  }

  // Thêm hóa đơn mới
  Future<int> insertInvoice(Invoice invoice) async {
    final db = _database ?? await database;
    final txn = db.transaction('invoices', idb.idbModeReadWrite);
    final data = invoice.toMap()..remove('id');

    try {
      final key = await txn.objectStore('invoices').add(data);
      await txn.completed;
      return (key as num).toInt();
    } catch (_) {
      try {
        await txn.completed;
      } catch (_) {}
      rethrow;
    }
  }

  // Cập nhật hóa đơn
  Future<int> updateInvoice(Invoice invoice) async {
    if (invoice.id == null) {
      throw ArgumentError('Invoice ID không được để trống khi cập nhật.');
    }
    final db = _database ?? await database;
    final txn = db.transaction('invoices', idb.idbModeReadWrite);

    try {
      final store = txn.objectStore('invoices');
      final existing = await store.getObject(invoice.id!);
      if (existing == null) {
        await txn.completed;
        return 0;
      }
      await store.put(invoice.toMap());
      await txn.completed;
      return 1;
    } catch (_) {
      try {
        await txn.completed;
      } catch (_) {}
      rethrow;
    }
  }

  // Xóa hóa đơn
  Future<int> deleteInvoice(int id) async {
    final db = _database ?? await database;
    final txn = db.transaction('invoices', idb.idbModeReadWrite);

    try {
      final store = txn.objectStore('invoices');
      final existing = await store.getObject(id);
      if (existing == null) {
        await txn.completed;
        return 0;
      }
      await store.delete(id);
      await txn.completed;
      return 1;
    } catch (_) {
      try {
        await txn.completed;
      } catch (_) {}
      rethrow;
    }
  }

  // Lấy danh sách hóa đơn theo số phòng (Tenant)
  Future<List<Invoice>> getInvoicesByRoom(String roomNumber) async {
    final allInvoices = await getAllInvoices();
    final cleanRoom = roomNumber
        .replaceFirst(RegExp(r'^phòng\s*', caseSensitive: false), '')
        .trim()
        .toLowerCase();

    return allInvoices.where((inv) {
      final cleanInvRoom = inv.roomNumber
          .replaceFirst(RegExp(r'^phòng\s*', caseSensitive: false), '')
          .trim()
          .toLowerCase();

      return cleanInvRoom == cleanRoom ||
          inv.roomNumber.trim().toLowerCase() ==
              roomNumber.trim().toLowerCase();
    }).toList();
  }
}
