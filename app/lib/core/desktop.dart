import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'background.dart';
import 'providers.dart';

/// Windows tray + start-with-Windows (decisions.md D8): closing the window hides the app to the tray, so the
/// 30-minute check and expiry reminders keep running and toasts keep arriving.
class DesktopShell with TrayListener, WindowListener {
  DesktopShell(this.container);
  final ProviderContainer container;
  bool _keepInTray = true;
  bool _quitting = false;

  bool get keepInTray => _keepInTray;

  Future<void> init() async {
    await windowManager.ensureInitialized();
    final db = container.read(databaseProvider);
    _keepInTray = (await db.getValue('keep_in_tray')) != 'false';
    await windowManager.setPreventClose(_keepInTray);
    windowManager.addListener(this);

    await trayManager.setIcon('assets/tray_icon.ico');
    await trayManager.setToolTip('Seafarer Assistant');
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'open', label: 'Open Seafarer Assistant'),
      MenuItem(key: 'check', label: 'Check for new alerts'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: 'Quit'),
    ]));
    trayManager.addListener(this);

    // First run: start with Windows (into the tray). The user can switch it off in Settings.
    if (await db.getValue('startup_initialized') == null) {
      await StartupService.setEnabled(true);
      await db.setValue('startup_initialized', '1');
    }
  }

  Future<void> showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> setKeepInTray(bool value) async {
    _keepInTray = value;
    await container.read(databaseProvider).setValue('keep_in_tray', '$value');
    await windowManager.setPreventClose(value);
  }

  Future<void> setUnreadCount(int n) =>
      trayManager.setToolTip(n == 0 ? 'Seafarer Assistant' : 'Seafarer Assistant – $n unread');

  Future<void> quit() async {
    _quitting = true;
    await trayManager.destroy();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @override
  void onWindowClose() {
    if (_keepInTray && !_quitting) {
      unawaited(windowManager.hide());
    } else {
      unawaited(quit());
    }
  }

  @override
  void onTrayIconMouseDown() => unawaited(showWindow());

  @override
  void onTrayIconRightMouseDown() => unawaited(trayManager.popUpContextMenu());

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'open':
        unawaited(showWindow());
      case 'check':
        unawaited(container.read(backgroundSyncProvider).runOnce());
      case 'quit':
        unawaited(quit());
    }
  }
}

/// The running app's tray/window shell. Null in tests and on non-Windows platforms.
DesktopShell? desktopShell;

/// Start with Windows. The installed (MSIX) app uses the package's StartupTask (msix_config.startup_task), which
/// Windows manages in Settings > Apps > Startup; the plain .exe (demo/dev) uses the per-user Run registry key.
class StartupService {
  static const _runKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const _valueName = 'SeafarerAssistant';

  static bool get isPackaged => Platform.resolvedExecutable.toLowerCase().contains(r'\windowsapps\');

  static Future<bool> isEnabled() async {
    if (!Platform.isWindows || isPackaged) return false;
    final r = await Process.run('reg', ['query', _runKey, '/v', _valueName]);
    return r.exitCode == 0;
  }

  static Future<void> setEnabled(bool on) async {
    if (!Platform.isWindows || isPackaged) return;
    if (on) {
      await Process.run('reg', [
        'add', _runKey, '/v', _valueName, '/t', 'REG_SZ', '/d', '"${Platform.resolvedExecutable}" --minimized', '/f',
      ]);
    } else {
      await Process.run('reg', ['delete', _runKey, '/v', _valueName, '/f']);
    }
  }
}
