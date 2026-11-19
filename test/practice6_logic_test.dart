import 'package:flutter_test/flutter_test.dart';
import 'package:ring_shop/auth/access.dart';
import 'package:ring_shop/auth/auth_user.dart';
import 'package:ring_shop/forms/validators.dart';
import 'package:ring_shop/models/product.dart';

void main() {
  group('Валидаторы', () {
    test('пустая строка отклоняется', () {
      expect(requiredText(''), isNotNull);
      expect(requiredText('   '), isNotNull);
    });

    test('непустая строка принимается', () {
      expect(requiredText('Перчатки Winning'), isNull);
    });

    test('короткий пароль просит длину', () {
      expect(passwordText('short1!'), 'Минимум 8 символов');
    });

    test('пароль без цифры просит цифру', () {
      expect(passwordText('longpassword!'), 'Добавьте цифру');
    });

    test('артикул короче четырёх символов отклоняется', () {
      expect(skuText('AB'), isNotNull);
    });

    test('телефон без +7 отклоняется', () {
      expect(phoneText('89991234567'), isNotNull);
    });
  });

  group('Разбор моделей', () {
    test('у товара без полей нет исключения', () {
      final product = Product.fromJson({'id': 1});
      expect(product.name, '');
      expect(product.sku, '');
      expect(product.categoryIds, isEmpty);
      expect(product.disciplineIds, isEmpty);
      expect(product.priceRub, 0);
    });

    test('у пользователя без роли остаётся покупатель', () {
      final user = AppUser.fromJson({'id': 4, 'username': 'guest'});
      expect(user.fullName, '');
      expect(user.role, Role.buyer);
    });
  });

  group('Права ролей', () {
    test('покупатель не удаляет навсегда и не продаёт', () {
      expect(can(Role.buyer, Operation.hardDelete), isFalse);
      expect(can(Role.buyer, Operation.sell), isFalse);
      expect(can(Role.buyer, Operation.viewOrders), isTrue);
    });

    test('продавец продаёт, но не управляет пользователями', () {
      expect(can(Role.seller, Operation.sell), isTrue);
      expect(can(Role.seller, Operation.manageUsers), isFalse);
    });

    test('администратор удаляет навсегда и не открывает кассу', () {
      expect(can(Role.admin, Operation.hardDelete), isTrue);
      expect(can(Role.admin, Operation.sell), isFalse);
    });
  });
}
