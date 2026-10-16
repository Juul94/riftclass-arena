import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../config.dart';
import '../riftclass_game.dart';

/// A full‑screen touch area that spawns a joystick at the drag‑start position.
/// Disappears when the finger is lifted.
class FloatingJoystick extends PositionComponent
    with DragCallbacks, HasGameReference<RiftclassGame> {
  FloatingJoystick() : super(priority: 900);

  /// Normalised direction (-1..1 on each axis).
  Vector2 relativeDelta = Vector2.zero();

  bool _active = false;
  Vector2 _basePos = Vector2.zero();
  Vector2 _knobPos = Vector2.zero();

  static const double _maxRadius = 50.0;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
    position = Vector2.zero();
  }

  // ── Drag handling ──

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _active = true;
    _basePos = event.localPosition.clone();
    _knobPos = _basePos.clone();
    relativeDelta = Vector2.zero();
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (!_active) return;
    _knobPos += event.localDelta;

    final delta = _knobPos - _basePos;
    if (delta.length > _maxRadius) {
      delta.normalize();
      delta.scale(_maxRadius);
      _knobPos = _basePos + delta;
    }
    relativeDelta = (_knobPos - _basePos) / _maxRadius;
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _active = false;
    relativeDelta = Vector2.zero();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _active = false;
    relativeDelta = Vector2.zero();
  }

  // ── Rendering ──

  @override
  void render(Canvas canvas) {
    if (!_active) return;

    final c = game.player?.classData.color ?? GameConfig.archerColor;

    // Background ring at base position
    canvas.drawCircle(
      _basePos.toOffset(),
      _maxRadius,
      Paint()..color = const Color(0x22FFFFFF),
    );
    canvas.drawCircle(
      _basePos.toOffset(),
      _maxRadius,
      Paint()
        ..color = const Color(0x33FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Knob at current drag position
    canvas.drawCircle(
      _knobPos.toOffset(),
      20,
      Paint()
        ..color = c.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(
      _knobPos.toOffset(),
      14,
      Paint()..color = c.withValues(alpha: 0.5),
    );
    canvas.drawCircle(
      _knobPos.toOffset(),
      14,
      Paint()
        ..color = c.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}
