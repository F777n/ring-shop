import 'dart:async';

import 'api_exceptions.dart';

class QuietRetry {
  Timer? _timer;

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void arm(Object error, Future<void> Function() retry) {
    cancel();
    if (error is! NetworkException) return;
    _timer = Timer(const Duration(seconds: 4), () {
      retry();
    });
  }

  void dispose() => cancel();
}
