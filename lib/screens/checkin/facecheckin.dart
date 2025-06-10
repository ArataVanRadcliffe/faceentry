// screens/checkin/facecheckin.dart

import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image/image.dart' as img;

import '../../services/api_service.dart';
import '../pages/home_pegawai.dart';

class FaceCheckIn extends StatefulWidget {
  final String uid;
  final String eventType; // NEW: Menambahkan eventType (e.g., 'check_in', 'check_out')

  const FaceCheckIn({super.key, required this.uid, this.eventType = 'check_in'}); // Default ke 'check_in'

  @override
  State<FaceCheckIn> createState() => _FaceCheckInState();
}

class _FaceCheckInState extends State<FaceCheckIn> with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _isProcessingImage = false;
  bool _cameraReady = false;

  Timer? _periodicCaptureTimer;
  late Size _previewSize;
  Rect? _detectedFaceRect;
  bool _faceInsideBox = false;
  String _checkInMessage = 'Posisikan wajah Anda di dalam area untuk Check-In.';

  double _sentImageWidth = 0.0;
  double _sentImageHeight = 0.0;

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
      _periodicCaptureTimer?.cancel();
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
    _periodicCaptureTimer?.cancel();
    _periodicCaptureTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_isProcessingImage && mounted) {
        _captureAndVerifyFace();
      }
    });
  }

  Future<void> _captureAndVerifyFace() async {
    if (!_cameraReady || _isProcessingImage || _cameraController == null || !_cameraController!.value.isInitialized) return;

    setState(() {
      _isProcessingImage = true;
      _checkInMessage = 'Mendeteksi wajah...';
      _faceInsideBox = false;
    });

    try {
      final XFile picture = await _cameraController!.takePicture();
      Uint8List imageBytes = await picture.readAsBytes();

      final img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        throw Exception("Failed to decode image bytes.");
      }

      final img.Image imageToSend = originalImage;

      _sentImageWidth = imageToSend.width.toDouble();
      _sentImageHeight = imageToSend.height.toDouble();

      Uint8List bytesToSend = Uint8List.fromList(img.encodeJpg(imageToSend));

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


        debugPrint('Face Check-In Log:');
        debugPrint('Sent Image Size: W:$_sentImageWidth, H:$_sentImageHeight');
        debugPrint('UI Screen Size: W:$uiScreenWidth, H:$uiScreenHeight');
        debugPrint('Detected Face Raw (from backend): ($x1, $y1, $x2, $y2)');
        debugPrint('Scaled Face Rect (for UI Display): ${_detectedFaceRect}');


        if (_detectedFaceRect != null && _isFaceInTargetArea(_detectedFaceRect!)) {
          if (mounted) setState(() => _faceInsideBox = true);
          _checkInMessage = 'Wajah di tengah! Memverifikasi...';
          await _verifyFaceWithBackend(bytesToSend);
        } else {
          if (mounted) setState(() => _faceInsideBox = false);
          _checkInMessage = 'Wajah tidak di tengah. Posisikan kembali.';
          _resetFeedbackMessage();
        }
      } else {
        if (mounted) setState(() => _faceInsideBox = false);
        _checkInMessage = 'Wajah tidak terdeteksi. Coba lagi.';
        _resetFeedbackMessage();
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Gagal deteksi wajah: $e');
      debugPrint('Face detection error for check-in: $e');
      _checkInMessage = 'Error deteksi wajah. Coba lagi.';
      _resetFeedbackMessage();
    } finally {
      if (mounted) setState(() => _isProcessingImage = false);
    }
  }

  void _resetFeedbackMessage() {
    _periodicCaptureTimer?.cancel();
    _periodicCaptureTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && !_isProcessingImage) {
        setState(() {
          _checkInMessage = 'Posisikan wajah Anda di dalam area untuk Check-In.';
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

  Future<void> _verifyFaceWithBackend(Uint8List imageBytes) async {
    try {
      debugPrint('Attempting face verification for UID: ${widget.uid}, eventType: ${widget.eventType}'); //
      final verificationResult = await ApiService.verifyFace(imageBytes, uid: widget.uid);
      debugPrint('Face verification response: $verificationResult');

      final bool isVerified = verificationResult['is_verified'] ?? false;
      final Map? matchedEmployeeData = verificationResult['matched_employee'];
      final double? distance = verificationResult['distance'];

      if (isVerified && matchedEmployeeData != null) {
        String successMessage = ''; //
        if (widget.eventType == 'check_in') { //
          successMessage = 'Check-In Berhasil untuk ${matchedEmployeeData['nama_pengguna']}!'; //
        } else if (widget.eventType == 'check_out') { //
          successMessage = 'Check-Out Berhasil untuk ${matchedEmployeeData['nama_pengguna']}!'; //
        } else {
          successMessage = 'Verifikasi Berhasil untuk ${matchedEmployeeData['nama_pengguna']}!'; //
        }
        Fluttertoast.showToast(msg: successMessage); //
        _checkInMessage = successMessage; //

        await ApiService.addCheckInOutLog( //
          uid: widget.uid, //
          eventType: widget.eventType, // Menggunakan eventType dari widget
          status: 'success', //
          employeeName: matchedEmployeeData['nama_pengguna'], //
          distance: distance, //
        );

        if (mounted) setState(() {});
        _periodicCaptureTimer?.cancel();

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomePegawai()),
                (route) => false,
          );
        }
      } else {
        Fluttertoast.showToast(msg: 'Verifikasi wajah gagal. Wajah tidak cocok dengan ID yang discan.'); //
        _checkInMessage = 'Check-${widget.eventType == 'check_in' ? 'In' : 'Out'} Gagal. Wajah tidak cocok dengan ID yang discan.'; //
        if (mounted) setState(() {}); //
        _resetFeedbackMessage(); //

        await ApiService.addCheckInOutLog( //
          uid: widget.uid, //
          eventType: widget.eventType, // Menggunakan eventType dari widget
          status: 'failed_face_mismatch', //
          employeeName: matchedEmployeeData?['nama_pengguna'], //
          distance: distance, //
        );
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('Request to backend timed out')) {
        Fluttertoast.showToast(msg: 'Verifikasi wajah: Server timeout. Coba lagi.'); //
        debugPrint('Face verification error: $e'); //
        _checkInMessage = 'Verifikasi timeout. Coba lagi.'; //
      } else {
        Fluttertoast.showToast(msg: 'Terjadi kesalahan verifikasi wajah: $e'); //
        debugPrint('Face verification error: $e'); //
        _checkInMessage = 'Error verifikasi. Coba lagi.'; //
      }
      await ApiService.addCheckInOutLog( //
        uid: widget.uid, //
        eventType: widget.eventType, // Menggunakan eventType dari widget
        status: 'failed_error', //
        employeeName: null, //
        distance: null, //
      );
      _resetFeedbackMessage(); //
    } finally {
      if (mounted) setState(() => _isProcessingImage = false); //
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _periodicCaptureTimer?.cancel();
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
      appBar: AppBar(
        title: Text('Check-${widget.eventType == 'check_in' ? 'In' : 'Out'} Wajah'), //
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
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
            bottom: 60,
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
                  _checkInMessage,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          if (_isProcessingImage)
            const Positioned.fill(
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
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