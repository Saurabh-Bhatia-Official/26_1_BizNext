// test/hardware_scanner_test.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zxing_lib/zxing.dart';
import 'package:biz_next/core/services/barcode_decoder_service.dart';
import 'package:biz_next/core/services/hardware_scanner_service.dart';

void main() {
  group('BarcodeDecoderService Tests', () {
    test('Decodes generated QR Code bytes successfully', () async {
      const payload = 'PROD-QR-2026-TEST';
      final writer = MultiFormatWriter();
      final bitMatrix = writer.encode(
        payload,
        BarcodeFormat.qrCode,
        200,
        200,
        const EncodeHint(margin: 1),
      );

      final imgImage = img.Image(width: bitMatrix.width, height: bitMatrix.height);
      for (int y = 0; y < bitMatrix.height; y++) {
        for (int x = 0; x < bitMatrix.width; x++) {
          final isBlack = bitMatrix.get(x, y);
          imgImage.setPixelRgb(x, y, isBlack ? 0 : 255, isBlack ? 0 : 255, isBlack ? 0 : 255);
        }
      }

      final pngBytes = Uint8List.fromList(img.encodePng(imgImage));
      final result = await BarcodeDecoderService.decodeBytes(pngBytes);

      expect(result, isNotNull);
      expect(result!.text, equals(payload));
    });

    test('Decodes generated Code 128 barcode bytes successfully', () async {
      const barcodeData = '8901030383321'; // Typical 13-digit EAN/Code128
      final writer = MultiFormatWriter();
      final bitMatrix = writer.encode(
        barcodeData,
        BarcodeFormat.code128,
        240,
        100,
        const EncodeHint(margin: 10),
      );

      final imgImage = img.Image(width: bitMatrix.width, height: bitMatrix.height);
      for (int y = 0; y < bitMatrix.height; y++) {
        for (int x = 0; x < bitMatrix.width; x++) {
          final isBlack = bitMatrix.get(x, y);
          imgImage.setPixelRgb(x, y, isBlack ? 0 : 255, isBlack ? 0 : 255, isBlack ? 0 : 255);
        }
      }

      final pngBytes = Uint8List.fromList(img.encodePng(imgImage));
      final result = await BarcodeDecoderService.decodeBytes(pngBytes);

      expect(result, isNotNull);
      expect(result!.text, equals(barcodeData));
    });

    test('Returns null for blank/corrupt image bytes without crashing', () async {
      final corruptBytes = Uint8List.fromList([0, 1, 2, 3, 4, 5]);
      final result = await BarcodeDecoderService.decodeBytes(corruptBytes);
      expect(result, isNull);
    });
  });

  group('HardwareBarcodeScannerService Tests', () {
    test('Simulated hardware scan invokes listeners and updates scan log', () {
      final service = HardwareBarcodeScannerService.instance;
      String? scannedBarcode;

      void listener(String code) {
        scannedBarcode = code;
      }

      service.addListener(listener);
      service.simulateHardwareScan('8901234567890');

      expect(scannedBarcode, equals('8901234567890'));
      expect(service.lastScanLog.value, isNotNull);
      expect(service.lastScanLog.value!.barcode, equals('8901234567890'));
      expect(service.lastScanLog.value!.isHardwareScanner, isTrue);

      service.removeListener(listener);
    });

    testWidgets('HardwareBarcodeScannerListener widget forwards scans when enabled', (tester) async {
      String? received;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HardwareBarcodeScannerListener(
              isEnabled: true,
              onBarcodeScanned: (code) {
                received = code;
              },
              child: const Text('POS Body'),
            ),
          ),
        ),
      );

      expect(find.text('POS Body'), findsOneWidget);

      HardwareBarcodeScannerService.instance.simulateHardwareScan('SCAN-WIDGET-001');
      await tester.pump();

      expect(received, equals('SCAN-WIDGET-001'));
    });
  });
}
