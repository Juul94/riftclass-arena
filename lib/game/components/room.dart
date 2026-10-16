import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show Alignment, HSLColor, LinearGradient;

import '../../models/world_theme.dart';
import '../config.dart';

/// Renders a 3D isometric dungeon room with proper depth, walls, torches,
/// floor tiles and atmospheric lighting.
class Room extends PositionComponent {
  Room({required this.theme, this.waveVariant = 0})
      : super(
          size: Vector2(GameConfig.roomWidth, GameConfig.roomHeight),
          priority: -100,
        );

  final WorldTheme theme;
  final int waveVariant;
  late final Random _rng = Random(42 + waveVariant);

  // ── Layout ──
  static const double _margin = 16.0;
  static const double _wallW = 20.0;     // side wall thickness
  static const double _backWallH = 44.0; // back wall height
  static const double _wallDepth = 10.0; // 3D depth offset
  static const double _frontEdge = 12.0;

  double get _floorL => _margin + _wallW;
  double get _floorT => _margin + _backWallH;
  double get _floorR => GameConfig.roomWidth - _margin - _wallW;
  double get _floorB => GameConfig.roomHeight - _margin - _frontEdge;
  double get _floorW => _floorR - _floorL;
  double get _floorH => _floorB - _floorT;

  // Tile grid
  static const double _tw = 54.0;
  static const double _th = 27.0;

  late int _cols;
  late int _rows;
  late List<List<int>> _tileVariant;
  late List<Offset> _cracks;

  // ── Static render cache (floor/walls baked once into a GPU image) ──
  static const double _cacheScale = 2.0;
  Image? _staticImage;
  final Paint _imagePaint = Paint()..filterQuality = FilterQuality.low;

  // ── Animation ──
  double _time = 0;
  late List<_Mote> _motes;

  List<Offset> get _torchPositions => [
        Offset(_floorL + 40, _margin + _backWallH - 4),
        Offset(_floorR - 40, _margin + _backWallH - 4),
        Offset(_margin + 8, GameConfig.roomHeight * 0.42),
        Offset(GameConfig.roomWidth - _margin - 8, GameConfig.roomHeight * 0.42),
      ];

  @override
  Future<void> onLoad() async {
    _cols = (_floorW / _tw).floor();
    _rows = (_floorH / _th).floor();

    _tileVariant = List.generate(
      _rows,
      (r) => List.generate(_cols, (c) => _rng.nextInt(8)),
    );

    _cracks = List.generate(
      10,
      (_) => Offset(
        _floorL + _rng.nextDouble() * _floorW,
        _floorT + _rng.nextDouble() * _floorH,
      ),
    );

    // Ambient floating particles (embers/spores/dust depending on theme)
    _motes = List.generate(18, (_) {
      return _Mote(
        x: _floorL + _rng.nextDouble() * _floorW,
        phase: _rng.nextDouble() * 600,
        speed: 6 + _rng.nextDouble() * 14,
        drift: 4 + _rng.nextDouble() * 10,
        size: 1.0 + _rng.nextDouble() * 1.8,
      );
    });

    _buildStaticCache();
  }

  @override
  void onRemove() {
    _staticImage?.dispose();
    _staticImage = null;
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  /// Bakes every static element into a single raster image so the per-frame
  /// cost of the room is one textured quad instead of hundreds of draw calls.
  void _buildStaticCache() {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(_cacheScale);

    canvas.drawRect(size.toRect(), _bgPaint);
    _drawFloor(canvas);
    _drawCracks(canvas);
    _drawWalls(canvas);
    _drawPillars(canvas);
    _drawTorchBrackets(canvas);
    _drawLightShafts(canvas);
    _drawVignette(canvas);

    final picture = recorder.endRecording();
    _staticImage = picture.toImageSync(
      (GameConfig.roomWidth * _cacheScale).toInt(),
      (GameConfig.roomHeight * _cacheScale).toInt(),
    );
    picture.dispose();
  }

  // ── Paint cache (avoid allocations in render) ──
  final Paint _bgPaint = Paint()..color = const Color(0xFF050510);
  final Paint _gridPaint = Paint()
    ..color = const Color(0x18FFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.5;
  final Paint _tilePaint = Paint();
  final Paint _crackPaint = Paint()
    ..color = const Color(0x30FFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.6;

  @override
  void render(Canvas canvas) {
    final img = _staticImage;
    if (img != null) {
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        size.toRect(),
        _imagePaint,
      );
    }

    // Animated layers on top of the baked room.
    _drawTorchFlames(canvas);
    _drawMotes(canvas);
  }

  // ── Ambient motes (floating embers / spores) ──

  final Paint _motePaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

  void _drawMotes(Canvas canvas) {
    final ac = theme.accentColor;
    for (final m in _motes) {
      final travel = (_time * m.speed + m.phase) % (_floorH + 40);
      final y = _floorB + 20 - travel;
      final x = m.x + sin(_time * 0.8 + m.phase) * m.drift;
      final alpha = (0.12 + 0.12 * sin(_time * 2 + m.phase)) *
          // fade near top/bottom of travel
          (travel < 40 ? travel / 40 : 1.0) *
          (y < _floorT + 40 ? ((y - _floorT) / 40).clamp(0.0, 1.0) : 1.0);
      if (alpha <= 0.01) continue;
      _motePaint.color = ac.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), m.size, _motePaint);
    }
  }

  // ── Floor ──

  void _drawFloor(Canvas canvas) {
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(_floorL - 1, _floorT - 1, _floorR + 1, _floorB + 1));

    // Depth gradient base (darker at top, lighter at bottom)
    final gradPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          theme.floorPrimary.withValues(alpha: 0.5),
          theme.floorPrimary,
        ],
      ).createShader(Rect.fromLTRB(_floorL, _floorT, _floorR, _floorB));
    canvas.drawRect(
      Rect.fromLTRB(_floorL, _floorT, _floorR, _floorB),
      gradPaint,
    );

    // Isometric diamond tiles
    for (int r = 0; r < _rows; r++) {
      for (int c = 0; c < _cols; c++) {
        final cx = _floorL + c * _tw + _tw / 2;
        final cy = _floorT + r * _th + _th / 2;

        final path = Path()
          ..moveTo(cx, cy - _th / 2)
          ..lineTo(cx + _tw / 2, cy)
          ..lineTo(cx, cy + _th / 2)
          ..lineTo(cx - _tw / 2, cy)
          ..close();

        // Tile colour from variant
        final v = _tileVariant[r][c];
        final Color tileColor;
        if (v < 4) {
          tileColor = theme.floorPrimary;
        } else if (v < 6) {
          tileColor = theme.floorSecondary;
        } else if (v == 6) {
          tileColor = Color.lerp(theme.floorPrimary, theme.wallColor, 0.2)!;
        } else {
          tileColor = Color.lerp(theme.floorSecondary, theme.floorPrimary, 0.5)!;
        }

        _tilePaint.color = tileColor;
        canvas.drawPath(path, _tilePaint);
        canvas.drawPath(path, _gridPaint);
      }
    }
    canvas.restore();
  }

  // ── 3D Walls ──

  void _drawWalls(Canvas canvas) {
    final wc = theme.wallColor;
    final wcTop = _lighten(wc, 0.12);
    final wcInner = _lighten(wc, 0.06);

    final roomW = GameConfig.roomWidth;
    final roomH = GameConfig.roomHeight;

    // ── Back wall (top of screen) ──
    // Main face
    canvas.drawRect(
      Rect.fromLTWH(_margin, _margin, roomW - 2 * _margin, _backWallH),
      Paint()..color = wc,
    );
    // Inner face (bottom edge, lighter – 3D depth)
    canvas.drawRect(
      Rect.fromLTWH(_floorL, _margin + _backWallH, _floorW, _wallDepth),
      Paint()..color = wcInner,
    );
    // Top highlight strip
    canvas.drawRect(
      Rect.fromLTWH(_margin, _margin, roomW - 2 * _margin, 3),
      Paint()..color = wcTop,
    );
    // Stone brick lines
    _drawBricks(canvas, _margin + 10, _margin + 8, roomW - 2 * _margin - 20, _backWallH - 12, wc);

    // ── Left wall ──
    canvas.drawRect(
      Rect.fromLTWH(_margin, _margin + _backWallH, _wallW, roomH - 2 * _margin - _backWallH),
      Paint()..color = wc,
    );
    // Inner face (right edge)
    canvas.drawRect(
      Rect.fromLTWH(_floorL, _floorT + _wallDepth, _wallDepth * 0.6, _floorH - _wallDepth),
      Paint()..color = wcInner,
    );

    // ── Right wall ──
    canvas.drawRect(
      Rect.fromLTWH(roomW - _margin - _wallW, _margin + _backWallH, _wallW, roomH - 2 * _margin - _backWallH),
      Paint()..color = wc,
    );
    // Inner face (left edge)
    canvas.drawRect(
      Rect.fromLTWH(_floorR - _wallDepth * 0.6, _floorT + _wallDepth, _wallDepth * 0.6, _floorH - _wallDepth),
      Paint()..color = wcInner,
    );

    // ── Front edge (bottom) ──
    canvas.drawRect(
      Rect.fromLTWH(_margin, _floorB, roomW - 2 * _margin, _frontEdge),
      Paint()..color = wc,
    );
    // Top face of front edge
    canvas.drawRect(
      Rect.fromLTWH(_floorL, _floorB, _floorW, 3),
      Paint()..color = wcTop,
    );

    // ── Accent border ──
    canvas.drawRect(
      Rect.fromLTRB(_floorL, _floorT, _floorR, _floorB),
      Paint()
        ..color = theme.accentColor.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  void _drawBricks(Canvas canvas, double x, double y, double w, double h, Color wc) {
    final paint = Paint()
      ..color = _lighten(wc, 0.04)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const brickH = 10.0;
    int row = 0;
    for (double by = y; by < y + h; by += brickH) {
      canvas.drawLine(Offset(x, by), Offset(x + w, by), paint);
      final offset = row.isEven ? 0.0 : 22.0;
      for (double bx = x + offset; bx < x + w; bx += 44) {
        canvas.drawLine(Offset(bx, by), Offset(bx, by + brickH), paint);
      }
      row++;
    }
  }

  // ── Pillars ──

  void _drawPillars(Canvas canvas) {
    final pc = _lighten(theme.wallColor, 0.08);
    final pH = 50.0;
    final pW = 14.0;

    final positions = [
      Offset(_floorL - 2, _floorT),          // top‑left
      Offset(_floorR - pW + 2, _floorT),     // top‑right
      Offset(_floorL - 2, _floorB - pH),     // bottom‑left
      Offset(_floorR - pW + 2, _floorB - pH),// bottom‑right
    ];

    for (final p in positions) {
      // Body
      canvas.drawRect(
        Rect.fromLTWH(p.dx, p.dy, pW, pH),
        Paint()..color = pc,
      );
      // Top cap
      canvas.drawRect(
        Rect.fromLTWH(p.dx - 2, p.dy - 3, pW + 4, 6),
        Paint()..color = _lighten(pc, 0.08),
      );
      // Bottom cap
      canvas.drawRect(
        Rect.fromLTWH(p.dx - 1, p.dy + pH - 3, pW + 2, 5),
        Paint()..color = pc,
      );
    }
  }

  // ── Torches ──

  /// Static torch hardware — baked into the cache.
  void _drawTorchBrackets(Canvas canvas) {
    for (final pos in _torchPositions) {
      canvas.drawRect(
        Rect.fromCenter(center: pos.translate(0, 5), width: 5, height: 10),
        Paint()..color = const Color(0xFF4a4a5a),
      );
      // Metal sconce cup
      canvas.drawArc(
        Rect.fromCenter(center: pos.translate(0, 1), width: 10, height: 8),
        0,
        pi,
        true,
        Paint()..color = const Color(0xFF5a5a6a),
      );
    }
  }

  // Animated flame paints (reused per frame)
  final Paint _torchAmbientPaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
  final Paint _torchCorePaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
  final Paint _flamePaint = Paint()..color = const Color(0xFFF97316);
  final Paint _flameInnerPaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

  /// Flickering flames + pulsing light pools — drawn live every frame.
  void _drawTorchFlames(Canvas canvas) {
    final ac = theme.accentColor;
    var i = 0;
    for (final pos in _torchPositions) {
      i++;
      final flicker = sin(_time * 7 + i * 1.7) * 0.5 + sin(_time * 13 + i) * 0.3;
      final pulse = 1.0 + flicker * 0.18;

      // Wide ambient glow (breathes)
      _torchAmbientPaint.color =
          ac.withValues(alpha: 0.05 + flicker.abs() * 0.025);
      canvas.drawCircle(pos, 40 * pulse, _torchAmbientPaint);

      // Core glow
      _torchCorePaint.color = ac.withValues(alpha: 0.18 + flicker.abs() * 0.06);
      canvas.drawCircle(pos, 15 * pulse, _torchCorePaint);

      // Flame body — tip sways with the flicker
      final sway = flicker * 2.2;
      final h = 10.0 * pulse;
      final flame = Path()
        ..moveTo(pos.dx + sway, pos.dy - h)
        ..quadraticBezierTo(pos.dx + 5, pos.dy - 3, pos.dx + 1, pos.dy + 3)
        ..lineTo(pos.dx - 1, pos.dy + 3)
        ..quadraticBezierTo(pos.dx - 5, pos.dy - 3, pos.dx + sway, pos.dy - h);
      canvas.drawPath(flame, _flamePaint);
      _flameInnerPaint.color =
          const Color(0xFFFBBF24).withValues(alpha: 0.55 + flicker.abs() * 0.2);
      canvas.drawPath(flame, _flameInnerPaint);
    }
  }

  // ── Light shafts (baked) ──

  /// Diagonal god-rays falling from above for atmosphere.
  void _drawLightShafts(Canvas canvas) {
    final ac = theme.accentColor;
    final shafts = [
      (x: _floorL + _floorW * 0.22, w: 46.0),
      (x: _floorL + _floorW * 0.62, w: 64.0),
    ];
    for (final s in shafts) {
      final path = Path()
        ..moveTo(s.x, _floorT - 30)
        ..lineTo(s.x + s.w, _floorT - 30)
        ..lineTo(s.x + s.w + 50, _floorT + _floorH * 0.55)
        ..lineTo(s.x + 50, _floorT + _floorH * 0.55)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              ac.withValues(alpha: 0.07),
              ac.withValues(alpha: 0.0),
            ],
          ).createShader(path.getBounds())
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  // ── Cracks ──

  void _drawCracks(Canvas canvas) {
    for (final pos in _cracks) {
      final path = Path()
        ..moveTo(pos.dx - 7, pos.dy)
        ..lineTo(pos.dx - 1, pos.dy + 3)
        ..lineTo(pos.dx + 6, pos.dy - 1)
        ..moveTo(pos.dx - 1, pos.dy + 3)
        ..lineTo(pos.dx + 1, pos.dy + 9);
      canvas.drawPath(path, _crackPaint);
    }
  }

  // ── Vignette ──

  void _drawVignette(Canvas canvas) {
    // Top edge – strong (far from camera = darker)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, GameConfig.roomWidth, GameConfig.roomHeight * 0.2),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x99000000), Color(0x00000000)],
        ).createShader(
          Rect.fromLTWH(0, 0, GameConfig.roomWidth, GameConfig.roomHeight * 0.2),
        ),
    );

    // Bottom edge – subtle
    final bottomRect = Rect.fromLTWH(
      0,
      GameConfig.roomHeight * 0.85,
      GameConfig.roomWidth,
      GameConfig.roomHeight * 0.15,
    );
    canvas.drawRect(
      bottomRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0x66000000), Color(0x00000000)],
        ).createShader(bottomRect),
    );

    // Side edges – subtle
    canvas.drawRect(
      Rect.fromLTWH(0, 0, GameConfig.roomWidth * 0.08, GameConfig.roomHeight),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0x55000000), Color(0x00000000)],
        ).createShader(
          Rect.fromLTWH(0, 0, GameConfig.roomWidth * 0.08, GameConfig.roomHeight),
        ),
    );
    final rightRect = Rect.fromLTWH(
      GameConfig.roomWidth * 0.92,
      0,
      GameConfig.roomWidth * 0.08,
      GameConfig.roomHeight,
    );
    canvas.drawRect(
      rightRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: [Color(0x55000000), Color(0x00000000)],
        ).createShader(rightRect),
    );
  }

  // ── Helpers ──

  static Color _lighten(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + amount).clamp(0, 1)).toColor();
  }
}

/// A single ambient floating particle (ember / spore / dust mote).
class _Mote {
  _Mote({
    required this.x,
    required this.phase,
    required this.speed,
    required this.drift,
    required this.size,
  });

  final double x;
  final double phase;
  final double speed;
  final double drift;
  final double size;
}
