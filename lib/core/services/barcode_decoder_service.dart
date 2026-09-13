// lib/core/services/barcode_decoder_service.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:zxing_lib/zxing.dart';
import 'package:zxing_lib/common.dart';

/// Result from a barcode or QR code scan.
class BarcodeScanResult {
  final String text;
  final String format;

  const BarcodeScanResult({
    required this.text,
    required this.format,
  });

  @override
  String toString() => 'BarcodeScanResult(format: $format, text: $text)';
}

/// Service providing cross-platform barcode & QR code decoding
/// from camera frames, image files, or memory buffers.
class BarcodeDecoderService {
  BarcodeDecoderService._();
  static final BarcodeDecoderService instance = BarcodeDecoderService._();

  static final MultiFormatReader _reader = MultiFormatReader();

  /// Decodes a barcode or QR code from an [img.Image] object.
  static BarcodeScanResult? decodeImage(img.Image image) {
    try {
      img.Image processed = image;

      // Downscale high-resolution images (e.g. 1080p webcam frames) for speed
      if (processed.width > 1000 || processed.height > 1000) {
        processed = img.copyResize(
          processed,
          width: processed.width >= processed.height ? 1000 : null,
          height: processed.height > processed.width ? 1000 : null,
          interpolation: img.Interpolation.linear,
        );
      }

      final width = processed.width;
      final height = processed.height;
      final luminances = Uint8List(width * height);

      int idx = 0;
      for (final pixel in processed) {
        luminances[idx++] = RGBLuminanceSource.getLuminance(
          pixel.r.toInt(),
          pixel.g.toInt(),
          pixel.b.toInt(),
        );
      }

      final source = RGBLuminanceSource.orig(width, height, luminances);

      // Attempt 1: Standard HybridBinarizer (optimal for most camera frames)
      try {
        final bitmap = BinaryBitmap(HybridBinarizer(source));
        final result = _reader.decode(bitmap, const DecodeHint(tryHarder: true));
        return BarcodeScanResult(
          text: result.text,
          format: result.barcodeFormat.name,
        );
      } catch (_) {}

      // Attempt 2: Inverted Luminance (for dark mode QR codes or white on black barcodes)
      try {
        final invertedSource = InvertedLuminanceSource(source);
        final bitmap = BinaryBitmap(HybridBinarizer(invertedSource));
        final result = _reader.decode(bitmap, const DecodeHint(tryHarder: true));
        return BarcodeScanResult(
          text: result.text,
          format: result.barcodeFormat.name,
        );
      } catch (_) {}

      // Attempt 3: Global Histogram Binarizer (for uneven camera lighting or low contrast)
      try {
        final bitmap = BinaryBitmap(GlobalHistogramBinarizer(source));
        final result = _reader.decode(bitmap, const DecodeHint(tryHarder: true));
        return BarcodeScanResult(
          text: result.text,
          format: result.barcodeFormat.name,
        );
      } catch (_) {}
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Barcode decode error: $e');
      }
    }

    return null;
  }

  /// Decodes a barcode or QR code from image bytes (e.g. JPEG, PNG, WebP).
  static Future<BarcodeScanResult?> decodeBytes(Uint8List bytes) async {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) return null;
      return decodeImage(image);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Barcode decodeBytes error: $e');
      }
      return null;
    }
  }

  /// Decodes a barcode or QR code from a file on disk.
  static Future<BarcodeScanResult?> decodeFile(File file) async {
    try {
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      return decodeBytes(bytes);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Barcode decodeFile error: $e');
      }
      return null;
    }
  }
}
