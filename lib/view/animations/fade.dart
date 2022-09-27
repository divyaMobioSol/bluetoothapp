import 'package:flutter/material.dart';
import 'package:simple_animations/simple_animations.dart';
import 'package:supercharged/supercharged.dart';

enum AnimationProps { opacity, translateY }

class Fade extends StatelessWidget {
  final double delay;
  final Widget child;

  Fade(this.delay, this.child);

  @override
  Widget build(BuildContext context) {
    final tween = Tween(begin: 100.0, end: 200.0);
 

    return MirrorAnimationBuilder(

      duration: Duration(seconds: 5),
      tween: tween,
      child: child,
      builder: (context, value, child) =>
          Transform.translate(offset: Offset(0, 70), child: child),
    );
  }
}
