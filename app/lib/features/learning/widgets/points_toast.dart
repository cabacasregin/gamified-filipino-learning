import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Small floating "+N points" badge. Purely presentational — pair it with
/// [PointsToastHost] to pop it over some content for a couple seconds.
class PointsToast extends StatelessWidget {
  final int points;
  const PointsToast({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.points,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              '+$points points!',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wraps [child] and exposes [show] (via a [GlobalKey]) to briefly pop a
/// [PointsToast] over it, e.g. right after a "Nakuha ko na!" tap awards
/// points. Calling [show] with 0 or fewer points is a no-op — nothing to
/// celebrate on a repeat completion.
class PointsToastHost extends StatefulWidget {
  final Widget child;
  const PointsToastHost({super.key, required this.child});

  @override
  State<PointsToastHost> createState() => PointsToastHostState();
}

class PointsToastHostState extends State<PointsToastHost> {
  int? _points;
  int _generation = 0;

  void show(int points) {
    if (points <= 0 || !mounted) return;
    final myGeneration = ++_generation;
    setState(() => _points = points);
    Future.delayed(const Duration(milliseconds: 1100), () {
      // Only clear if a newer toast hasn't already replaced this one.
      if (mounted && _generation == myGeneration) {
        setState(() => _points = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        widget.child,
        Positioned(
          top: 12,
          child: IgnorePointer(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: _points == null
                  ? const SizedBox.shrink(key: ValueKey('empty'))
                  : PointsToast(key: ValueKey(_generation), points: _points!),
            ),
          ),
        ),
      ],
    );
  }
}
