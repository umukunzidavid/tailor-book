import 'dart:convert';

import 'l10n.dart';

String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseYmd(String s) {
  final p = s.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

DateTime today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

int daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day)
        .difference(DateTime.utc(a.year, a.month, a.day))
        .inDays;

/// Standard body measurements (cm). The tailor can add custom ones per order.
const List<String> kMeasurementFields = [
  'Neck',
  'Shoulder',
  'Chest',
  'Waist',
  'Hip',
  'Back length',
  'Sleeve length',
  'Bicep',
  'Wrist',
  'Top length',
  'Thigh',
  'Knee',
  'Ankle',
  'Inseam',
  'Outseam',
  'Height',
];

class Status {
  static const inProgress = 'in_progress';
  static const ready = 'ready';
  static const delivered = 'delivered';
  static const all = [inProgress, ready, delivered];

  static String label(String s) => t('status.$s');
}

class Client {
  int? id;
  String name;
  String phone;
  String email;
  String? photo; // file name inside the app's photos folder
  String notes;

  Client({
    this.id,
    required this.name,
    this.phone = '',
    this.email = '',
    this.photo,
    this.notes = '',
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'photo': photo,
        'notes': notes,
      };

  factory Client.fromMap(Map<String, Object?> m) => Client(
        id: m['id'] as int?,
        name: m['name'] as String,
        phone: (m['phone'] as String?) ?? '',
        email: (m['email'] as String?) ?? '',
        photo: m['photo'] as String?,
        notes: (m['notes'] as String?) ?? '',
      );
}

class TailorOrder {
  int? id;
  int clientId;
  DateTime received;
  DateTime deadline;
  String? clothPhoto; // the cloth the client brought
  String? modelPhoto; // the style / finished model to sew
  String model; // description of the model
  Map<String, String> measurements;
  String details; // extra notes
  int price; // RWF
  int deposit; // RWF paid in advance
  String status;

  // Filled by joins, not stored in the orders table.
  String clientName;
  String clientPhone;
  String? clientPhoto;

  TailorOrder({
    this.id,
    required this.clientId,
    required this.received,
    required this.deadline,
    this.clothPhoto,
    this.modelPhoto,
    this.model = '',
    Map<String, String>? measurements,
    this.details = '',
    this.price = 0,
    this.deposit = 0,
    this.status = Status.inProgress,
    this.clientName = '',
    this.clientPhone = '',
    this.clientPhoto,
  }) : measurements = measurements ?? {};

  bool get isActive => status != Status.delivered;
  int get balance => price - deposit;

  Map<String, Object?> toMap() => {
        'id': id,
        'client_id': clientId,
        'received': ymd(received),
        'deadline': ymd(deadline),
        'cloth_photo': clothPhoto,
        'model_photo': modelPhoto,
        'model': model,
        'measurements': jsonEncode(measurements),
        'details': details,
        'price': price,
        'deposit': deposit,
        'status': status,
      };

  factory TailorOrder.fromMap(Map<String, Object?> m) {
    Map<String, String> meas = {};
    try {
      final raw = jsonDecode((m['measurements'] as String?) ?? '{}') as Map;
      meas = raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {}
    return TailorOrder(
      id: m['id'] as int?,
      clientId: m['client_id'] as int,
      received: parseYmd(m['received'] as String),
      deadline: parseYmd(m['deadline'] as String),
      clothPhoto: m['cloth_photo'] as String?,
      modelPhoto: m['model_photo'] as String?,
      model: (m['model'] as String?) ?? '',
      measurements: meas,
      details: (m['details'] as String?) ?? '',
      price: (m['price'] as int?) ?? 0,
      deposit: (m['deposit'] as int?) ?? 0,
      status: (m['status'] as String?) ?? Status.inProgress,
      clientName: (m['client_name'] as String?) ?? '',
      clientPhone: (m['client_phone'] as String?) ?? '',
      clientPhoto: m['client_photo'] as String?,
    );
  }
}
