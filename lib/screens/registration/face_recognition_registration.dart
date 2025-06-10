// screens/registration/face_recognition_registration.dart

import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image/image.dart' as img;
import 'dart:convert';

import '../../services/api_service.dart';
import '../../services/firestore_service.dart';
import 'fingerprint_registration.dart';

class FaceRecognitionRegistration extends StatefulWidget {
  final String uid;
  final String role;
  final String name;
  final String email;
  final String idUser;
  final String password; // TAMBAHKAN INI
  final String? jabatan;
  final String? tanggalLahir;
  final int? usia;
  final String? alamat;

  const FaceRecognitionRegistration({
    Key? key,
    required this.uid,
    required this.role,
    required this.name,
    required this.email,
    required this.idUser,
    required this.password, // TAMBAHKAN INI
    this.jabatan,
    this.tanggalLahir,
    this.usia,
    this.alamat,
  }) : super(key: key);

  @override
  State<FaceRecognitionRegistration> createState() => _FaceRecognitionRegistrationState();
}

class _FaceRecognitionRegistrationState extends State<FaceRecognitionRegistration> with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _isProcessingImage = false;
  bool _cameraReady = false;

  Timer? _uiFeedbackTimer;
  late Size _previewSize;
  Rect? _detectedFaceRect;
  bool _faceInsideBox = false;
  String _detectionMessage = 'Posisikan wajah Anda di dalam area.';

  double _sentImageWidth = 0.0;
  double _sentImageHeight = 0.0;
  Uint8List? _imageToRegisterBytes; // VARIABEL BARU UNTUK MENYIMPAN GAMBAR

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      if (state == AppLifecycleState.resumed) {
        _initializeCamera();
      }
      return;
    }

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _cameraController?.dispose();
      _cameraController = null;
      _uiFeedbackTimer?.cancel();
      if (mounted) setState(() => _cameraReady = false);
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      await _cameraController!.dispose();
      _cameraController = null;
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      Fluttertoast.showToast(msg: 'Tidak ada kamera ditemukan');
      if (mounted) setState(() => _cameraReady = false);
      return;
    }

    final frontCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _cameraController!.initialize();
      if (!mounted) return;

      _previewSize = _cameraController!.value.previewSize!;

      setState(() => _cameraReady = true);

      _startPeriodicCapture();
    } catch (e) {
      debugPrint("Error initializing camera: $e");
      Fluttertoast.showToast(msg: 'Gagal menginisialisasi kamera: $e');
      if (mounted) setState(() => _cameraReady = false);
    }
  }

  void _startPeriodicCapture() {
    _uiFeedbackTimer?.cancel();
    _uiFeedbackTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!_isProcessingImage && mounted) {
        _captureAndDetectFace();
      }
    });
  }

  Future<void> _captureAndDetectFace() async {
    if (!_cameraReady || _isProcessingImage || _cameraController == null || !_cameraController!.value.isInitialized) return;

    setState(() {
      _isProcessingImage = true;
      _detectionMessage = 'Mendeteksi wajah...';
      _faceInsideBox = false;
    });

    try {
      final XFile picture = await _cameraController!.takePicture();
      Uint8List imageBytes = await picture.readAsBytes();

      final img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        throw Exception("Failed to decode image bytes.");
      }

      final img.Image imageToSend = originalImage; // Tidak ada rotasi di sini

      _sentImageWidth = imageToSend.width.toDouble();
      _sentImageHeight = imageToSend.height.toDouble();

      Uint8List bytesToSend = Uint8List.fromList(img.encodeJpg(imageToSend));

      final String debugFilename = 'raw_unrotated_${widget.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await ApiService.sendDebugImage(bytesToSend, debugFilename);

      final detectionResult = await ApiService.detectFaceOnBackend(bytesToSend);

      final bool isDetected = detectionResult['is_detected'] ?? false;
      final Map? boundingBox = detectionResult['bounding_box'];

      if (isDetected && boundingBox != null) {
        final double x1 = boundingBox['left']?.toDouble() ?? 0.0;
        final double y1 = boundingBox['top']?.toDouble() ?? 0.0;
        final double x2 = boundingBox['right']?.toDouble() ?? 0.0;
        final double y2 = boundingBox['bottom']?.toDouble() ?? 0.0;

        final double uiScreenWidth = MediaQuery.of(context).size.width;
        final double uiScreenHeight = MediaQuery.of(context).size.height;

        double scaledLeft, scaledTop, scaledRight, scaledBottom;

        if (_sentImageWidth > _sentImageHeight && uiScreenWidth < uiScreenHeight) {
          final double scaleRawYtoUiX = uiScreenWidth / _sentImageHeight;
          final double scaleRawXtoUiY = uiScreenHeight / _sentImageWidth;

          scaledLeft = y1 * scaleRawYtoUiX;
          scaledRight = y2 * scaleRawYtoUiX;
          scaledTop = x1 * scaleRawXtoUiY;
          scaledBottom = x2 * scaleRawXtoUiY;
        } else {
          scaledLeft = x1 * (uiScreenWidth / _sentImageWidth);
          scaledTop = y1 * (uiScreenHeight / _sentImageHeight);
          scaledRight = x2 * (uiScreenWidth / _sentImageWidth);
          scaledBottom = y2 * (uiScreenHeight / _sentImageHeight);
        }

        _detectedFaceRect = Rect.fromLTRB(scaledLeft, scaledTop, scaledRight, scaledBottom);

        debugPrint('--- Deteksi Wajah ---');
        debugPrint('Original Image Size: W:${originalImage.width}, H:${originalImage.height}');
        debugPrint('Sent Image Size (to backend): W:$_sentImageWidth, H:$_sentImageHeight');
        debugPrint('Camera Preview Size (from CameraController): W:${_previewSize.width}, H:${_previewSize.height}');
        debugPrint('UI Screen Size: W:${uiScreenWidth}, H:${uiScreenHeight}');
        debugPrint('Detected Face Raw (from backend): ($x1, $y1, $x2, $y2)');
        debugPrint('Scaled Face Rect (for UI Display): ${_detectedFaceRect}');

        if (_detectedFaceRect != null && _isFaceInTargetArea(_detectedFaceRect!)) {
          if (mounted) {
            setState(() {
              _faceInsideBox = true;
              _imageToRegisterBytes = bytesToSend; // SIMPAN GAMBAR YANG AKAN DIDAFTARKAN
            });
          }
          _detectionMessage = 'Wajah di tengah! Melanjutkan...';
          await _navigateToFingerprintRegistration(); // GANTI KE FUNGSI NAVIGASI
        } else {
          if (mounted) setState(() => _faceInsideBox = false);
          _detectionMessage = 'Wajah tidak di tengah. Posisikan kembali.';
          _resetFeedbackMessage();
        }
      } else {
        if (mounted) setState(() => _faceInsideBox = false);
        _detectionMessage = 'Wajah tidak terdeteksi. Coba lagi.';
        _resetFeedbackMessage();
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Gagal deteksi wajah: $e');
      debugPrint('Face detection error: $e');
      _detectionMessage = 'Error deteksi wajah. Coba lagi.';
      _resetFeedbackMessage();
    } finally {
      if (mounted) setState(() => _isProcessingImage = false);
    }
  }

  void _resetFeedbackMessage() {
    _uiFeedbackTimer?.cancel();
    _uiFeedbackTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isProcessingImage) {
        setState(() {
          _detectionMessage = 'Posisikan wajah Anda di dalam area.';
          _faceInsideBox = false;
        });
        _startPeriodicCapture();
      }
    });
  }

  bool _isFaceInTargetArea(Rect faceRect) {
    if (_detectedFaceRect == null) return false;

    final double overlayPadding = 40.0;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    final double targetBoxWidth = screenWidth - (2 * overlayPadding);
    final double targetBoxHeight = targetBoxWidth;

    final double targetBoxLeft = overlayPadding;
    final double targetBoxTop = (screenHeight - targetBoxHeight) / 2;
    final double targetBoxRight = screenWidth - overlayPadding;
    final double targetBoxBottom = targetBoxTop + targetBoxHeight;

    debugPrint("Target Area (UI Screen Coords): L:$targetBoxLeft T:$targetBoxTop R:$targetBoxRight B:$targetBoxBottom");
    debugPrint("Face Rect (Scaled to UI Screen Coords): L:${faceRect.left} T:${faceRect.top} R:${faceRect.right} B:${faceRect.bottom}");

    return faceRect.left >= targetBoxLeft &&
        faceRect.top >= targetBoxTop &&
        faceRect.right <= targetBoxRight &&
        faceRect.bottom <= targetBoxBottom;
  }

  // FUNGSI BARU UNTUK NAVIGASI SETELAH WAJAH TERDETEKSI DAN GAMBAR DISIMPAN TEMPORARY
  Future<void> _navigateToFingerprintRegistration() async {
    if (_imageToRegisterBytes == null) {
      Fluttertoast.showToast(msg: 'Gambar wajah belum siap untuk pendaftaran.');
      _resetFeedbackMessage();
      return;
    }

    // Hentikan timer sebelum navigasi agar tidak ada pemrosesan lagi
    _uiFeedbackTimer?.cancel();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => FingerprintRegistration(
          uid: widget.uid, // Masih kosong, akan diisi nanti
          role: widget.role,
          name: widget.name,
          email: widget.email,
          idUser: widget.idUser,
          password: widget.password, // TERUSKAN PASSWORD
          jabatan: widget.jabatan,
          tanggalLahir: widget.tanggalLahir,
          usia: widget.usia,
          alamat: widget.alamat,
          faceImageBytes: _imageToRegisterBytes, // TERUSKAN GAMBAR WAJAH DI SINI
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _uiFeedbackTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_cameraReady || _cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    final Size cameraPreviewSize = _cameraController!.value.previewSize!;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: cameraPreviewSize.height,
                height: cameraPreviewSize.width,
                child: CameraPreview(_cameraController!),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).padding.top + 60,
            child: Container(
              color: Colors.black54,
              alignment: Alignment.bottomCenter,
              padding: const EdgeInsets.only(bottom: 10),
              child: const Text(
                'SCAN WAJAH',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: CustomPaint(
                    painter: FaceOverlayPainter(
                      faceInsideBox: _faceInsideBox,
                    ),
                    child: Container(),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _detectionMessage,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FaceOverlayPainter extends CustomPainter {
  final bool faceInsideBox;

  FaceOverlayPainter({required this.faceInsideBox});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = faceInsideBox ? Colors.greenAccent : Colors.white70
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final cornerLength = size.width * 0.2;

    canvas.drawLine(Offset(0, cornerLength), const Offset(0, 0), paint);
    canvas.drawLine(Offset(cornerLength, 0), const Offset(0, 0), paint);

    canvas.drawLine(Offset(size.width - cornerLength, 0), Offset(size.width, 0), paint);
    canvas.drawLine(Offset(size.width, cornerLength), Offset(size.width, 0), paint);

    canvas.drawLine(Offset(0, size.height - cornerLength), Offset(0, size.height), paint);
    canvas.drawLine(Offset(cornerLength, size.height), Offset(0, size.height), paint);

    canvas.drawLine(Offset(size.width, size.height - cornerLength), Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width - cornerLength, size.height), Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return (oldDelegate as FaceOverlayPainter).faceInsideBox != faceInsideBox;
  }
}