// lib/features/billing/screens/sale_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../models/sale_history_model.dart';
import '../providers/billing_provider.dart';
import '../providers/sales_stats_provider.dart';
import '../utils/invoice_service.dart';
import '../../auth/providers/auth_provider.dart';
import 'pos_billing_screen.dart';
import '../../../core/services/subscription_service.dart';

class SaleDetailScreen extends ConsumerWidget {
  final int saleId;

  const SaleDetailScreen({super.key, required this.saleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saleAsync = ref.watch(saleDetailProvider(saleId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: const Text('Invoice Details', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          saleAsync.when(
            data: (sale) => sale != null ? ActionButtons(sale: sale) : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: saleAsync.when(
        data: (sale) {
          if (sale == null) return const Center(child: Text('Invoice not found'));
          return SaleContent(sale: sale, isDark: isDark);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class ActionButtons extends ConsumerStatefulWidget {
  final SaleHistoryModel sale;
  const ActionButtons({super.key, required this.sale});

  @override
  ConsumerState<ActionButtons> createState() => _ActionButtonsState();
}

class _ActionButtonsState extends ConsumerState<ActionButtons> {
  int _selectedTemplateId = 0;

  @override
  Widget build(BuildContext context) {
    final subService = ref.watch(subscriptionServiceProvider);
    final isPro = subService.isPro;

    return Row(
      children: [
        DropdownButton<int>(
          value: _selectedTemplateId,
          dropdownColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF112A4A) : Colors.white,
          underline: const SizedBox(),
          items: const [
            DropdownMenuItem(value: 0, child: Text('Classic (Free)', style: TextStyle(fontSize: 12))),
            DropdownMenuItem(value: 1, child: Text('Modern Indigo (PRO)', style: TextStyle(fontSize: 12))),
            DropdownMenuItem(value: 2, child: Text('Minimalist (PRO)', style: TextStyle(fontSize: 12))),
            DropdownMenuItem(value: 3, child: Text('Crimson (PRO)', style: TextStyle(fontSize: 12))),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedTemplateId = val;
              });
            }
          },
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.print_rounded),
          onPressed: () {
            if (_selectedTemplateId > 0 && !isPro) {
              _showProRequirementDialog(context);
            } else {
              _printInvoice(context, widget.sale, _selectedTemplateId);
            }
          },
          tooltip: 'Print',
        ),
        IconButton(
          icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary),
          onPressed: () {
            if (_selectedTemplateId > 0 && !isPro) {
              _showProRequirementDialog(context);
            } else {
              _exportInvoice(context, widget.sale, _selectedTemplateId);
            }
          },
          tooltip: 'Export PDF',
        ),
        IconButton(
          icon: const Icon(Icons.preview_rounded, color: Colors.blueAccent),
          onPressed: () {
            _previewTemplateMock(context, _selectedTemplateId);
          },
          tooltip: 'Preview Layout',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  void _printInvoice(BuildContext context, SaleHistoryModel sale, int templateId) async {
    final business = ref.read(currentBusinessProvider);
    if (business != null) {
      await InvoiceService.generateAndPrintInvoice(business: business, sale: sale, templateId: templateId);
    }
  }

  void _exportInvoice(BuildContext context, SaleHistoryModel sale, int templateId) async {
    final business = ref.read(currentBusinessProvider);
    if (business != null) {
      await InvoiceService.exportInvoice(business: business, sale: sale, templateId: templateId);
    }
  }

  void _showProRequirementDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.star_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('Premium Template Only'),
          ],
        ),
        content: const Text(
          'Premium invoice templates are only available for PRO members. Upgrade your subscription to unlock all professional designs, automated cloud sync, and unlimited invoicing!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black87),
            onPressed: () {
              Navigator.pop(ctx);
              // Navigate to Settings page
            },
            child: const Text('Upgrade Now', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _previewTemplateMock(BuildContext context, int templateId) {
    final templates = [
      ('Classic Blue', 'Traditional layout with deep blue accents and standard sans-serif details. (FREE)', Colors.blue),
      ('Modern Indigo', 'Bold indigo banner header with white contrast typography and rounded grids. (PRO Only)', Colors.indigo),
      ('Minimalist Charcoal', 'Elegant grayscale spacing with fine divider lines for a modern agency style. (PRO Only)', Colors.grey.shade700),
      ('Crimson Premium', 'High-contrast dark crimson bands and corporate styling. (PRO Only)', Colors.red),
    ];

    final (name, desc, color) = templates[templateId];
    final isPro = ref.read(subscriptionServiceProvider).isPro;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Preview: $name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                border: Border.all(color: color, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.description_rounded, color: color, size: 40),
                  const SizedBox(height: 8),
                  Text(name, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(desc, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
            label: const Text('Open PDF Preview'),
            onPressed: () async {
              Navigator.pop(ctx);
              if (templateId > 0 && !isPro) {
                _showProRequirementDialog(context);
              } else {
                _printInvoice(context, widget.sale, templateId);
              }
            },
          ),
        ],
      ),
    );
  }
}

class SaleContent extends ConsumerWidget {
  final SaleHistoryModel sale;
  final bool isDark;
  const SaleContent({super.key, required this.sale, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref.watch(currentBusinessProvider);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── PDF-Style Header ──
              Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              business?.name ?? 'Business Name',
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: -1),
                            ),
                            if (business?.address != null)
                              Text(business!.address!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                            if (business?.phone != null)
                              Text('Phone: ${business!.phone}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                            if (business?.gstNumber != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('GSTIN: ${business!.gstNumber}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                              ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('INVOICE', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: AppColors.textMuted, letterSpacing: 2)),
                            const SizedBox(height: 8),
                            Text('Invoice #: ${sale.invoiceNo}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                            Text('Date: ${DateFormatter.toDisplay(sale.date)}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Divider(thickness: 2, color: AppColors.primary),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('BILL TO:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textMuted, letterSpacing: 1)),
                            const SizedBox(height: 8),
                            Text(sale.customerName ?? 'Walk-in Customer', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                            if (sale.customerPhone != null && sale.customerPhone!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('Phone: ${sale.customerPhone}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                              ),
                            if (sale.customerAddress != null && sale.customerAddress!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text('Address: ${sale.customerAddress}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                              ),
                            if (sale.customerName == null)
                              const Text('Cash Sale', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('PAYMENT STATUS:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textMuted, letterSpacing: 1)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: (sale.status == 'completed' ? AppColors.success : AppColors.warning).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                sale.status.toUpperCase(),
                                style: TextStyle(fontWeight: FontWeight.w900, color: sale.status == 'completed' ? AppColors.success : AppColors.warning, fontSize: 11),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('Mode: ${sale.paymentMode}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Items Table ──
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                      child: const Row(
                        children: [
                          Expanded(flex: 4, child: Text('Item Description', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                          Expanded(flex: 1, child: Text('Qty', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12), textAlign: TextAlign.center)),
                          Expanded(flex: 2, child: Text('Rate', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12), textAlign: TextAlign.right)),
                          Expanded(flex: 1, child: Text('GST', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12), textAlign: TextAlign.right)),
                          Expanded(flex: 2, child: Text('Amount', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12), textAlign: TextAlign.right)),
                        ],
                      ),
                    ),
                    ...sale.items.map((item) => Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 4, 
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.productName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                if (item.discount > 0)
                                  Text('Saved: ${CurrencyFormatter.format(item.discount)}', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                          Expanded(flex: 1, child: Text(item.quantity.toInt().toString(), style: const TextStyle(fontSize: 13), textAlign: TextAlign.center)),
                          Expanded(flex: 2, child: Text(CurrencyFormatter.format(item.price), style: const TextStyle(fontSize: 13), textAlign: TextAlign.right)),
                          Expanded(
                            flex: 1, 
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${item.gstPercent.toInt()}%', style: const TextStyle(fontSize: 13)),
                                Text(CurrencyFormatter.format(item.gstAmount), style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                          Expanded(flex: 2, child: Text(CurrencyFormatter.format(item.total), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800), textAlign: TextAlign.right)),
                        ],
                      ),
                    )),
                  ],
                ),
              ),

              // ── Totals ──
              Padding(
                padding: const EdgeInsets.all(40),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('TERMS & CONDITIONS:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textMuted, letterSpacing: 1)),
                          const SizedBox(height: 8),
                          const Text('1. Goods once sold will not be taken back.', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                          const Text('2. All disputes are subject to local jurisdiction.', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                          const SizedBox(height: 24),
                          if (sale.notes != null && sale.notes!.isNotEmpty) ...[
                            const Text('NOTES:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textMuted, letterSpacing: 1)),
                            const SizedBox(height: 4),
                            Text(sale.notes!, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 40),
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          _TotalRow(label: 'Subtotal', value: sale.subtotal),
                          _TotalRow(label: 'Tax (GST)', value: sale.gstAmount),
                          if (sale.discount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                              ),
                              child: _TotalRow(label: 'Discounts & Offers Applied', value: -sale.discount, highlightColor: AppColors.success),
                            ),
                          const Divider(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Grand Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                              Text(
                                CurrencyFormatter.format(sale.grandTotal),
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: -0.5),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Signature Footer ──
              Padding(
                padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const SizedBox(height: 40),
                        const Text('Authorized Signatory', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text('For ${business?.name ?? 'Business'}', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isRed;
  final Color? highlightColor;
  const _TotalRow({required this.label, required this.value, this.highlightColor, this.isRed = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: highlightColor ?? AppColors.textMuted)),
          Text(
            CurrencyFormatter.format(value),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: highlightColor ?? (isRed ? AppColors.error : null),
            ),
          ),
        ],
      ),
    );
  }
}
