import 'package:flutter/material.dart';

import '../db.dart';
import '../l10n.dart';
import '../models.dart';
import '../widgets.dart';
import 'client_detail_screen.dart';
import 'order_form_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  TailorOrder? _order;

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
    final o = await AppDb.instance.order(widget.orderId);
    if (!mounted) return;
    if (o == null) {
      Navigator.of(context).pop(); // deleted
      return;
    }
    setState(() => _order = o);
  }

  Future<void> _edit() async {
    final o = _order!;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => OrderFormScreen(order: o),
    ));
  }

  Future<void> _delete() async {
    final o = _order!;
    final ok = await confirm(context, t('od.delTitle'), t('od.delBody'));
    if (ok) await AppDb.instance.deleteOrder(o);
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    if (o == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final text = Theme.of(context).textTheme;
    final diff = daysBetween(today(), o.deadline);

    return Scaffold(
      appBar: AppBar(
        title: Text(o.model.isEmpty ? t('od.title') : o.model),
        actions: [
          IconButton(icon: const Icon(Icons.edit), onPressed: _edit),
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // client
        Card(
          child: ListTile(
            leading: PhotoThumb(file: o.clientPhoto, circle: true, size: 48),
            title: Text(o.clientName),
            subtitle: Text(o.clientPhone),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (o.clientPhone.isNotEmpty)
                IconButton(icon: const Icon(Icons.call), onPressed: () => callNumber(o.clientPhone)),
              if (o.clientPhone.isNotEmpty)
                IconButton(icon: const Icon(Icons.chat), onPressed: () => openWhatsApp(o.clientPhone)),
            ]),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ClientDetailScreen(clientId: o.clientId),
            )),
          ),
        ),
        const SizedBox(height: 12),

        // status
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            for (final s in Status.all)
              ButtonSegment(value: s, label: Text(Status.label(s), textAlign: TextAlign.center)),
          ],
          selected: {o.status},
          onSelectionChanged: (v) => AppDb.instance.setStatus(o.id!, v.first),
        ),
        const SizedBox(height: 16),

        // dates
        Row(children: [
          Expanded(child: _Fact(t('od.received'), fmtDate(o.received))),
          Expanded(
            child: _Fact(
              t('of.deadline'),
              fmtDate(o.deadline),
              sub: !o.isActive
                  ? null
                  : diff < 0
                      ? t('od.overdueBy', {'n': -diff})
                      : diff == 0
                          ? t('od.dueToday')
                          : t('od.inDays', {'n': diff}),
              subColor: diff <= 1 && o.isActive ? Theme.of(context).colorScheme.error : null,
            ),
          ),
        ]),
        const SizedBox(height: 16),

        // photos
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _Photo(t('of.cloth'), o.clothPhoto, Icons.checkroom),
          _Photo(t('of.modelPhoto'), o.modelPhoto, Icons.style),
        ]),
        const SizedBox(height: 16),

        if (o.model.isNotEmpty) ...[
          Text(t('od.model'), style: text.titleSmall),
          Text(o.model),
          const SizedBox(height: 16),
        ],

        // measurements
        Text(t('od.measure'), style: text.titleSmall),
        const SizedBox(height: 6),
        if (o.measurements.isEmpty)
          Text(t('od.none'))
        else
          Card(
            child: Column(children: [
              for (final e in o.measurements.entries)
                ListTile(
                  dense: true,
                  title: Text(measureLabel(e.key)),
                  trailing: Text(e.value, style: text.titleMedium),
                ),
            ]),
          ),
        const SizedBox(height: 16),

        if (o.details.isNotEmpty) ...[
          Text(t('of.details'), style: text.titleSmall),
          Text(o.details),
          const SizedBox(height: 16),
        ],

        // money
        if (o.price > 0 || o.deposit > 0)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                _Row(t('od.price'), fmtMoney(o.price)),
                _Row(t('of.deposit'), fmtMoney(o.deposit)),
                const Divider(),
                _Row(t('od.balance'), fmtMoney(o.balance), bold: true),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _Fact extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color? subColor;
  const _Fact(this.label, this.value, {this.sub, this.subColor});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      Text(value, style: Theme.of(context).textTheme.titleMedium),
      if (sub != null) Text(sub!, style: TextStyle(color: subColor, fontWeight: FontWeight.w600)),
    ]);
  }
}

class _Photo extends StatelessWidget {
  final String label;
  final String? file;
  final IconData icon;
  const _Photo(this.label, this.file, this.icon);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      GestureDetector(
        onTap: () => viewPhoto(context, file),
        child: PhotoThumb(file: file, size: 140, placeholder: icon),
      ),
      const SizedBox(height: 4),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _Row(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = bold ? const TextStyle(fontWeight: FontWeight.bold) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: style),
        Text(value, style: style),
      ]),
    );
  }
}
