import 'dart:math';

import 'package:flutter/material.dart';

class MyButton extends StatefulWidget {
  final Widget child;

  final VoidCallback? onPressed;

  const MyButton({super.key, required this.child, this.onPressed});

  @override
  State<MyButton> createState() => _MyButtonState();
}

class _MyButtonState extends State<MyButton>
    with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 300),
    vsync: this,
  );
  
  late final AnimationController _straightenController = AnimationController(
    duration: const Duration(milliseconds: 200),
    vsync: this,
  );
  
  bool _isHovered = false;

  @override
  void dispose() {
    _controller.dispose();
    _straightenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (event) {
        setState(() {
          _isHovered = true;
        });
        _straightenController.stop();
        _controller.repeat();
      },
      onExit: (event) {
        setState(() {
          _isHovered = false;
        });
        _controller.stop(canceled: false);
        _straightenController.reset();
        _straightenController.forward();
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_controller, _straightenController]),
        builder: (context, child) {
          double rotationValue;
          if (_isHovered) {
            rotationValue = const _MySineTween(0.005).transform(_controller.value);
          } else {
            // Smoothly transition to straight position
            final currentRotation = const _MySineTween(0.005).transform(_controller.value);
            rotationValue = currentRotation * (1.0 - _straightenController.value);
          }
          
          return Transform.rotate(
            angle: rotationValue * 2 * pi,
            child: FilledButton(
              onPressed: widget.onPressed,
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}

class _MySineTween extends Animatable<double> {
  final double maxExtent;

  const _MySineTween(this.maxExtent);

  @override
  double transform(double t) {
    return sin(t * 2 * pi) * maxExtent;
  }
}
