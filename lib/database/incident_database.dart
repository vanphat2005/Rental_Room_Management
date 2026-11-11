// ============================================================
// File   : lib/database/incident_database.dart
// Mô tả  : Data Access Layer - IndexedDB cho Incident
//          Hỗ trợ soft-delete (archive) và filter theo status
// ============================================================

import 'package:idb_shim/idb.dart' as idb;
import 'package:idb_shim/idb_browser.dart';

import '../models/incident.dart';

class IncidentDatabase {
  IncidentDatabase._();
  static final IncidentDatabase instance = IncidentDatabase._();
  static idb.Database? _database;

  Future<idb.Database> get database async {
    if (_database != null) return _database!;

    final factory = idbFactoryBrowser;
    _database = await factory.open(
      'rental_incidents_web',
      version: 2, // tăng version để migrate thêm field is_archived
      onUpgradeNeeded: (idb.VersionChangeEvent event) {
        final db = event.database;
        if (!db.objectStoreNames.contains('incidents')) {
          final store = db.createObjectStore(
            'incidents',
            keyPath: 'id',
            autoIncrement: true,
          );
          store.createIndex('by_room', 'room_number', unique: false);
          store.createIndex('by_status', 'status', unique: false);
        }
      },
    );

    await _seedSampleData();
    return _database!;
  }

  Future<void> _seedSampleData() async {
    final list = await getAllIncidents(includeArchived: true);
    if (list.isEmpty) {
      final db = _database!;
      final txn = db.transaction('incidents', idb.idbModeReadWrite);
      final store = txn.objectStore('incidents');

      await store.add(
        const Incident(
          roomNumber: 'Phòng 101',
          title: 'Hỏng vòi nước nhà vệ sinh',
          description: 'Vòi nước bị rò rỉ liên tục, nước chảy tràn sàn.',
          reportDate: '12/10/2026',
          status: 'pending',
        ).toMap()..remove('id'),
      );

      await store.add(
        const Incident(
          roomNumber: 'Phòng 102',
          title: 'Mất nguồn ổ cắm điện bàn làm việc',
          description: 'Cắm sạc laptop không nhận điện.',
          reportDate: '10/10/2026',
          status: 'processing',
          resolutionNote: 'Đã cử thợ điện kiểm tra, đang chờ thay cầu chì.',
        ).toMap()..remove('id'),
      );

      await store.add(
        const Incident(
          roomNumber: 'Phòng 101',
          title: 'Bóng đèn ban công bị cháy',
          description: 'Đèn ban công tối không sáng vào ban đêm.',
          reportDate: '08/10/2026',
          status: 'resolved',
          resolutionNote: 'Đã thay bóng đèn LED mới ngày 09/10/2026.',
        ).toMap()..remove('id'),
      );

      await txn.completed;
    }
  }

  /// Lấy tất cả sự cố. Mặc định bỏ qua các sự cố đã lưu trữ.
  Future<List<Incident>> getAllIncidents({bool includeArchived = false}) async {
    final db = _database ?? await database;
    final txn = db.transaction('incidents', idb.idbModeReadOnly);
    final records = await txn.objectStore('incidents').getAll();
    await txn.completed;

    final incidents = records
        .map((r) => Incident.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();

    if (includeArchived) return incidents;
    return incidents.where((i) => !i.isArchived).toList();
  }

  /// Lấy sự cố theo phòng cụ thể.
  Future<List<Incident>> getIncidentsByRoom(String roomNumber) async {
    final all = await getAllIncidents();
    return all.where((i) => i.roomNumber == roomNumber).toList();
  }

  Future<int> insertIncident(Incident incident) async {
    final db = await database;
    final txn = db.transaction('incidents', idb.idbModeReadWrite);
    final data = incident.toMap()..remove('id');

    try {
      final key = await txn.objectStore('incidents').add(data);
      await txn.completed;
      return (key as num).toInt();
    } catch (_) {
      try { await txn.completed; } catch (_) {}
      rethrow;
    }
  }

  Future<int> updateIncident(Incident incident) async {
    if (incident.id == null) {
      throw ArgumentError('Incident ID không được để trống.');
    }

    final db = await database;
    final txn = db.transaction('incidents', idb.idbModeReadWrite);

    try {
      final store = txn.objectStore('incidents');
      final existing = await store.getObject(incident.id!);
      if (existing == null) {
        await txn.completed;
        return 0;
      }
      await store.put(incident.toMap());
      await txn.completed;
      return 1;
    } catch (_) {
      try { await txn.completed; } catch (_) {}
      rethrow;
    }
  }

  /// Xóa mềm: đánh dấu is_archived = true thay vì xóa hẳn.
  Future<int> archiveIncident(int id) async {
    final all = await getAllIncidents(includeArchived: true);
    final incident = all.where((i) => i.id == id).firstOrNull;
    if (incident == null) return 0;

    return updateIncident(incident.copyWith(isArchived: true));
  }

  /// Xóa cứng (chỉ dùng nội bộ / admin).
  Future<int> deleteIncident(int id) async {
    final db = await database;
    final txn = db.transaction('incidents', idb.idbModeReadWrite);

    try {
      final store = txn.objectStore('incidents');
      final existing = await store.getObject(id);
      if (existing == null) {
        await txn.completed;
        return 0;
      }
      await store.delete(id);
      await txn.completed;
      return 1;
    } catch (_) {
      try { await txn.completed; } catch (_) {}
      rethrow;
    }
  }

  Future<List<Incident>> searchIncidents(String keyword) async {
    final all = await getAllIncidents();
    final q = keyword.trim().toLowerCase();
    return all.where((i) =>
      i.roomNumber.toLowerCase().contains(q) ||
      i.title.toLowerCase().contains(q) ||
      i.description.toLowerCase().contains(q),
    ).toList();
  }
}
