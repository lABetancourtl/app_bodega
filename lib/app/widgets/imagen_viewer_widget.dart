import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:app_bodega/app/theme/app_colors.dart';

/// Widget reutilizable para visualizar imágenes de productos con zoom
/// Soporta imágenes locales (File) y de red (URL)
class ImagenViewerPage extends StatefulWidget {
  final String? imagenPath;
  final String titulo;

  const ImagenViewerPage({
    super.key,
    required this.imagenPath,
    required this.titulo,
  });

  @override
  State<ImagenViewerPage> createState() => _ImagenViewerPageState();
}

class _ImagenViewerPageState extends State<ImagenViewerPage> {
  final TransformationController _transformationController = TransformationController();
  TapDownDetails? _doubleTapDetails;
  bool _showControls = true;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      // Si está con zoom, resetear
      _transformationController.value = Matrix4.identity();
    } else {
      // Si está normal, hacer zoom 2.5x en el punto tocado
      final position = _doubleTapDetails!.localPosition;

      _transformationController.value = Matrix4.identity()
        ..translate(-position.dx * 1.5, -position.dy * 1.5)
        ..scale(2.5);
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  Widget _buildImageWidget() {
    if (widget.imagenPath == null || widget.imagenPath!.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_not_supported, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Imagen no disponible',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    // Imagen desde URL
    if (widget.imagenPath!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: widget.imagenPath!,
        fit: BoxFit.contain,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        errorWidget: (context, url, error) => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.image_not_supported, size: 80, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Error al cargar la imagen',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    // Imagen desde archivo local
    final file = File(widget.imagenPath!);
    if (file.existsSync()) {
      return Image.file(file, fit: BoxFit.contain);
    }

    // Si el archivo no existe
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_not_supported, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Imagen no encontrada',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Imagen centrada en toda la pantalla
          GestureDetector(
            onTap: _toggleControls,
            onDoubleTapDown: _handleDoubleTapDown,
            onDoubleTap: _handleDoubleTap,
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.5,
              maxScale: 4.0,
              boundaryMargin: const EdgeInsets.all(80),
              panEnabled: true,
              scaleEnabled: true,
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                child: Center(
                  child: _buildImageWidget(),
                ),
              ),
            ),
          ),

          // AppBar flotante
          if (_showControls)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.left,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.black.withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: SizedBox(
                    height: kToolbarHeight,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.accentLight, size: 28),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Text(
                            widget.titulo,
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppColors.accentLight,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 48), // Balance visual
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}