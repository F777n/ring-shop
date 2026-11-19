import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/access.dart';
import '../auth/auth_api.dart';
import '../auth/auth_user.dart';
import '../core/api_exceptions.dart';

class AuthBinder {
  AuthNotifier? _auth;

  String? token;

  void attach(AuthNotifier auth) => _auth = auth;

  Future<bool> refresh() => _auth?.refreshTokens() ?? Future<bool>.value(false);

  Future<void> sessionExpired() async {
    await _auth?.logout(reason: 'Не удалось обновить сессию. Войдите снова.');
  }
}

class AuthNotifier extends ChangeNotifier {
  AuthNotifier(this._prefs, this._api, this._binder) {
    _binder?.attach(this);
  }

  AuthNotifier.preview({Role role = Role.admin, bool signedIn = true})
      : _prefs = null,
        _api = null,
        _binder = null,
        _user = signedIn
            ? AppUser(
                id: 0,
                username: role.name,
                fullName: switch (role) {
                  Role.buyer => 'Иванов Пётр',
                  Role.seller => 'Петрова Анна',
                  Role.admin => 'Сидоров Игорь',
                },
                role: role,
              )
            : null;

  static const _kAccess = 'auth_access_token';
  static const _kRefresh = 'auth_refresh_token';

  static const roleKey = 'auth_role';
  static const _kUser = 'auth_user';
  static const _kLast = 'auth_last_action';
  static const _kUntil = 'auth_session_until';

  final SharedPreferences? _prefs;
  final AuthApi? _api;
  final AuthBinder? _binder;

  AppUser? _user;
  DateTime? _sessionEnds;
  String? notice;
  Future<bool>? _refreshing;

  AppUser? get user => _user;
  bool get isAuthenticated => _user != null;
  DateTime? get sessionEnds => _sessionEnds;

  bool can(Operation operation) {
    final current = _user;
    if (current == null) return false;
    return canDo(current.role, operation);
  }

  bool allowsPath(String path) {
    final current = _user;
    if (current == null) return false;
    if (path == '/forbidden') return true;
    if (path == '/orders') return canDo(current.role, Operation.viewOrders);
    if (path == '/counter') return canDo(current.role, Operation.sell);
    if (path == '/admin' || path.startsWith('/admin/')) {
      return canDo(current.role, Operation.manageUsers);
    }
    if (path.startsWith('/customers')) {
      return canDo(current.role, Operation.manageCustomers);
    }
    if (path.startsWith('/brands') ||
        path.startsWith('/categories') ||
        path.startsWith('/disciplines')) {
      return canDo(current.role, Operation.manageCatalog);
    }
    if (path.startsWith('/products')) {
      final editing = path.endsWith('/new') || path.endsWith('/edit');
      return canDo(current.role,
          editing ? Operation.manageCatalog : Operation.viewCatalog);
    }
    return false;
  }

  Future<void> restore() async {
    final prefs = _prefs;
    final api = _api;
    if (prefs == null || api == null) return;
    final access = prefs.getString(_kAccess);
    final refresh = prefs.getString(_kRefresh);
    if (access == null && refresh == null) return;
    _binder?.token = access;
    _sessionEnds = _readTime(_kUntil);
    if (_sessionEnds != null && DateTime.now().isAfter(_sessionEnds!)) {
      await logout(reason: 'Время сессии истекло. Войдите снова.');
      return;
    }
    final last = _readTime(_kLast);
    if (last != null &&
        DateTime.now().difference(last) > const Duration(minutes: 3)) {
      await logout(reason: 'Сессия завершена из-за неактивности.');
      return;
    }
    try {
      final me = access == null ? null : await api.me();
      final storedRole = Role.parse(prefs.getString(roleKey));
      final profile = me ?? _readUser();
      if (profile == null) {
        await logout();
        return;
      }
      _user = profile.copyWith(role: storedRole ?? profile.role);
      _binder?.token = prefs.getString(_kAccess);
      touch();
    } on UnauthorizedException {
      final ok = refresh != null && await refreshTokens();
      if (!ok) {
        await logout();
        return;
      }
      try {
        final me = await api.me();
        final storedRole = Role.parse(prefs.getString(roleKey));
        _user = me.copyWith(role: storedRole ?? me.role);
        touch();
      } catch (_) {
        await logout();
      }
    } catch (_) {
      _user = _readUser();
    }
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    final api = _api;
    if (api == null) return;
    final result = await api.login(username.trim(), password);
    await _keep(result);
  }

  Future<void> register({
    required String username,
    required String password,
    required String fullName,
  }) async {
    final api = _api;
    if (api == null) return;
    final result = await api.register(
      username: username.trim(),
      password: password,
      fullName: fullName.trim(),
    );
    await _keep(result);
  }

  Future<bool> refreshTokens() {
    final running = _refreshing;
    if (running != null) return running;
    final future = _refreshOnce();
    _refreshing = future;
    return future.whenComplete(() => _refreshing = null);
  }

  Future<bool> _refreshOnce() async {
    final api = _api;
    final prefs = _prefs;
    final refresh = prefs?.getString(_kRefresh);
    if (api == null || refresh == null) return false;
    try {
      final result = await api.refresh(refresh);
      _binder?.token = result.accessToken;
      _sessionEnds = result.sessionExpiresAt;
      await prefs?.setString(_kAccess, result.accessToken);
      await prefs?.setString(_kRefresh, result.refreshToken);
      await prefs?.setInt(
          _kUntil, result.sessionExpiresAt.millisecondsSinceEpoch);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout({String? reason}) async {
    _user = null;
    _sessionEnds = null;
    _binder?.token = null;
    notice = reason;
    final prefs = _prefs;
    await prefs?.remove(_kAccess);
    await prefs?.remove(_kRefresh);
    await prefs?.remove(roleKey);
    await prefs?.remove(_kUser);
    await prefs?.remove(_kLast);
    await prefs?.remove(_kUntil);
    notifyListeners();
  }

  void touch() {
    final prefs = _prefs;
    if (prefs == null || _user == null) return;
    prefs.setInt(_kLast, DateTime.now().millisecondsSinceEpoch);
  }

  void clearNotice() {
    if (notice == null) return;
    notice = null;
    notifyListeners();
  }

  Future<void> _keep(AuthResult result) async {
    final prefs = _prefs;
    _user = result.user;
    _sessionEnds = result.sessionExpiresAt;
    _binder?.token = result.accessToken;
    notice = null;
    await prefs?.setString(_kAccess, result.accessToken);
    await prefs?.setString(_kRefresh, result.refreshToken);
    await prefs?.setString(roleKey, result.user.role.name);
    await prefs?.setString(_kUser, jsonEncode(result.user.toJson()));
    await prefs?.setInt(
        _kUntil, result.sessionExpiresAt.millisecondsSinceEpoch);
    touch();
    notifyListeners();
  }

  AppUser? _readUser() {
    final raw = _prefs?.getString(_kUser);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is Map) {
        final storedRole = Role.parse(_prefs?.getString(roleKey));
        final user = AppUser.fromJson(Map<String, dynamic>.from(json));
        return user.copyWith(role: storedRole ?? user.role);
      }
    } catch (_) {}
    return null;
  }

  DateTime? _readTime(String key) {
    final value = _prefs?.getInt(key);
    if (value == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
}

bool canDo(Role role, Operation operation) => can(role, operation);
