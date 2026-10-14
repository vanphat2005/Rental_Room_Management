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
      version: 1,
      onUpgradeNeeded: (idb.VersionChangeEvent event) {
        final db = event.database;

        if (!db.objectStoreNames.contains('incidents')) {
          db.createObjectStore(
            'incidents',
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
    final list = await getAllIncidents();
    if (list.isEmpty) {
      final db = _database!;
      final txn = db.transaction('incidents', idb.idbModeReadWrite);
      final store = txn.objectStore('incidents');

      await store.add(
        const Incident(
          roomNumber: 'P101',
          title: 'Hỏng vòi nước nhà vệ sinh',
          description: 'Vòi nước bị rò rỉ liên tục, nước chảy tràn sàn.',
          reportDate: '12/10/2026',
          status: 'pending',
          resolutionNote: '',
        ).toMap()..remove('id'),
      );

      await store.add(
        const Incident(
          roomNumber: 'P102',
          title: 'Mất nguồn ổ cắm điện bàn làm việc',
          description: 'Cắm sạc laptop không nhận điện.',
          reportDate: '10/10/2026',
          status: 'processing',
          resolutionNote: 'Đã cử thợ điện kiểm tra, đang chờ thay cầu chì.',
        ).toMap()..remove('id'),
      );

      await store.add(
        const Incident(
          roomNumber: 'P201',
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

  Future<List<Incident>> getAllIncidents() async {
    final db = _database ?? await database;
    final txn = db.transaction('incidents', idb.idbModeReadOnly);
    final records = await txn.objectStore('incidents').getAll();
    await txn.completed;

    return records.map((record) {
      return Incident.fromMap(
        Map<String, dynamic>.from(record as Map),
      );
    }).toList();
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
      try {
        await txn.completed;
      } catch (_) {}
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
      try {
        await txn.completed;
      } catch (_) {}
      rethrow;
    }
  }

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
      try {
        await txn.completed;
      } catch (_) {}
      rethrow;
    }
  }
}
