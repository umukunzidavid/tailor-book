import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'db.dart';
import 'l10n.dart';
import 'models.dart';
import 'settings.dart';

/// Schedules local reminders (they work with no internet).
///
/// For every date that has unfinished orders:
///   normal day: 2 days before, 1 day before, on the day
///   busy day (>= threshold orders): 5, 3, 2, 1 days before and on the day,
///   so the tailor can plan the workload early.
/// One day after a missed deadline an "overdue" reminder is shown.
class Notifier {
  Notifier._();
  static final Notifier instance = Notifier._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'deadlines',
      'Order deadlines',
      channelDescription: 'Reminders about orders that are due soon',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  Future<void> init() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Africa/Kigali'));
    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ));
    _ready = true;
  }

  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  Future<void> showTest() => _plugin.show(
        0,
        t('n.testTitle'),
        t('n.testBody'),
        _details,
      );

  /// Cancels everything and schedules again from the current data.
  Future<void> reschedule() async {
    if (!_ready) return;
    await _plugin.cancelAll();

    final byDate = await AppDb.instance.activeDueByDate();
    final hour = Settings.instance.reminderHour;
    final threshold = Settings.instance.busyThreshold;
    final now = tz.TZDateTime.now(tz.local);

    for (final entry in byDate.entries) {
      final due = parseYmd(entry.key);
      final names = entry.value;
      final busy = names.length >= threshold;
      final dayNum = DateTime.utc(due.year, due.month, due.day)
          .difference(DateTime.utc(2020))
          .inDays;

      // offsets = days before the deadline (negative = after it)
      final offsets = busy ? [5, 3, 2, 1, 0, -1] : [2, 1, 0, -1];

      for (var i = 0; i < offsets.length; i++) {
        final off = offsets[i];
        final day = addDays(due, -off);
        final when = tz.TZDateTime(tz.local, day.year, day.month, day.day, hour);
        if (!when.isAfter(now)) continue;

        final n = names.length;
        final orders = n == 1 ? t('n.one') : t('n.many', {'n': n});
        final whenText = off > 1
            ? t('n.when.days', {'d': off})
            : off == 1
                ? t('n.when.tomorrow')
                : t('n.when.today');
        final title = off < 0
            ? t('n.overdue', {'orders': orders})
            : busy
                ? t('n.busy', {'orders': orders, 'when': whenText})
                : t('n.title', {'orders': orders, 'when': whenText});
        final body = names.length > 4
            ? t('n.more', {
                'names': names.take(4).join(', '),
                'n': names.length - 4,
              })
            : names.join(', ');

        await _plugin.zonedSchedule(
          dayNum * 8 + i,
          title,
          body,
          when,
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    }
  }
}
