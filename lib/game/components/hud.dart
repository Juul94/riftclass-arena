import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart'
    show
        Alignment,
        LinearGradient,
        TextDirection,
        TextPainter,
        TextSpan,
        TextStyle,
        FontWeight;

import '../config.dart';
import '../riftclass_game.dart';

/// Heads‑up display: health bar, world/room info, score.
/// Rendered as a Flame overlay on top of the game world.
class Hud extends PositionComponent with HasGameReference<RiftclassGame> {
  Hud() : super(priority: 1000);

  /// "Ghost" health that lags behind real health to show recent damage.
  double _ghostHp = -1;
  double _time = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    final player = game.player;
    if (player == null) return;
    if (_ghostHp < 0 || _ghostHp < player.health) {
      _ghostHp = player.health;
    } else if (_ghostHp > player.health) {
      // Drain toward real health after a hit
      _ghostHp = max(player.health, _ghostHp - player.maxHealth * 0.6 * dt);
    }
  }

  @override
  void render(Canvas canvas) {
    final player = game.player;
    if (player == null) return;

    final screenW = game.size.x;

    _drawHealthBar(canvas, player.health, player.maxHealth, screenW);
    _drawRoomInfo(canvas, screenW);
    _drawWavePips(canvas, screenW);
    _drawLowHealthPulse(canvas, player.health / player.maxHealth);
  }

  TextPainter _makeText(String text, TextStyle style) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  void _drawHealthBar(Canvas canvas, double hp, double maxHp, double screenW) {
    const barH = 10.0;
    const margin = 20.0;
    final barW = screenW - margin * 2;
    const barY = 46.0;

    final barRect = Rect.fromLTWH(margin, barY, barW, barH);

    // Background with bevel (3D inset look)
    canvas.drawRRect(
      RRect.fromRectAndRadius(barRect.inflate(1.5), const Radius.circular(6)),
      Paint()..color = const Color(0xCC000000),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(barRect, const Radius.circular(5)),
      Paint()..color = GameConfig.hpBarBg,
    );

    final ratio = (hp / maxHp).clamp(0.0, 1.0);
    final ghostRatio = (_ghostHp / maxHp).clamp(0.0, 1.0);

    // Ghost bar (recent damage trail, bright amber)
    if (ghostRatio > ratio) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(margin, barY, barW * ghostRatio, barH),
          const Radius.circular(5),
        ),
        Paint()..color = const Color(0xFFFFB84D),
      );
    }

    if (ratio > 0) {
      final fillRect = Rect.fromLTWH(margin, barY, barW * ratio, barH);
      // Gradient fill (lit top → dark bottom = 3D tube)
      canvas.drawRRect(
        RRect.fromRectAndRadius(fillRect, const Radius.circular(5)),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFff7b6b),
              Color(0xFFef4444),
              Color(0xFFb91c1c),
            ],
            stops: [0.0, 0.45, 1.0],
          ).createShader(fillRect),
      );
      // Specular highlight strip
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(margin + 2, barY + 1.5, barW * ratio - 4, 2.5),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0x55FFFFFF),
      );
      // Glow on health bar
      canvas.drawRRect(
        RRect.fromRectAndRadius(fillRect, const Radius.circular(5)),
        Paint()
          ..color = GameConfig.hpBar.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    // HP text
    final hpText = '${hp.toInt()} / ${maxHp.toInt()}';
    final tp = _makeText(
      hpText,
      const TextStyle(
        color: Color(0xCCFFFFFF),
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    );
    tp.paint(canvas, Offset(screenW / 2 - tp.width / 2, barY - 1));
  }

  /// Wave progress pips under the health bar.
  void _drawWavePips(Canvas canvas, double screenW) {
    final rm = game.roomManager;
    const pipR = 3.5;
    const gap = 14.0;
    const y = 94.0;
    final total = GameConfig.wavesPerLevel;
    final startX = screenW / 2 - (total - 1) * gap / 2;
    final ac = rm.theme.accentColor;

    for (var i = 0; i < total; i++) {
      final x = startX + i * gap;
      final isBoss = i == total - 1;
      final done = i < rm.currentWave;
      final current = i == rm.currentWave;

      if (current) {
        // Pulsing halo on the active wave
        canvas.drawCircle(
          Offset(x, y),
          pipR + 3 + sin(_time * 4) * 1.2,
          Paint()
            ..color = ac.withValues(alpha: 0.25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }
      final paint = Paint()
        ..color = done
            ? ac
            : current
                ? ac.withValues(alpha: 0.9)
                : const Color(0x44FFFFFF);
      if (isBoss) {
        // Boss pip: diamond
        final path = Path()
          ..moveTo(x, y - pipR - 1.5)
          ..lineTo(x + pipR + 1.5, y)
          ..lineTo(x, y + pipR + 1.5)
          ..lineTo(x - pipR - 1.5, y)
          ..close();
        canvas.drawPath(path, paint);
      } else {
        canvas.drawCircle(Offset(x, y), pipR, paint);
      }
    }
  }

  /// Pulsing red edge vignette when health is critical.
  void _drawLowHealthPulse(Canvas canvas, double ratio) {
    if (ratio > 0.3) return;
    final intensity =
        (1 - ratio / 0.3) * (0.35 + 0.2 * sin(_time * 5));
    final rect = Rect.fromLTWH(0, 0, game.size.x, game.size.y);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = Gradient.radial(
          rect.center,
          rect.longestSide * 0.7,
          [
            const Color(0x00FF0000),
            Color.fromARGB((110 * intensity).toInt(), 255, 0, 32),
          ],
          [0.6, 1.0],
        ),
    );
  }

  void _drawRoomInfo(Canvas canvas, double screenW) {
    final rm = game.roomManager;
    final worldName = rm.theme.name;
    final roomLabel = rm.isBossWave
        ? 'BOSS'
        : 'Wave ${rm.currentWave + 1}/${GameConfig.wavesPerLevel}';

    final worldTp = _makeText(
      worldName,
      TextStyle(
        color: rm.theme.accentColor.withValues(alpha: 0.8),
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
    worldTp.paint(canvas, Offset(screenW / 2 - worldTp.width / 2, 60));

    final roomTp = _makeText(
      roomLabel,
      const TextStyle(
        color: Color(0x99FFFFFF),
        fontSize: 10,
      ),
    );
    roomTp.paint(canvas, Offset(screenW / 2 - roomTp.width / 2, 74));
  }
}
