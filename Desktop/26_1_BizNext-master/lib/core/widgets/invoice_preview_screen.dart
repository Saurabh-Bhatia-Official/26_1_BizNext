// lib/core/widgets/invoice_preview_screen.dart
//
// A full in-app PDF preview window powered by the `printing` package's
// PdfPreview widget. Shows the rendered invoice with zoom / scroll, and
// has a Print and Save-as-PDF action button in the app-bar.

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../theme/app_theme.dart';

class InvoicePreviewScreen extends StatefulWidget {
  /// Callback that returns the PDF bytes for the given page format.
  final LayoutCallback onLayout;

  /// File-name used in the title bar and when saving to disk.
  final String documentName;

  const InvoicePreviewScreen({
    super.key,
    required this.onLayout,
    required this.documentName,
  });

  // ── Convenience navigator helper ──────────────────────────────────────────
  static Future<void> show(
    BuildContext context, {
    required LayoutCallback onLayout,
    required String documentName,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => InvoicePreviewScreen(
          onLayout: onLayout,
          documentName: documentName,
        ),
      ),
    );
  }

  @override
  State<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends State<InvoicePreviewScreen> {
  bool _isDark = false;

  @override
  Widget build(BuildContext context) {
    _isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: _isDark ? AppColors.darkBg : const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: _isDark ? AppColors.darkCard : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.documentName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    'Invoice Preview',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // ── Print button ──────────────────────────────────────────────────
          _AppBarAction(
            icon: Icons.print_rounded,
            label: 'Print',
            color: AppColors.primary,
            isDark: _isDark,
            onTap: () async {
              await Printing.layoutPdf(
                onLayout: widget.onLayout,
                name: widget.documentName,
              );
            },
          ),
          const SizedBox(width: 8),
          // ── Save PDF button ───────────────────────────────────────────────
          _AppBarAction(
            icon: Icons.save_alt_rounded,
            label: 'Save PDF',
            color: AppColors.success,
            isDark: _isDark,
            onTap: () async {
              final bytes = await widget.onLayout(PdfPageFormat.a4);
              await Printing.sharePdf(
                bytes: bytes,
                filename: '${widget.documentName}.pdf',
              );
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: PdfPreview(
            build: widget.onLayout,
            pdfFileName: '${widget.documentName}.pdf',
            allowPrinting: false,
            allowSharing: false,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            initialPageFormat: PdfPageFormat.a4,
            maxPageWidth: 900,
            previewPageMargin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            padding: const EdgeInsets.all(8),
            scrollViewDecoration: BoxDecoration(
              color: _isDark ? AppColors.darkBg : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(16),
            ),
            pdfPreviewPageDecoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            loadingWidget: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Rendering invoice...',
                    style: TextStyle(
                      color: _isDark ? Colors.white70 : AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Small styled app-bar action button ──────────────────────────────────────
class _AppBarAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _AppBarAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
