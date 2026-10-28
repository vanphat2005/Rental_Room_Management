
import 'package:idb_shim/idb.dart' as idb;
import 'package:idb_shim/idb_browser.dart';

import '../models/room.dart';

class RoomDatabase {
  RoomDatabase._();

  static final RoomDatabase instance = RoomDatabase._();

  static idb.Database? _database;

  Future<idb.Database> get database async {
    if (_database != null) return _database!;

    final factory = idbFactoryBrowser;

    _database = await factory.open(
      'rental_room_web',
      version: 1,
      onUpgradeNeeded: (idb.VersionChangeEvent event) {
        final db = event.database;

        if (!db.objectStoreNames.contains('rooms')) {
          final store = db.createObjectStore(
            'rooms',
            keyPath: 'id',
            autoIncrement: true,
          );

          store.createIndex(
            'by_room_number',
            'room_number',
            unique: true,
          );
        }
      },
    );

    return _database!;
  }


  Future<List<Room>> getAllRooms() async {
    final db = await database;
    final txn = db.transaction(
      'rooms',
      idb.idbModeReadOnly,
    );

    final records = await txn.objectStore('rooms').getAll();
    await txn.completed;

    return records.map((record) {
      return Room.fromMap(
        Map<String, dynamic>.from(record as Map),
      );
    }).toList();
  }

 
  Future<int> insertRoom(Room room) async {
    final db = await database;
    final txn = db.transaction(
      'rooms',
      idb.idbModeReadWrite,
    );

    final data = room.toMap()..remove('id');

    try {
      final key = await txn.objectStore('rooms').add(data);
      await txn.completed;

      return (key as num).toInt();
    } catch (_) {
      try {
        await txn.completed;
      } catch (_) {}

      rethrow;
    }
  }

  
  Future<int> updateRoom(Room room) async {
    if (room.id == null) {
      throw ArgumentError('Room ID không được để trống.');
    }

    final db = await database;
    final txn = db.transaction(
      'rooms',
      idb.idbModeReadWrite,
    );

    try {
      final store = txn.objectStore('rooms');

      final existing = await store.getObject(room.id!);

      if (existing == null) {
        await txn.completed;
        return 0;
      }

      await store.put(room.toMap());
      await txn.completed;

      return 1;
    } catch (_) {
      try {
        await txn.completed;
      } catch (_) {}

      rethrow;
    }
  }


  Future<int> deleteRoom(int id) async {
    final db = await database;
    final txn = db.transaction(
      'rooms',
      idb.idbModeReadWrite,
    );

    try {
      final store = txn.objectStore('rooms');
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

  Future<void> updateStatusByRoomNumber(
    String roomNumber,
    String newStatus,
  ) async {
    final rooms = await getAllRooms();
    final normalizedTarget = roomNumber
        .trim()
        .replaceFirst(RegExp(r'^phòng\s*', caseSensitive: false), '')
        .trim();

    for (final room in rooms) {
      final normalizedRoom = room.roomNumber
          .trim()
          .replaceFirst(RegExp(r'^phòng\s*', caseSensitive: false), '')
          .trim();

      final matchesRoom = room.roomNumber == roomNumber ||
          normalizedRoom == normalizedTarget ||
          'Phòng $normalizedRoom' == roomNumber ||
          'Phòng $normalizedTarget' == room.roomNumber;

      if (matchesRoom && room.status != newStatus) {
        await updateRoom(
          Room(
            id: room.id,
            roomNumber: room.roomNumber,
            rentPrice: room.rentPrice,
            area: room.area,
            status: newStatus,
            description: room.description,
          ),
        );
      }
    }
  }

  Future<List<Room>> searchRooms(String keyword) async {
    final rooms = await getAllRooms();
    final query = keyword.trim().toLowerCase();

    return rooms.where((room) {
      return room.roomNumber.toLowerCase().contains(query);
    }).toList();
  }
}