import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
// Request location permission
  static Future<bool> requestLocationPermission() async {
    print('Requesting location permission');
    
    // First check if location service is enabled
    bool serviceEnabled = await Permission.locationWhenInUse.serviceStatus.isEnabled;
    if (!serviceEnabled) {
      print('Location services are disabled');
      return false;
    }
    
    var status = await Permission.locationWhenInUse.status;
    print('Current location permission status: $status');
    
    if (status.isDenied) {
      status = await Permission.locationWhenInUse.request();
      print('Location permission after request: $status');
    }
    
    if (status.isPermanentlyDenied) {
      print('Location permission permanently denied');
      return false;
    }
    
    return status.isGranted;
  }
  // Request microphone permission
  static Future<bool> requestMicrophonePermission() async {
    print('Requesting microphone permission');
    var status = await Permission.microphone.status;
    print('Current microphone permission status: $status');
    
    if (status.isDenied) {
      status = await Permission.microphone.request();
      print('Microphone permission after request: $status');
    }
    
    if (status.isPermanentlyDenied) {
      print('Microphone permission permanently denied');
      return false;
    }
    
    return status.isGranted;
  }

  // Request storage permission
  static Future<bool> requestStoragePermission() async {
    print('Requesting storage permission');
    
    // For Android 13+ (API level 33+), we need to request specific permissions
    bool hasPhotoPermission = false;
    bool hasVideoPermission = false;
    bool hasAudioPermission = false;
    
    // Check for photos permission
    if (await Permission.photos.status.isDenied) {
      final photoStatus = await Permission.photos.request();
      hasPhotoPermission = photoStatus.isGranted;
    } else {
      hasPhotoPermission = await Permission.photos.isGranted;
    }
    
    // Check for videos permission
    if (await Permission.videos.status.isDenied) {
      final videoStatus = await Permission.videos.request();
      hasVideoPermission = videoStatus.isGranted;
    } else {
      hasVideoPermission = await Permission.videos.isGranted;
    }
    
    // Check for audio permission
    if (await Permission.audio.status.isDenied) {
      final audioStatus = await Permission.audio.request();
      hasAudioPermission = audioStatus.isGranted;
    } else {
      hasAudioPermission = await Permission.audio.isGranted;
    }
    
    // For older Android versions, use storage permission
    var storageStatus = await Permission.storage.status;
    print('Current storage permission status: $storageStatus');
    
    if (storageStatus.isDenied) {
      storageStatus = await Permission.storage.request();
      print('Storage permission after request: $storageStatus');
    }
    
    if (storageStatus.isPermanentlyDenied && 
        !hasPhotoPermission && 
        !hasVideoPermission && 
        !hasAudioPermission) {
      print('All storage permissions permanently denied');
      return false;
    }
    
    return storageStatus.isGranted || 
           hasPhotoPermission || 
           hasVideoPermission || 
           hasAudioPermission;
  }

  // Check if location permission is granted
  static Future<bool> hasLocationPermission() async {
    return await Permission.locationWhenInUse.isGranted;
  }

  // Check if microphone permission is granted
  static Future<bool> hasMicrophonePermission() async {
    return await Permission.microphone.isGranted;
  }

  // Check if storage permission is granted
  static Future<bool> hasStoragePermission() async {
    return await Permission.storage.isGranted || 
           await Permission.photos.isGranted || 
           await Permission.videos.isGranted || 
           await Permission.audio.isGranted;
  }

  // Request all permissions needed for the app
  static Future<Map<String, bool>> requestAllPermissions() async {
    Map<String, bool> permissions = {
      'location': false,
      'microphone': false,
      'storage': false,
    };
    
    // Request permissions with a small delay between each to avoid overwhelming the user
    permissions['location'] = await requestLocationPermission();
    print('Location permission result: ${permissions['location']}');
    await Future.delayed(const Duration(milliseconds: 500));
    
    permissions['microphone'] = await requestMicrophonePermission();
    print('Microphone permission result: ${permissions['microphone']}');
    await Future.delayed(const Duration(milliseconds: 500));
    
    permissions['storage'] = await requestStoragePermission();
    print('Storage permission result: ${permissions['storage']}');
    
    return permissions;
  }

  // Show permission dialog if permission is denied
  static Future<void> showPermissionDialog(BuildContext context, String permissionName) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$permissionName Diperlukan'),
          content: Text('Aplikasi memerlukan izin $permissionName untuk berfungsi dengan baik. Silakan aktifkan di pengaturan aplikasi.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () {
                openAppSettings();
                Navigator.of(context).pop();
              },
              child: const Text('Buka Pengaturan'),
            ),
          ],
        );
      },
    );
  }
}

