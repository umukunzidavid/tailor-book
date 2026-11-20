import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../backup.dart';
import '../l10n.dart';
import '../notifier.dart';
import '../settings.dart';
import '../widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  GoogleSignInAccount? _account;
  DateTime? _lastBackup;
  bool _busy = false;
  final _backup = BackupService.instance;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    GoogleSignInAccount? acc;
    try {
      acc = await _backup.currentAccount();
    } catch (_) {}
    final last = await _backup.lastBackupTime();
    if (mounted) {
      setState(() {
        _account = acc;
        _lastBackup = last;
      });
    }
  }

  /// [errorKey] is the translation key of the message shown if the job fails.
  Future<void> _run(String errorKey, Future<void> Function() job) async {
    setState(() => _busy = true);
    try {
      await job();
    } catch (e) {
      if (mounted) snack(context, t(errorKey));
      _backup.lastError.value = e.toString();
    } finally {
      if (mounted) setState(() => _busy = false);
      _refresh();
    }
  }

  Future<void> _signIn() => _run('st.errSignIn', () async {
        final acc = await _backup.signIn();
        if (acc != null) await SyncService.instance.maybeBackup();
      });

  Future<void> _backupNow() => _run('st.errBackup', () async {
        await _backup.backupNow();
        if (mounted) snack(context, t('st.backupSaved'));
      });

  Future<void> _restore() async {
    final ok = await confirm(
      context,
      t('st.restoreTitle'),
      t('st.restoreBody'),
      yes: t('st.restore'),
    );
    if (!ok) return;
    await _run('st.errRestore', () async {
      final found = await _backup.restore();
      if (mounted) {
        snack(context, found ? t('st.restoreDone') : t('st.noBackupFound'));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = Settings.instance;
    final l = L10n.instance;
    return ListView(padding: const EdgeInsets.all(16), children: [
      // ---- language
      Text(t('st.language'), style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 4, children: [
        for (final e in L10n.languages.entries)
          ChoiceChip(
            label: Text(e.value),
            selected: l.lang == e.key,
            onSelected: (_) => l.setLang(e.key),
          ),
      ]),
      const SizedBox(height: 24),

      // ---- backup
      Text(t('st.backup'), style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 4),
      Text(t('st.backupInfo')),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (_account == null) ...[
              Text(t('st.notSigned')),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _busy ? null : _signIn,
                icon: const Icon(Icons.login),
                label: Text(t('st.signIn')),
              ),
            ] else ...[
              Row(children: [
                const Icon(Icons.cloud_done_outlined),
                const SizedBox(width: 8),
                Expanded(child: Text(_account!.email)),
              ]),
              const SizedBox(height: 4),
              Text(_lastBackup == null
                  ? t('st.noBackup')
                  : t('st.lastBackup', {'when': fmtDateTime(_lastBackup!)})),
              ValueListenableBuilder<String?>(
                valueListenable: _backup.lastError,
                builder: (_, err, __) => err == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          t('st.failed'),
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _backupNow,
                  icon: const Icon(Icons.backup),
                  label: Text(t('st.backupNow')),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _restore,
                  icon: const Icon(Icons.settings_backup_restore),
                  label: Text(t('st.restore')),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          await _backup.signOut();
                          _refresh();
                        },
                  child: Text(t('st.signOut')),
                ),
              ]),
            ],
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
          ]),
        ),
      ),
      const SizedBox(height: 24),

      // ---- reminders
      Text(t('st.reminders'), style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      ListenableBuilder(
        listenable: s,
        builder: (_, __) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('st.busyDef', {'n': s.busyThreshold})),
          Slider(
            min: 2,
            max: 10,
            divisions: 8,
            value: s.busyThreshold.toDouble(),
            label: '${s.busyThreshold}',
            onChanged: (v) => s.setBusyThreshold(v.round()),
          ),
          Text(t('st.remindAt', {'h': s.reminderHour.toString().padLeft(2, '0')})),
          Slider(
            min: 5,
            max: 20,
            divisions: 15,
            value: s.reminderHour.toDouble(),
            label: '${s.reminderHour}:00',
            onChanged: (v) => s.setReminderHour(v.round()),
          ),
        ]),
      ),
      Text(t('st.remindInfo')),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        icon: const Icon(Icons.notifications_active_outlined),
        label: Text(t('st.allowTest')),
        onPressed: () async {
          final ok = await Notifier.instance.requestPermission();
          if (!mounted) return;
          if (ok) {
            await Notifier.instance.showTest();
          } else {
            snack(context, t('st.blocked'));
          }
        },
      ),
      const SizedBox(height: 40),
    ]);
  }
}
