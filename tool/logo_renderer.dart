import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:perako/core/branding/perako_logo.dart';

/// Offline generator for every PeraKo launcher/app icon and a preview sheet.
///
/// Rasterizes the same vector geometry used in-app ([PerakoMarkPainter]) via
/// `dart:ui`, so the shipped icons always match the UI exactly.
///
/// Run with:
///   flutter test tool/logo_renderer.dart
void main() {
  testWidgets('render perako logo assets', (tester) async {
    await tester.runAsync(() async {
      final icons = <_IconSpec>[
        // ------------------------------------------------------------------
        // Android legacy launcher icons (5 densities)
        // ------------------------------------------------------------------
        _IconSpec('android/app/src/main/res/mipmap-mdpi/ic_launcher.png', 48, _drawAppIcon),
        _IconSpec('android/app/src/main/res/mipmap-hdpi/ic_launcher.png', 72, _drawAppIcon),
        _IconSpec('android/app/src/main/res/mipmap-xhdpi/ic_launcher.png', 96, _drawAppIcon),
        _IconSpec('android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png', 144, _drawAppIcon),
        _IconSpec('android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png', 192, _drawAppIcon),

        // ------------------------------------------------------------------
        // iOS AppIcon set (filenames match AppIcon.appiconset/Contents.json)
        // ------------------------------------------------------------------
        _IconSpec('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png', 20, _drawAppIcon),
        _IconSpec('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png', 40, _drawAppIcon),
        _IconSpec('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png', 60, _drawAppIcon),
        _IconSpec('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png', 29, _drawAppIcon),
        _IconSpec('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png', 58, _drawAppIcon),
        _IconSpec('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png', 87, _drawAppIcon),
        _IconSpec('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png', 40, _drawAppIcon),
        _IconSpec('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png', 80, _drawAppIcon),
        _IconSpec('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png', 120, _drawAppIcon),
        _IconSpec('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png', 120, _drawAppIcon),
        _IconSpec('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png', 180, _drawAppIcon),
        _IconSpec('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png', 76, _drawAppIcon),
        _IconSpec('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png', 152, _drawAppIcon),
        _IconSpec('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png', 167, _drawAppIcon),
        _IconSpec('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png', 1024, _drawAppIcon),

        // ------------------------------------------------------------------
        // macOS AppIcon set
        // ------------------------------------------------------------------
        _IconSpec('macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png', 16, _drawAppIcon),
        _IconSpec('macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png', 32, _drawAppIcon),
        _IconSpec('macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png', 64, _drawAppIcon),
        _IconSpec('macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png', 128, _drawAppIcon),
        _IconSpec('macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png', 256, _drawAppIcon),
        _IconSpec('macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png', 512, _drawAppIcon),
        _IconSpec('macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png', 1024, _drawAppIcon),

        // ------------------------------------------------------------------
        // Web PWA icons + favicon
        // ------------------------------------------------------------------
        _IconSpec('web/icons/Icon-192.png', 192, _drawAppIcon),
        _IconSpec('web/icons/Icon-512.png', 512, _drawAppIcon),
        _IconSpec('web/icons/Icon-maskable-192.png', 192, _drawMaskable),
        _IconSpec('web/icons/Icon-maskable-512.png', 512, _drawMaskable),
        _IconSpec('web/favicon.png', 32, _drawAppIcon),
      ];

      for (final spec in icons) {
        final png = await _renderPng(spec.size, spec.draw);
        await _writeFile(spec.path, png);
      }

      await _writeWindowsIco();

      final preview = await _renderPreviewSheet();
      await _writeFile('assets/branding/preview.png', preview);

      // Sanity check: every icon decodes back to its intended size.
      for (final spec in icons) {
        final codec = await ui.instantiateImageCodec(await File(spec.path).readAsBytes());
        final frame = await codec.getNextFrame();
        expect(frame.image.width, spec.size, reason: spec.path);
        frame.image.dispose();
        codec.dispose();
      }
    });
  });
}

typedef _Drawer = void Function(ui.Canvas canvas, double size);

class _IconSpec {
  const _IconSpec(this.path, this.size, this.draw);

  final String path;
  final int size;
  final _Drawer draw;
}

/// Green brand tile with the white symbol (launcher/app icons).
void _drawAppIcon(ui.Canvas canvas, double size) {
  const PerakoMarkPainter(
    style: PerakoMarkStyle.appIcon,
    symbolColor: kBrandWhite,
    accentColor: kBrandWhite,
    background: kBrandGreen,
  ).paint(canvas, ui.Size.square(size));
}

/// Full-bleed green tile for maskable web icons (safe-zone safe).
void _drawMaskable(ui.Canvas canvas, double size) {
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, size, size),
    ui.Paint()..color = kBrandGreen,
  );
  final inset = size * 0.17;
  paintPeraKoMark(
    canvas,
    bounds: ui.Rect.fromLTWH(inset, inset, size - 2 * inset, size - 2 * inset),
    symbolColor: kBrandWhite,
    accentColor: kBrandWhite,
    background: kBrandGreen,
  );
}

Future<Uint8List> _renderPng(int size, _Drawer draw) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  draw(canvas, size.toDouble());
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

Future<void> _writeFile(String path, List<int> bytes) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
  final size = await file.length();
  expect(size, greaterThan(0), reason: path);
  stdout.writeln('  wrote $file ($size bytes)');
}

Future<void> _writeWindowsIco() async {
  final entries = <_IconSpec>[
    const _IconSpec('', 16, _drawAppIcon),
    const _IconSpec('', 32, _drawAppIcon),
    const _IconSpec('', 48, _drawAppIcon),
    const _IconSpec('', 64, _drawAppIcon),
    const _IconSpec('', 256, _drawAppIcon),
  ];
  final pngs = <Uint8List>[];
  for (final e in entries) {
    pngs.add(await _renderPng(e.size, e.draw));
  }
  final ico = _buildIco(pngs, entries.map((e) => e.size).toList());
  await _writeFile('windows/runner/resources/app_icon.ico', ico);
}

/// Minimal ICO container embedding PNG entries (Windows Vista+).
Uint8List _buildIco(List<Uint8List> pngs, List<int> sizes) {
  final bb = BytesBuilder(copy: false);
  void u16(int v) => bb.add([v & 0xFF, (v >> 8) & 0xFF]);
  void u32(int v) => bb.add([v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]);

  u16(0); // reserved
  u16(1); // type: icon
  u16(pngs.length);

  var offset = 6 + 16 * pngs.length;
  final blobs = <Uint8List>[];
  for (var i = 0; i < pngs.length; i++) {
    final size = sizes[i];
    final dim = size >= 256 ? 0 : size;
    blobs.add(pngs[i]);
    bb.add([dim, dim, 0, 0, 1, 0, 32, 0]);
    u32(pngs[i].length);
    u32(offset);
    offset += pngs[i].length;
  }
  for (final blob in blobs) {
    bb.add(blob);
  }
  return bb.toBytes();
}

/// 2x2 brand preview sheet at `assets/branding/preview.png`.
Future<Uint8List> _renderPreviewSheet() async {
  const cell = 512;
  Future<ui.Image> cellImage(ui.Color background, void Function(ui.Canvas, double) draw) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(background, ui.BlendMode.src);
    draw(canvas, cell.toDouble());
    final picture = recorder.endRecording();
    return picture.toImage(cell, cell);
  }

  final images = <ui.Image>[
    // 1. Brand symbol on the primary container.
    await cellImage(kBrandPrimaryContainer, (c, s) {
      paintPeraKoMark(
        c,
        bounds: _centered(s * 0.7),
        symbolColor: kBrandBlue,
        accentColor: kBrandGreen,
      );
    }),
    // 2. App-icon tile.
    await cellImage(const ui.Color(0xFFFFFFFF), (c, s) => _drawAppIcon(c, s)),
    // 3. Monochrome mark (no accent) on the container.
    await cellImage(kBrandPrimaryContainer, (c, s) {
      paintPeraKoMark(
        c,
        bounds: _centered(s * 0.7),
        symbolColor: kBrandInk,
        accentColor: null,
      );
    }),
    // 4. White symbol on the brand blue (inverse tile).
    await cellImage(kBrandBlue, (c, s) {
      paintPeraKoMark(
        c,
        bounds: _centered(s * 0.7),
        symbolColor: kBrandWhite,
        accentColor: kBrandWhite,
        background: kBrandBlue,
      );
    }),
  ];

  try {
    final sheet = await _renderPng(cell * 2, (c, s) {
      c.drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src);
      final cellD = cell.toDouble();
      for (var i = 0; i < images.length; i++) {
        final x = (i % 2) * cellD;
        final y = (i ~/ 2) * cellD;
        c.drawImageRect(
          images[i],
          ui.Rect.fromLTWH(0, 0, cellD, cellD),
          ui.Rect.fromLTWH(x, y, cellD, cellD),
          ui.Paint(),
        );
      }
    });
    return sheet;
  } finally {
    for (final image in images) {
      image.dispose();
    }
  }
}

ui.Rect _centered(double side) {
  final inset = (512 - side) / 2;
  return ui.Rect.fromLTWH(inset, inset, side, side);
}
