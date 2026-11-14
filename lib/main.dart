import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'auth/auth_api.dart';
import 'core/api_client.dart';
import 'core/config.dart';
import 'state/auth_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  ApiProbe.readLaunchUri();
  final preferences = await SharedPreferences.getInstance();
  final binder = AuthBinder();
  final dio = buildDio(tokenProvider: () => binder.token, binder: binder);
  final auth = AuthNotifier(preferences, AuthApi(dio), binder);
  await auth.restore();
  runApp(buildRingApp(dio: dio, auth: auth));
}
