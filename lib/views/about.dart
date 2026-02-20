import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/controller.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/list.dart';
import 'package:fl_clash/widgets/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AboutView extends ConsumerWidget {
  const AboutView({super.key});

  String _displayVersion() {
    final raw = globalState.appDisplayVersion;
    return raw.startsWith('v') ? raw : 'v$raw';
  }

  Future<String> _resolveVisibleBaseDir() async {
    final env = Platform.environment;
    final home = env['USERPROFILE'] ?? env['HOME'] ?? Directory.current.path;
    final candidates = <String>[
      if (system.isWindows && (env['OneDriveConsumer']?.isNotEmpty ?? false))
        '${env['OneDriveConsumer']}${Platform.pathSeparator}Desktop',
      if (system.isWindows && (env['OneDriveCommercial']?.isNotEmpty ?? false))
        '${env['OneDriveCommercial']}${Platform.pathSeparator}Desktop',
      if (system.isWindows && (env['OneDrive']?.isNotEmpty ?? false))
        '${env['OneDrive']}${Platform.pathSeparator}Desktop',
      '$home${Platform.pathSeparator}Desktop',
      home,
    ];
    for (final path in candidates) {
      try {
        final dir = Directory(path);
        if (!dir.existsSync()) {
          continue;
        }
        final probe = Directory(
          '$path${Platform.pathSeparator}.flclash_write_probe',
        );
        if (!probe.existsSync()) {
          await probe.create(recursive: true);
        }
        if (probe.existsSync()) {
          await probe.delete(recursive: true);
          return path;
        }
      } catch (_) {}
    }
    return home;
  }

  Future<String> _ensureBrowserUserDataDir() async {
    final basePath = await _resolveVisibleBaseDir();
    final folderName = system.isWindows ? 'flclash-edge' : 'flclash-chrome';
    final dir = Directory('$basePath${Platform.pathSeparator}$folderName');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    final markerFile = File(
      '${dir.path}${Platform.pathSeparator}flclash-profile.txt',
    );
    if (!markerFile.existsSync()) {
      await markerFile.writeAsString(
        'This folder is used by FlClash browser launch profile.\n',
      );
    }
    return dir.path;
  }

  Future<void> _ensureStarted(WidgetRef ref) async {
    if (ref.read(isStartProvider)) {
      return;
    }
    await appController.updateStatus(
      true,
      isInit: !ref.read(initProvider),
    );
    if (!ref.read(isStartProvider)) {
      throw 'FlClash failed to start, please check profile and core status.';
    }
  }

  Future<void> _launchWithProxy(int port, String userDataDir) async {
    final proxyArg = '--proxy-server=http://127.0.0.1:$port';
    final userDataArg = '--user-data-dir=$userDataDir';
    const homeUrl = 'https://v2free.org/';
    if (system.isWindows) {
      final env = Platform.environment;
      final localAppData = env['LOCALAPPDATA'] ?? '';
      final candidates = <String>[
        r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
        r'C:\Program Files\Microsoft\Edge\Application\msedge.exe',
        if (localAppData.isNotEmpty)
          '$localAppData${Platform.pathSeparator}Microsoft${Platform.pathSeparator}Edge${Platform.pathSeparator}Application${Platform.pathSeparator}msedge.exe',
      ];
      for (final command in candidates) {
        try {
          await Process.start(command, [
            '--new-window',
            userDataArg,
            proxyArg,
            homeUrl,
          ]);
          return;
        } catch (_) {}
      }
      await Process.start('cmd', [
        '/c',
        'start',
        '',
        'msedge',
        '--new-window',
        userDataArg,
        proxyArg,
        homeUrl,
      ]);
      return;
    }
    if (system.isMacOS) {
      await Process.start('open', [
        '-n',
        '-a',
        'Google Chrome',
        '--args',
        '--new-window',
        userDataArg,
        proxyArg,
        homeUrl,
      ]);
      return;
    }
    if (system.isLinux) {
      final commands = [
        'google-chrome',
        'google-chrome-stable',
        'chromium-browser',
        'chromium',
      ];
      for (final command in commands) {
        try {
          await Process.start(command, [
            '--new-window',
            userDataArg,
            proxyArg,
            homeUrl,
          ]);
          return;
        } catch (_) {}
      }
      throw 'Chrome is not found on this Linux system.';
    }
  }

  Future<void> _openV2free(WidgetRef ref) async {
    final hasProfile = ref.read(
      profilesProvider.select((state) => state.isNotEmpty),
    );
    if (system.isAndroid) {
      // Android: no profile means no action.
      if (!hasProfile) {
        return;
      }
      if (!ref.read(isStartProvider)) {
        await _ensureStarted(ref);
      }
      globalState.openUrl('https://v2free.org/');
      return;
    }
    if (!hasProfile) {
      throw 'No profile found. Please add a profile first.';
    }
    final port = ref.read(proxyStateProvider.select((state) => state.port));
    final isStart = ref.read(isStartProvider);
    if (!isStart) {
      await _ensureStarted(ref);
    }
    final userDataDir = await _ensureBrowserUserDataDir();
    await _launchWithProxy(port, userDataDir);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = [
      ListTile(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Consumer(
              builder: (_, ref, _) {
                return _DeveloperModeDetector(
                  child: Wrap(
                    spacing: 16,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Image.asset(
                          'assets/images/icon.png',
                          width: 64,
                          height: 64,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appName,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          Text(
                            _displayVersion(),
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ],
                      ),
                    ],
                  ),
                  onEnterDeveloperMode: () {
                    ref
                        .read(appSettingProvider.notifier)
                        .update((state) => state.copyWith(developerMode: true));
                    context.showNotifier(
                      appLocalizations.developerModeEnableTip,
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              appLocalizations.desc,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      ListItem(
        title: const Text('V2free'),
        onTap: () async {
          try {
            await _openV2free(ref);
          } catch (e) {
            globalState.showNotifier(
              '${appLocalizations.launchBrowserFailed}: $e',
            );
          }
        },
        trailing: const Icon(Icons.launch),
      ),
    ];
    return BaseScaffold(
      title: appLocalizations.about,
      body: Padding(
        padding: kMaterialListPadding.copyWith(top: 16, bottom: 16),
        child: generateListView(items),
      ),
    );
  }
}

class _DeveloperModeDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback onEnterDeveloperMode;

  const _DeveloperModeDetector({
    required this.child,
    required this.onEnterDeveloperMode,
  });

  @override
  State<_DeveloperModeDetector> createState() => _DeveloperModeDetectorState();
}

class _DeveloperModeDetectorState extends State<_DeveloperModeDetector> {
  int _counter = 0;
  Timer? _timer;

  void _handleTap() {
    _counter++;
    if (_counter >= 5) {
      widget.onEnterDeveloperMode();
      _resetCounter();
    } else {
      _timer?.cancel();
      _timer = Timer(Duration(seconds: 1), _resetCounter);
    }
  }

  void _resetCounter() {
    _counter = 0;
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: _handleTap, child: widget.child);
  }
}
