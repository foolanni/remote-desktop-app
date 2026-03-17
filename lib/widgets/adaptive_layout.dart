import 'package:flutter/material.dart';

/// 自适应布局工具：根据屏幕宽度区分手机/平板布局
class AdaptiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  static const double tabletBreakpoint = 600;

  const AdaptiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
  });

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreakpoint;

  @override
  Widget build(BuildContext context) {
    if (isTablet(context) && tablet != null) {
      return tablet!;
    }
    return mobile;
  }
}

/// 平板双栏布局（左侧列表 + 右侧详情）
class TabletSplitView extends StatelessWidget {
  final Widget sidebar;
  final Widget content;
  final double sidebarWidth;

  const TabletSplitView({
    super.key,
    required this.sidebar,
    required this.content,
    this.sidebarWidth = 320,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: sidebarWidth,
          child: Material(
            elevation: 1,
            child: sidebar,
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: content),
      ],
    );
  }
}
