import 'package:flutter/material.dart';

import '../core/api_exceptions.dart';
import '../core/quiet_retry.dart';
import '../models/brand.dart';
import '../models/brand_query.dart';
import '../models/load_status.dart';
import '../models/page_result.dart';
import '../repositories/brand_repository.dart';

class BrandListNotifier extends ChangeNotifier {
  BrandListNotifier(this._repository);

  final BrandRepository _repository;

  BrandQuery _query = const BrandQuery();
  PageResult<Brand> _result = PageResult<Brand>.empty();
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  final Set<int> _selected = {};
  bool _failNext = false;
  int _ticket = 0;
  final _retry = QuietRetry();

  BrandQuery get query => _query;
  PageResult<Brand> get result => _result;
  LoadStatus get status => _status;
  String? get error => _error;
  Set<int> get selected => Set.unmodifiable(_selected);
  bool get hasSelection => _selected.isNotEmpty;

  Future<void> load({bool quiet = false}) async {
    _retry.cancel();
    final ticket = ++_ticket;
    if (!quiet) {
      _status = LoadStatus.loading;
      _error = null;
      notifyListeners();
    }
    Object? failure;
    try {
      if (_failNext) {
        _failNext = false;
        throw StateError('Учебная имитация: справочник брендов не ответил');
      }
      final result = await _repository.find(_query);
      if (ticket != _ticket) return;
      _result = result;
      _status = LoadStatus.success;
    } on RequestCancelled {
      return;
    } on ApiException catch (error) {
      if (ticket != _ticket) return;
      failure = error;
      _error = error.message;
      _status = LoadStatus.error;
    } on StateError catch (error) {
      if (ticket != _ticket) return;
      failure = error;
      _error = error.message;
      _status = LoadStatus.error;
    } catch (error) {
      if (ticket != _ticket) return;
      failure = error;
      _error = 'Не удалось загрузить список: $error';
      _status = LoadStatus.error;
    }
    if (failure != null) _retry.arm(failure, () => load(quiet: true));
    notifyListeners();
  }

  @override
  void dispose() {
    _retry.dispose();
    super.dispose();
  }

  Future<void> applyQuery(BrandQuery next) async {
    final changed = _query != next;
    if (!changed && _status == LoadStatus.success) return;
    _query = next;
    if (changed) _selected.clear();
    await load();
  }

  Future<void> demonstrateError() async {
    _failNext = true;
    await load();
  }

  void toggleSelection(int id) {
    if (_selected.contains(id)) {
      _selected.remove(id);
    } else {
      _selected.add(id);
    }
    notifyListeners();
  }

  void clearSelection() {
    if (_selected.isEmpty) return;
    _selected.clear();
    notifyListeners();
  }

  Future<void> deleteSelected() async {
    final ids = _selected.toList();
    if (ids.isEmpty) return;
    await _mutate(() async {
      await _repository.deleteMany(ids);
      _selected.clear();
    }, 'Не удалось скрыть выбранные бренды.');
  }

  Future<void> softDelete(int id) {
    _selected.remove(id);
    return _mutate(
        () => _repository.softDelete(id), 'Не удалось скрыть бренд.');
  }

  Future<void> hardDelete(int id) {
    _selected.remove(id);
    return _mutate(
        () => _repository.hardDelete(id), 'Не удалось удалить бренд.');
  }

  Future<void> restore(int id) {
    return _mutate(
        () => _repository.restore(id), 'Не удалось восстановить бренд.');
  }

  Future<void> _mutate(
    Future<void> Function() action,
    String failMessage,
  ) async {
    try {
      await action();
    } on ApiException catch (error) {
      _error = error.message;
      _status = LoadStatus.error;
      notifyListeners();
      return;
    } catch (error) {
      _error = '$failMessage $error';
      _status = LoadStatus.error;
      notifyListeners();
      return;
    }
    await load();
  }
}
