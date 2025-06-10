import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

class CameraService {
  static Future<CameraController> initializeCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first);

    final controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      imageFormatGroup: ImageFormatGroup.yuv420,
      enableAudio: false,
    );

    await controller.initialize();
    return controller;
  }

  static img.Image _convertYUV420ToImage(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final imgImage = img.Image(width: width, height: height);

    int uvPixelStride = uPlane.bytesPerRow ~/ (width ~/ 2);

    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        final yp = yPlane.bytes[y * yPlane.bytesPerRow + x];

        final uvX = x ~/ 2;
        final uvY = y ~/ 2;
        final uvIndex = uvY * uPlane.bytesPerRow + uvX * uvPixelStride;

        final up = uPlane.bytes[uvIndex];
        final vp = vPlane.bytes[uvIndex];

        int r = (yp + (1.370705 * (vp - 128))).round();
        int g = (yp - (0.698001 * (vp - 128)) - (0.337633 * (up - 128))).round();
        int b = (yp + (1.732446 * (up - 128))).round();

        r = r.clamp(0, 255);
        g = g.clamp(0, 255);
        b = b.clamp(0, 255);

        imgImage.setPixelRgba(x, y, r, g, b, 255);
      }
    }

    return imgImage;
  }


  static Future<Uint8List> convertCameraImageToJpeg(CameraImage image) async {
    final imgImage = _convertYUV420ToImage(image);
    final jpegData = img.encodeJpg(imgImage);
    return Uint8List.fromList(jpegData);
  }
}
