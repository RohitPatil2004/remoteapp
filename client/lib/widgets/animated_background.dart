import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AnimatedBackground extends StatefulWidget {
  final Widget child;
  const AnimatedBackground({super.key, required this.child});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with TickerProviderStateMixin {
  late AnimationController _ctrl1, _ctrl2, _ctrl3;
  late Animation<Offset> _orb1, _orb2, _orb3;

  @override
  void initState() {
    super.initState();
    _ctrl1 =
        AnimationController(vsync: this, duration: const Duration(seconds: 8))
          ..repeat(reverse: true);
    _ctrl2 =
        AnimationController(vsync: this, duration: const Duration(seconds: 12))
          ..repeat(reverse: true);
    _ctrl3 =
        AnimationController(vsync: this, duration: const Duration(seconds: 10))
          ..repeat(reverse: true);

    _orb1 = Tween(begin: Offset.zero, end: const Offset(0.06, 0.08))
        .animate(CurvedAnimation(parent: _ctrl1, curve: Curves.easeInOut));
    _orb2 = Tween(begin: Offset.zero, end: const Offset(-0.05, 0.06))
        .animate(CurvedAnimation(parent: _ctrl2, curve: Curves.easeInOut));
    _orb3 = Tween(begin: Offset.zero, end: const Offset(0.04, -0.07))
        .animate(CurvedAnimation(parent: _ctrl3, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl1.dispose();
    _ctrl2.dispose();
    _ctrl3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        // Base dark background
        Container(color: AppTheme.bgDark),

        // Orb 1 — large amber glow (top left)
        AnimatedBuilder(
          animation: _orb1,
          builder: (_, __) => Positioned(
            left: -120 + (_orb1.value.dx * size.width),
            top: -80 + (_orb1.value.dy * size.height),
            child: _Orb(size: 380, color: AppTheme.accent.withOpacity(0.18)),
          ),
        ),

        // Orb 2 — medium orange glow (bottom right)
        AnimatedBuilder(
          animation: _orb2,
          builder: (_, __) => Positioned(
            right: -100 + (_orb2.value.dx * size.width),
            bottom: -60 + (_orb2.value.dy * size.height),
            child:
                _Orb(size: 300, color: AppTheme.accentLight.withOpacity(0.12)),
          ),
        ),

        // Orb 3 — small warm glow (center)
        AnimatedBuilder(
          animation: _orb3,
          builder: (_, __) => Positioned(
            left: size.width * 0.4 + (_orb3.value.dx * size.width),
            top: size.height * 0.35 + (_orb3.value.dy * size.height),
            child: _Orb(size: 200, color: AppTheme.accent.withOpacity(0.08)),
          ),
        ),

        // Grid overlay (subtle)
        Positioned.fill(
          child: CustomPaint(painter: _GridPainter()),
        ),

        // Content
        widget.child,
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  const _Orb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0)],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.025)
      ..strokeWidth = 0.5;
    const step = 48.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
