import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vibration/vibration.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

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

  // <CHANGE> Variables para manejar orientación eficientemente
  int _quarterTurns = 0;
  StreamSubscription<NativeDeviceOrientation>? _orientationSubscription;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // <CHANGE> Inicializar cámara con delay para asegurar que se abra correctamente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCamera();
      _startOrientationListener();
    });
  }

  // <CHANGE> Escuchar orientación con StreamSubscription en lugar de builder
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
      detectionSpeed: DetectionSpeed.normal, // <CHANGE> Mejor balance velocidad/eficiencia
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

    // <CHANGE> Marcar cámara como lista después de inicializar
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

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ingresar Código'),
        content: TextField(
          controller: codigoController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Ej: 7701234567890',
            labelText: 'Código de barras',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final codigo = codigoController.text.trim();
              if (codigo.isNotEmpty) {
                Navigator.pop(dialogContext);
                Navigator.pop(context, codigo);
              }
            },
            child: const Text('Buscar'),
          ),
        ],
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.titulo),
        actions: [
          IconButton(
            icon: const Icon(Icons.keyboard),
            tooltip: 'Ingresar manualmente',
            onPressed: _ingresarCodigoManual,
          ),
          IconButton(
            icon: Icon(_scannerActivo ? Icons.pause : Icons.play_arrow),
            tooltip: _scannerActivo ? 'Pausar' : 'Reanudar',
            onPressed: _toggleScanner,
          ),
          IconButton(
            icon: Icon(
              _torchOn ? Icons.flash_on : Icons.flash_off,
              color: _torchOn ? Colors.yellow : Colors.white,
            ),
            tooltip: 'Flash',
            onPressed: _toggleTorch,
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            tooltip: 'Cambiar cámara',
            onPressed: _switchCamera,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // <CHANGE> Cámara con rotación compensada, solo se reconstruye cuando cambia _quarterTurns
          if (_cameraReady && cameraController != null)
            Center(
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
            )
          else
          // <CHANGE> Mostrar indicador mientras la cámara carga
            const Center(
              child: CircularProgressIndicator(
                color: Colors.greenAccent,
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
                          color: Colors.greenAccent,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.greenAccent.withOpacity(0.5),
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
              top: _barcodeRect!.bottom + 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.greenAccent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _barcodeValue!,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),

          // Indicador de estado
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: _scannerActivo
                      ? Colors.black.withOpacity(0.6)
                      : Colors.orange.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(24),
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
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.greenAccent.withOpacity(0.8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      _scannerActivo ? 'Buscando código...' : 'Pausado',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Instrucciones
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.instruccion,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}