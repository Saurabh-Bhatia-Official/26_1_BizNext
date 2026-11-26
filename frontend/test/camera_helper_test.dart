// test/camera_helper_test.dart

import 'package:camera/camera.dart' as cam;
import 'package:flutter_test/flutter_test.dart';
import 'package:biz_next/core/utils/camera_helper.dart';

void main() {
  test('prioritizeCameras puts physical webcams ahead of virtual camera drivers', () {
    final rawCameras = [
      const cam.CameraDescription(
        name: 'Iriun Webcam #2',
        lensDirection: cam.CameraLensDirection.external,
        sensorOrientation: 0,
      ),
      const cam.CameraDescription(
        name: 'Iriun Webcam',
        lensDirection: cam.CameraLensDirection.external,
        sensorOrientation: 0,
      ),
      const cam.CameraDescription(
        name: 'USB2.0 FHD UVC WebCam',
        lensDirection: cam.CameraLensDirection.front,
        sensorOrientation: 0,
      ),
      const cam.CameraDescription(
        name: 'OBS Virtual Camera',
        lensDirection: cam.CameraLensDirection.external,
        sensorOrientation: 0,
      ),
    ];

    final prioritized = CameraHelper.prioritizeCameras(rawCameras);

    expect(prioritized.first.name, equals('USB2.0 FHD UVC WebCam'));
    expect(prioritized.length, equals(4));
    expect(prioritized.map((c) => c.name).toList(), [
      'USB2.0 FHD UVC WebCam',
      'Iriun Webcam #2',
      'Iriun Webcam',
      'OBS Virtual Camera',
    ]);
  });
}
