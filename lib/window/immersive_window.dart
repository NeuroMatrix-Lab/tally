import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

export 'package:window_manager/window_manager.dart' show windowManager;

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

/// 桌面端初始化：隐藏系统标题栏，窗口底色对齐 Tally 深色。
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
  await windowManager.setBackgroundColor(const Color(0xFF1E1E2E));
  await windowManager.setTitle('Tally');
  await windowManager.setMinimumSize(const Size(900, 600));
}

/// 自绘顶栏：整条可拖拽，右侧最小化/最大化/关闭。
class ImmersiveTitleBar extends StatefulWidget {
  const ImmersiveTitleBar({super.key});

  @override
  State<ImmersiveTitleBar> createState() => _ImmersiveTitleBarState();
}

class _ImmersiveTitleBarState extends State<ImmersiveTitleBar> with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      windowManager.addListener(this);
      _syncMaximized();
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

  Future<void> _syncMaximized() async {
    try {
      final v = await windowManager.isMaximized();
      if (mounted && v != _maximized) {
        setState(() => _maximized = v);
      }
    } catch (_) {}
  }

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
    await _syncMaximized();
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: appChrome,
      builder: (context, _) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) {
            windowManager.startDragging();
          },
          onDoubleTap: _toggleMaximize,
          child: Material(
            color: scheme.surface,
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
                  const SizedBox(width: 4),
                  _CaptionButton(
                    tooltip: '最小化',
                    icon: Icons.remove_rounded,
                    onTap: () => windowManager.minimize(),
                  ),
                  _CaptionButton(
                    tooltip: _maximized ? '还原' : '最大化',
                    icon: _maximized
                        ? Icons.filter_none_rounded
                        : Icons.crop_square_rounded,
                    onTap: _toggleMaximize,
                  ),
                  _CaptionButton(
                    tooltip: '关闭',
                    icon: Icons.close_rounded,
                    hoverColor: const Color(0xFFE81123),
                    onTap: () => windowManager.close(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CaptionButton extends StatefulWidget {
  const _CaptionButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.hoverColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final Color? hoverColor;

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hover = widget.hoverColor ?? scheme.onSurface.withValues(alpha: 0.08);
    final iconColor = _hover && widget.hoverColor != null
        ? Colors.white
        : scheme.onSurface.withValues(alpha: 0.85);

    final btn = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 46,
          height: kImmersiveTitleBarHeight,
          color: _hover ? hover : Colors.transparent,
          child: Icon(widget.icon, size: 16, color: iconColor),
        ),
      ),
    );

    if (widget.tooltip == null) return btn;
    return Tooltip(message: widget.tooltip!, child: btn);
  }
}

/// 手机端头部：只放标题 + 同步图标，不带窗口按钮，不依赖系统标题栏。
class ChromeHeader extends StatelessWidget {
  const ChromeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    // 桌面由 ImmersiveTitleBar 负责
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

/// 非 Windows 等桌面端时，用普通高度占位，避免布局跳动。
Widget wrapWithImmersiveChrome(Widget child) {
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    return Column(
      children: [
        const ImmersiveTitleBar(),
        Expanded(child: child),
      ],
    );
  }

  // 手机：无系统顶栏需求，但标题和同步图标要可见
  return Column(
    children: [
      const ChromeHeader(),
      Expanded(child: child),
    ],
  );
}
