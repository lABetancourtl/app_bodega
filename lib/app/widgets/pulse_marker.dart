import 'package:flutter/material.dart';

class PulseMarker extends StatefulWidget {
  const PulseMarker({super.key});

  @override
  State<PulseMarker> createState() => _PulseMarkerState();
}

class _PulseMarkerState extends State<PulseMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(); // animación infinita
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // --- Onda expansiva ---
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final double scale = 1 + (_controller.value * 1.5);
              final double opacity = (1 - _controller.value).clamp(0.0, 1.0);

              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 25,
                  height: 25,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue.withOpacity(0.2 * opacity),
                  ),
                ),
              );
            },
          ),

          // --- Punto central ---
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
