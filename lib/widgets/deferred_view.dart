import 'package:flutter/material.dart';

import 'status_views.dart';

class DeferredView extends StatefulWidget {
  const DeferredView({super.key, required this.load, required this.builder});

  final Future<void> Function() load;
  final Widget Function() builder;

  @override
  State<DeferredView> createState() => _DeferredViewState();
}

class _DeferredViewState extends State<DeferredView> {
  late Future<void> _ready = widget.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingView(message: 'Открываем раздел…');
        }
        if (snapshot.hasError) {
          return ErrorView(
            message: 'Раздел не загрузился.',
            onRetry: () {
              setState(() {
                _ready = widget.load();
              });
            },
          );
        }
        return widget.builder();
      },
    );
  }
}
