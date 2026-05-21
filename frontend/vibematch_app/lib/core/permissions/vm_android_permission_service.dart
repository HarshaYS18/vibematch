import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

class VmAndroidPermissionService {
  const VmAndroidPermissionService();

  Future<VmPermissionSnapshot> requestAppLaunchPermissions() async {
    if (!Platform.isAndroid) return VmPermissionSnapshot.empty();
    final permissions = <Permission>[
      Permission.notification,
      Permission.microphone,
      Permission.camera,
      Permission.photos,
      Permission.videos,
      Permission.audio,
      Permission.bluetoothConnect,
    ];
    final result = await permissions.request();
    return VmPermissionSnapshot.fromStatuses(result);
  }

  Future<bool> ensureMediaUploadPermissions() async {
    if (!Platform.isAndroid) return true;
    final statuses = await [Permission.photos, Permission.videos, Permission.storage].request();
    return statuses.values.any((status) => status.isGranted || status.isLimited);
  }

  Future<bool> ensureAudioRoomPermissions() async {
    if (!Platform.isAndroid) return true;
    final statuses = await [Permission.microphone, Permission.bluetoothConnect].request();
    return statuses[Permission.microphone]?.isGranted == true;
  }

  Future<bool> ensureVideoCallPermissions() async {
    if (!Platform.isAndroid) return true;
    final statuses = await [Permission.microphone, Permission.camera, Permission.bluetoothConnect].request();
    return statuses[Permission.microphone]?.isGranted == true && statuses[Permission.camera]?.isGranted == true;
  }
}

class VmPermissionSnapshot {
  const VmPermissionSnapshot({required this.statuses});
  final Map<Permission, PermissionStatus> statuses;

  factory VmPermissionSnapshot.empty() => const VmPermissionSnapshot(statuses: {});
  factory VmPermissionSnapshot.fromStatuses(Map<Permission, PermissionStatus> statuses) => VmPermissionSnapshot(statuses: Map.unmodifiable(statuses));

  bool get hasCriticalMediaAccess {
    final photos = statuses[Permission.photos];
    final videos = statuses[Permission.videos];
    return photos?.isGranted == true || photos?.isLimited == true || videos?.isGranted == true || videos?.isLimited == true;
  }

  bool get hasMicrophone => statuses[Permission.microphone]?.isGranted == true;
  bool get hasCamera => statuses[Permission.camera]?.isGranted == true;
  bool get hasNotifications => statuses[Permission.notification]?.isGranted == true;
}
