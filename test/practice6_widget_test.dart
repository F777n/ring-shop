import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ring_shop/app.dart';
import 'package:ring_shop/auth/access.dart';
import 'package:ring_shop/repositories/directory_repositories.dart';
import 'package:ring_shop/repositories/in_memory_brand_repository.dart';
import 'package:ring_shop/repositories/in_memory_product_repository.dart';
import 'package:ring_shop/state/auth_notifier.dart';
import 'package:ring_shop/storage/catalog_store.dart';

void main() {
  void wide(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  }

  testWidgets('каталог показывает загрузку', (tester) async {
    wide(tester);
    await tester.pumpWidget(buildRingApp());
    await tester.pump();
    expect(find.text('Загружаем каталог…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('пустой каталог показывает сообщение', (tester) async {
    wide(tester);
    const pause = Duration.zero;
    await tester.pumpWidget(
      buildRingApp(
        session: CatalogSession(
          products:
              InMemoryProductRepository(products: const [], latency: pause),
          brands: InMemoryBrandRepository(brands: const [], latency: pause),
          categories:
              InMemoryCategoryRepository(categories: const [], latency: pause),
          disciplines: InMemoryDisciplineRepository(
              disciplines: const [], latency: pause),
          customers:
              InMemoryCustomerRepository(customers: const [], latency: pause),
          notice: StorageNotice(null),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Ничего не найдено'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
      'ошибка показывает повтор, и список возвращается без перезагрузки',
      (tester) async {
    wide(tester);
    await tester.pumpWidget(buildRingApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byTooltip('Ещё'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Показать состояние ошибки'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Список не загрузился'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);

    await tester.tap(find.text('Повторить'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Список не загрузился'), findsNothing);
    expect(find.textContaining('Everlast'), findsWidgets);
  });

  testWidgets('пустой вход не отправляется', (tester) async {
    wide(tester);
    await tester
        .pumpWidget(buildRingApp(auth: AuthNotifier.preview(signedIn: false)));
    await tester.pump();
    await tester.tap(find.text('Войти'));
    await tester.pump();
    expect(find.text('Укажите логин'), findsOneWidget);
    expect(find.text('Укажите пароль'), findsOneWidget);
  });

  testWidgets('покупатель не видит удаление навсегда', (tester) async {
    wide(tester);
    await tester
        .pumpWidget(buildRingApp(auth: AuthNotifier.preview(role: Role.buyer)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byTooltip('Удалить навсегда'), findsNothing);
    expect(find.text('Добавить'), findsNothing);
    expect(find.text('Мои брони'), findsWidgets);
  });

  testWidgets('четыре ширины перестраивают навигацию и список', (tester) async {
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final width in [360.0, 768.0, 1280.0, 1920.0]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpWidget(buildRingApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Каталог товаров'), findsOneWidget);
      if (width < 600) {
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.byType(NavigationRail), findsNothing);
      } else {
        expect(find.byType(NavigationRail), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);
      }
      if (width >= 1100) {
        expect(find.byType(DataTable), findsOneWidget);
      } else {
        expect(find.byType(DataTable), findsNothing);
      }
    }
  });
}
