// ============================================================
// Author : Le Van Nguyen - CE181235
// Feature: Invoice Management
// Module : Invoice Database Layer (IndexedDB via idb_shim)
// ============================================================

import 'package:idb_shim/idb.dart' as idb;
import 'package:idb_shim/idb_browser.dart';

import '../models/invoice.dart';

/// Lớp truy cập cơ sở dữ liệu IndexedDB cho module Hóa đơn.
/// Áp dụng Singleton Pattern nhằm duy trì duy nhất 1 kết nối database trong suốt vòng đời ứng dụng.
class InvoiceDatabase {
  InvoiceDatabase._();

  static final InvoiceDatabase instance = InvoiceDatabase._();

  static idb.Database? _database;

  /// Getter khởi tạo hoặc lấy kết nối Database sẵn có.
  Future<idb.Database> get database async {
    if (_database != null) return _database!;

    final factory = idbFactoryBrowser;

    _database = await factory.open(
      'rental_invoices_web',
      version: 1,
      onUpgradeNeeded: (idb.VersionChangeEvent event) {
        final db = event.database;

        // Tạo ObjectStore 'invoices' với khóa chính 'id' tự tăng
        if (!db.objectStoreNames.contains('invoices')) {
          db.createObjectStore(
            'invoices',
            keyPath: 'id',
            autoIncrement: true,
          );
        }
      },
    );

    // Tự động nạp dữ liệu mẫu ban đầu nếu cơ sở dữ liệu còn trống
    await _seedSampleData();

    return _database!;
  }

  /// Khởi tạo dữ liệu mẫu cho lần chạy đầu tiên.
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

  /// [UC-9] Lấy toàn bộ danh sách hóa đơn trong hệ thống (dành cho Landlord).
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

  /// [UC-10] Thêm hóa đơn mới vào cơ sở dữ liệu.
  Future<int> insertInvoice(Invoice invoice) async {
    final db = _database ?? await database;
    final txn = db.transaction('invoices', idb.idbModeReadWrite);
    final data = invoice.toMap()..remove('id'); // Xóa id để IndexedDB tự sinh auto-increment

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

  /// [UC-11] Cập nhật hóa đơn hiện có dựa theo khóa chính id.
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

  /// [UC-12] Xóa hóa đơn theo khóa chính id.
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

  /// [UC-22] Lấy danh sách hóa đơn theo số phòng (dành cho Tenant).
  /// Chuẩn hóa chuỗi số phòng bằng Regex để so khớp chính xác (VD: "101" vs "Phòng 101").
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
