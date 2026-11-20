import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// Local SQLite database. Everything works offline; photos are stored as files
/// in the app folder and referenced by file name only, so a backup can be
/// restored on a different phone.
class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();

  /// Bumped after every change. Screens, reminders and backup listen to it.
  final ValueNotifier<int> revision = ValueNotifier(0);

  late Directory _docs;
  Database? _db;

  String get photosDir => p.join(_docs.path, 'photos');
  String get _dbPath => p.join(_docs.path, 'tailor.db');

  // While a backup/restore briefly closes the database, queries wait here.
  Future<Database> get _d async {
    while (_db == null) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    return _db!;
  }

  Future<void> init() async {
    _docs = await getApplicationDocumentsDirectory();
    await Directory(photosDir).create(recursive: true);
    await _open();
  }

  Future<void> _open() async {
    _db = await openDatabase(
      _dbPath,
      version: 1,
      onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
      onCreate: (d, v) async {
        await d.execute('''
          CREATE TABLE clients(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            phone TEXT NOT NULL DEFAULT '',
            email TEXT NOT NULL DEFAULT '',
            photo TEXT,
            notes TEXT NOT NULL DEFAULT '',
            created_at TEXT NOT NULL
          )''');
        await d.execute('''
          CREATE TABLE orders(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            client_id INTEGER NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
            received TEXT NOT NULL,
            deadline TEXT NOT NULL,
            cloth_photo TEXT,
            model_photo TEXT,
            model TEXT NOT NULL DEFAULT '',
            measurements TEXT NOT NULL DEFAULT '{}',
            details TEXT NOT NULL DEFAULT '',
            price INTEGER NOT NULL DEFAULT 0,
            deposit INTEGER NOT NULL DEFAULT 0,
            status TEXT NOT NULL DEFAULT 'in_progress',
            created_at TEXT NOT NULL
          )''');
        await d.execute('CREATE INDEX idx_orders_deadline ON orders(deadline)');
        await d.execute('CREATE INDEX idx_orders_client ON orders(client_id)');
      },
    );
  }

  void _changed() => revision.value++;

  // ---------------------------------------------------------------- photos

  /// Copies a picked image into the app folder and returns its file name.
  Future<String> savePhoto(String sourcePath) async {
    final name = '${DateTime.now().microsecondsSinceEpoch}.jpg';
    await File(sourcePath).copy(p.join(photosDir, name));
    return name;
  }

  File? photoFile(String? name) {
    if (name == null || name.isEmpty) return null;
    final f = File(p.join(photosDir, name));
    return f.existsSync() ? f : null;
  }

  Future<void> deletePhoto(String? name) async {
    final f = photoFile(name);
    if (f != null) {
      try {
        await f.delete();
      } catch (_) {}
    }
  }

  // --------------------------------------------------------------- clients

  Future<List<Client>> clients([String query = '']) async {
    final d = await _d;
    final q = query.trim();
    List<Map<String, Object?>> rows;
    if (q.isEmpty) {
      rows = await d.query('clients', orderBy: 'name COLLATE NOCASE');
    } else {
      final like = '%$q%';
      final likeNoSpace = '%${q.replaceAll(' ', '')}%';
      rows = await d.query(
        'clients',
        where:
            "name LIKE ? OR phone LIKE ? OR REPLACE(phone,' ','') LIKE ? OR email LIKE ?",
        whereArgs: [like, like, likeNoSpace, like],
        orderBy: 'name COLLATE NOCASE',
      );
    }
    return rows.map(Client.fromMap).toList();
  }

  Future<Client?> client(int id) async {
    final d = await _d;
    final rows = await d.query('clients', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Client.fromMap(rows.first);
  }

  Future<int> insertClient(Client c) async {
    final d = await _d;
    final id = await d.insert('clients', {
      ...c.toMap(),
      'created_at': DateTime.now().toIso8601String(),
    });
    _changed();
    return id;
  }

  Future<void> updateClient(Client c) async {
    final d = await _d;
    await d.update('clients', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
    _changed();
  }

  /// Deletes the client, all their orders and the photos that belonged to them.
  Future<void> deleteClient(int id) async {
    final d = await _d;
    final c = await client(id);
    final rows = await d.query('orders',
        columns: ['cloth_photo', 'model_photo'],
        where: 'client_id = ?',
        whereArgs: [id]);
    await d.delete('clients', where: 'id = ?', whereArgs: [id]);
    for (final r in rows) {
      await deletePhoto(r['cloth_photo'] as String?);
      await deletePhoto(r['model_photo'] as String?);
    }
    await deletePhoto(c?.photo);
    _changed();
  }

  // ---------------------------------------------------------------- orders

  static const _select =
      'SELECT o.*, c.name AS client_name, c.phone AS client_phone, c.photo AS client_photo '
      'FROM orders o JOIN clients c ON c.id = o.client_id';

  /// [filter] is 'active', 'done' or 'all'.
  Future<List<TailorOrder>> orders({
    String query = '',
    String filter = 'active',
    int? clientId,
  }) async {
    final d = await _d;
    final where = <String>[];
    final args = <Object?>[];
    if (filter == 'active') where.add("o.status != 'delivered'");
    if (filter == 'done') where.add("o.status = 'delivered'");
    if (clientId != null) {
      where.add('o.client_id = ?');
      args.add(clientId);
    }
    final q = query.trim();
    if (q.isNotEmpty) {
      where.add(
          "(c.name LIKE ? OR c.phone LIKE ? OR REPLACE(c.phone,' ','') LIKE ? OR o.model LIKE ? OR o.details LIKE ?)");
      final like = '%$q%';
      args.addAll([like, like, '%${q.replaceAll(' ', '')}%', like, like]);
    }
    final order =
        filter == 'done' ? 'o.deadline DESC, o.id DESC' : 'o.deadline ASC, o.id ASC';
    final sql =
        '$_select ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} ORDER BY $order';
    final rows = await d.rawQuery(sql, args);
    return rows.map(TailorOrder.fromMap).toList();
  }

  Future<TailorOrder?> order(int id) async {
    final d = await _d;
    final rows = await d.rawQuery('$_select WHERE o.id = ?', [id]);
    return rows.isEmpty ? null : TailorOrder.fromMap(rows.first);
  }

  Future<int> insertOrder(TailorOrder o) async {
    final d = await _d;
    final id = await d.insert('orders', {
      ...o.toMap(),
      'created_at': DateTime.now().toIso8601String(),
    });
    _changed();
    return id;
  }

  Future<void> updateOrder(TailorOrder o) async {
    final d = await _d;
    await d.update('orders', o.toMap(), where: 'id = ?', whereArgs: [o.id]);
    _changed();
  }

  Future<void> setStatus(int id, String status) async {
    final d = await _d;
    await d.update('orders', {'status': status}, where: 'id = ?', whereArgs: [id]);
    _changed();
  }

  Future<void> deleteOrder(TailorOrder o) async {
    final d = await _d;
    await d.delete('orders', where: 'id = ?', whereArgs: [o.id]);
    await deletePhoto(o.clothPhoto);
    await deletePhoto(o.modelPhoto);
    _changed();
  }

  /// Names of clients with unfinished orders, grouped by deadline (yyyy-MM-dd).
  Future<Map<String, List<String>>> activeDueByDate() async {
    final d = await _d;
    final rows = await d.rawQuery(
        "SELECT o.deadline AS deadline, c.name AS name FROM orders o "
        "JOIN clients c ON c.id = o.client_id "
        "WHERE o.status != 'delivered' ORDER BY o.deadline, o.id");
    final out = <String, List<String>>{};
    for (final r in rows) {
      out.putIfAbsent(r['deadline'] as String, () => []).add(r['name'] as String);
    }
    return out;
  }

  Future<int> countDueOn(DateTime day, {int? excludeOrderId}) async {
    final d = await _d;
    final rows = await d.rawQuery(
      "SELECT COUNT(*) AS n FROM orders WHERE deadline = ? AND status != 'delivered' "
      "AND id != ?",
      [ymd(day), excludeOrderId ?? -1],
    );
    return (rows.first['n'] as int?) ?? 0;
  }

  /// Measurements from the client's most recent order that has any.
  Future<Map<String, String>?> lastMeasurements(int clientId, {int? excludeOrderId}) async {
    final d = await _d;
    final rows = await d.query('orders',
        where: "client_id = ? AND measurements != '{}' AND id != ?",
        whereArgs: [clientId, excludeOrderId ?? -1],
        orderBy: 'id DESC',
        limit: 1);
    if (rows.isEmpty) return null;
    return TailorOrder.fromMap(rows.first).measurements;
  }

  // ------------------------------------------------------ backup / restore

  /// Packs the database and all photos into one zip file.
  Future<Uint8List> exportZip() async {
    await _db?.close();
    _db = null;
    try {
      final archive = Archive();
      final dbBytes = await File(_dbPath).readAsBytes();
      archive.addFile(ArchiveFile('tailor.db', dbBytes.length, dbBytes));
      await for (final e in Directory(photosDir).list()) {
        if (e is File) {
          final b = await e.readAsBytes();
          archive.addFile(ArchiveFile('photos/${p.basename(e.path)}', b.length, b));
        }
      }
      final out = ZipEncoder().encode(archive);
      return Uint8List.fromList(out!);
    } finally {
      await _open();
    }
  }

  /// Replaces ALL local data with the contents of a backup zip.
  Future<void> importZip(Uint8List bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    final dbFile = archive.findFile('tailor.db');
    if (dbFile == null) {
      throw Exception('This backup file is not valid.');
    }
    await _db?.close();
    _db = null;
    try {
      for (final suffix in ['-wal', '-shm', '-journal']) {
        final f = File('$_dbPath$suffix');
        if (f.existsSync()) f.deleteSync();
      }
      await File(_dbPath).writeAsBytes(dbFile.content as List<int>);
      for (final f in Directory(photosDir).listSync()) {
        if (f is File) f.deleteSync();
      }
      for (final f in archive.files) {
        if (f.isFile && f.name.startsWith('photos/')) {
          await File(p.join(photosDir, p.basename(f.name)))
              .writeAsBytes(f.content as List<int>);
        }
      }
    } finally {
      await _open();
    }
    _changed();
  }
}
