enum Role {
  buyer,
  seller,
  admin;

  String get label => switch (this) {
        Role.buyer => 'Покупатель',
        Role.seller => 'Продавец',
        Role.admin => 'Администратор',
      };

  static Role? parse(String? raw) => switch (raw) {
        'buyer' => Role.buyer,
        'seller' => Role.seller,
        'admin' => Role.admin,
        _ => null,
      };
}

enum Operation {
  viewCatalog,
  manageCatalog,
  softDelete,
  sell,
  manageCustomers,
  viewOrders,
  extendOrder,
  hardDelete,
  restore,
  manageUsers,
  viewStats,
  manageSchedule,
}

bool can(Role role, Operation operation) {
  return switch (operation) {
    Operation.viewCatalog => true,
    Operation.manageCatalog ||
    Operation.softDelete =>
      role == Role.seller || role == Role.admin,
    Operation.sell => role == Role.seller,
    Operation.manageCustomers => role == Role.seller || role == Role.admin,
    Operation.viewOrders || Operation.extendOrder => role == Role.buyer,
    Operation.manageSchedule => role == Role.seller || role == Role.admin,
    Operation.hardDelete ||
    Operation.restore ||
    Operation.manageUsers ||
    Operation.viewStats =>
      role == Role.admin,
  };
}
