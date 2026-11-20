import 'package:flutter/material.dart';

import '../db.dart';
import '../l10n.dart';
import '../models.dart';
import '../settings.dart';
import '../widgets.dart';
import 'client_form_screen.dart';

/// Create or edit an order. Pass [client] to pre-select the client.
class OrderFormScreen extends StatefulWidget {
  final TailorOrder? order;
  final Client? client;
  const OrderFormScreen({super.key, this.order, this.client});

  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  final _form = GlobalKey<FormState>();
  Client? _client;
  late DateTime _received;
  late DateTime _deadline;
  String? _cloth;
  String? _modelPhoto;
  String _status = Status.inProgress;
  int _sameDay = 0; // other unfinished orders already due on the chosen deadline
  bool _saving = false;

  final _model = TextEditingController();
  final _details = TextEditingController();
  final _price = TextEditingController();
  final _deposit = TextEditingController();
  final Map<String, TextEditingController> _m = {};

  @override
  void initState() {
    super.initState();
    for (final k in kMeasurementFields) {
      _m[k] = TextEditingController();
    }
    final o = widget.order;
    if (o == null) {
      _client = widget.client;
      _received = today();
      _deadline = addDays(today(), 7);
    } else {
      _received = o.received;
      _deadline = o.deadline;
      _cloth = o.clothPhoto;
      _modelPhoto = o.modelPhoto;
      _status = o.status;
      _model.text = o.model;
      _details.text = o.details;
      _price.text = o.price == 0 ? '' : '${o.price}';
      _deposit.text = o.deposit == 0 ? '' : '${o.deposit}';
      _setMeasurements(o.measurements);
      AppDb.instance.client(o.clientId).then((c) {
        if (mounted) setState(() => _client = c);
      });
    }
    _refreshSameDay();
  }

  @override
  void dispose() {
    _model.dispose();
    _details.dispose();
    _price.dispose();
    _deposit.dispose();
    for (final c in _m.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _setMeasurements(Map<String, String> values) {
    for (final e in values.entries) {
      _m.putIfAbsent(e.key, () => TextEditingController()).text = e.value;
    }
  }

  Future<void> _refreshSameDay() async {
    final n = await AppDb.instance.countDueOn(_deadline, excludeOrderId: widget.order?.id);
    if (mounted) setState(() => _sameDay = n);
  }

  Future<void> _pickDate({required bool deadline}) async {
    final initial = deadline ? _deadline : _received;
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    setState(() {
      if (deadline) {
        _deadline = d;
      } else {
        _received = d;
        if (_deadline.isBefore(_received)) _deadline = addDays(_received, 7);
      }
    });
    _refreshSameDay();
  }

  Future<void> _chooseClient() async {
    final c = await showModalBottomSheet<Client>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ClientPicker(),
    );
    if (c != null) setState(() => _client = c);
  }

  Future<void> _copyMeasurements() async {
    if (_client == null) return;
    final last = await AppDb.instance
        .lastMeasurements(_client!.id!, excludeOrderId: widget.order?.id);
    if (!mounted) return;
    if (last == null) {
      snack(context, t('of.noEarlier'));
      return;
    }
    setState(() => _setMeasurements(last));
    snack(context, t('of.copied'));
  }

  Future<void> _addCustom() async {
    final ctl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('of.addTitle')),
        content: TextField(
          controller: ctl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: t('of.addName')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
              child: Text(t('add'))),
        ],
      ),
    );
    ctl.dispose();
    if (name == null || name.isEmpty) return;
    setState(() => _m.putIfAbsent(name, () => TextEditingController()));
  }

  int _money(TextEditingController c) =>
      int.tryParse(c.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_client == null) {
      snack(context, t('of.chooseFirst'));
      return;
    }
    setState(() => _saving = true);
    final old = widget.order;
    final measurements = {
      for (final e in _m.entries)
        if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
    };
    final o = TailorOrder(
      id: old?.id,
      clientId: _client!.id!,
      received: _received,
      deadline: _deadline,
      clothPhoto: _cloth,
      modelPhoto: _modelPhoto,
      model: _model.text.trim(),
      measurements: measurements,
      details: _details.text.trim(),
      price: _money(_price),
      deposit: _money(_deposit),
      status: _status,
    );
    if (old == null) {
      await AppDb.instance.insertOrder(o);
    } else {
      await AppDb.instance.updateOrder(o);
      if (old.clothPhoto != null && old.clothPhoto != o.clothPhoto) {
        await AppDb.instance.deletePhoto(old.clothPhoto);
      }
      if (old.modelPhoto != null && old.modelPhoto != o.modelPhoto) {
        await AppDb.instance.deletePhoto(old.modelPhoto);
      }
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final threshold = Settings.instance.busyThreshold;
    final wouldBeBusy = _sameDay + 1 >= threshold;
    final standard = kMeasurementFields.where(_m.containsKey).toList();
    final custom = _m.keys.where((k) => !kMeasurementFields.contains(k)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.order == null ? t('of.new') : t('of.edit')),
        actions: [
          TextButton(onPressed: _saving ? null : _save, child: Text(t('save'))),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          // ---- client
          Card(
            child: ListTile(
              leading: PhotoThumb(file: _client?.photo, circle: true, size: 44),
              title: Text(_client?.name ?? t('of.chooseClient')),
              subtitle: _client == null
                  ? Text(t('required'))
                  : Text(_client!.phone.isNotEmpty ? _client!.phone : _client!.email),
              trailing: const Icon(Icons.arrow_drop_down),
              onTap: _chooseClient,
            ),
          ),
          const SizedBox(height: 14),

          // ---- dates
          Row(children: [
            Expanded(
              child: _DateBox(
                label: t('of.received'),
                value: fmtDate(_received),
                onTap: () => _pickDate(deadline: false),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DateBox(
                label: t('of.deadline'),
                value: fmtDate(_deadline),
                onTap: () => _pickDate(deadline: true),
              ),
            ),
          ]),
          if (_sameDay > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                Icon(
                  wouldBeBusy ? Icons.warning_amber_rounded : Icons.info_outline,
                  size: 18,
                  color: wouldBeBusy ? Colors.orange.shade800 : null,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    wouldBeBusy
                        ? t('of.busyWarn', {'n': _sameDay})
                        : t('of.sameDay', {'n': _sameDay}),
                    style: TextStyle(color: wouldBeBusy ? Colors.orange.shade800 : null),
                  ),
                ),
              ]),
            ),
          const SizedBox(height: 18),

          // ---- photos
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            PhotoField(
              label: t('of.cloth'),
              value: _cloth,
              placeholder: Icons.checkroom,
              onChanged: (v) => setState(() => _cloth = v),
            ),
            PhotoField(
              label: t('of.modelPhoto'),
              value: _modelPhoto,
              placeholder: Icons.style,
              onChanged: (v) => setState(() => _modelPhoto = v),
            ),
          ]),
          const SizedBox(height: 18),

          TextFormField(
            controller: _model,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: t('of.model'),
              hintText: t('of.modelHint'),
            ),
          ),
          const SizedBox(height: 14),

          // ---- measurements
          Card(
            child: ExpansionTile(
              initiallyExpanded: widget.order != null,
              title: Text(t('of.measure')),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(spacing: 8, children: [
                    if (_client != null)
                      ActionChip(
                        avatar: const Icon(Icons.copy, size: 16),
                        label: Text(t('of.copyLast')),
                        onPressed: _copyMeasurements,
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 16),
                      label: Text(t('of.addMeasure')),
                      onPressed: _addCustom,
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 3.2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  children: [
                    for (final k in [...standard, ...custom])
                      TextFormField(
                        controller: _m[k],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: measureLabel(k)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _details,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: t('of.details'),
              hintText: t('of.detailsHint'),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),

          // ---- money + status
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _price,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: t('of.price')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _deposit,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: t('of.deposit')),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: InputDecoration(labelText: t('of.status')),
            items: [
              for (final s in Status.all)
                DropdownMenuItem(value: s, child: Text(Status.label(s))),
            ],
            onChanged: (v) => setState(() => _status = v ?? _status),
          ),
          const SizedBox(height: 30),
        ]),
      ),
    );
  }
}

class _DateBox extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _DateBox({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(value),
      ),
    );
  }
}

/// Bottom sheet: search existing clients or add a new one.
class _ClientPicker extends StatefulWidget {
  const _ClientPicker();

  @override
  State<_ClientPicker> createState() => _ClientPickerState();
}

class _ClientPickerState extends State<_ClientPicker> {
  final _search = TextEditingController();
  List<Client> _clients = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final c = await AppDb.instance.clients(_search.text);
    if (mounted) setState(() => _clients = c);
  }

  Future<void> _addNew() async {
    final c = await Navigator.of(context).push<Client>(
      MaterialPageRoute(builder: (_) => const ClientFormScreen()),
    );
    if (c != null && mounted) Navigator.pop(context, c);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              onChanged: (_) => _load(),
              decoration: InputDecoration(
                hintText: t('of.searchClients'),
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_add)),
            title: Text(t('fab.newClient')),
            onTap: _addNew,
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: _clients.length,
              itemBuilder: (_, i) {
                final c = _clients[i];
                return ListTile(
                  leading: PhotoThumb(file: c.photo, circle: true, size: 44),
                  title: Text(c.name),
                  subtitle: Text(c.phone.isNotEmpty ? c.phone : c.email),
                  onTap: () => Navigator.pop(context, c),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
