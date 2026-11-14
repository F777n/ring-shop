import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_api.dart';
import '../core/api_exceptions.dart';
import '../models/customer.dart';
import '../models/customer_query.dart';
import '../models/product.dart';
import '../models/product_query.dart';
import '../repositories/directory_repositories.dart';
import '../repositories/product_repository.dart';

class CounterScreen extends StatefulWidget {
  const CounterScreen({super.key});

  @override
  State<CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends State<CounterScreen> {
  List<Product> _products = const [];
  List<Customer> _customers = const [];
  List<ShopSale> _sales = const [];
  int? _productId;
  int? _customerId;
  String? _error;
  bool _loading = true;
  bool _busy = false;

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
    final productsRepo = context.read<ProductRepository>();
    final customersRepo = context.read<CustomerRepository>();
    final desk = context.read<DeskApi>();
    try {
      final products = await productsRepo.find(const ProductQuery(size: 50));
      final customers = await customersRepo.find(const CustomerQuery(size: 50));
      final sales = await desk.sales();
      if (!mounted) return;
      setState(() {
        _products = products.items.where((item) => !item.isDeleted && item.stockAvailable > 0).toList();
        _customers = customers.items.where((item) => !item.isDeleted).toList();
        _sales = sales;
        _productId ??= _products.isEmpty ? null : _products.first.id;
        _customerId ??= _customers.isEmpty ? null : _customers.first.id;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open() async {
    final productId = _productId;
    final customerId = _customerId;
    if (productId == null || customerId == null || _busy) return;
    setState(() => _busy = true);
    try {
      await context.read<DeskApi>().openSale(productId: productId, customerId: customerId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Продажа оформлена.')));
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close(ShopSale sale) async {
    try {
      await context.read<DeskApi>().closeSale(sale.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Продажа закрыта.')));
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
        Text('Касса', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Экран продавца: оформить продажу и закрыть её. Покупатель и администратор сюда не попадают.'),
        const SizedBox(height: 16),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (_products.isNotEmpty && _customers.isNotEmpty) ...[
          DropdownButtonFormField<int>(
            value: _productId,
            decoration: const InputDecoration(labelText: 'Товар'),
            items: [
              for (final product in _products)
                DropdownMenuItem(value: product.id, child: Text(product.name)),
            ],
            onChanged: (value) => setState(() => _productId = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _customerId,
            decoration: const InputDecoration(labelText: 'Клиент'),
            items: [
              for (final customer in _customers)
                DropdownMenuItem(value: customer.id, child: Text(customer.fullName)),
            ],
            onChanged: (value) => setState(() => _customerId = value),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: _busy ? null : _open,
              child: const Text('Оформить продажу'),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text('Открытые продажи', style: Theme.of(context).textTheme.titleMedium),
        for (final sale in _sales.where((item) => item.isOpen))
          ListTile(
            title: Text(sale.productName),
            subtitle: Text(sale.customerName),
            trailing: OutlinedButton(onPressed: () => _close(sale), child: const Text('Закрыть')),
          ),
      ],
    );
  }
}
