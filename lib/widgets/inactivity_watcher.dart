import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'confirm_dialog.dart';

class InactivityWatcher extends StatefulWidget {
  const InactivityWatcher({
    super.key,
    required this.enabled,
    required this.timeout,
    required this.warningBefore,
    required this.onInactive,
    required this.onSessionEnd,
    required this.onActivity,
    required this.child,
    this.sessionEnds,
  });

  final bool enabled;
  final Duration timeout;
  final Duration warningBefore;
  final DateTime? sessionEnds;
  final VoidCallback onInactive;
  final VoidCallback onSessionEnd;
  final VoidCallback onActivity;
  final Widget child;

  @override
  State<InactivityWatcher> createState() => _InactivityWatcherState();
}

class _InactivityWatcherState extends State<InactivityWatcher> {
  Timer? _warn;
  Timer? _logout;
  Timer? _session;
  bool _dialog = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    _arm();
  }

  @override
  void didUpdateWidget(covariant InactivityWatcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.sessionEnds != widget.sessionEnds) {
      _arm();
    }
  }

  bool _onKey(KeyEvent event) {
    _restart();
    return false;
  }

  void _arm() {
    _stopTimers();
    if (!widget.enabled) return;
    final ends = widget.sessionEnds;
    if (ends != null) {
      final left = ends.difference(DateTime.now());
      if (left <= Duration.zero) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.enabled) widget.onSessionEnd();
        });
      } else {
        _session = Timer(left, widget.onSessionEnd);
      }
    }
    _restart(record: false);
  }

  void _restart({bool record = true}) {
    if (!widget.enabled) return;
    if (_dialog && mounted) {
      final navigator = Navigator.maybeOf(context, rootNavigator: true);
      if (navigator != null) navigator.maybePop();
      _dialog = false;
    }
    _warn?.cancel();
    _logout?.cancel();
    final warnAfter = widget.timeout - widget.warningBefore;
    if (warnAfter > Duration.zero) {
      _warn = Timer(warnAfter, _showWarning);
    }
    _logout = Timer(widget.timeout, widget.onInactive);
    if (record) widget.onActivity();
  }

  Future<void> _showWarning() async {
    if (!mounted ||
        _dialog ||
        !widget.enabled ||
        Navigator.maybeOf(context) == null) return;
    _dialog = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => narrowDialog(AlertDialog(
        title: const Text('Сессия скоро завершится'),
        content: const Text('Без действий выход произойдёт через 30 секунд.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Я здесь'),
          ),
        ],
      )),
    );
    _dialog = false;
    if (mounted && widget.enabled) _restart();
  }

  void _stopTimers() {
    _warn?.cancel();
    _logout?.cancel();
    _session?.cancel();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _stopTimers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _restart(),
      onPointerMove: (_) => _restart(),
      onPointerSignal: (_) => _restart(),
      child: widget.child,
    );
  }
}
