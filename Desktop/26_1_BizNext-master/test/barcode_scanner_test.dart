import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:zxing_lib/zxing.dart';
import 'package:zxing_lib/common.dart';
import 'package:image/image.dart' as img;

void main() {
  test('MultiFormatWriter generates and MultiFormatReader decodes QR code', () {
    const testContent = 'BIZ-PROD-987654';
    
    // Generate QR with zxing_lib
    final writer = MultiFormatWriter();
    final bitMatrix = writer.encode(
      testContent,
      BarcodeFormat.qrCode,
      200,
      200,
      const EncodeHint(margin: 1),
    );

    // Convert bitMatrix to luminances
    final luminances = Uint8List(bitMatrix.width * bitMatrix.height);
    int idx = 0;
    for (int y = 0; y < bitMatrix.height; y++) {
      for (int x = 0; x < bitMatrix.width; x++) {
        final isBlack = bitMatrix.get(x, y);
        final val = isBlack ? 0 : 255;
        luminances[idx++] = val;
      }
    }

    // Now decode using MultiFormatReader
    final source = RGBLuminanceSource.orig(bitMatrix.width, bitMatrix.height, luminances);
    final bitmap = BinaryBitmap(HybridBinarizer(source));
    final reader = MultiFormatReader();
    final result = reader.decode(bitmap, const DecodeHint(tryHarder: true));

    expect(result.text, equals(testContent));
  });

  test('MultiFormatWriter generates and MultiFormatReader decodes Code128 barcode', () {
    const testBarcode = '1234567890';
    
    final writer = MultiFormatWriter();
    final bitMatrix = writer.encode(
      testBarcode,
      BarcodeFormat.code128,
      200,
      80,
      const EncodeHint(margin: 10),
    );

    final luminances = Uint8List(bitMatrix.width * bitMatrix.height);
    int idx = 0;
    for (int y = 0; y < bitMatrix.height; y++) {
      for (int x = 0; x < bitMatrix.width; x++) {
        final isBlack = bitMatrix.get(x, y);
        final val = isBlack ? 0 : 255;
        luminances[idx++] = val;
      }
    }

    final source = RGBLuminanceSource.orig(bitMatrix.width, bitMatrix.height, luminances);
    final bitmap = BinaryBitmap(HybridBinarizer(source));
    final reader = MultiFormatReader();
    final result = reader.decode(bitmap, const DecodeHint(tryHarder: true));

    expect(result.text, equals(testBarcode));
  });

  test('Decode QR code from PNG image bytes', () {
    const testContent = 'ENTERPRISE-INVOICE-2026-9901';
    final writer = MultiFormatWriter();
    final bitMatrix = writer.encode(
      testContent,
      BarcodeFormat.qrCode,
      250,
      250,
      const EncodeHint(margin: 2),
    );

    // Create an img.Image from bitMatrix
    final imgImage = img.Image(width: bitMatrix.width, height: bitMatrix.height);
    for (int y = 0; y < bitMatrix.height; y++) {
      for (int x = 0; x < bitMatrix.width; x++) {
        final isBlack = bitMatrix.get(x, y);
        imgImage.setPixelRgb(x, y, isBlack ? 0 : 255, isBlack ? 0 : 255, isBlack ? 0 : 255);
      }
    }

    final pngBytes = Uint8List.fromList(img.encodePng(imgImage));

    // Now decode bytes using image package + zxing_lib
    final decodedImg = img.decodeImage(pngBytes);
    expect(decodedImg, isNotNull);

    final width = decodedImg!.width;
    final height = decodedImg.height;
    final luminances = Uint8List(width * height);
    int idx = 0;
    for (final pixel in decodedImg) {
      luminances[idx++] = RGBLuminanceSource.getLuminance(
        pixel.r.toInt(),
        pixel.g.toInt(),
        pixel.b.toInt(),
      );
    }

    final source = RGBLuminanceSource.orig(width, height, luminances);
    final bitmap = BinaryBitmap(HybridBinarizer(source));
    final reader = MultiFormatReader();
    final result = reader.decode(bitmap, const DecodeHint(tryHarder: true));

    expect(result.text, equals(testContent));
  });

  test('Decode Inverted QR code using InvertedLuminanceSource', () {
    const testContent = 'INVERTED-QR-999';
    final writer = MultiFormatWriter();
    final bitMatrix = writer.encode(
      testContent,
      BarcodeFormat.qrCode,
      200,
      200,
      const EncodeHint(margin: 2),
    );

    // Create inverted image: black becomes white, white becomes black
    final imgImage = img.Image(width: bitMatrix.width, height: bitMatrix.height);
    for (int y = 0; y < bitMatrix.height; y++) {
      for (int x = 0; x < bitMatrix.width; x++) {
        final isBlack = bitMatrix.get(x, y);
        // INVERT: black module -> 255 (white), white background -> 0 (black)
        final val = isBlack ? 255 : 0;
        imgImage.setPixelRgb(x, y, val, val, val);
      }
    }

    final pngBytes = Uint8List.fromList(img.encodePng(imgImage));
    final decodedImg = img.decodeImage(pngBytes);
    expect(decodedImg, isNotNull);

    final width = decodedImg!.width;
    final height = decodedImg.height;
    final luminances = Uint8List(width * height);
    int idx = 0;
    for (final pixel in decodedImg) {
      luminances[idx++] = RGBLuminanceSource.getLuminance(
        pixel.r.toInt(),
        pixel.g.toInt(),
        pixel.b.toInt(),
      );
    }

    final source = RGBLuminanceSource.orig(width, height, luminances);
    final invertedSource = InvertedLuminanceSource(source);
    final bitmap = BinaryBitmap(HybridBinarizer(invertedSource));
    final reader = MultiFormatReader();
    final result = reader.decode(bitmap, const DecodeHint(tryHarder: true));

    expect(result.text, equals(testContent));
  });
}
