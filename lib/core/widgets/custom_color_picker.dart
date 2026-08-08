import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../features/accounts/presentation/account_style.dart';

/// Opens a modal bottom sheet for picking an arbitrary color. The picked
/// color is delivered through [onChanged] as a `#RRGGBB` hex string.
Future<void> showCustomColorPicker(
  BuildContext context, {
  required Color initial,
  required ValueChanged<String> onChanged,
}) async {
  final picked = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CustomColorSheet(initial: initial),
  );
  if (picked != null) onChanged(picked);
}

class _CustomColorSheet extends StatefulWidget {
  const _CustomColorSheet({required this.initial});

  final Color initial;

  @override
  State<_CustomColorSheet> createState() => _CustomColorSheetState();
}

class _CustomColorSheetState extends State<_CustomColorSheet> {
  late HSVColor _hsv;
  late final TextEditingController _hex;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initial);
    _hex = TextEditingController(text: colorToHex(widget.initial));
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  Color get _preview => _hsv.toColor();

  void _setHsv(HSVColor value) {
    setState(() {
      _hsv = value;
      _hex.text = colorToHex(_preview);
    });
  }

  void _onHexChanged(String raw) {
    final parsed = tryParseHexColor(raw);
    if (parsed == null) return;
    setState(() => _hsv = HSVColor.fromColor(parsed));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Custom color',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Center(child: _HueRing(hue: _hsv.hue, onChanged: _setHue)),
          const SizedBox(height: 12),
          _SliderLabel(
            label: 'Saturation',
            child: _GradientSlider(
              value: _hsv.saturation,
              colors: [
                HSVColor.fromAHSV(1, _hsv.hue, 0, _hsv.value).toColor(),
                HSVColor.fromAHSV(1, _hsv.hue, 1, _hsv.value).toColor(),
              ],
              onChanged: (v) => _setHsv(_hsv.withSaturation(v)),
            ),
          ),
          const SizedBox(height: 12),
          _SliderLabel(
            label: 'Brightness',
            child: _GradientSlider(
              value: _hsv.value,
              colors: [
                HSVColor.fromAHSV(1, _hsv.hue, _hsv.saturation, 0).toColor(),
                HSVColor.fromAHSV(1, _hsv.hue, _hsv.saturation, 1).toColor(),
              ],
              onChanged: (v) => _setHsv(_hsv.withValue(v)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _preview,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const Key('custom-color-hex'),
                  controller: _hex,
                  decoration: const InputDecoration(
                    labelText: 'Hex',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: _onHexChanged,
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () => Navigator.pop(context, colorToHex(_preview)),
                child: const Text('Select'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _setHue(double hue) => _setHsv(_hsv.withHue(hue));
}

class _SliderLabel extends StatelessWidget {
  const _SliderLabel({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

/// A hue wheel: a ring painted with the rainbow spectrum. Dragging anywhere on
/// it updates the hue.
class _HueRing extends StatelessWidget {
  const _HueRing({required this.hue, required this.onChanged});

  final double hue;
  final ValueChanged<double> onChanged;

  static const double _size = 180;
  static const double _thickness = 26;

  void _handle(Offset localPosition, BoxConstraints constraints) {
    final center = constraints.biggest.center(Offset.zero);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    var angle = math.atan2(dy, dx) * 180 / math.pi + 90;
    if (angle < 0) angle += 360;
    onChanged(angle % 360);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: LayoutBuilder(
        builder: (context, constraints) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) => _handle(d.localPosition, constraints),
          onPanUpdate: (d) => _handle(d.localPosition, constraints),
          child: CustomPaint(
            size: Size(_size, _size),
            painter: _HueRingPainter(hue: hue),
          ),
        ),
      ),
    );
  }
}

class _HueRingPainter extends CustomPainter {
  _HueRingPainter({required this.hue});

  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - _HueRing._thickness / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _HueRing._thickness
      ..shader = SweepGradient(
        colors: [
          for (var h = 0; h <= 360; h += 60)
            HSVColor.fromAHSV(1, h % 360, 1, 1).toColor(),
        ],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);
    canvas.drawCircle(center, radius, ring);

    final radians = (hue - 90) * math.pi / 180;
    final thumbCenter =
        center + Offset(math.cos(radians), math.sin(radians)) * radius;
    canvas.drawCircle(thumbCenter, 9, Paint()..color = Colors.white);
    canvas.drawCircle(
      thumbCenter,
      9,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.black26,
    );
  }

  @override
  bool shouldRepaint(covariant _HueRingPainter oldDelegate) =>
      oldDelegate.hue != hue;
}

/// A thin gradient track with a draggable thumb for the 0..1 axes.
class _GradientSlider extends StatelessWidget {
  const _GradientSlider({
    required this.value,
    required this.colors,
    required this.onChanged,
  });

  final double value;
  final List<Color> colors;
  final ValueChanged<double> onChanged;

  static const double _thumbSize = 22;

  void _update(double dx, double width) {
    final track = math.max(0, width - _thumbSize);
    onChanged((dx / track).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: 30,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _update(d.localPosition.dx, width),
            onHorizontalDragUpdate: (d) => _update(d.localPosition.dx, width),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: LinearGradient(colors: colors),
                  ),
                ),
                Align(
                  alignment: Alignment(-1 + 2 * value, 0),
                  child: Container(
                    width: _thumbSize,
                    height: _thumbSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.black26, width: 1.5),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
