import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/background.dart';
import 'core/providers.dart';
import 'data/db.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);

  final toasts = container.read(toastProvider);
  await toasts.init();
  // Clicking a toast opens the document or certificate it is about.
  toasts.onTap = (payload) {
    if (payload != null) {
      container.read(routerProvider).go(payload.startsWith('/document/')
        ? '/feed/doc/${payload.substring('/document/'.length)}'
        : payload);
    }
  };

  // Start syncing once signed in; stop when signed out.
  container.listen<SessionState>(sessionProvider, (prev, next) {
    final sync = container.read(backgroundSyncProvider);
    if (next == SessionState.ready) {
      sync.start();
    } else {
      sync.stop();
    }
  }, fireImmediately: true);

  runApp(UncontrolledProviderScope(container: container, child: const SeafarerApp()));
}
