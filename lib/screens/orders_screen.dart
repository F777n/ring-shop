import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_api.dart';
import '../core/api_exceptions.dart';
import '../format.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<ShopOrder> _items = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await context.read<DeskApi>().orders();
      if (!mounted) return;
      setState(() => _items = items);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _extend(ShopOrder order) async {
    try {
      await context.read<DeskApi>().extendOrder(order.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Срок брони продлён на 7 дней.')),
      );
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Мои брони', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Только покупатель видит свои брони и может продлить срок.'),
        const SizedBox(height: 16),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (!_loading && _error == null && _items.isEmpty) const Text('Броней нет.'),
        for (final order in _items)
          Card(
            child: ListTile(
              title: Text(order.productName),
              subtitle: Text('До ${formatDateTime(order.dueAt)}'),
              trailing: FilledButton(
                onPressed: () => _extend(order),
                child: const Text('Продлить'),
              ),
            ),
          ),
      ],
    );
  }
}
