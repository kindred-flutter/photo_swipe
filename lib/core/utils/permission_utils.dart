import 'package:permission_handler/permission_handler.dart';

class PermissionUtils {
  PermissionUtils._();

  static Future<bool> requestPhotosPermission() async {
    final status = await Permission.photos.request();
    return status.isGranted || status.isLimited;
  }

  static Future<PermissionStatus> checkPhotosPermission() async {
    return await Permission.photos.status;
  }

  static Future<bool> isPermanentlyDenied() async {
    return await Permission.photos.isPermanentlyDenied;
  }

  static Future<void> openSettings() async {
    await openAppSettings();
  }
}
