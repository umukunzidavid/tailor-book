import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'db.dart';
import 'l10n.dart';

String fmtMoney(int n) => '${NumberFormat('#,###').format(n)} RWF';

/// Rwandan numbers: 07XXXXXXXX -> 2507XXXXXXXX (needed for WhatsApp links).
String normalizePhone(String raw) {
  var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('0') && digits.length == 10) {
    digits = '250${digits.substring(1)}';
  }
  return digits;
}

Future<void> callNumber(String phone) =>
    launchUrl(Uri(scheme: 'tel', path: phone));

Future<void> openWhatsApp(String phone) => launchUrl(
      Uri.parse('https://wa.me/${normalizePhone(phone)}'),
      mode: LaunchMode.externalApplication,
    );

void snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Shows a stored photo (or a placeholder icon).
class PhotoThumb extends StatelessWidget {
  final String? file;
  final double size;
  final IconData placeholder;
  final bool circle;

  const PhotoThumb({
    super.key,
    required this.file,
    this.size = 56,
    this.placeholder = Icons.person,
    this.circle = false,
  });

  @override
  Widget build(BuildContext context) {
    final f = AppDb.instance.photoFile(file);
    final scheme = Theme.of(context).colorScheme;
    final child = f == null
        ? Container(
            width: size,
            height: size,
            color: scheme.surfaceContainerHighest,
            child: Icon(placeholder, color: scheme.onSurfaceVariant, size: size * 0.5),
          )
        : Image.file(f,
            width: size,
            height: size,
            fit: BoxFit.cover,
            cacheWidth: (size * 3).round());
    return ClipRRect(
      borderRadius: BorderRadius.circular(circle ? size : 10),
      child: child,
    );
  }
}

/// Tap to take a photo or pick one from the gallery.
class PhotoField extends StatelessWidget {
  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;
  final double size;
  final IconData placeholder;

  const PhotoField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.size = 120,
    this.placeholder = Icons.add_a_photo_outlined,
  });

  Future<void> _pick(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: Text(t('photo.take')),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: Text(t('photo.gallery')),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          if (value != null)
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(t('photo.remove')),
              onTap: () {
                Navigator.pop(ctx);
                onChanged(null);
              },
            ),
        ]),
      ),
    );
    if (source == null) return;
    // Resized + compressed so the local database and backups stay small.
    final x = await ImagePicker()
        .pickImage(source: source, maxWidth: 1280, imageQuality: 70);
    if (x == null) return;
    onChanged(await AppDb.instance.savePhoto(x.path));
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      InkWell(
        onTap: () => _pick(context),
        borderRadius: BorderRadius.circular(10),
        child: PhotoThumb(file: value, size: size, placeholder: placeholder),
      ),
      const SizedBox(height: 4),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}

/// Full screen, pinch-to-zoom viewer.
void viewPhoto(BuildContext context, String? file) {
  final f = AppDb.instance.photoFile(file);
  if (f == null) return;
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Center(child: InteractiveViewer(child: Image.file(File(f.path)))),
    ),
  ));
}

Future<bool> confirm(BuildContext context, String title, String message,
    {String? yes}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false), child: Text(t('cancel'))),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true), child: Text(yes ?? t('delete'))),
      ],
    ),
  );
  return r ?? false;
}
