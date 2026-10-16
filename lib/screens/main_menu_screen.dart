import 'dart:math';

import 'package:flutter/material.dart';

import 'class_select_screen.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full‑screen logo background
          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, child) {
              final pulse = 1.0 + sin(_ctrl.value * pi) * 0.02;
              return Transform.scale(scale: pulse, child: child);
            },
            child: Image.asset(
              'assets/images/logo-with-background.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // Gradient vignette on top to push buttons to bottom
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Color(0xBB000000),
                  Color(0xEE000000),
                ],
                stops: [0.0, 0.55, 0.8, 1.0],
              ),
            ),
          ),

          // Buttons at bottom
          SafeArea(
            child: Column(
              children: [
                const Spacer(),
                // Subtle tagline
                Text(
                  'DARK FANTASY ROGUELITE',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 3,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(height: 28),
                _MenuButton(
                  label: 'PLAY',
                  color: const Color(0xFFc084fc),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const ClassSelectScreen()),
                  ),
                ),
                const SizedBox(height: 14),
                _MenuButton(
                  label: 'SETTINGS',
                  color: const Color(0xFF6b7280),
                  onTap: () {},
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 12,
            ),
          ],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}
