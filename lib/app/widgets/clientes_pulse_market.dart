import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ClientesPulseMarker extends StatefulWidget {
  final String nombre;
  final Color color;
  final bool esSeleccionado;

  const ClientesPulseMarker({
    super.key,
    required this.nombre,
    required this.color,
    required this.esSeleccionado,
  });

  @override
  State<ClientesPulseMarker> createState() => _ClientesPulseMarkerState();
}

class _ClientesPulseMarkerState extends State<ClientesPulseMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final esSel = widget.esSeleccionado;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Marcador circular + onda
        SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // --- Onda ---
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final scale = 1 + (_controller.value * 1.5);
                  final opacity = (1 - _controller.value).clamp(0.0, 1.0);

                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withOpacity(0.25 * opacity),
                      ),
                    ),
                  );
                },
              ),

              // --- Punto central + icono ---
              Container(
                width: esSel ? 34 : 26,
                height: esSel ? 34 : 26,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: esSel
                      ? Border.all(color: Colors.white, width: 3)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.5),
                      blurRadius: esSel ? 12 : 8,
                      spreadRadius: esSel ? 3 : 1,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.store,
                  color: Colors.white,
                  size: esSel ? 20 : 16,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 4),

        // --- Nombre ---
        // Container(
        //   padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        //   decoration: BoxDecoration(
        //     color: Colors.white,
        //     borderRadius: BorderRadius.circular(4),
        //     boxShadow: [
        //       BoxShadow(
        //         color: Colors.black.withOpacity(0.12),
        //         blurRadius: 4,
        //       ),
        //     ],
        //   ),
        //   child: Text(
        //     widget.nombre,
        //     maxLines: 1,
        //     overflow: TextOverflow.ellipsis,
        //     style: TextStyle(
        //       fontSize: esSel ? 11 : 9,
        //       fontWeight: FontWeight.bold,
        //       color: Colors.black,
        //     ),
        //   ),
        // ),
      ],
    );
  }
}
