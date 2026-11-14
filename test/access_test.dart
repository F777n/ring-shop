import 'package:flutter_test/flutter_test.dart';
import 'package:ring_shop/auth/access.dart';
import 'package:ring_shop/forms/validators.dart';

void main() {
  test('покупатель видит каталог и свои брони, но не правит товары', () {
    expect(can(Role.buyer, Operation.viewCatalog), isTrue);
    expect(can(Role.buyer, Operation.viewOrders), isTrue);
    expect(can(Role.buyer, Operation.extendOrder), isTrue);
    expect(can(Role.buyer, Operation.manageCatalog), isFalse);
    expect(can(Role.buyer, Operation.sell), isFalse);
  });

  test('покупатель не удаляет записи навсегда', () {
    expect(can(Role.buyer, Operation.hardDelete), isFalse);
    expect(can(Role.buyer, Operation.restore), isFalse);
    expect(can(Role.buyer, Operation.manageUsers), isFalse);
  });

  test('продавец ведёт каталог и кассу, но не пользователей', () {
    expect(can(Role.seller, Operation.manageCatalog), isTrue);
    expect(can(Role.seller, Operation.sell), isTrue);
    expect(can(Role.seller, Operation.manageCustomers), isTrue);
    expect(can(Role.seller, Operation.manageUsers), isFalse);
    expect(can(Role.seller, Operation.viewStats), isFalse);
  });

  test('продавец не открывает брони покупателя и не удаляет навсегда', () {
    expect(can(Role.seller, Operation.viewOrders), isFalse);
    expect(can(Role.seller, Operation.hardDelete), isFalse);
    expect(can(Role.seller, Operation.restore), isFalse);
  });

  test('администратор управляет людьми и удалением, но не кассой', () {
    expect(can(Role.admin, Operation.manageUsers), isTrue);
    expect(can(Role.admin, Operation.viewStats), isTrue);
    expect(can(Role.admin, Operation.hardDelete), isTrue);
    expect(can(Role.admin, Operation.restore), isTrue);
    expect(can(Role.admin, Operation.sell), isFalse);
    expect(can(Role.admin, Operation.viewOrders), isFalse);
  });

  test('пароль проверяется по длине, цифре и символу', () {
    expect(passwordText('short1!'), 'Минимум 8 символов');
    expect(passwordText('longpassword'), 'Добавьте цифру');
    expect(passwordText('longpass1'), 'Добавьте специальный символ');
    expect(passwordText('Buyer123!'), isNull);
  });
}
