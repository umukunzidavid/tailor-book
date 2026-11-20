import 'package:flutter/material.dart';

import '../db.dart';
import '../l10n.dart';
import '../models.dart';
import '../widgets.dart';

/// Create or edit a client. Pops with the saved [Client].
class ClientFormScreen extends StatefulWidget {
  final Client? client;
  const ClientFormScreen({super.key, this.client});

  @override
  State<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends State<ClientFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _notes;
  String? _photo;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.client;
    _name = TextEditingController(text: c?.name ?? '');
    _phone = TextEditingController(text: c?.phone ?? '');
    _email = TextEditingController(text: c?.email ?? '');
    _notes = TextEditingController(text: c?.notes ?? '');
    _photo = c?.photo;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final old = widget.client;
    final c = Client(
      id: old?.id,
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      photo: _photo,
      notes: _notes.text.trim(),
    );
    if (old == null) {
      c.id = await AppDb.instance.insertClient(c);
    } else {
      await AppDb.instance.updateClient(c);
      if (old.photo != null && old.photo != c.photo) {
        await AppDb.instance.deletePhoto(old.photo);
      }
    }
    if (mounted) Navigator.pop(context, c);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.client == null ? t('cf.new') : t('cf.edit')),
        actions: [
          TextButton(onPressed: _saving ? null : _save, child: Text(t('save'))),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Center(
            child: PhotoField(
              label: t('cf.photo'),
              value: _photo,
              size: 110,
              placeholder: Icons.person_add_alt,
              onChanged: (v) => setState(() => _photo = v),
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: t('cf.name')),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? t('cf.nameReq') : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: t('cf.phone'),
              hintText: '07XX XXX XXX',
              prefixIcon: const Icon(Icons.phone),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: t('cf.email'),
              prefixIcon: const Icon(Icons.email_outlined),
            ),
            validator: (v) {
              // A way to contact the client is required: phone or email.
              if (_phone.text.trim().isEmpty && (v == null || v.trim().isEmpty)) {
                return t('cf.contactReq');
              }
              final e = v?.trim() ?? '';
              if (e.isNotEmpty && !e.contains('@')) return t('cf.badEmail');
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _notes,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: t('cf.notes'),
              alignLabelWithHint: true,
            ),
          ),
        ]),
      ),
    );
  }
}
