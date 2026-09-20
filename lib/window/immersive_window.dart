import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

export 'package:window_manager/window_manager.dart'
    show windowManager, WindowListener, DragToMoveArea, WindowCaptionButton;

/// Windows 沉浸式窗口：隐藏系统标题栏后的高度。
const double kImmersiveTitleBarHeight = 42;

/// 顶栏内容，供各页面在无 AppBar 时填充标题/操作。
class ChromeModel extends ChangeNotifier {
  String title = 'Tally';
  Widget? leading;
  final List<Widget> actions = [];

  void update({
    String? title,
    Widget? leading,
    List<Widget>? actions,
  }) {
    var changed = false;
    if (title != null && title != this.title) {
      this.title = title;
      changed = true;
    }
    if (leading != this.leading) {
      this.leading = leading;
      changed = true;
    }
    if (actions != null) {
      this.actions
        ..clear()
        ..addAll(actions);
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }

  void clear({String title = 'Tally'}) {
    this.title = title;
    leading = null;
    actions.clear();
    notifyListeners();
  }
}

final ChromeModel appChrome = ChromeModel();

/// 强制隐藏系统标题栏和原生窗口按钮，避免 hover 时冒出白色系统条。
Future<void> applyHiddenTitleBar() async {
  if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
    return;
  }
  try {
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
  } catch (_) {}
}

/// 桌面端初始化：隐藏系统标题栏与原生按钮。
Future<void> setupDesktopWindow() async {
  if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
    return;
  }

  await windowManager.ensureInitialized();

  const options = WindowOptions(
    size: Size(1280, 720),
    center: true,
    backgroundColor: Color(0xFF1E1E2E),
    titleBarStyle: TitleBarStyle.hidden,
    skipTaskbar: false,
  );

  await windowManager.waitUntilReadyToShow(options, null);
  await applyHiddenTitleBar();
  await windowManager.setBackgroundColor(const Color(0xFF1E1E2E));
  await windowManager.setTitle('Tally');
  await windowManager.setMinimumSize(const Size(900, 600));
}

/// 自绘顶栏：左侧可拖拽（标题/操作），右侧固定窗口按钮（不参与拖拽）。
///
/// 布局对齐 window_manager 官方 WindowCaption：按钮在 Row 外侧，
/// 避免和拖拽区抢事件，也避免按钮被挤到左边。
class ImmersiveTitleBar extends StatefulWidget {
  const ImmersiveTitleBar({super.key});

  @override
  State<ImmersiveTitleBar> createState() => _ImmersiveTitleBarState();
}

class _ImmersiveTitleBarState extends State<ImmersiveTitleBar>
    with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      windowManager.addListener(this);
      _syncMaximized();
      // 启动后再压一次，清掉原生按钮热区
      WidgetsBinding.instance.addPostFrameCallback((_) {
        applyHiddenTitleBar();
      });
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowMaximize() => _syncMaximized();

  @override
  void onWindowUnmaximize() => _syncMaximized();

  @override
  void onWindowRestore() => _syncMaximized();

  @override
  void onWindowFocus() => setState(() {});

  Future<void> _syncMaximized() async {
    try {
      final v = await windowManager.isMaximized();
      if (mounted && v != _maximized) {
        setState(() => _maximized = v);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    return ListenableBuilder(
      listenable: appChrome,
      builder: (context, _) {
        return Material(
          color: scheme.surface,
          child: SizedBox(
            height: kImmersiveTitleBarHeight,
            child: Row(
              children: [
                // 左侧：标题 + 页面操作，整块可拖拽；按钮不在这里面
                Expanded(
                  child: DragToMoveArea(
                    child: SizedBox(
                      height: kImmersiveTitleBarHeight,
                      child: Row(
                        children: [
                          if (appChrome.leading != null)
                            appChrome.leading!
                          else
                            const SizedBox(width: 12),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              appChrome.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: scheme.onSurface,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          ...appChrome.actions,
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),
                ),
                // 右侧：原生感窗口按钮，固定在最右，不随标题变形
                WindowCaptionButton.minimize(
                  brightness: brightness,
                  onPressed: () => windowManager.minimize(),
                ),
                if (_maximized)
                  WindowCaptionButton.unmaximize(
                    brightness: brightness,
                    onPressed: () => windowManager.unmaximize(),
                  )
                else
                  WindowCaptionButton.maximize(
                    brightness: brightness,
                    onPressed: () => windowManager.maximize(),
                  ),
                WindowCaptionButton.close(
                  brightness: brightness,
                  onPressed: () => windowManager.close(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 手机端头部：只放标题 + 同步图标，不带窗口按钮。
class ChromeHeader extends StatelessWidget {
  const ChromeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 48,
          child: ListenableBuilder(
            listenable: appChrome,
            builder: (context, _) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    if (appChrome.leading != null) appChrome.leading!,
                    if (appChrome.leading != null) const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        appChrome.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ...appChrome.actions,
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

Widget wrapWithImmersiveChrome(Widget child) {
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    return Column(
      children: [
        const ImmersiveTitleBar(),
        Expanded(child: child),
      ],
    );
  }

  return Column(
    children: [
      const ChromeHeader(),
      Expanded(child: child),
    ],
  );
}
