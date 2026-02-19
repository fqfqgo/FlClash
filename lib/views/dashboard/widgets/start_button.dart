import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StartButton extends ConsumerStatefulWidget {
  const StartButton({super.key});

  @override
  ConsumerState<StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends ConsumerState<StartButton>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late Animation<double> _animation;
  bool isStart = false;

  @override
  void initState() {
    super.initState();
    isStart = ref.read(isStartProvider);
    _controller = AnimationController(
      vsync: this,
      value: isStart ? 1 : 0,
      duration: const Duration(milliseconds: 200),
    );
    _animation = CurvedAnimation(
      parent: _controller!,
      curve: Curves.easeOutBack,
    );
    ref.listenManual(isStartProvider, (prev, next) {
      if (next != isStart) {
        isStart = next;
        updateController();
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  void handleSwitchStart() {
    isStart = !isStart;
    updateController();
    debouncer.call(FunctionTag.updateStatus, () {
      appController.updateStatus(isStart, isInit: !ref.read(initProvider));
    }, duration: commonDuration);
  }

  void updateController() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isStart && mounted) {
        _controller?.forward();
      } else {
        _controller?.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasProfile = ref.watch(
      profilesProvider.select((state) => state.isNotEmpty),
    );
    if (!hasProfile) {
      return Container();
    }
    return Theme(
      data: Theme.of(context).copyWith(
        floatingActionButtonTheme: Theme.of(context).floatingActionButtonTheme
            .copyWith(
              sizeConstraints: BoxConstraints(minWidth: 56, maxWidth: 200),
            ),
      ),
      child: AnimatedBuilder(
        animation: _controller!.view,
        builder: (_, child) {
          final textWidth =
              globalState.measure
                  .computeTextSize(
                    Text(
                      utils.getTimeDifference(DateTime.now()),
                      style: context.textTheme.titleMedium?.toSoftBold,
                    ),
                  )
                  .width +
              16;
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: FloatingActionButton(
              clipBehavior: Clip.antiAlias,
              materialTapTargetSize: MaterialTapTargetSize.padded,
              mouseCursor: SystemMouseCursors.click,
              heroTag: null,
              onPressed: () {
                handleSwitchStart();
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 56,
                    width: 56,
                    alignment: Alignment.center,
                    child: AnimatedIcon(
                      icon: AnimatedIcons.play_pause,
                      progress: _animation,
                    ),
                  ),
                  SizedBox(width: textWidth * _animation.value, child: child!),
                ],
              ),
            ),
          );
        },
        child: Consumer(
          builder: (_, ref, _) {
            final runTime = ref.watch(runTimeProvider);
            final text = utils.getTimeText(runTime);
            return Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.visible,
              style: Theme.of(context).textTheme.titleMedium?.toSoftBold
                  .copyWith(color: context.colorScheme.onPrimaryContainer),
            );
          },
        ),
      ),
    );
  }
}

class LaunchBrowserButton extends ConsumerWidget {
  const LaunchBrowserButton({super.key});

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
      } catch (_) {
        // try next candidate
      }
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
    // Write a marker file so users can quickly verify the folder location.
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
    const homeUrl = 'https://www.google.com';
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
        } catch (_) {
          // try next command
        }
      }
      // Fallback to command-in-shell style for unusual installations.
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
        } catch (_) {
          // try next command
        }
      }
      throw 'Chrome is not found on this Linux system.';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (system.isAndroid) {
      return const SizedBox.shrink();
    }
    final hasProfile = ref.watch(
      profilesProvider.select((state) => state.isNotEmpty),
    );
    if (!hasProfile) {
      return const SizedBox.shrink();
    }
    final isStart = ref.watch(isStartProvider);
    final port = ref.watch(proxyStateProvider.select((state) => state.port));
    return Theme(
      data: Theme.of(context).copyWith(
        floatingActionButtonTheme: Theme.of(context).floatingActionButtonTheme
            .copyWith(
              sizeConstraints: const BoxConstraints.tightFor(
                width: 56,
                height: 56,
              ),
            ),
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: FloatingActionButton(
          clipBehavior: Clip.antiAlias,
          materialTapTargetSize: MaterialTapTargetSize.padded,
          mouseCursor: SystemMouseCursors.click,
          heroTag: null,
          tooltip: appLocalizations.launchBrowser,
          onPressed: () async {
            try {
              if (!isStart) {
                await _ensureStarted(ref);
              }
              final userDataDir = await _ensureBrowserUserDataDir();
              await _launchWithProxy(port, userDataDir);
            } catch (e) {
              globalState.showNotifier('${appLocalizations.launchBrowserFailed}: $e');
            }
          },
          child: const SizedBox(
            width: 56,
            height: 56,
            child: Center(child: Icon(Icons.language)),
          ),
        ),
      ),
    );
  }
}
