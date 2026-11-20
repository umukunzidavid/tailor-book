import 'package:flutter/material.dart';

import '../db.dart';
import '../l10n.dart';
import '../models.dart';
import '../widgets.dart';
import 'client_form_screen.dart';
import 'order_detail_screen.dart';
import 'order_form_screen.dart';

class ClientDetailScreen extends StatefulWidget {
  final int clientId;
  const ClientDetailScreen({super.key, required this.clientId});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  Client? _client;
  List<TailorOrder> _orders = [];

  @override
  void initState() {
    super.initState();
    AppDb.instance.revision.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    AppDb.instance.revision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final c = await AppDb.instance.client(widget.clientId);
    final o = await AppDb.instance.orders(filter: 'all', clientId: widget.clientId);
    if (!mounted) return;
    if (c == null) {
      Navigator.of(context).pop(); // deleted
      return;
    }
    setState(() {
      _client = c;
      _orders = o;
    });
  }

  Future<void> _delete() async {
    final c = _client!;
    final ok = await confirm(
      context,
      t('cd.delTitle', {'name': c.name}),
      t('cd.delBody', {'n': _orders.length}),
    );
    if (ok) await AppDb.instance.deleteClient(c.id!);
  }

  @override
  Widget build(BuildContext context) {
    final c = _client;
    if (c == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text(c.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ClientFormScreen(client: c),
            )),
          ),
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(t('fab.newOrder')),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OrderFormScreen(client: c),
        )),
      ),
      body: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            GestureDetector(
              onTap: () => viewPhoto(context, c.photo),
              child: PhotoThumb(file: c.photo, size: 88, circle: true),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (c.phone.isNotEmpty) Text(c.phone, style: Theme.of(context).textTheme.titleMedium),
                if (c.email.isNotEmpty) Text(c.email),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  if (c.phone.isNotEmpty)
                    ActionChip(
                      avatar: const Icon(Icons.call, size: 18),
                      label: Text(t('call')),
                      onPressed: () => callNumber(c.phone),
                    ),
                  if (c.phone.isNotEmpty)
                    ActionChip(
                      avatar: const Icon(Icons.chat, size: 18),
                      label: Text(t('whatsapp')),
                      onPressed: () => openWhatsApp(c.phone),
                    ),
                ]),
              ]),
            ),
          ]),
        ),
        if (c.notes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(c.notes),
          ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(t('cd.orders', {'n': _orders.length}),
              style: Theme.of(context).textTheme.titleMedium),
        ),
        if (_orders.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(t('cd.noOrders')),
          ),
        for (final o in _orders)
          ListTile(
            leading: PhotoThumb(file: o.clothPhoto ?? o.modelPhoto, placeholder: Icons.checkroom),
            title: Text(o.model.isEmpty ? t('cd.order') : o.model),
            subtitle: Text(t('cd.due', {
              'date': fmtShort(o.deadline),
              'status': Status.label(o.status),
            })),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => OrderDetailScreen(orderId: o.id!),
            )),
          ),
      ]),
    );
  }
}
