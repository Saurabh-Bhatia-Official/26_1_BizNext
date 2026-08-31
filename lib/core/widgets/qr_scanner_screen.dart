// lib/core/widgets/qr_scanner_screen.dart

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as ms;
import 'package:camera/camera.dart' as cam;
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../theme/app_theme.dart';

class QRScannerScreen extends StatefulWidget {
  final int initialCameraIndex;
  const QRScannerScreen({super.key, this.initialCameraIndex = 0});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  // Mobile Scanner
  ms.MobileScannerController? msController;
  
  // Windows Camera
  cam.CameraController? camController;
  List<cam.CameraDescription>? cameras;
  bool isCamInitialized = false;
  late int selectedCameraIndex;

  bool isWindows = !kIsWeb && Platform.isWindows;

  @override
  void initState() {
    super.initState();
    selectedCameraIndex = widget.initialCameraIndex;
    if (isWindows) {
      _initWindowsCamera();
    } else {
      msController = ms.MobileScannerController();
    }
  }

  Future<void> _initWindowsCamera() async {
    try {
      cameras = await cam.availableCameras();
      if (cameras != null && cameras!.isNotEmpty) {
        if (selectedCameraIndex >= cameras!.length) {
          selectedCameraIndex = 0;
        }

        if (camController != null) {
          final old = camController;
          camController = null;
          try {
            await old?.dispose();
          } catch (_) {}
        }

        final cameraDesc = cameras![selectedCameraIndex];
        cam.CameraController? newController;
        final presets = [
          cam.ResolutionPreset.medium,
          cam.ResolutionPreset.low,
          cam.ResolutionPreset.high,
        ];

        for (final preset in presets) {
          try {
            newController = cam.CameraController(
              cameraDesc,
              preset,
              enableAudio: false,
            );
            await newController.initialize();
            if (newController.value.isInitialized) {
              break;
            }
          } catch (e) {
            if (kDebugMode) debugPrint('QR Scanner Preset $preset failed: $e');
            try {
              await newController?.dispose();
            } catch (_) {}
            newController = null;
          }
        }

        if (mounted) {
          setState(() {
            camController = newController;
            isCamInitialized = newController != null && newController.value.isInitialized;
          });
        } else {
          try {
            await newController?.dispose();
          } catch (_) {}
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Camera init error: $e');
    }
  }

  @override
  void dispose() {
    msController?.dispose();
    final c = camController;
    camController = null;
    try {
      c?.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── App Bar Area ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button
                  _CircleButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  
                  const Text(
                    'Scanner',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),

                  // Camera Switch
                  _CircleButton(
                    icon: Icons.cameraswitch_rounded,
                    onTap: () async {
                      if (isWindows) {
                        if (cameras != null && cameras!.length > 1) {
                          setState(() {
                            isCamInitialized = false;
                            selectedCameraIndex = (selectedCameraIndex + 1) % cameras!.length;
                          });
                          _initWindowsCamera();
                        }
                      } else {
                        await msController?.switchCamera();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          // ── Limited Scanner Box (Center) ──
          Center(
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: isWindows
                    ? (isCamInitialized && camController != null
                        ? cam.CameraPreview(camController!)
                        : const Center(child: CircularProgressIndicator()))
                    : ms.MobileScanner(
                        controller: msController!,
                        fit: BoxFit.cover,
                        onDetect: (capture) {
                          final List<ms.Barcode> barcodes = capture.barcodes;
                          if (barcodes.isNotEmpty) {
                            final String? code = barcodes.first.rawValue;
                            if (code != null) {
                              Navigator.pop(context, code);
                            }
                          }
                        },
                      ),
              ),
            ),
          ),

          // ── Instruction Text (Bottom) ──
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Align the code within the frame to scan',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),
          
          // If Windows, add a "Capture" button
          if (isWindows)
            Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // Return a mock code for demonstration on Windows
                    Navigator.pop(context, 'MOCK_CODE_123');
                  },
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('Capture & Scan'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
