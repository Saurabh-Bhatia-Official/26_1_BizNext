// lib/core/services/hardware_scanner_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Diagnostic telemetry recorded for a scanned barcode.
class HardwareScannerScanLog {
  final String barcode;
  final int charCount;
  final int totalDurationMs;
  final double avgMsPerChar;
  final DateTime timestamp;
  final bool isHardwareScanner;

  const HardwareScannerScanLog({
    required this.barcode,
    required this.charCount,
    required this.totalDurationMs,
    required this.avgMsPerChar,
    required this.timestamp,
    required this.isHardwareScanner,
  });
}

/// Service that monitors physical keyboard events globally to intercept
/// high-speed keystrokes from USB or Bluetooth HID barcode scanners.
class HardwareBarcodeScannerService {
  HardwareBarcodeScannerService._() {
    _initKeyboardHandler();
  }

  static final HardwareBarcodeScannerService instance = HardwareBarcodeScannerService._();

  /// Maximum time allowed between keystrokes to be considered a hardware scanner burst (ms).
  /// Hardware scanners typically emit characters in 5ms-40ms intervals.
  static const int maxInterKeyDelayMs = 80;

  /// Minimum barcode length to prevent false positives from rapid double-clicks.
  static const int minBarcodeLength = 3;

  final StringBuffer _buffer = StringBuffer();
  DateTime? _firstCharTime;
  DateTime? _lastCharTime;
  bool _initialized = false;

  final List<void Function(String barcode)> _listeners = [];
  final StreamController<String> _barcodeStreamController = StreamController<String>.broadcast();
  final ValueNotifier<HardwareScannerScanLog?> lastScanLog = ValueNotifier<HardwareScannerScanLog?>(null);

  Stream<String> get barcodeStream => _barcodeStreamController.stream;

  void _initKeyboardHandler() {
    if (_initialized) return;
    _initialized = true;
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  /// Add a listener to receive scanned barcodes.
  void addListener(void Function(String barcode) listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  /// Remove a registered listener.
  void removeListener(void Function(String barcode) listener) {
    _listeners.remove(listener);
  }

  bool _handleKeyEvent(KeyEvent event) {
    // Only evaluate key-down events to avoid duplicates from key-up
    if (event is! KeyDownEvent) {
      return false;
    }

    final now = DateTime.now();

    // Check for Enter / Return indicating end of barcode transmission
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      final code = _buffer.toString();
      final length = code.length;

      if (length >= minBarcodeLength && _firstCharTime != null && _lastCharTime != null) {
        final totalDurationMs = _lastCharTime!.difference(_firstCharTime!).inMilliseconds;
        final avgMsPerChar = length > 1 ? totalDurationMs / (length - 1) : 0.0;

        // Verify that this was a rapid hardware burst, not slow human keyboard typing
        final isFastBurst = avgMsPerChar <= maxInterKeyDelayMs || (totalDurationMs <= 600 && length >= 5);

        final log = HardwareScannerScanLog(
          barcode: code,
          charCount: length,
          totalDurationMs: totalDurationMs,
          avgMsPerChar: avgMsPerChar,
          timestamp: now,
          isHardwareScanner: isFastBurst,
        );
        lastScanLog.value = log;

        _resetBuffer();

        if (isFastBurst && _listeners.isNotEmpty) {
          if (kDebugMode) {
            debugPrint('Hardware Barcode Scanned: "$code" ($length chars, avg ${avgMsPerChar.toStringAsFixed(1)}ms/char)');
          }

          // Make a copy of listeners to avoid ConcurrentModificationException
          final currentListeners = List<void Function(String)>.from(_listeners);
          for (final listener in currentListeners) {
            try {
              listener(code);
            } catch (e) {
              if (kDebugMode) debugPrint('Hardware scanner listener error: $e');
            }
          }

          _barcodeStreamController.add(code);

          // Audio/haptic feedback
          SystemSound.play(SystemSoundType.click);

          // Return true to consume the Enter key so it doesn't trigger unrelated buttons
          return true;
        }
      }

      _resetBuffer();
      return false;
    }

    final char = event.character;
    if (char != null && char.isNotEmpty && char != '\n' && char != '\r') {
      if (_lastCharTime != null) {
        final interval = now.difference(_lastCharTime!).inMilliseconds;
        // If elapsed time since last character is too long, clear stale buffer
        if (interval > maxInterKeyDelayMs * 2) {
          _buffer.clear();
          _firstCharTime = now;
        }
      } else {
        _firstCharTime = now;
      }

      _lastCharTime = now;
      _buffer.write(char);
    }

    return false;
  }

  void _resetBuffer() {
    _buffer.clear();
    _firstCharTime = null;
    _lastCharTime = null;
  }

  /// Diagnostic method to simulate a hardware scanner scan (useful for unit tests & demos).
  void simulateHardwareScan(String barcode) {
    final log = HardwareScannerScanLog(
      barcode: barcode,
      charCount: barcode.length,
      totalDurationMs: barcode.length * 15,
      avgMsPerChar: 15.0,
      timestamp: DateTime.now(),
      isHardwareScanner: true,
    );
    lastScanLog.value = log;

    final currentListeners = List<void Function(String)>.from(_listeners);
    for (final listener in currentListeners) {
      listener(barcode);
    }
    _barcodeStreamController.add(barcode);
    SystemSound.play(SystemSoundType.click);
  }
}

/// Declarative widget that listens for hardware barcode scans while mounted and enabled.
class HardwareBarcodeScannerListener extends StatefulWidget {
  final Widget child;
  final ValueChanged<String> onBarcodeScanned;
  final bool isEnabled;

  const HardwareBarcodeScannerListener({
    super.key,
    required this.child,
    required this.onBarcodeScanned,
    this.isEnabled = true,
  });

  @override
  State<HardwareBarcodeScannerListener> createState() => _HardwareBarcodeScannerListenerState();
}

class _HardwareBarcodeScannerListenerState extends State<HardwareBarcodeScannerListener> {
  @override
  void initState() {
    super.initState();
    if (widget.isEnabled) {
      HardwareBarcodeScannerService.instance.addListener(_handleScan);
    }
  }

  @override
  void didUpdateWidget(HardwareBarcodeScannerListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isEnabled != widget.isEnabled) {
      if (widget.isEnabled) {
        HardwareBarcodeScannerService.instance.addListener(_handleScan);
      } else {
        HardwareBarcodeScannerService.instance.removeListener(_handleScan);
      }
    }
  }

  @override
  void dispose() {
    HardwareBarcodeScannerService.instance.removeListener(_handleScan);
    super.dispose();
  }

  void _handleScan(String barcode) {
    if (mounted && widget.isEnabled) {
      widget.onBarcodeScanned(barcode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
