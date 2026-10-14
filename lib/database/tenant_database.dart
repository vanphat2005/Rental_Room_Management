// ============================================================
// File   : lib/database/tenant_database.dart
// Author : Long
// Mô tả  : Xử lý CRUD dữ liệu Người thuê phòng (Tenant)
//          sử dụng IndexedDB thông qua idb_shim (web)
// ============================================================

// BẮT ĐẦU CODE - Long

import 'package:idb_shim/idb.dart' as idb;
import 'package:idb_shim/idb_browser.dart';

import '../models/tenant.dart';

class TenantDatabase {
  // Singleton: chỉ tồn tại 1 instance duy nhất trong toàn app
  TenantDatabase._();

  static final TenantDatabase instance = TenantDatabase._();

  static idb.Database? _database;

  // Khởi tạo / lấy kết nối database (lazy initialization)
  Future<idb.Database> get database async {
    if (_database != null) return _database!;

    final factory = idbFactoryBrowser;

    _database = await factory.open(
      'rental_tenants_web', // Tên IndexedDB riêng cho Tenant
      version: 1,
      onUpgradeNeeded: (idb.VersionChangeEvent event) {
        final db = event.database;

        if (!db.objectStoreNames.contains('tenants')) {
          final store = db.createObjectStore(
            'tenants',
            keyPath: 'id',
            autoIncrement: true,
          );

          // Index theo username để tìm nhanh theo tài khoản
          store.createIndex('by_username', 'username', unique: true);

          // Index theo số phòng để lọc tenant theo phòng
          store.createIndex('by_room', 'room_number', unique: false);
        }
      },
    );

    // Tạo dữ liệu mẫu nếu database còn trống
    await _seedSampleData();

    return _database!;
  }

  // Seed dữ liệu mẫu ban đầu
  Future<void> _seedSampleData() async {
    final list = await getAllTenants();
    if (list.isEmpty) {
      final db = _database!;
      final txn = db.transaction('tenants', idb.idbModeReadWrite);
      final store = txn.objectStore('tenants');

      await store.add(
        const Tenant(
          username: 'tenant101',
          fullName: 'Ho Van Phat',
          cccd: '079204012345',
          phone: '0987654321',
          email: 'tenant101@gmail.com',
          address: '123 Đường Lê Lợi, Q.1, TP.HCM',
          emergencyContact: 'Nguyen Thi Lan (Mẹ)',
          emergencyPhone: '0901111222',
          roomNumber: 'Phòng 101',
          startDate: '01/10/2026',
          endDate: '01/10/2027',
          status: 'active',
          note: 'Thuê phòng dài hạn, thanh toán đúng hạn',
        ).toMap()
          ..remove('id'),
      );

      await store.add(
        const Tenant(
          username: 'tenant102',
          fullName: 'Tran Minh Khoa',
          cccd: '079204067890',
          phone: '0912345678',
          email: 'khoa102@gmail.com',
          address: '45 Đường Nguyễn Huệ, Q.3, TP.HCM',
          emergencyContact: 'Tran Van Binh (Bố)',
          emergencyPhone: '0903333444',
          roomNumber: 'Phòng 102',
          startDate: '15/09/2026',
          endDate: '15/09/2027',
          status: 'active',
          note: '',
        ).toMap()
          ..remove('id'),
      );

      await txn.completed;
    }
  }

  // Lấy toàn bộ danh sách người thuê
  Future<List<Tenant>> getAllTenants() async {
    final db = _database ?? await database;
    final txn = db.transaction('tenants', idb.idbModeReadOnly);
    final records = await txn.objectStore('tenants').getAll();
    await txn.completed;

    return records.map((record) {
      return Tenant.fromMap(Map<String, dynamic>.from(record as Map));
    }).toList();
  }

  // Thêm người thuê mới
  Future<int> insertTenant(Tenant tenant) async {
    final db = await database;
    final txn = db.transaction('tenants', idb.idbModeReadWrite);
    final data = tenant.toMap()..remove('id');

    try {
      final key = await txn.objectStore('tenants').add(data);
      await txn.completed;
      return (key as num).toInt();
    } catch (_) {
      try {
        await txn.completed;
      } catch (_) {}
      rethrow;
    }
  }

  // Cập nhật thông tin người thuê
  Future<int> updateTenant(Tenant tenant) async {
    if (tenant.id == null) {
      throw ArgumentError('Tenant ID không được để trống.');
    }

    final db = await database;
    final txn = db.transaction('tenants', idb.idbModeReadWrite);

    try {
      final store = txn.objectStore('tenants');
      final existing = await store.getObject(tenant.id!);

      if (existing == null) {
        await txn.completed;
        return 0;
      }

      await store.put(tenant.toMap());
      await txn.completed;
      return 1;
    } catch (_) {
      try {
        await txn.completed;
      } catch (_) {}
      rethrow;
    }
  }

  // Xóa người thuê theo ID
  Future<int> deleteTenant(int id) async {
    final db = await database;
    final txn = db.transaction('tenants', idb.idbModeReadWrite);

    try {
      final store = txn.objectStore('tenants');
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

  // Tìm kiếm người thuê theo tên, username, CCCD hoặc số phòng
  Future<List<Tenant>> searchTenants(String keyword) async {
    final tenants = await getAllTenants();
    final query = keyword.trim().toLowerCase();

    return tenants.where((t) {
      return t.fullName.toLowerCase().contains(query) ||
          t.username.toLowerCase().contains(query) ||
          t.cccd.contains(query) ||
          t.roomNumber.toLowerCase().contains(query) ||
          t.phone.contains(query);
    }).toList();
  }
}

// KẾT THÚC CODE - Long
