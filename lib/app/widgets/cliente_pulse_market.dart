import 'package:app_bodega/app/model/cliente_model.dart';
import 'package:flutter/material.dart';

class ClientePulseMarker extends StatefulWidget {
  final String nombre;
  final Ruta ruta;

  const ClientePulseMarker({super.key, required this.nombre, required this.ruta});

  @override
  State<ClientePulseMarker> createState() => _ClientePulseMarkerState();
}

class _ClientePulseMarkerState extends State<ClientePulseMarker>
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
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // --- Marcador con onda (PUNTO DE ANCLAJE AQUÍ) ---
        SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Onda
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
                        color: Colors.green.withOpacity(0.25 * opacity),
                      ),
                    ),
                  );
                },
              ),

              // Punto central con ícono de tienda
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.4),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.store,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ],
          ),
        ),

        // --- Nombre del negocio (POSICIONADO DEBAJO) ---
        Positioned(
          top: 80, // Justo debajo del marcador
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Text(
                widget.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}