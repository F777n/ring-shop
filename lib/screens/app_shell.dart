import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/access.dart';
import '../forms/form_guard.dart';
import '../state/auth_notifier.dart';
import '../storage/catalog_store.dart';
import '../theme.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/inactivity_watcher.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final auth = context.watch<AuthNotifier>();
    final sections = _sectionsFor(auth.user?.role ?? Role.buyer);
    final index = _sectionIndex(path, sections);
    final wide = MediaQuery.sizeOf(context).width >= kTableBreakpoint;
    final theme = context.watch<ThemeController>();
    final notice = context.watch<StorageNotice>();
    final scheme = Theme.of(context).colorScheme;
    final person = auth.user;

    return InactivityWatcher(
      enabled: auth.isAuthenticated && auth.sessionEnds != null,
      timeout: const Duration(minutes: 3),
      warningBefore: const Duration(seconds: 30),
      sessionEnds: auth.sessionEnds,
      onActivity: auth.touch,
      onInactive: () => auth.logout(reason: 'Сессия завершена из-за неактивности.'),
      onSessionEnd: () => auth.logout(reason: 'Время сессии истекло. Войдите снова.'),
      child: Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.sports_mma, color: scheme.onPrimary, size: 20),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ринг'),
                  if (MediaQuery.sizeOf(context).width >= 720)
                    Text(
                      'Магазин боксёрских принадлежностей',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (person != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(person.fullName, style: Theme.of(context).textTheme.labelLarge),
                  Text(person.role.label, style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
          if (person != null)
            IconButton(
              tooltip: 'Выйти',
              onPressed: auth.logout,
              icon: const Icon(Icons.logout),
            ),
          IconButton(
            tooltip: theme.isDark ? 'Светлая тема' : 'Тёмная тема',
            onPressed: theme.toggle,
            icon: Icon(theme.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          if (notice.message != null)
            MaterialBanner(
              content: Text(notice.message!),
              actions: [
                TextButton(onPressed: notice.dismiss, child: const Text('Скрыть')),
              ],
            ),
          Expanded(
            child: wide
                ? Row(
                    children: [
                      NavigationRail(
                        selectedIndex: index,
                        onDestinationSelected: (value) => _openSection(context, value, sections),
                        labelType: NavigationRailLabelType.all,
                        destinations: [
                          for (final section in sections)
                            NavigationRailDestination(
                              icon: Icon(section.icon),
                              selectedIcon: Icon(section.selected),
                              label: Text(section.label),
                            ),
                        ],
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: child),
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: child,
                  ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              height: 68,
              selectedIndex: index,
              onDestinationSelected: (value) => _openSection(context, value, sections),
              destinations: [
                for (final section in sections)
                  NavigationDestination(
                    icon: Icon(section.icon),
                    selectedIcon: Icon(section.selected),
                    label: section.short,
                  ),
              ],
            ),
      ),
    );
  }

  Future<void> _openSection(BuildContext context, int index, List<_Section> sections) async {
    final guard = context.read<FormGuard>();
    if (guard.dirty) {
      final ok = await confirmAction(
        context,
        title: 'Есть несохранённые изменения',
        message: 'Уйти со страницы? Введённые данные не сохранятся.',
        confirmLabel: 'Уйти',
        danger: true,
      );
      if (!ok || !context.mounted) return;
      guard.allowProgrammaticLeave();
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!context.mounted) return;
    final path = GoRouterState.of(context).uri.path;
    final target = sections[index].path;
    if (path != target) context.go(target);
  }
}

class _Section {
  const _Section(this.path, this.label, this.short, this.icon, this.selected);

  final String path;
  final String label;
  final String short;
  final IconData icon;
  final IconData selected;
}

const _products = _Section('/products', 'Товары', 'Товары', Icons.inventory_2_outlined, Icons.inventory_2);
const _brands = _Section('/brands', 'Бренды', 'Бренды', Icons.workspace_premium_outlined, Icons.workspace_premium);
const _categories = _Section('/categories', 'Категории', 'Катег.', Icons.category_outlined, Icons.category);
const _disciplines = _Section(
  '/disciplines',
  'Дисциплины',
  'Дисц.',
  Icons.sports_martial_arts_outlined,
  Icons.sports_martial_arts,
);
const _customers = _Section('/customers', 'Клиенты', 'Клиенты', Icons.badge_outlined, Icons.badge);
const _orders = _Section('/orders', 'Мои брони', 'Брони', Icons.event_available_outlined, Icons.event_available);
const _counter = _Section('/counter', 'Касса', 'Касса', Icons.point_of_sale_outlined, Icons.point_of_sale);
const _admin = _Section('/admin', 'Админ', 'Админ', Icons.admin_panel_settings_outlined, Icons.admin_panel_settings);

List<_Section> _sectionsFor(Role role) {
  return [
    _products,
    if (can(role, Operation.manageCatalog)) ...[_brands, _categories, _disciplines],
    if (can(role, Operation.manageCustomers)) _customers,
    if (can(role, Operation.viewOrders)) _orders,
    if (can(role, Operation.sell)) _counter,
    if (can(role, Operation.manageUsers)) _admin,
  ];
}

int _sectionIndex(String path, List<_Section> sections) {
  for (var i = 0; i < sections.length; i++) {
    if (path.startsWith(sections[i].path)) return i;
  }
  return 0;
}
