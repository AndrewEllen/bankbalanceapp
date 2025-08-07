import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:sensors_plus/sensors_plus.dart';

const _kMaxRollDeg   = 45.0;   // stop moving after ±45°
const _kMaxPitchDeg  = 45.0;   // fully narrow at 0°, fully wide at 45°
const _kMinAlpha     = 0.05;
const _kMaxAlpha     = 0.15;
const _kMinWidthFrac = 0.15;   // band width as % of bar
const _kMaxWidthFrac = 0.70;
const _kSmoothing    = 14.0;    // bigger = snappier
const _kBlurSigma     = 4.0;  // backdrop blur strength
const _kVertRangeFrac = 0.18;  // how far the band can travel up/down
const _kEdgeSoftness  = 8.0;   // px of Gaussian blur on the specular band
double _vCenter = 0.5;          // smoothed Y (0 = top, 1 = bottom)
double _tVCenter = 0.5;         // sensor-driven target



class BottomNavBar extends StatefulWidget {
  const BottomNavBar({super.key});

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> with SingleTickerProviderStateMixin {
  // Smoothed highlight parameters
  double _center = 0.5;   // 0–1, 0 = left, 1 = right
  double _width  = _kMaxWidthFrac;
  double _alpha  = _kMinAlpha;

  late final StreamSubscription _accelSub;
  late final Ticker _ticker;

  // Target values straight from sensors
  double _tCenter = 0.5, _tWidth = _kMaxWidthFrac, _tAlpha = _kMinAlpha;

  @override
  void initState() {
    super.initState();

    // Listen to accelerometer
    _accelSub = accelerometerEvents.listen(_onAccel);

    // Paint at vsync to apply smoothing
    _ticker = createTicker(_tick)..start();
  }

  bool _isUpsideDown = false;

  void _onAccel(AccelerometerEvent e) {
    // ────────────── 1. Decide if we should flip the mapping ──────────────
    // y > 0 means the phone’s top edge is pointing toward the floor.
    // Only commit to the flip after |y| > 3 m/s² to avoid jitter at 90 °.
    final bool newUpsideDown = e.y > 0;
    if (newUpsideDown != _isUpsideDown) {
      if (e.y.abs() > 3.0) _isUpsideDown = newUpsideDown;
    }

    // ────────────── 2. Normalise gravity vector ──────────────
    final double g = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    if (g == 0) return;                    // safety

    double nx = e.x / g;                   // side-to-side tilt  (-1 … +1)
    double nz = e.z / g;                   // front-back tilt    (-1 … +1)

    // ────────────── 3. Keep gestures natural when upside-down ────────────
    if (_isUpsideDown) {
      nx = -nx;                            // invert left ↔ right
      nz = -nz;                            // invert front ↔ back
    }

    // ────────────── 4. Map to highlight targets ──────────────
    _tCenter = 0.5 + 0.30 * nx;            // horizontal wander (±30 % of bar)
    final nzAbs = nz.abs();
    _tVCenter = 0.5 + _kVertRangeFrac * nz;   // vertical wander (≈20 %)
    _tWidth   = _lerp(_kMinWidthFrac, _kMaxWidthFrac, 1 - nzAbs);
    _tAlpha   = _lerp(_kMinAlpha,     _kMaxAlpha,     1 - nzAbs);
  }



  Duration? _prevTimestamp;          // add this field to the State class

  void _tick(Duration timestamp) {
    // Work out how many seconds have passed since the previous tick
    final dtSeconds = _prevTimestamp == null
        ? 1.0 / 60.0                        // first frame → assume 60 fps
        : (timestamp - _prevTimestamp!).inMicroseconds / 1e6;
    _prevTimestamp = timestamp;

    // Exponential smoothing – clamp factor to [0,1] for safety
    final factor = (_kSmoothing * dtSeconds).clamp(0.0, 1.0);

    _center = _lerp(_center, _tCenter, factor);
    _width  = _lerp(_width , _tWidth , factor);
    _alpha  = _lerp(_alpha , _tAlpha , factor);
    _vCenter = _lerp(_vCenter, _tVCenter, factor);

    if (mounted) setState(() {});   // trigger repaint
  }


  static double _lerp(double a, double b, double t) => a + (b - a) * t.clamp(0.0, 1.0);

  @override
  void dispose() {
    _accelSub.cancel();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnims = MediaQuery.of(context).disableAnimations;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: constraints.maxWidth,
          height: 56,
          margin: const EdgeInsets.symmetric(horizontal: 100, vertical: 8),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Color.fromRGBO(67, 67, 68, 0.8), // pick any Color
                width: 2,           // stroke thickness
              ),
              boxShadow: [
            BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 4))
          ]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Frosted glass base
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: _kBlurSigma, sigmaY: _kBlurSigma),
                  child: const SizedBox(),
                ),
                // Tint (light/dark based on backdrop luminance could be added here)
                Container(color: Colors.white.withOpacity(0.08)),
                // Liquid-glass specular band
                CustomPaint(
                  painter: _LiquidHighlightPainter(
                    centerFrac:  disableAnims ? 0.5           : _center,
                    verticalFrac: disableAnims ? 0.5           : _vCenter,
                    widthFrac:   disableAnims ? _kMinWidthFrac : _width,
                    alpha:       disableAnims ? _kMinAlpha     : _alpha,
                  ),
                ),
                // Nav icons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: const [
                    _NavIcon(icon: Icons.home),
                    _NavIcon(icon: Icons.search),
                    _NavIcon(icon: Icons.person),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The dynamic specular highlight band
class _LiquidHighlightPainter extends CustomPainter {
  _LiquidHighlightPainter({
    required this.centerFrac,
    required this.verticalFrac,
    required this.widthFrac,
    required this.alpha,
  });

  final double centerFrac;   // 0–1 across width
  final double verticalFrac; // 0–1 down height
  final double widthFrac;    // 0–1 of total width
  final double alpha;        // 0–1 opacity of band core

  @override
  void paint(Canvas canvas, Size size) {
    final bandWidth = size.width * widthFrac;
    final centerX   = size.width  * centerFrac;
    final centerY   = size.height * verticalFrac;
    final bandRect  = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: bandWidth,
      height: size.height * 0.8,
    );

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(bandRect, Radius.circular(size.height * 0.4)));

    final gradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      stops: const [0.0, 0.5, 1.0],
      colors: [
        Colors.white.withOpacity(0.0),
        Colors.white.withOpacity(alpha),
        Colors.white.withOpacity(0.0),
      ],
    );

    final paint = Paint()
      ..shader     = gradient.createShader(bandRect)
      ..blendMode  = BlendMode.plus
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, _kEdgeSoftness);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LiquidHighlightPainter old) =>
      old.centerFrac   != centerFrac   ||
          old.verticalFrac != verticalFrac ||
          old.widthFrac    != widthFrac    ||
          old.alpha        != alpha;
}


class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      splashRadius: 24,
      onPressed: () {},
      icon: Icon(icon, color: Colors.white, size: 26),
    );
  }
}
