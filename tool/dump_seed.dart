import 'dart:convert';
import 'dart:io';

import 'package:ring_shop/data/seed.dart';

void main() {
  final catalog = {
    'products': buildSeedProducts().map((item) => item.toJson()).toList(),
    'brands': buildSeedBrands().map((item) => item.toJson()).toList(),
    'categories': buildSeedCategories().map((item) => item.toJson()).toList(),
    'disciplines': buildSeedDisciplines().map((item) => item.toJson()).toList(),
    'customers': buildSeedCustomers().map((item) => item.toJson()).toList(),
  };
  final file = File('api/catalog.json');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(catalog));
}
