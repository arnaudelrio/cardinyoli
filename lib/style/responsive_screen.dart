import 'package:flutter/material.dart';

/// A widget that adapts its layout to the screen size.
///
/// It displays a [squarishMainArea] and a [rectangularMenuArea].
/// On wide screens (width >= 450 pixels), these are displayed side-by-side,
/// with the main area taking more space. On narrow screens (width < 450 pixels),
/// they are stacked vertically.
class ResponsiveScreen extends StatelessWidget {
  final Widget squarishMainArea;
  final Widget rectangularMenuArea;

  const ResponsiveScreen({
    super.key,
    required this.squarishMainArea,
    required this.rectangularMenuArea,
  });

  static const _widthBreakpoint = 900.0;
  static const _gap = SizedBox(height: 50);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SafeArea(
          child: constraints.maxWidth < _widthBreakpoint
              ? Column(
                  children: [
                    // The squarishMainArea takes up all available vertical space
                    // above the menu area, allowing its content to scroll if needed.
                    Expanded(
                      child: squarishMainArea,
                    ),
                    _gap, // Space between main content and menu buttons
                    // The rectangularMenuArea takes its intrinsic height.
                    rectangularMenuArea,
                    _gap, // Bottom padding for the menu area.
                  ],
                )
              : Row(
                  children: [
                    // The main content area takes 3/5 of the available width.
                    Expanded(
                      flex: 3,
                      child: squarishMainArea,
                    ),
                    // The menu area takes 2/5 of the available width.
                    // Its content is centered within this space to prevent stretching
                    // and provide natural alignment for buttons.
                    Expanded(
                      flex: 2,
                      child: Center(child: rectangularMenuArea),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
