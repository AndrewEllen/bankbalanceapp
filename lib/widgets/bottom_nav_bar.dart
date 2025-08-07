import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:sensors_plus/sensors_plus.dart';

const _kMaxRollDeg    = 45.0;   // stop moving after ±45°
const _kMaxPitchDeg   = 45.0;   // fully narrow at 0°, fully wide at 45°
const _kMinAlpha      = 0.1;
const _kMaxAlpha      = 0.3;
const _kMinWidthFrac  = 0.1;   // keep your original floor
const _kMaxWidthFrac  = 0.70;
const _kSmoothing     = 14.0;   // bigger = snappier
const _kBlurSigma     = 1.0;    // backdrop blur strength
const _kVertRangeFrac = 0.8;   // subtle vertical travel
const _kEdgeSoftness  = 14.0;    // px of Gaussian blur on the specular band

// ---- Visual-tuning constants (unchanged except one new knob) ----
const _kNeutralPitchDeg = 40.0; // treat ~40° pitch as neutral
const _kWidthEase       = 1.35; // >1 = gentler shrink near neutral
const _kAlphaEase       = 1.10; // mild easing for brightness
const _kHorizAmt        = 0.26; // horizontal wander amount

// NEW: scale how much width is allowed to shrink overall (0..1, lower = less shrink)
const _kWidthAmount     = 0.65;

double _vCenter  = 0.5;   // smoothed Y (0 = top, 1 = bottom)
double _tVCenter = 0.5;   // sensor-driven target

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

  // Targets straight from sensors
  double _tCenter = 0.5, _tWidth = _kMaxWidthFrac, _tAlpha = _kMinAlpha;

  bool _isUpsideDown = false;
  Duration? _prevTimestamp;

  @override
  void initState() {
    super.initState();
    _accelSub = accelerometerEvents.listen(_onAccel);
    _ticker = createTicker(_tick)..start();
  }

  void _onAccel(AccelerometerEvent e) {
    // 1) Flip mapping when the phone is upside-down (top edge toward floor)
    final bool newUpsideDown = e.y > 0;
    if (newUpsideDown != _isUpsideDown) {
      if (e.y.abs() > 3.0) _isUpsideDown = newUpsideDown; // commit only when clearly flipped
    }

    // 2) Normalise gravity vector
    final double g = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    if (g == 0) return;

    double nx = e.x / g; // left-right tilt
    double nz = e.z / g; // front-back tilt (pitch-ish)

    // 3) Keep gestures natural when upside-down
    if (_isUpsideDown) {
      nx = -nx;
      nz = -nz;
    }

    // 4) Map to highlight targets with neutral pitch handling
    final double nzNeutral = math.sin(_kNeutralPitchDeg * math.pi / 180.0); // ~0.643 at 40°
    final double nzAbs = nz.abs();

    // tFromNeutral: 0 at |nz| == nzNeutral, 1 at |nz| == 1 (phone flat)
    double tFromNeutral = (nzAbs - nzNeutral);
    if (tFromNeutral < 0) tFromNeutral = 0;
    tFromNeutral /= (1.0 - nzNeutral);

    // Width: make shrink less sensitive with ease + global scale
    final double tWidthRaw = math.pow(tFromNeutral, _kWidthEase).toDouble();
    final double tWidth    = (tWidthRaw * _kWidthAmount).clamp(0.0, 1.0);

    // Alpha: keep your current mapping
    final double tAlpha  = math.pow(tFromNeutral, _kAlphaEase).toDouble();

    // Horizontal wander (unchanged)
    _tCenter = 0.5 + _kHorizAmt * nx;

    // Vertical wander: only move past neutral, eased slightly
    double vSigned = 0.0;
    if (nzAbs > nzNeutral) {
      final double vUnit = (nzAbs - nzNeutral) / (1.0 - nzNeutral); // 0..1
      vSigned = nz.sign * math.pow(vUnit, 1.2).toDouble();
    }
    _tVCenter = 0.5 + _kVertRangeFrac * vSigned;

    // Apply width & brightness
    _tWidth = _lerp(_kMaxWidthFrac, _kMinWidthFrac, tWidth);
    _tAlpha = _lerp(_kMinAlpha,     _kMaxAlpha,     tAlpha);
  }

  void _tick(Duration timestamp) {
    final dtSeconds = _prevTimestamp == null
        ? 1.0 / 60.0
        : (timestamp - _prevTimestamp!).inMicroseconds / 1e6;
    _prevTimestamp = timestamp;

    final factor = (_kSmoothing * dtSeconds).clamp(0.0, 1.0);

    _center  = _lerp(_center , _tCenter , factor);
    _width   = _lerp(_width  , _tWidth  , factor);
    _alpha   = _lerp(_alpha  , _tAlpha  , factor);
    _vCenter = _lerp(_vCenter, _tVCenter, factor);

    if (mounted) setState(() {});
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
              color: const Color.fromRGBO(67, 67, 68, 0.8),
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 4)),
            ],
          ),
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
                // Subtle tint
                Container(color: Colors.white.withOpacity(0.08)),
                // Liquid-glass specular band
                CustomPaint(
                  painter: _LiquidHighlightPainter(
                    centerFrac:   disableAnims ? 0.5            : _center,
                    verticalFrac: disableAnims ? 0.5            : _vCenter,
                    widthFrac:    disableAnims ? _kMinWidthFrac : _width,
                    alpha:        disableAnims ? _kMinAlpha     : _alpha,
                  ),
                ),
                // Nav icons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _NavIcon(
                      icon: Icons.home,
                      onPressed: () {
                        Navigator.popUntil(context, (route) => route.isFirst);
                      },
                    ),
                    _NavIcon(
                      icon: Icons.attach_money,
                      onPressed: () {
                        Navigator.pushNamed(context, '/recurring');
                      },
                    ),
                    _NavIcon(
                      icon: Icons.person,
                      onPressed: () {
                        Navigator.pushNamed(context, '/break-rules');
                      },
                    ),
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

    final gradient = const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      stops: [0.0, 0.5, 1.0],
      colors: [
        Color.fromRGBO(255, 255, 255, 0.0),
        Color.fromRGBO(255, 255, 255, 1.0),
        Color.fromRGBO(255, 255, 255, 0.0),
      ],
    );

    final paint = Paint()
      ..shader     = gradient.createShader(bandRect)
      ..blendMode  = BlendMode.plus
      ..color      = Colors.white.withOpacity(alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _kEdgeSoftness);

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
  const _NavIcon({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      splashRadius: 24,
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white, size: 26),
    );
  }
}

