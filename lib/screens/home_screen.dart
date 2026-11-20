import 'package:flutter/material.dart';

import '../db.dart';
import '../l10n.dart';
import '../models.dart';
import '../settings.dart';
import '../widgets.dart';
import 'client_detail_screen.dart';
import 'client_form_screen.dart';
import 'order_detail_screen.dart';
import 'order_form_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  /// Remembered so that changing the language (which rebuilds the app)
  /// keeps the tailor on the same tab.
  static int lastTab = 0;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = HomeScreen.lastTab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _tab,
          children: const [OrdersTab(), ClientsTab(), SettingsScreen()],
        ),
      ),
      floatingActionButton: _tab == 2
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: Text(_tab == 0 ? t('fab.newOrder') : t('fab.newClient')),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    _tab == 0 ? const OrderFormScreen() : const ClientFormScreen(),
              )),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          HomeScreen.lastTab = i;
          setState(() => _tab = i);
        },
        destinations: [
          NavigationDestination(icon: const Icon(Icons.content_cut), label: t('nav.orders')),
          NavigationDestination(icon: const Icon(Icons.people), label: t('nav.clients')),
          NavigationDestination(icon: const Icon(Icons.settings), label: t('nav.settings')),
        ],
      ),
    );
  }
}

// ======================================================================
// Orders tab
// ======================================================================

class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  final _search = TextEditingController();
  String _filter = 'active';
  List<TailorOrder> _orders = [];
  Map<String, List<String>> _due = {};

  @override
  void initState() {
    super.initState();
    AppDb.instance.revision.addListener(_load);
    Settings.instance.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    AppDb.instance.revision.removeListener(_load);
    Settings.instance.removeListener(_load);
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final o = await AppDb.instance.orders(query: _search.text, filter: _filter);
      final d = await AppDb.instance.activeDueByDate();
      if (!mounted) return;
      setState(() {
        _orders = o;
        _due = d;
      });
    } catch (_) {}
  }

  bool _isBusy(DateTime d) =>
      (_due[ymd(d)]?.length ?? 0) >= Settings.instance.busyThreshold;

  @override
  Widget build(BuildContext context) {
    final t0 = today();
    final busyDays = _due.entries
        .where((e) =>
            e.value.length >= Settings.instance.busyThreshold &&
            !parseYmd(e.key).isBefore(t0))
        .toList();
    final busyList = busyDays
        .take(4)
        .map((e) => t('busy.item', {
              'date': fmtShort(parseYmd(e.key)),
              'n': e.value.length,
            }))
        .join(', ');
    final busyMore =
        busyDays.length > 4 ? t('busy.more', {'n': busyDays.length - 4}) : '';

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: TextField(
          controller: _search,
          onChanged: (_) => _load(),
          decoration: InputDecoration(
            hintText: t('orders.search'),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _search.clear();
                      _load();
                    }),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Wrap(spacing: 8, children: [
          for (final f in const [
            ('active', 'filter.todo'),
            ('done', 'filter.done'),
            ('all', 'filter.all'),
          ])
            ChoiceChip(
              label: Text(t(f.$2)),
              selected: _filter == f.$1,
              onSelected: (_) {
                setState(() => _filter = f.$1);
                _load();
              },
            ),
        ]),
      ),
      if (busyDays.isNotEmpty)
        Card(
          color: Theme.of(context).colorScheme.tertiaryContainer,
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.warning_amber_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Text(t('busy.banner', {'list': busyList, 'more': busyMore})),
              ),
            ]),
          ),
        ),
      Expanded(
        child: _orders.isEmpty
            ? Center(
                child: Text(
                  _search.text.isEmpty ? t('orders.empty') : t('no.results'),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 90, top: 4),
                itemCount: _orders.length,
                itemBuilder: (_, i) => _OrderTile(
                  order: _orders[i],
                  busy: _orders[i].isActive && _isBusy(_orders[i].deadline),
                ),
              ),
      ),
    ]);
  }
}

class _OrderTile extends StatelessWidget {
  final TailorOrder order;
  final bool busy;
  const _OrderTile({required this.order, required this.busy});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final diff = daysBetween(today(), order.deadline);
    String label;
    Color color = scheme.onSurfaceVariant;
    if (!order.isActive) {
      label = t('status.delivered');
      color = scheme.primary;
    } else if (diff < 0) {
      label = t('tile.overdue', {'n': -diff});
      color = scheme.error;
    } else if (diff == 0) {
      label = t('tile.today');
      color = scheme.error;
    } else if (diff == 1) {
      label = t('tile.tomorrow');
      color = Colors.orange.shade800;
    } else if (diff <= 3) {
      label = t('tile.inDays', {'n': diff});
      color = Colors.orange.shade800;
    } else {
      label = fmtShort(order.deadline);
    }

    return ListTile(
      leading: PhotoThumb(
        file: order.clothPhoto ?? order.modelPhoto,
        placeholder: Icons.checkroom,
      ),
      title: Text(order.clientName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          if (order.model.isNotEmpty) order.model,
          if (order.isActive && order.status == Status.ready) t('status.ready'),
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          if (busy)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange.shade800),
              Text(t('tile.busy'),
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade800)),
            ]),
        ],
      ),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OrderDetailScreen(orderId: order.id!),
      )),
    );
  }
}

// ======================================================================
// Clients tab
// ======================================================================

class ClientsTab extends StatefulWidget {
  const ClientsTab({super.key});

  @override
  State<ClientsTab> createState() => _ClientsTabState();
}

class _ClientsTabState extends State<ClientsTab> {
  final _search = TextEditingController();
  List<Client> _clients = [];

  @override
  void initState() {
    super.initState();
    AppDb.instance.revision.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    AppDb.instance.revision.removeListener(_load);
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final c = await AppDb.instance.clients(_search.text);
      if (!mounted) return;
      setState(() => _clients = c);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: TextField(
          controller: _search,
          onChanged: (_) => _load(),
          decoration: InputDecoration(
            hintText: t('clients.search'),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _search.clear();
                      _load();
                    }),
          ),
        ),
      ),
      Expanded(
        child: _clients.isEmpty
            ? Center(
                child: Text(_search.text.isEmpty ? t('clients.empty') : t('no.results')))
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 90),
                itemCount: _clients.length,
                itemBuilder: (_, i) {
                  final c = _clients[i];
                  return ListTile(
                    leading: PhotoThumb(file: c.photo, circle: true),
                    title: Text(c.name),
                    subtitle: Text([c.phone, c.email].where((s) => s.isNotEmpty).join(' · ')),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ClientDetailScreen(clientId: c.id!),
                    )),
                  );
                },
              ),
      ),
    ]);
  }
}
