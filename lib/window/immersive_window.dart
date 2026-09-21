import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../theme/app_theme.dart';

export 'package:window_manager/window_manager.dart' show windowManager;

/// 桌面端窗口初始化：保留系统标题栏（关闭/最小化/最大化），不再自绘顶栏。
Future<void> setupDesktopWindow() async {
  if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
    return;
  }

  await windowManager.ensureInitialized();

  const options = WindowOptions(
    size: Size(1280, 720),
    center: true,
    backgroundColor: Color(0xFF1E1E2E),
    titleBarStyle: TitleBarStyle.normal,
    skipTaskbar: false,
  );

  await windowManager.waitUntilReadyToShow(options, null);
  await windowManager.setBackgroundColor(const Color(0xFF1E1E2E));
  await windowManager.setTitle('Tally');
  await windowManager.setMinimumSize(const Size(900, 600));
}

/// 页内标题栏：紧凑标题 + 可选同步指示 + 操作。
class PageTitleBar extends StatelessWidget {
  const PageTitleBar({
    super.key,
    required this.title,
    this.isSyncing,
    this.isServerConnected,
    this.onSync,
    this.actions = const [],
    this.padding = const EdgeInsets.fromLTRB(16, 4, 8, 0),
  });

  final String title;
  final bool? isSyncing;
  final bool? isServerConnected;
  final VoidCallback? onSync;
  final List<Widget> actions;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ...actions,
            if (isSyncing == true)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (onSync != null && isServerConnected != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onSync,
                tooltip: isServerConnected! ? '已连接服务器' : '服务器未连接，点击同步',
                icon: Icon(
                  isServerConnected! ? Icons.cloud_done : Icons.cloud_off,
                  size: 20,
                  color: isServerConnected!
                      ? AppColors.success
                      : AppColors.error,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
