import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> requestMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  static Future<bool> checkPermissions(bool isVideo) async {
    bool mic = await requestMicPermission();
    if (isVideo) {
      bool cam = await requestCameraPermission();
      return mic && cam;
    }
    return mic;
  }

  static Future<void> openSettings() async {
    await openAppSettings();
  }
}
