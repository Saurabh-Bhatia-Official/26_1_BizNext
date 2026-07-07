// lib/features/billing/utils/invoice_service.dart

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../auth/models/business_model.dart';
import '../models/sale_history_model.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';

class InvoiceService {
  static Future<void> generateAndPrintInvoice({
    required BusinessModel business,
    required SaleHistoryModel sale,
    int templateId = 0,
  }) async {
    final pdf = await _generateDocument(business, sale, templateId);

    // Show print preview
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Invoice_${sale.invoiceNo}',
    );
  }

  static Future<void> exportInvoice({
    required BusinessModel business,
    required SaleHistoryModel sale,
    int templateId = 0,
  }) async {
    final pdf = await _generateDocument(business, sale, templateId);
    final bytes = await pdf.save();
    
    final safeInvoiceNo = sale.invoiceNo.replaceAll(RegExp(r'[^\w\-]'), '_');
    final fileName = 'Invoice_$safeInvoiceNo.pdf';

    final output = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Invoice PDF',
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
    SaleHistoryModel sale,
    int templateId,
  ) async {
    final pdf = pw.Document();
    
    // Choose Fonts based on template
    final fontRegular = (templateId == 2) 
        ? await PdfGoogleFonts.robotoRegular() 
        : await PdfGoogleFonts.interRegular();
    final fontBold = (templateId == 2) 
        ? await PdfGoogleFonts.robotoBold() 
        : await PdfGoogleFonts.interBold();

    // Determine colors
    PdfColor primaryColor;
    PdfColor accentColor;
    
    switch (templateId) {
      case 1: // Modern Indigo
        primaryColor = PdfColors.indigo900;
        accentColor = PdfColors.indigo50;
        break;
      case 2: // Minimalist Charcoal
        primaryColor = PdfColors.grey900;
        accentColor = PdfColors.grey100;
        break;
      case 3: // Crimson Premium
        primaryColor = PdfColors.red900;
        accentColor = PdfColors.red50;
        break;
      case 0: // Classic Blue
      default:
        primaryColor = PdfColors.blue900;
        accentColor = PdfColors.blue50;
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
              // Header Layout based on Template
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
                          pw.Text('INVOICE', style: pw.TextStyle(font: fontBold, fontSize: 26, color: PdfColors.white)),
                          pw.Text('No: ${sale.invoiceNo}', style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.grey200)),
                          pw.Text('Date: ${DateFormatter.toDisplay(sale.date)}', style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.grey200)),
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
                        pw.Text('INVOICE', style: pw.TextStyle(font: fontBold, fontSize: 24, color: PdfColors.grey800)),
                        pw.Text('Invoice #: ${sale.invoiceNo}', style: pw.TextStyle(font: fontRegular, fontSize: 10)),
                        pw.Text('Date: ${DateFormatter.toDisplay(sale.date)}', style: pw.TextStyle(font: fontRegular, fontSize: 9)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Divider(thickness: 1, color: PdfColors.grey400),
                pw.SizedBox(height: 20),
              ] else ...[
                // Classic Blue & Crimson Standard layout
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
                        pw.Text('INVOICE', style: pw.TextStyle(font: fontBold, fontSize: 32, color: PdfColors.grey700)),
                        pw.SizedBox(height: 8),
                        pw.Text('Invoice #: ${sale.invoiceNo}', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                        pw.Text('Date: ${DateFormatter.toDisplay(sale.date)}', style: pw.TextStyle(font: fontRegular, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
                pw.Divider(thickness: 2, color: primaryColor, height: 40),
              ],

              // Customer / Billing Details
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BILL TO:', style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.grey700)),
                      pw.SizedBox(height: 4),
                      pw.Text(sale.customerName ?? 'Walk-in Customer', style: pw.TextStyle(font: fontBold, fontSize: 14)),
                      if (sale.customerPhone != null && sale.customerPhone!.isNotEmpty)
                        pw.Text('Phone: ${sale.customerPhone}', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      if (sale.customerAddress != null && sale.customerAddress!.isNotEmpty)
                        pw.Text('Address: ${sale.customerAddress}', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('PAYMENT STATUS:', style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.grey700)),
                      pw.SizedBox(height: 4),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: sale.status == 'completed' ? PdfColors.green100 : PdfColors.orange100,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          sale.status.toUpperCase(),
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 10,
                            color: sale.status == 'completed' ? PdfColors.green800 : PdfColors.orange800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Items Table Header
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: primaryColor, 
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                padding: const pw.EdgeInsets.all(8),
                child: pw.Row(
                  children: [
                    pw.Expanded(flex: 3, child: pw.Text('Item Description', style: pw.TextStyle(font: fontBold, color: PdfColors.white, fontSize: 10))),
                    pw.Expanded(flex: 1, child: pw.Text('Qty', style: pw.TextStyle(font: fontBold, color: PdfColors.white, fontSize: 10), textAlign: pw.TextAlign.center)),
                    pw.Expanded(flex: 2, child: pw.Text('Rate', style: pw.TextStyle(font: fontBold, color: PdfColors.white, fontSize: 10), textAlign: pw.TextAlign.right)),
                    pw.Expanded(flex: 1, child: pw.Text('GST', style: pw.TextStyle(font: fontBold, color: PdfColors.white, fontSize: 10), textAlign: pw.TextAlign.right)),
                    pw.Expanded(flex: 2, child: pw.Text('Amount', style: pw.TextStyle(font: fontBold, color: PdfColors.white, fontSize: 10), textAlign: pw.TextAlign.right)),
                  ],
                ),
              ),

              // Items Table Rows
              ...sale.items.map((item) => pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 3, 
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(item.productName, style: pw.TextStyle(font: fontRegular, fontSize: 10)),
                          if (item.discount > 0)
                            pw.Text('Saved: ${CurrencyFormatter.format(item.discount)}', style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey600)),
                        ],
                      ),
                    ),
                    pw.Expanded(flex: 1, child: pw.Text(item.quantity.toStringAsFixed(0), style: pw.TextStyle(font: fontRegular, fontSize: 10), textAlign: pw.TextAlign.center)),
                    pw.Expanded(flex: 2, child: pw.Text(CurrencyFormatter.format(item.price), style: pw.TextStyle(font: fontRegular, fontSize: 10), textAlign: pw.TextAlign.right)),
                    pw.Expanded(
                      flex: 1, 
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('${item.gstPercent.toInt()}%', style: pw.TextStyle(font: fontRegular, fontSize: 10)),
                          pw.Text(CurrencyFormatter.format(item.gstAmount), style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey600)),
                        ],
                      ),
                    ),
                    pw.Expanded(flex: 2, child: pw.Text(CurrencyFormatter.format(item.total), style: pw.TextStyle(font: fontBold, fontSize: 10), textAlign: pw.TextAlign.right)),
                  ],
                ),
              )),

              pw.SizedBox(height: 20),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      _buildTotalRow('Subtotal:', CurrencyFormatter.format(sale.subtotal), fontRegular),
                      _buildTotalRow('Tax (GST):', CurrencyFormatter.format(sale.gstAmount), fontRegular),
                      if (sale.discount > 0) ...[
                        _buildTotalRow('Discounts & Offers:', '-${CurrencyFormatter.format(sale.discount)}', fontRegular),
                      ],
                      pw.Divider(color: PdfColors.grey400),
                      _buildTotalRow('Grand Total:', CurrencyFormatter.format(sale.grandTotal), fontBold, isLarge: true, primaryColor: primaryColor),
                      pw.SizedBox(height: 8),
                      pw.Text('Payment Mode: ${sale.paymentMode}', style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),

              pw.Spacer(),

              // Footer
              pw.Divider(color: PdfColors.grey400),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (sale.notes != null && sale.notes!.isNotEmpty) ...[
                        pw.Text('Notes:', style: pw.TextStyle(font: fontBold, fontSize: 8)),
                        pw.Text(sale.notes!, style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                        pw.SizedBox(height: 6),
                      ],
                      pw.Text('Terms & Conditions:', style: pw.TextStyle(font: fontBold, fontSize: 8)),
                      pw.Text('1. Goods once sold will not be taken back.', style: pw.TextStyle(font: fontRegular, fontSize: 7)),
                      pw.Text('2. Subject to local jurisdiction.', style: pw.TextStyle(font: fontRegular, fontSize: 7)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.SizedBox(height: 15),
                      pw.Text('Authorized Signatory', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                      pw.SizedBox(height: 4),
                      pw.Text('For ${business.name}', style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text('Thank you for your business!', style: pw.TextStyle(font: fontRegular, fontStyle: pw.FontStyle.italic, fontSize: 9)),
              ),
            ],
          );
        },
      ),
    );
    return pdf;
  }

  static pw.Widget _buildTotalRow(String label, String value, pw.Font font, {bool isLarge = false, PdfColor? primaryColor}) {
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
                color: isLarge ? (primaryColor ?? PdfColors.black) : PdfColors.black,
              ), 
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
