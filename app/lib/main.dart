import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/background.dart';
import 'core/desktop.dart';
import 'core/providers.dart';
import 'data/db.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);

  if (Platform.isWindows) {
    desktopShell = DesktopShell(container);
    await desktopShell!.init();
  }

  final toasts = container.read(toastProvider);
  await toasts.init();
  // Clicking a toast brings the window back (it may be in the tray) and opens what it is about.
  toasts.onTap = (payload) {
    unawaited(desktopShell?.showWindow());
    if (payload == null) return;
    container.read(routerProvider).go(payload.startsWith('/document/')
        ? '/feed/doc/${payload.substring('/document/'.length)}'
        : payload);
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

  // Unread count in the tray tooltip.
  container.listen(feedItemsProvider, (_, next) {
    final unread = next.value?.where((f) => !f.read).length ?? 0;
    unawaited(desktopShell?.setUnreadCount(unread));
  }, fireImmediately: true);

  runApp(UncontrolledProviderScope(container: container, child: const SeafarerApp()));
}
