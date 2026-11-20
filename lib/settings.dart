import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings extends ChangeNotifier {
  Settings._();
  static final Settings instance = Settings._();

  /// A date with this many (or more) unfinished orders counts as a busy day.
  int busyThreshold = 3;

  /// Hour of the day (0-23) when reminders are shown.
  int reminderHour = 8;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    busyThreshold = p.getInt('busyThreshold') ?? 3;
    reminderHour = p.getInt('reminderHour') ?? 8;
  }

  Future<void> setBusyThreshold(int v) async {
    busyThreshold = v;
    (await SharedPreferences.getInstance()).setInt('busyThreshold', v);
    notifyListeners();
  }

  Future<void> setReminderHour(int v) async {
    reminderHour = v;
    (await SharedPreferences.getInstance()).setInt('reminderHour', v);
    notifyListeners();
  }
}
