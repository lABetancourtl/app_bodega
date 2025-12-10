import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vibration/vibration.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:app_bodega/app/theme/app_colors.dart';


class BarcodeScannerPage extends StatefulWidget {
  final String titulo;
  final String instruccion;

  const BarcodeScannerPage({
    super.key,
    this.titulo = 'Escanear Código',
    this.instruccion = 'Apunta la cámara hacia el código de barras',
  });

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage>
    with SingleTickerProviderStateMixin {
  MobileScannerController? cameraController;
  bool _escaneado = false;
  bool _torchOn = false;
  bool _scannerActivo = true;
  bool _cameraReady = false;

  Rect? _barcodeRect;
  String? _barcodeValue;
  Size? _imageSize;

  late AnimationController _animationController;

  int _quarterTurns = 0;
  StreamSubscription<NativeDeviceOrientation>? _orientationSubscription;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCamera();
      _startOrientationListener();
    });
  }

  void _startOrientationListener() {
    _orientationSubscription = NativeDeviceOrientationCommunicator()
        .onOrientationChanged(useSensor: true)
        .listen((orientation) {
      final newQuarterTurns = _getQuarterTurns(orientation);
      if (newQuarterTurns != _quarterTurns) {
        setState(() {
          _quarterTurns = newQuarterTurns;
        });
      }
    });
  }

  void _initializeCamera() {
    cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      formats: [
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.code93,
        BarcodeFormat.codabar,
        BarcodeFormat.itf,
      ],
    );

    setState(() {
      _cameraReady = true;
    });
  }

  @override
  void dispose() {
    _orientationSubscription?.cancel();
    _animationController.dispose();
    cameraController?.dispose();
    super.dispose();
  }

  int _getQuarterTurns(NativeDeviceOrientation orientation) {
    switch (orientation) {
      case NativeDeviceOrientation.landscapeLeft:
        return 1;
      case NativeDeviceOrientation.landscapeRight:
        return -1;
      case NativeDeviceOrientation.portraitDown:
        return 2;
      case NativeDeviceOrientation.portraitUp:
      default:
        return 0;
    }
  }

  Rect? _calcularRectangulo(Barcode barcode, Size screenSize, Size? imageSize) {
    if (barcode.corners == null || barcode.corners!.isEmpty) return null;
    if (imageSize == null) return null;

    final corners = barcode.corners!;

    final double scaleX = screenSize.width / imageSize.width;
    final double scaleY = screenSize.height / imageSize.height;
    final double scale = scaleX > scaleY ? scaleX : scaleY;

    final double offsetX = (screenSize.width - imageSize.width * scale) / 2;
    final double offsetY = (screenSize.height - imageSize.height * scale) / 2;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final corner in corners) {
      final x = corner.dx * scale + offsetX;
      final y = corner.dy * scale + offsetY;

      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }

    const padding = 12.0;
    return Rect.fromLTRB(
      (minX - padding).clamp(0.0, screenSize.width),
      (minY - padding).clamp(0.0, screenSize.height),
      (maxX + padding).clamp(0.0, screenSize.width),
      (maxY + padding).clamp(0.0, screenSize.height),
    );
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_escaneado || !_scannerActivo) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) {
      if (_barcodeRect != null) {
        setState(() {
          _barcodeRect = null;
          _barcodeValue = null;
        });
      }
      return;
    }

    final barcode = barcodes.first;
    if (barcode.rawValue == null || barcode.rawValue!.isEmpty) return;

    if (capture.size != null) {
      _imageSize = capture.size!;
    }

    final screenSize = MediaQuery.of(context).size;
    final rect = _calcularRectangulo(barcode, screenSize, _imageSize);

    if (rect != null) {
      setState(() {
        _barcodeRect = rect;
        _barcodeValue = barcode.rawValue;
        _escaneado = true;
      });

      _animationController.forward(from: 0);

      await _vibrarDeteccion();
      await Future.delayed(const Duration(milliseconds: 400));

      if (mounted) {
        Navigator.pop(context, barcode.rawValue);
      }
    }
  }

  void _toggleTorch() async {
    await cameraController?.toggleTorch();
    setState(() {
      _torchOn = !_torchOn;
    });
  }

  void _switchCamera() async {
    await cameraController?.switchCamera();
  }

  void _toggleScanner() {
    setState(() {
      _scannerActivo = !_scannerActivo;
      _barcodeRect = null;
      _barcodeValue = null;
    });
    if (_scannerActivo) {
      cameraController?.start();
    } else {
      cameraController?.stop();
    }
  }

  void _ingresarCodigoManual() {
    final TextEditingController codigoController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(dialogContext).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.keyboard, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ingresar Código',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Escribe el código manualmente',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Input
              TextField(
                controller: codigoController,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Ej: 7701234567890',
                  labelText: 'Código de barras',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.5)),
                  prefixIcon: const Icon(Icons.qr_code, color: AppColors.primary),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Botones
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final codigo = codigoController.text.trim();
                        if (codigo.isNotEmpty) {
                          Navigator.pop(dialogContext);
                          Navigator.pop(context, codigo);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Buscar', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _vibrarDeteccion() async {
    if (await Vibration.hasVibrator() ?? false) {
      if (await Vibration.hasCustomVibrationsSupport() ?? false) {
        Vibration.vibrate(duration: 70, amplitude: 128);
      } else {
        Vibration.vibrate(duration: 70);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: Text(
          widget.titulo,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          _buildAppBarButton(
            icon: Icons.keyboard,
            tooltip: 'Ingresar manualmente',
            onPressed: _ingresarCodigoManual,
          ),
          _buildAppBarButton(
            icon: _scannerActivo ? Icons.pause : Icons.play_arrow,
            tooltip: _scannerActivo ? 'Pausar' : 'Reanudar',
            onPressed: _toggleScanner,
          ),
          _buildAppBarButton(
            icon: _torchOn ? Icons.flash_on : Icons.flash_off,
            tooltip: 'Flash',
            onPressed: _toggleTorch,
            isActive: _torchOn,
          ),
          _buildAppBarButton(
            icon: Icons.cameraswitch,
            tooltip: 'Cambiar cámara',
            onPressed: _switchCamera,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Cámara
          if (_cameraReady && cameraController != null)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              child: Center(
                child: RotatedBox(
                  quarterTurns: _quarterTurns,
                  child: SizedBox(
                    width: _quarterTurns.abs() == 1 ? screenSize.height : screenSize.width,
                    height: _quarterTurns.abs() == 1 ? screenSize.width : screenSize.height,
                    child: MobileScanner(
                      controller: cameraController!,
                      onDetect: _onDetect,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            )
          else
            Container(
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            ),

          // Recuadro dinámico
          if (_barcodeRect != null)
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                final scale = Curves.elasticOut.transform(
                  _animationController.value.clamp(0.0, 1.0),
                );
                return Positioned(
                  left: _barcodeRect!.left,
                  top: _barcodeRect!.top,
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: _barcodeRect!.width,
                      height: _barcodeRect!.height,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.accent,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

          // Valor del código
          if (_barcodeValue != null && _barcodeRect != null)
            Positioned(
              left: _barcodeRect!.left,
              top: _barcodeRect!.bottom + 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  _barcodeValue!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),

          // Indicador de estado
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _scannerActivo
                      ? AppColors.surface
                      : AppColors.warning,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_scannerActivo) ...[
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Buscando código...',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ] else ...[
                      const Icon(Icons.pause_circle_filled, size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      const Text(
                        'Escáner pausado',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Instrucciones
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.qr_code_scanner, size: 20, color: AppColors.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        widget.instruccion,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBarButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isActive ? AppColors.accent : Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Colors.white,
          ),
        ),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}