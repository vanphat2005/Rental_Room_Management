import 'package:idb_shim/idb.dart' as idb;
import 'package:idb_shim/idb_browser.dart';

import '../models/account.dart';

class AccountDatabase {
  AccountDatabase._();

  static final AccountDatabase instance = AccountDatabase._();
  static idb.Database? _database;

  Future<idb.Database> get database async {
    if (_database != null) return _database!;
    final factory = idbFactoryBrowser;
    _database = await factory.open(
      'rental_accounts_web',
      version: 1,
      onUpgradeNeeded: (idb.VersionChangeEvent event) {
        final db = event.database;
        if (!db.objectStoreNames.contains('accounts')) {
          final store = db.createObjectStore(
            'accounts',
            keyPath: 'id',
            autoIncrement: true,
          );
          store.createIndex('by_username', 'username', unique: true);
        }
      },
    );
    await _seedSampleData();
    return _database!;
  }

  Future<void> _seedSampleData() async {
    final list = await getAllAccounts();
    if (list.isEmpty) {
      final db = _database!;
      final txn = db.transaction('accounts', idb.idbModeReadWrite);
      final store = txn.objectStore('accounts');

      await store.add(
        const Account(
          username: 'landlord',
          password: '123',
          fullName: 'Chủ Trọ Ha Minh Man',
          role: 'landlord',
          phone: '0901234567',
          email: 'landlord@gmail.com',
          status: 'active',
        ).toMap()..remove('id'),
      );

      await store.add(
        const Account(
          username: 'tenant101',
          password: '123',
          fullName: 'Ho Van Phat (Phòng 101)',
          role: 'tenant',
          phone: '0987654321',
          email: 'tenant101@gmail.com',
          status: 'active',
        ).toMap()..remove('id'),
      );

      await txn.completed;
    }
  }

  Future<List<Account>> getAllAccounts() async {
    final db = await database;
    final txn = db.transaction('accounts', idb.idbModeReadOnly);
    final records = await txn.objectStore('accounts').getAll();
    await txn.completed;

    return records.map((record) {
      return Account.fromMap(Map<String, dynamic>.from(record as Map));
    }).toList();
  }

  Future<Account?> login(
    String username,
    String password, {
    String? role,
  }) async {
    final normalizedUsername = username.trim();
    if (normalizedUsername.isEmpty || password.isEmpty) {
      return null;
    }

    final accounts = await getAllAccounts();
    for (final account in accounts) {
      final matchesUsername =
          account.username.toLowerCase() == normalizedUsername.toLowerCase();
      final matchesPassword = account.password == password;
      final matchesRole = role == null || account.role == role;
      final isActive = account.status == 'active';

      if (matchesUsername && matchesPassword && matchesRole && isActive) {
        return account;
      }
    }

    return null;
  }

  Future<Account?> loginWithRole(String username, String password, String role) {
    return login(username, password, role: role);
  }

  Future<int> insertAccount(Account account) async {
    final db = await database;
    final txn = db.transaction('accounts', idb.idbModeReadWrite);
    final data = account.toMap()..remove('id');
    try {
      final key = await txn.objectStore('accounts').add(data);
      await txn.completed;
      return (key as num).toInt();
    } catch (_) {
      try {
        await txn.completed;
      } catch (_) {}
      rethrow;
    }
  }

  Future<int> updateAccount(Account account) async {
    if (account.id == null) throw ArgumentError('Account ID không hợp lệ.');
    final db = await database;
    final txn = db.transaction('accounts', idb.idbModeReadWrite);
    try {
      final store = txn.objectStore('accounts');
      await store.put(account.toMap());
      await txn.completed;
      return 1;
    } catch (_) {
      try {
        await txn.completed;
      } catch (_) {}
      rethrow;
    }
  }

  Future<int> deleteAccount(int id) async {
    final db = await database;
    final txn = db.transaction('accounts', idb.idbModeReadWrite);
    try {
      await txn.objectStore('accounts').delete(id);
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
