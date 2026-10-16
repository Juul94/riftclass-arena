import 'dart:math';

import 'package:flutter/material.dart';

import '../models/player_class.dart';
import 'class_character_painter.dart';

class ClassPreview extends StatefulWidget {
  const ClassPreview({super.key, required this.classData, this.size = 80});

  final PlayerClassData classData;
  final double size;

  @override
  State<ClassPreview> createState() => _ClassPreviewState();
}

class _ClassPreviewState extends State<ClassPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size.square(widget.size),
          painter: _PreviewPainter(
            classData: widget.classData,
            phase: _controller.value * pi * 2,
          ),
        );
      },
    );
  }
}

class _PreviewPainter extends CustomPainter {
  const _PreviewPainter({required this.classData, required this.phase});

  final PlayerClassData classData;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 96, size.height / 96);
    paintClassCharacter(
      canvas,
      className: classData.id,
      color: classData.color,
      center: const Offset(48, 47),
      scale: 1.08,
      phase: phase,
      attack: (sin(phase * 1.35) + 1) * 0.18,
      includeGround: true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PreviewPainter oldDelegate) {
    return oldDelegate.phase != phase || oldDelegate.classData != classData;
  }
}
