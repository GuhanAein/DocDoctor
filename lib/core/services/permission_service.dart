import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<bool> ensureCamera() async {
    final status = await Permission.camera.request();
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) await openAppSettings();
    return status.isGranted;
  }

  Future<bool> ensureStorage() async {
    final status = await Permission.storage.request();
    if (status.isGranted || status.isLimited) return true;
    return false;
  }

  Future<bool> ensurePhotos() async {
    final status = await Permission.photos.request();
    if (status.isGranted || status.isLimited) return true;
    if (status.isPermanentlyDenied) await openAppSettings();
    return status.isGranted || status.isLimited;
  }
}

final permissionServiceProvider = Provider<PermissionService>((ref) => PermissionService());
