// lib/core/utils/camera_helper.dart

import 'package:camera/camera.dart' as cam;
import 'package:flutter/foundation.dart';

/// Helper to safely initialize and select cameras on desktop (Windows/macOS/Linux) and mobile,
/// with automatic preset fallback and hardware device prioritization over virtual drivers.
class CameraHelper {
  /// Sorts cameras to prioritize real hardware webcams over disconnected virtual drivers
  /// (such as Iriun Webcam, OBS Virtual Camera, DroidCam, etc.)
  static List<cam.CameraDescription> prioritizeCameras(List<cam.CameraDescription> cameras) {
    if (cameras.isEmpty) return [];

    final physical = <cam.CameraDescription>[];
    final virtual = <cam.CameraDescription>[];

    for (final c in cameras) {
      final name = c.name.toLowerCase();
      if (name.contains('iriun') ||
          name.contains('obs virtual') ||
          name.contains('droidcam') ||
          name.contains('epoccam') ||
          name.contains('manycam') ||
          name.contains('vmix') ||
          name.contains('hello face')) {
        virtual.add(c);
      } else {
        physical.add(c);
      }
    }

    return [...physical, ...virtual];
  }

  /// Attempts to initialize a camera controller with automatic preset and device fallback.
  /// On Windows, camera_windows requires ResolutionPreset.max for Full HD (1080p) webcams
  /// because ResolutionPreset.medium limits height to <= 480px, causing 'Failed to initialize video preview'.
  static Future<CameraInitResult> initializeWithFallback({
    required List<cam.CameraDescription> availableCameras,
    required int preferredCameraIndex,
    List<cam.ResolutionPreset> presets = const [
      cam.ResolutionPreset.max,      // No height limit in camera_windows (matches FHD/HD webcams)
      cam.ResolutionPreset.high,     // 720p
      cam.ResolutionPreset.medium,   // 480p
      cam.ResolutionPreset.veryHigh, // 1080p
      cam.ResolutionPreset.low,      // 240p
    ],
  }) async {
    if (availableCameras.isEmpty) {
      return const CameraInitResult(controller: null, workingCameraIndex: 0, errorMessage: 'No cameras detected');
    }

    final prioritized = prioritizeCameras(availableCameras);

    // Candidates list: preferred camera first if valid, then remaining prioritized cameras
    final candidates = <cam.CameraDescription>[];
    if (preferredCameraIndex >= 0 && preferredCameraIndex < availableCameras.length) {
      candidates.add(availableCameras[preferredCameraIndex]);
    }
    for (final c in prioritized) {
      if (!candidates.contains(c)) {
        candidates.add(c);
      }
    }

    String? lastError;

    for (final cameraDesc in candidates) {
      for (final preset in presets) {
        cam.CameraController? testController;
        try {
          testController = cam.CameraController(
            cameraDesc,
            preset,
            enableAudio: false,
          );
          await testController.initialize();
          if (testController.value.isInitialized) {
            final actualIndex = availableCameras.indexOf(cameraDesc);
            if (kDebugMode) {
              debugPrint('Camera "${cameraDesc.name}" successfully initialized with preset $preset (index: $actualIndex)');
            }
            return CameraInitResult(
              controller: testController,
              workingCameraIndex: actualIndex >= 0 ? actualIndex : 0,
            );
          }
        } catch (e) {
          lastError = e.toString();
          if (kDebugMode) {
            debugPrint('Camera "${cameraDesc.name}" preset $preset failed: $e');
          }
          try {
            await testController?.dispose();
          } catch (_) {}
        }
      }
    }

    return CameraInitResult(
      controller: null,
      workingCameraIndex: preferredCameraIndex,
      errorMessage: lastError ?? 'Failed to initialize video preview on any available camera',
    );
  }
}

class CameraInitResult {
  final cam.CameraController? controller;
  final int workingCameraIndex;
  final String? errorMessage;

  const CameraInitResult({
    required this.controller,
    required this.workingCameraIndex,
    this.errorMessage,
  });

  bool get isSuccess => controller != null && controller!.value.isInitialized;
}
