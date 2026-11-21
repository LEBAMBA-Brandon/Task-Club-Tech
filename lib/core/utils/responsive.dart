import 'package:flutter/widgets.dart';

/// Points de rupture : smartphone < 600 px ≤ tablette < 1100 px ≤ desktop.
enum ScreenSize { phone, tablet, desktop }

extension ResponsiveContext on BuildContext {
  ScreenSize get screenSize {
    final width = MediaQuery.sizeOf(this).width;
    if (width >= 1100) return ScreenSize.desktop;
    if (width >= 600) return ScreenSize.tablet;
    return ScreenSize.phone;
  }

  bool get isPhone => screenSize == ScreenSize.phone;
  bool get isDesktop => screenSize == ScreenSize.desktop;
}

/// Limite la largeur du contenu sur grand écran et le centre.
class MaxWidth extends StatelessWidget {
  const MaxWidth({super.key, required this.child, this.maxWidth = 820});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
      );
}
