import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Perako brand symbol: an abstract "P + coin".
///
/// Drawn as a geometric composition that reads as the letter "P" fused with a
/// coin/disc — a circle (the bowl) that opens toward a rounded stem (the
/// spine) that extends below as the leg. An optional rising tick at the foot
/// of the stem suggests financial growth.
///
/// Everything is vector geometry shared by the in-app widgets ([PerakoMark],
/// [PerakoLockup]) and the offline icon generator (`tool/logo_renderer.dart`),
/// so the app icon and the UI never drift apart.

/// PeraKo brand blue — `#008BF8`.
const Color kBrandBlue = AppColors.primary;

/// PeraKo brand green — `#04E762`.
const Color kBrandGreen = AppColors.success;

/// Brand white, used for symbol-on-tile applications.
const Color kBrandWhite = Color(0xFFFFFFFF);

/// Light blue tint used behind brand symbols — `#E5F3FF`.
const Color kBrandPrimaryContainer = AppColors.primaryContainer;

/// Deep navy used for monochrome marks on light surfaces — `#063A63`.
const Color kBrandInk = AppColors.primaryContainerDark;

/// Virtual 100-unit grid in which the mark is authored.
///
/// All coordinates live here; [paintPeraKoMark] fits and centers this grid
/// into any target [Rect].
class PerakoMarkGrid {
  const PerakoMarkGrid._();

  /// Bowl: the "coin" that forms the top-left of the P.
  static const Offset bowlCenter = Offset(36, 34);
  static const double bowlRadius = 30;

  /// Stem: the P's spine, a rounded bar on the right, extending below the bowl.
  static final RRect stem = RRect.fromLTRBR(60, 8, 76, 86, Radius.circular(7));

  /// Notch: negative space cut between bowl and stem that opens the P's eye.
  static const Offset notchCenter = Offset(58, 42);
  static const double notchRadius = 11;

  /// Growth accent: a short rising stroke at the stem's foot.
  static const Offset tickStart = Offset(74.5, 85.5);
  static const Offset tickEnd = Offset(80.5, 79.5);
  static const double tickWidth = 5;

  /// Union bounding box of every authored element (including the accent).
  static final Rect contentBounds = () {
    final bowl = Rect.fromCircle(center: bowlCenter, radius: bowlRadius);
    final tick = Rect.fromPoints(
      tickStart - const Offset(tickWidth / 2, tickWidth / 2),
      tickEnd + const Offset(tickWidth / 2, tickWidth / 2),
    );
    return Rect.fromLTRB(
      math.min(bowl.left, math.min(stem.left, tick.left)),
      math.min(bowl.top, math.min(stem.top, tick.top)),
      math.max(bowl.right, math.max(stem.right, tick.right)),
      math.max(bowl.bottom, math.max(stem.bottom, tick.bottom)),
    );
  }();
}

/// Paints the PeraKo "P + coin" symbol into [bounds].
///
/// [bounds] should be a square; the mark is fit inside it and centered. The
/// accent tick is only drawn when [accentColor] is non-null (pass null for a
/// strict monochrome mark). When [background] is non-null the notch gap is
/// filled with that color; otherwise the gap is left transparent so whatever
/// sits behind the painter shows through.
void paintPeraKoMark(
  ui.Canvas canvas, {
  required Rect bounds,
  required Color symbolColor,
  Color? accentColor,
  Color? background,
}) {
  final bbox = PerakoMarkGrid.contentBounds;
  final scale = bounds.shortestSide /
      math.max(bbox.width, bbox.height);
  final center = bounds.center;

  final bowl = Path()..addOval(
    Rect.fromCircle(
      center: PerakoMarkGrid.bowlCenter,
      radius: PerakoMarkGrid.bowlRadius,
    ),
  );
  final stemPath = Path()..addRRect(PerakoMarkGrid.stem);
  final body = Path.combine(PathOperation.union, bowl, stemPath);

  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.scale(scale);
  canvas.translate(-bbox.center.dx, -bbox.center.dy);

  canvas.drawPath(body, Paint()..color = symbolColor);

  if (background != null) {
    canvas.drawCircle(
      PerakoMarkGrid.notchCenter,
      PerakoMarkGrid.notchRadius,
      Paint()..color = background,
    );
  }

  if (accentColor != null) {
    final paint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = PerakoMarkGrid.tickWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(PerakoMarkGrid.tickStart, PerakoMarkGrid.tickEnd, paint);
  }

  canvas.restore();
}

/// How a [PerakoMark] should be framed.
enum PerakoMarkStyle {
  /// The symbol alone, on whatever surface it is placed.
  symbol,

  /// A rounded-square tile (blue background + white symbol), as used for
  /// launcher/app icons.
  appIcon,
}

/// The PeraKo brand symbol as a widget.
///
/// For [PerakoMarkStyle.symbol] this defaults to the brand blue symbol with
/// the green growth accent. For [PerakoMarkStyle.appIcon] it defaults to the
/// green brand tile with a white symbol. Pass [accentColor] = null (and
/// matching [symbolColor]) for monochrome usage.
class PerakoMark extends StatelessWidget {
  const PerakoMark({
    super.key,
    required this.size,
    this.symbolColor,
    this.accentColor,
    this.background,
    this.style = PerakoMarkStyle.symbol,
  });

  final double size;
  final Color? symbolColor;
  final Color? accentColor;
  final Color? background;
  final PerakoMarkStyle style;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: PerakoMarkPainter(
          symbolColor: symbolColor,
          accentColor: accentColor,
          background: background,
          style: style,
        ),
      ),
    );
  }
}

/// [CustomPainter] backing [PerakoMark].
class PerakoMarkPainter extends CustomPainter {
  const PerakoMarkPainter({
    this.symbolColor,
    this.accentColor,
    this.background,
    this.style = PerakoMarkStyle.symbol,
  });

  final Color? symbolColor;
  final Color? accentColor;
  final Color? background;
  final PerakoMarkStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    if (style == PerakoMarkStyle.appIcon) {
      final tileColor = background ?? kBrandGreen;
      final symbol = symbolColor ?? kBrandWhite;
      final accent = accentColor ?? kBrandWhite;
      final tile = RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(size.shortestSide * 0.2237),
      );
      canvas.drawRRect(tile, Paint()..color = tileColor);
      final inset = size.shortestSide * 0.175;
      paintPeraKoMark(
        canvas,
        bounds: Rect.fromLTWH(inset, inset, size.shortestSide - 2 * inset, size.shortestSide - 2 * inset),
        symbolColor: symbol,
        accentColor: accent,
        background: tileColor,
      );
      return;
    }

    paintPeraKoMark(
      canvas,
      bounds: Offset.zero & size,
      symbolColor: symbolColor ?? kBrandBlue,
      accentColor: accentColor ?? kBrandGreen,
      background: background,
    );
  }

  @override
  bool shouldRepaint(PerakoMarkPainter oldDelegate) =>
      oldDelegate.symbolColor != symbolColor ||
      oldDelegate.accentColor != accentColor ||
      oldDelegate.background != background ||
      oldDelegate.style != style;
}

/// Wordmark lockup: the [PerakoMark] beside the "PeraKo" wordmark.
///
/// When [tile] is true the mark renders as the green brand tile (matching the
/// app icon) instead of the bare symbol.
class PerakoLockup extends StatelessWidget {
  const PerakoLockup({
    super.key,
    this.markSize = 28,
    this.gap = 10,
    this.symbolColor,
    this.accentColor,
    this.tile = false,
    this.textStyle,
  });

  final double markSize;
  final double gap;
  final Color? symbolColor;
  final Color? accentColor;
  final bool tile;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PerakoMark(
          size: markSize,
          symbolColor: tile ? null : symbolColor,
          accentColor: tile ? null : accentColor,
          style: tile ? PerakoMarkStyle.appIcon : PerakoMarkStyle.symbol,
        ),
        SizedBox(width: gap),
        Flexible(
          child: Text(
            'PeraKo',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (textStyle ?? theme.textTheme.headlineSmall)?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}
