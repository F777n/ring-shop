import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'models/brand_query.dart';
import 'models/category.dart';
import 'models/category_query.dart';
import 'models/customer.dart';
import 'models/customer_query.dart';
import 'models/discipline.dart';
import 'models/discipline_query.dart';
import 'models/product_query.dart';
import 'navigation.dart';
import 'repositories/directory_repositories.dart';
import 'repositories/product_repository.dart';
import 'screens/app_shell.dart';
import 'screens/brand_details_screen.dart';
import 'screens/brand_form_screen.dart';
import 'screens/brand_list_screen.dart';
import 'screens/directory_form_screens.dart';
import 'screens/directory_pages.dart';
import 'screens/forbidden_screen.dart';
import 'screens/login_screen.dart';
import 'screens/not_found_screen.dart';
import 'screens/admin_screen.dart' deferred as admin_lib;
import 'screens/counter_screen.dart' deferred as counter_lib;
import 'screens/orders_screen.dart' deferred as orders_lib;
import 'widgets/deferred_view.dart';
import 'screens/product_details_screen.dart';
import 'screens/product_form_screen.dart';
import 'screens/product_list_screen.dart';
import 'screens/register_screen.dart';
import 'state/auth_notifier.dart';
import 'state/simple_list_notifier.dart';

GoRouter createRouter(AuthNotifier auth) {
  return GoRouter(
    initialLocation: '/products',
    refreshListenable: auth,
    redirect: (context, state) {
      final path = state.uri.path;
      final logged = auth.isAuthenticated;
      final public = path == '/login' || path == '/register';
      if (!logged && !public) {
        return '/login?from=${Uri.encodeComponent(state.uri.toString())}';
      }
      if (logged && public) {
        final from = state.uri.queryParameters['from'];
        if (from != null && _safeReturn(auth, from)) return from;
        return '/products';
      }
      if (logged && path != '/forbidden' && !auth.allowsPath(path)) {
        return '/forbidden';
      }
      if (path == '/') return '/products';
      return null;
    },
    errorBuilder: (context, state) {
      return NotFoundScreen(location: state.uri.toString());
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            LoginScreen(from: state.uri.queryParameters['from']),
      ),
      GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen()),
      GoRoute(
          path: '/forbidden',
          builder: (context, state) => const ForbiddenScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          _section(
            path: '/products',
            list: (state) =>
                ProductListScreen(query: ProductQuery.fromUri(state.uri)),
            create: const ProductFormScreen(),
            details: (id) => ProductDetailsPage(id: id),
            edit: (id) => ProductFormScreen(id: id),
          ),
          _section(
            path: '/brands',
            list: (state) =>
                BrandListScreen(query: BrandQuery.fromUri(state.uri)),
            create: const BrandFormScreen(),
            details: (id) => BrandDetailsPage(id: id),
            edit: (id) => BrandFormScreen(id: id),
          ),
          _section(
            path: '/categories',
            list: (state) =>
                CategoryListScreen(query: CategoryQuery.fromUri(state.uri)),
            create: const CategoryFormScreen(),
            details: (id) => _categoryDetails(id),
            edit: (id) => CategoryFormScreen(id: id),
          ),
          _section(
            path: '/disciplines',
            list: (state) =>
                DisciplineListScreen(query: DisciplineQuery.fromUri(state.uri)),
            create: const DisciplineFormScreen(),
            details: (id) => _disciplineDetails(id),
            edit: (id) => DisciplineFormScreen(id: id),
          ),
          _section(
            path: '/customers',
            list: (state) =>
                CustomerListScreen(query: CustomerQuery.fromUri(state.uri)),
            create: const CustomerFormScreen(),
            details: (id) => _customerDetails(id),
            edit: (id) => CustomerFormScreen(id: id),
          ),
          GoRoute(
            path: '/orders',
            builder: (context, state) => DeferredView(
              load: orders_lib.loadLibrary,
              builder: () => orders_lib.OrdersScreen(),
            ),
          ),
          GoRoute(
            path: '/counter',
            builder: (context, state) => DeferredView(
              load: counter_lib.loadLibrary,
              builder: () => counter_lib.CounterScreen(),
            ),
          ),
          GoRoute(
            path: '/admin',
            builder: (context, state) => DeferredView(
              load: admin_lib.loadLibrary,
              builder: () => admin_lib.AdminScreen(),
            ),
          ),
        ],
      ),
    ],
  );
}

bool _safeReturn(AuthNotifier auth, String from) {
  if (!from.startsWith('/') || from.startsWith('//')) return false;
  final uri = Uri.tryParse(from);
  if (uri == null || uri.hasScheme) return false;
  return auth.allowsPath(uri.path);
}

GoRoute _section({
  required String path,
  required Widget Function(GoRouterState state) list,
  required Widget create,
  required Widget Function(int id) details,
  required Widget Function(int id) edit,
}) {
  return GoRoute(
    path: path,
    builder: (context, state) => list(state),
    routes: [
      GoRoute(path: 'new', builder: (context, state) => create),
      GoRoute(
        path: ':id',
        builder: (context, state) => _idPage(state, details),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) => _idPage(state, edit),
          ),
        ],
      ),
    ],
  );
}

Widget _idPage(GoRouterState state, Widget Function(int id) build) {
  final id = int.tryParse(state.pathParameters['id'] ?? '');
  if (id == null) return InvalidIdPage(location: state.uri.toString());
  return build(id);
}

Widget _categoryDetails(int id) {
  return Builder(
    builder: (context) {
      final repository = context.read<CategoryRepository>();
      final products = context.read<ProductRepository>();
      final list = context.read<SimpleListNotifier<Category, CategoryQuery>>();
      return RecordDetailsPage(
        id: id,
        back: context.read<ListLocationMemory>().categories,
        editPath: '/categories/$id/edit',
        load: (itemId) async {
          final item = await repository.findById(itemId);
          if (item == null) return null;
          return RecordView(
            title: item.name,
            deleted: item.isDeleted,
            deletedAt: item.deletedAt,
            lines: [
              ('Код', item.code),
              ('Группа', item.kind),
              ('Год появления', '${item.introducedYear}'),
              ('Описание', item.description),
            ],
          );
        },
        linksOf: (itemId) => products.countLinked(categoryId: itemId),
        onSoft: repository.softDelete,
        onRestore: repository.restore,
        onHard: repository.hardDelete,
        onReloadList: list.load,
      );
    },
  );
}

Widget _disciplineDetails(int id) {
  return Builder(
    builder: (context) {
      final repository = context.read<DisciplineRepository>();
      final products = context.read<ProductRepository>();
      final list =
          context.read<SimpleListNotifier<Discipline, DisciplineQuery>>();
      return RecordDetailsPage(
        id: id,
        back: context.read<ListLocationMemory>().disciplines,
        editPath: '/disciplines/$id/edit',
        load: (itemId) async {
          final item = await repository.findById(itemId);
          if (item == null) return null;
          return RecordView(
            title: item.name,
            deleted: item.isDeleted,
            deletedAt: item.deletedAt,
            lines: [
              ('Страна', item.country),
              ('Год оформления правил', '${item.establishedYear}'),
              ('Описание', item.summary),
            ],
          );
        },
        linksOf: (itemId) => products.countLinked(disciplineId: itemId),
        onSoft: repository.softDelete,
        onRestore: repository.restore,
        onHard: repository.hardDelete,
        onReloadList: list.load,
      );
    },
  );
}

Widget _customerDetails(int id) {
  return Builder(
    builder: (context) {
      final repository = context.read<CustomerRepository>();
      final list = context.read<SimpleListNotifier<Customer, CustomerQuery>>();
      return RecordDetailsPage(
        id: id,
        back: context.read<ListLocationMemory>().customers,
        editPath: '/customers/$id/edit',
        load: (itemId) async {
          final item = await repository.findById(itemId);
          if (item == null) return null;
          return RecordView(
            title: item.fullName,
            deleted: item.isDeleted,
            deletedAt: item.deletedAt,
            lines: [
              ('Почта', item.email),
              ('Телефон', item.phone),
              ('Город', item.city),
              ('Год рождения', '${item.birthYear}'),
              ('Номер карты', item.card.number),
              ('Дата выдачи', item.card.issuedOn),
              ('Скидка', '${item.card.discountPercent}%'),
              ('Карта', item.card.active ? 'Активна' : 'Заблокирована'),
            ],
          );
        },
        linksOf: (_) async => 0,
        onSoft: repository.softDelete,
        onRestore: repository.restore,
        onHard: repository.hardDelete,
        onReloadList: list.load,
      );
    },
  );
}
