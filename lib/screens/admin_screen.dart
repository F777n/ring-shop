import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/access.dart';
import '../auth/auth_api.dart';
import '../core/api_exceptions.dart';
import '../state/auth_notifier.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  ShopStats? _stats;
  List<AccountUser> _users = const [];
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
    final api = context.read<DeskApi>();
    try {
      final stats = await api.stats();
      final users = await api.users();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _users = users;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _role(AccountUser user, String role) async {
    try {
      await context.read<DeskApi>().setRole(user.id, role);
      if (!mounted) return;
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Администрирование',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
            'Пользователи, роли и сводка. Этот экран есть только у администратора.'),
        const SizedBox(height: 16),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null)
          Text(_error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (stats != null)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _stat('Товары', stats.products),
              _stat('Бренды', stats.brands),
              _stat('Клиенты', stats.customers),
              _stat('Учётки', stats.users),
              _stat('Открытые продажи', stats.openSales),
            ],
          ),
        const SizedBox(height: 20),
        for (final user in _users)
          Builder(
            builder: (context) {
              final current = context.watch<AuthNotifier>().user;
              final mine = current != null &&
                  (user.id == current.id || user.username == current.username);
              final roleLabel = Role.parse(user.role)?.label ?? user.role;
              return Card(
                child: ListTile(
                  title: Text(user.fullName),
                  subtitle: Text(mine
                      ? '${user.username} · свою роль менять нельзя'
                      : user.username),
                  trailing: mine
                      ? Text(roleLabel)
                      : DropdownButton<String>(
                          value: user.role,
                          items: [
                            for (final role in Role.values)
                              DropdownMenuItem(
                                  value: role.name, child: Text(role.label)),
                          ],
                          onChanged: (value) {
                            if (value != null && value != user.role) {
                              _role(user, value);
                            }
                          },
                        ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _stat(String label, int value) {
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$value', style: Theme.of(context).textTheme.headlineSmall),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}
