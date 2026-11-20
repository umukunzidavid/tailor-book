import 'dart:async';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:shared_preferences/shared_preferences.dart';

import 'db.dart';

/// Backup to the tailor's OWN Google account.
///
/// The backup is one zip file (database + photos) stored in the hidden
/// "appDataFolder" of the user's Google Drive. It is private to this app, does
/// not show up in the Drive file list, and needs only the narrow
/// `drive.appdata` permission. Signing in with the same Google account on a
/// new phone lets the tailor restore everything.
class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  static const _fileName = 'tailorbook_backup.zip';

  final GoogleSignIn _gs =
      GoogleSignIn(scopes: [drive.DriveApi.driveAppdataScope]);

  /// Last error or status message, shown in Settings.
  final ValueNotifier<String?> lastError = ValueNotifier(null);

  Future<GoogleSignInAccount?> currentAccount() async =>
      _gs.currentUser ?? await _gs.signInSilently();

  Future<GoogleSignInAccount?> signIn() => _gs.signIn();

  Future<void> signOut() => _gs.signOut();

  Future<DateTime?> lastBackupTime() async {
    final s = (await SharedPreferences.getInstance()).getString('lastBackup');
    return s == null ? null : DateTime.tryParse(s);
  }

  Future<T> _withApi<T>(Future<T> Function(drive.DriveApi api) fn) async {
    final client = await _gs.authenticatedClient();
    if (client == null) {
      throw Exception('Not signed in to Google.');
    }
    try {
      return await fn(drive.DriveApi(client));
    } finally {
      client.close();
    }
  }

  Future<drive.File?> _find(drive.DriveApi api) async {
    final res = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_fileName'",
      orderBy: 'modifiedTime desc',
      pageSize: 1,
      $fields: 'files(id,name,modifiedTime,size)',
    );
    final files = res.files ?? [];
    return files.isEmpty ? null : files.first;
  }

  Future<void> backupNow() async {
    final Uint8List bytes = await AppDb.instance.exportZip();
    await _withApi((api) async {
      final existing = await _find(api);
      final media = drive.Media(Stream.value(bytes), bytes.length);
      if (existing == null) {
        await api.files.create(
          drive.File()
            ..name = _fileName
            ..parents = ['appDataFolder'],
          uploadMedia: media,
        );
      } else {
        await api.files.update(drive.File(), existing.id!, uploadMedia: media);
      }
    });
    final p = await SharedPreferences.getInstance();
    await p.setString('lastBackup', DateTime.now().toIso8601String());
    await p.setBool('dirty', false);
    lastError.value = null;
  }

  /// Returns false when no backup exists in this Google account yet.
  Future<bool> restore() async {
    final bytes = await _withApi<Uint8List?>((api) async {
      final f = await _find(api);
      if (f == null) return null;
      final media = await api.files.get(
        f.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;
      final b = BytesBuilder();
      await for (final chunk in media.stream) {
        b.add(chunk);
      }
      return b.toBytes();
    });
    if (bytes == null) return false;
    await AppDb.instance.importZip(bytes);
    final p = await SharedPreferences.getInstance();
    await p.setString('lastBackup', DateTime.now().toIso8601String());
    await p.setBool('dirty', false);
    return true;
  }
}

/// Backs up automatically: a little after any change, when the phone gets
/// internet again, and every 15 minutes as a retry. Nothing happens while
/// offline or signed out - the data simply stays "dirty" until it can upload.
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  Timer? _debounce;
  bool _running = false;

  void start() {
    AppDb.instance.revision.addListener(_onChange);
    Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) maybeBackup();
    });
    Timer.periodic(const Duration(minutes: 15), (_) => maybeBackup());
    maybeBackup();
  }

  Future<void> _onChange() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('dirty', true);
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 20), maybeBackup);
  }

  Future<void> maybeBackup() async {
    if (_running) return;
    _running = true;
    try {
      final p = await SharedPreferences.getInstance();
      if (!(p.getBool('dirty') ?? false)) return;
      final net = await Connectivity().checkConnectivity();
      if (net.contains(ConnectivityResult.none)) return;
      if (await BackupService.instance.currentAccount() == null) return;
      await BackupService.instance.backupNow();
    } catch (e) {
      BackupService.instance.lastError.value = e.toString();
    } finally {
      _running = false;
    }
  }
}
