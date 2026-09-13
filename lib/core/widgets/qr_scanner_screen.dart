// lib/core/widgets/qr_scanner_screen.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart' as cam;
import 'package:mobile_scanner/mobile_scanner.dart' as ms;
import 'package:file_picker/file_picker.dart';
import '../services/barcode_decoder_service.dart';
import '../services/hardware_scanner_service.dart';
import '../utils/camera_helper.dart';
import '../theme/app_theme.dart';

class QRScannerScreen extends StatefulWidget {
  final int initialCameraIndex;
  const QRScannerScreen({super.key, this.initialCameraIndex = 0});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> with SingleTickerProviderStateMixin {
  // Mobile Scanner (used on Android / iOS)
  ms.MobileScannerController? msController;

  // Desktop / Laptop Camera Controller (Windows / macOS / Linux)
  cam.CameraController? camController;
  List<cam.CameraDescription>? cameras;
  bool isCamInitialized = false;
  late int selectedCameraIndex;

  final bool isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  // Auto-scan state for laptop camera
  Timer? _autoScanTimer;
  bool _isProcessingFrame = false;
  final bool _autoScanEnabled = true;
  String? _cameraErrorMessage;

  // Animated laser line
  late AnimationController _laserAnimController;
  late Animation<double> _laserAnimation;

  @override
  void initState() {
    super.initState();
    selectedCameraIndex = widget.initialCameraIndex;

    _laserAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _laserAnimController, curve: Curves.easeInOut),
    );

    if (isDesktop) {
      _initDesktopCamera();
    } else {
      msController = ms.MobileScannerController();
    }
  }

  Future<void> _initDesktopCamera() async {
    setState(() => _cameraErrorMessage = null);
    try {
      cameras = await cam.availableCameras();
      if (cameras != null && cameras!.isNotEmpty) {
        if (camController != null) {
          final old = camController;
          camController = null;
          try {
            await old?.dispose();
          } catch (_) {}
        }

        final result = await CameraHelper.initializeWithFallback(
          availableCameras: cameras!,
          preferredCameraIndex: selectedCameraIndex,
        );

        if (mounted) {
          setState(() {
            camController = result.controller;
            selectedCameraIndex = result.workingCameraIndex;
            isCamInitialized = result.isSuccess;
            _cameraErrorMessage = result.isSuccess ? null : result.errorMessage;
          });

          if (isCamInitialized) {
            _startAutoScan();
          }
        } else {
          try {
            await result.controller?.dispose();
          } catch (_) {}
        }
      } else {
        if (mounted) {
          setState(() {
            _cameraErrorMessage = 'No webcam devices detected on this computer.';
          });
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Desktop camera initialization error: $e');
      if (mounted) {
        setState(() {
          _cameraErrorMessage = 'Camera error: $e';
        });
      }
    }
  }

  void _startAutoScan() {
    _autoScanTimer?.cancel();
    _autoScanTimer = Timer.periodic(const Duration(milliseconds: 650), (_) async {
      if (!mounted || !_autoScanEnabled || _isProcessingFrame || camController == null || !isCamInitialized) {
        return;
      }

      _isProcessingFrame = true;
      try {
        if (camController!.value.isInitialized && !camController!.value.isTakingPicture) {
          final xfile = await camController!.takePicture();
          final bytes = await xfile.readAsBytes();
          try {
            await File(xfile.path).delete();
          } catch (_) {}

          final result = await BarcodeDecoderService.decodeBytes(bytes);
          if (result != null && mounted) {
            _autoScanTimer?.cancel();
            _onScanSuccess(result.text);
            return;
          }
        }
      } catch (e) {
        // Frame capture busy or dropped; retry on next cycle
      } finally {
        _isProcessingFrame = false;
      }
    });
  }

  Future<void> _manualCaptureAndScan() async {
    if (camController == null || !isCamInitialized || _isProcessingFrame) return;

    setState(() => _isProcessingFrame = true);
    try {
      final xfile = await camController!.takePicture();
      final bytes = await xfile.readAsBytes();
      try {
        await File(xfile.path).delete();
      } catch (_) {}

      final result = await BarcodeDecoderService.decodeBytes(bytes);
      if (result != null && mounted) {
        _onScanSuccess(result.text);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('No barcode or QR code detected. Try holding closer or adjusting lighting.')),
              ],
            ),
            backgroundColor: AppColors.primaryDark,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera capture failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingFrame = false);
    }
  }

  Future<void> _pickImageAndScan() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final scanResult = await BarcodeDecoderService.decodeFile(File(path));

        if (scanResult != null && mounted) {
          _onScanSuccess(scanResult.text);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No QR code or barcode found in selected image.'),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Pick image scan error: $e');
    }
  }

  void _onScanSuccess(String code) {
    if (!mounted) return;
    SystemSound.play(SystemSoundType.click);
    Navigator.pop(context, code);
  }

  @override
  void dispose() {
    _autoScanTimer?.cancel();
    _laserAnimController.dispose();
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
    return HardwareBarcodeScannerListener(
      onBarcodeScanned: _onScanSuccess,
      child: Scaffold(
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
                      tooltip: 'Back',
                      onTap: () => Navigator.pop(context),
                    ),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          isDesktop ? 'Laptop Webcam Scanner' : 'Barcode & QR Scanner',
                          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Pick Image File button
                        _CircleButton(
                          icon: Icons.image_search_rounded,
                          tooltip: 'Scan from Image File',
                          onTap: _pickImageAndScan,
                        ),
                        const SizedBox(width: 8),
                        // Camera Switch button
                        _CircleButton(
                          icon: Icons.cameraswitch_rounded,
                          tooltip: 'Switch Camera',
                          onTap: () async {
                            if (isDesktop) {
                              if (cameras != null && cameras!.length > 1) {
                                setState(() {
                                  isCamInitialized = false;
                                  selectedCameraIndex = (selectedCameraIndex + 1) % cameras!.length;
                                });
                                _initDesktopCamera();
                              }
                            } else {
                              await msController?.switchCamera();
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Scanner Viewfinder Box (Center) ──
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary, width: 2.5),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (isDesktop)
                            (isCamInitialized && camController != null
                                ? cam.CameraPreview(camController!)
                                : Container(
                                    color: const Color(0xFF1E293B),
                                    padding: const EdgeInsets.all(16),
                                    child: Center(
                                      child: _cameraErrorMessage != null
                                          ? Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Icon(Icons.videocam_off_rounded, color: AppColors.warning, size: 36),
                                                const SizedBox(height: 8),
                                                const Text(
                                                  'Webcam Unavailable',
                                                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  _cameraErrorMessage!,
                                                  textAlign: TextAlign.center,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                                                ),
                                                const SizedBox(height: 12),
                                                Wrap(
                                                  spacing: 8,
                                                  children: [
                                                    ElevatedButton.icon(
                                                      onPressed: _initDesktopCamera,
                                                      icon: const Icon(Icons.refresh_rounded, size: 14),
                                                      label: const Text('Retry', style: TextStyle(fontSize: 11)),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: AppColors.primary,
                                                        foregroundColor: Colors.white,
                                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                      ),
                                                    ),
                                                    if (cameras != null && cameras!.length > 1)
                                                      OutlinedButton.icon(
                                                        onPressed: () {
                                                          setState(() {
                                                            selectedCameraIndex = (selectedCameraIndex + 1) % cameras!.length;
                                                            isCamInitialized = false;
                                                          });
                                                          _initDesktopCamera();
                                                        },
                                                        icon: const Icon(Icons.cameraswitch_rounded, size: 14),
                                                        label: const Text('Switch', style: TextStyle(fontSize: 11)),
                                                        style: OutlinedButton.styleFrom(
                                                          foregroundColor: Colors.white,
                                                          side: const BorderSide(color: Colors.white24),
                                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ],
                                            )
                                          : const Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                CircularProgressIndicator(color: AppColors.primary),
                                                SizedBox(height: 12),
                                                Text(
                                                  'Connecting to Laptop Webcam...',
                                                  style: TextStyle(color: Colors.white70, fontSize: 13),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ))
                          else
                            ms.MobileScanner(
                              controller: msController!,
                              fit: BoxFit.cover,
                              onDetect: (capture) {
                                final List<ms.Barcode> barcodes = capture.barcodes;
                                if (barcodes.isNotEmpty) {
                                  final String? code = barcodes.first.rawValue;
                                  if (code != null) {
                                    _onScanSuccess(code);
                                  }
                                }
                              },
                            ),

                          // Animated Scanning Laser Line
                          AnimatedBuilder(
                            animation: _laserAnimation,
                            builder: (context, child) {
                              return Positioned(
                                top: 320 * _laserAnimation.value,
                                left: 16,
                                right: 16,
                                child: Container(
                                  height: 2.5,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        Color(0xFF22C55E),
                                        Color(0xFF00F0FF),
                                        Color(0xFF22C55E),
                                        Colors.transparent,
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF00F0FF).withValues(alpha: 0.8),
                                        blurRadius: 10,
                                        spreadRadius: 1.5,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                          // Corner accents
                          const Positioned(
                            top: 8,
                            left: 8,
                            child: Icon(Icons.crop_free_rounded, color: Colors.white54, size: 28),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Hardware scanner / auto-scan status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isDesktop
                              ? 'Live Auto-Scan Active • USB/BT Scanner Ready'
                              : 'Point camera at QR or Barcode',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Desktop Controls / Action Buttons (Bottom) ──
            Positioned(
              bottom: 36,
              left: 20,
              right: 20,
              child: Center(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    if (isDesktop)
                      ElevatedButton.icon(
                        onPressed: _isProcessingFrame ? null : _manualCaptureAndScan,
                        icon: _isProcessingFrame
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.camera_alt_rounded),
                        label: Text(_isProcessingFrame ? 'Decoding...' : 'Capture & Scan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 6,
                        ),
                      ),

                    OutlinedButton.icon(
                      onPressed: _pickImageAndScan,
                      icon: const Icon(Icons.photo_library_rounded, size: 18),
                      label: const Text('From File'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  const _CircleButton({required this.icon, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final button = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white10),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}
