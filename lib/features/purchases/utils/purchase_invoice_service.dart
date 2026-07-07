// lib/features/purchases/utils/purchase_invoice_service.dart

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../auth/models/business_model.dart';
import '../models/purchase_model.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';

class PurchaseInvoiceService {
  static Future<void> generateAndPrintPurchase({
    required BusinessModel business,
    required PurchaseModel purchase,
    int templateId = 0,
  }) async {
    final pdf = await _generateDocument(business, purchase, templateId);

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Purchase_Bill_${purchase.billNo ?? purchase.id}',
    );
  }

  static Future<void> exportPurchasePDF({
    required BusinessModel business,
    required PurchaseModel purchase,
    int templateId = 0,
  }) async {
    final pdf = await _generateDocument(business, purchase, templateId);
    final bytes = await pdf.save();

    final safeBillNo = (purchase.billNo ?? 'Bill_${purchase.id}').replaceAll(RegExp(r'[^\w\-]'), '_');
    final fileName = 'Purchase_$safeBillNo.pdf';

    final output = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Purchase PDF',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (output != null) {
      final file = File(output);
      await file.writeAsBytes(bytes);
    }
  }

  static Future<pw.Document> _generateDocument(
    BusinessModel business,
    PurchaseModel purchase,
    int templateId,
  ) async {
    final pdf = pw.Document();

    // Fonts per template
    final fontRegular = (templateId == 2)
        ? await PdfGoogleFonts.robotoRegular()
        : await PdfGoogleFonts.interRegular();
    final fontBold = (templateId == 2)
        ? await PdfGoogleFonts.robotoBold()
        : await PdfGoogleFonts.interBold();

    // Colors per template
    PdfColor primaryColor;
    switch (templateId) {
      case 1: // Modern Indigo
        primaryColor = PdfColors.indigo900;
        break;
      case 2: // Minimalist Charcoal
        primaryColor = PdfColors.grey900;
        break;
      case 3: // Crimson Premium
        primaryColor = PdfColors.red900;
        break;
      case 0: // Classic Blue
      default:
        primaryColor = PdfColors.blue900;
        break;
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── Header (template-specific) ──
              if (templateId == 1) ...[
                // Modern Indigo Banner Header
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: primaryColor,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            business.name,
                            style: pw.TextStyle(font: fontBold, fontSize: 22, color: PdfColors.white),
                          ),
                          pw.SizedBox(height: 4),
                          if (business.address != null)
                            pw.Text(business.address!, style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.grey200)),
                          if (business.phone != null)
                            pw.Text('Ph: ${business.phone}', style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.grey200)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('PURCHASE BILL', style: pw.TextStyle(font: fontBold, fontSize: 20, color: PdfColors.white)),
                          pw.Text('Bill #: ${purchase.billNo ?? purchase.id}', style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.grey200)),
                          pw.Text('Date: ${DateFormatter.toDisplay(purchase.date)}', style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.grey200)),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 24),
              ] else if (templateId == 2) ...[
                // Minimalist Charcoal Clean Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          business.name.toUpperCase(),
                          style: pw.TextStyle(font: fontBold, fontSize: 20, color: primaryColor),
                        ),
                        pw.SizedBox(height: 4),
                        if (business.address != null)
                          pw.Text(business.address!, style: pw.TextStyle(font: fontRegular, fontSize: 9)),
                        if (business.phone != null)
                          pw.Text('Phone: ${business.phone}', style: pw.TextStyle(font: fontRegular, fontSize: 9)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('PURCHASE BILL', style: pw.TextStyle(font: fontBold, fontSize: 20, color: PdfColors.grey800)),
                        pw.Text('Bill #: ${purchase.billNo ?? purchase.id}', style: pw.TextStyle(font: fontRegular, fontSize: 10)),
                        pw.Text('Date: ${DateFormatter.toDisplay(purchase.date)}', style: pw.TextStyle(font: fontRegular, fontSize: 9)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Divider(thickness: 1, color: PdfColors.grey400),
                pw.SizedBox(height: 20),
              ] else ...[
                // Classic Blue & Crimson standard layout
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          business.name,
                          style: pw.TextStyle(font: fontBold, fontSize: 24, color: primaryColor),
                        ),
                        pw.SizedBox(height: 4),
                        if (business.address != null)
                          pw.Text(business.address!, style: pw.TextStyle(font: fontRegular, fontSize: 10)),
                        if (business.phone != null)
                          pw.Text('Phone: ${business.phone}', style: pw.TextStyle(font: fontRegular, fontSize: 10)),
                        if (business.gstNumber != null)
                          pw.Text('GSTIN: ${business.gstNumber}', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('PURCHASE BILL', style: pw.TextStyle(font: fontBold, fontSize: 24, color: PdfColors.grey700)),
                        pw.SizedBox(height: 8),
                        pw.Text('Bill #: ${purchase.billNo ?? purchase.id}', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                        pw.Text('Date: ${DateFormatter.toDisplay(purchase.date)}', style: pw.TextStyle(font: fontRegular, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
                pw.Divider(thickness: 2, color: primaryColor, height: 40),
              ],

              // ── Supplier / Bill Info ──
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('VENDOR / SUPPLIER:', style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.grey700)),
                      pw.SizedBox(height: 4),
                      pw.Text(purchase.supplierName ?? 'Direct Supplier', style: pw.TextStyle(font: fontBold, fontSize: 14)),
                      pw.Text('Account: ${purchase.accountName ?? "Main Account"}', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('BILL STATUS:', style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.grey700)),
                      pw.SizedBox(height: 4),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: purchase.status == 'completed' ? PdfColors.green100 : PdfColors.orange100,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          purchase.status.toUpperCase(),
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 10,
                            color: purchase.status == 'completed' ? PdfColors.green800 : PdfColors.orange800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // ── Items Table Header ──
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                padding: const pw.EdgeInsets.all(8),
                child: pw.Row(
                  children: [
                    pw.Expanded(flex: 4, child: pw.Text('Item Description', style: pw.TextStyle(font: fontBold, color: PdfColors.white, fontSize: 10))),
                    pw.Expanded(flex: 1, child: pw.Text('Qty', style: pw.TextStyle(font: fontBold, color: PdfColors.white, fontSize: 10), textAlign: pw.TextAlign.center)),
                    pw.Expanded(flex: 2, child: pw.Text('Rate', style: pw.TextStyle(font: fontBold, color: PdfColors.white, fontSize: 10), textAlign: pw.TextAlign.right)),
                    pw.Expanded(flex: 1, child: pw.Text('GST', style: pw.TextStyle(font: fontBold, color: PdfColors.white, fontSize: 10), textAlign: pw.TextAlign.right)),
                    pw.Expanded(flex: 2, child: pw.Text('Amount', style: pw.TextStyle(font: fontBold, color: PdfColors.white, fontSize: 10), textAlign: pw.TextAlign.right)),
                  ],
                ),
              ),

              // ── Items Table Rows ──
              if (purchase.items != null)
                ...purchase.items!.map((item) => pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 4, child: pw.Text(item.productName, style: pw.TextStyle(font: fontRegular, fontSize: 10))),
                      pw.Expanded(flex: 1, child: pw.Text(item.quantity.toStringAsFixed(0), style: pw.TextStyle(font: fontRegular, fontSize: 10), textAlign: pw.TextAlign.center)),
                      pw.Expanded(flex: 2, child: pw.Text(CurrencyFormatter.format(item.purchasePrice), style: pw.TextStyle(font: fontRegular, fontSize: 10), textAlign: pw.TextAlign.right)),
                      pw.Expanded(
                        flex: 1,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text('${item.gstPercent.toInt()}%', style: pw.TextStyle(font: fontRegular, fontSize: 10)),
                          ],
                        ),
                      ),
                      pw.Expanded(flex: 2, child: pw.Text(CurrencyFormatter.format(item.total), style: pw.TextStyle(font: fontBold, fontSize: 10), textAlign: pw.TextAlign.right)),
                    ],
                  ),
                )),

              pw.SizedBox(height: 20),

              // ── Totals ──
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      _buildTotalRow('Subtotal:', CurrencyFormatter.format(purchase.subtotal), fontRegular),
                      _buildTotalRow('Tax (GST):', CurrencyFormatter.format(purchase.gstAmount), fontRegular),
                      if (purchase.discount > 0) _buildTotalRow('Discount:', '-${CurrencyFormatter.format(purchase.discount)}', fontRegular),
                      pw.Divider(color: PdfColors.grey400),
                      _buildTotalRow('Grand Total:', CurrencyFormatter.format(purchase.grandTotal), fontBold, isLarge: true, primaryColor: primaryColor),
                      _buildTotalRow('Amount Paid:', CurrencyFormatter.format(purchase.paidAmount), fontRegular),
                      _buildTotalRow(
                        'Balance Due:',
                        CurrencyFormatter.format(purchase.balanceDue),
                        fontBold,
                        color: purchase.balanceDue > 0 ? PdfColors.red : PdfColors.green,
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text('Payment Mode: ${purchase.paymentMode}', style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),

              pw.Spacer(),

              // ── Footer ──
              pw.Divider(color: PdfColors.grey400),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (purchase.notes != null && purchase.notes!.isNotEmpty) ...[
                        pw.Text('Notes:', style: pw.TextStyle(font: fontBold, fontSize: 8)),
                        pw.Text(purchase.notes!, style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                      ],
                      pw.Text('Terms & Conditions:', style: pw.TextStyle(font: fontBold, fontSize: 8)),
                      pw.Text('1. This is a computer generated purchase record.', style: pw.TextStyle(font: fontRegular, fontSize: 7)),
                      pw.Text('2. Subject to local jurisdiction.', style: pw.TextStyle(font: fontRegular, fontSize: 7)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.SizedBox(height: 20),
                      pw.Text('Authorized Receiver', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                      pw.SizedBox(height: 5),
                      pw.Text('For ${business.name}', style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text('Thank you for your business!', style: pw.TextStyle(font: fontRegular, fontStyle: pw.FontStyle.italic, fontSize: 8)),
              ),
            ],
          );
        },
      ),
    );
    return pdf;
  }

  static pw.Widget _buildTotalRow(
    String label,
    String value,
    pw.Font font, {
    bool isLarge = false,
    PdfColor? color,
    PdfColor? primaryColor,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: isLarge ? 13 : 9, color: PdfColors.grey700)),
          pw.SizedBox(width: 20),
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              value,
              style: pw.TextStyle(
                font: font,
                fontSize: isLarge ? 13 : 9,
                color: color ?? (isLarge ? (primaryColor ?? PdfColors.black) : PdfColors.black),
              ),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
