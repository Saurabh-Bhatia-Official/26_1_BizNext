// lib/features/purchases/screens/purchase_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../accounts/models/ledger_model.dart';
import '../models/purchase_model.dart';
import '../providers/purchase_provider.dart';
import 'add_purchase_screen.dart';
import '../utils/purchase_invoice_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/subscription_service.dart';

class PurchaseDetailScreen extends ConsumerWidget {
  final PurchaseModel purchase;

  const PurchaseDetailScreen({super.key, required this.purchase});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(purchase.billNo ?? 'Purchase #${purchase.id}'),
        backgroundColor: Colors.transparent,
        actions: [
          _PurchaseActionButtons(purchase: purchase),
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, color: AppColors.primary),
            tooltip: 'Edit Record',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AddPurchaseScreen(initialPurchase: purchase)),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailHeader(purchase: purchase, isDark: isDark),
            const SizedBox(height: 32),
            const Text('Items Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            _ItemsList(purchaseId: purchase.id!, isDark: isDark),
            const SizedBox(height: 32),
            const Text('Payment History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            _PaymentHistory(purchaseId: purchase.id!, isDark: isDark),
          ],
        ),
      ),
    );
  }
}

// ── Action Buttons with Template Picker ──────────────────────────────────────

class _PurchaseActionButtons extends ConsumerStatefulWidget {
  final PurchaseModel purchase;
  const _PurchaseActionButtons({required this.purchase});

  @override
  ConsumerState<_PurchaseActionButtons> createState() => _PurchaseActionButtonsState();
}

class _PurchaseActionButtonsState extends ConsumerState<_PurchaseActionButtons> {
  int _selectedTemplateId = 0;

  Future<PurchaseModel> _loadWithItems() async {
    final items = await ref.read(purchaseRepositoryProvider).getPurchaseItems(widget.purchase.id!);
    return PurchaseModel(
      id: widget.purchase.id,
      businessId: widget.purchase.businessId,
      billNo: widget.purchase.billNo,
      supplierId: widget.purchase.supplierId,
      supplierName: widget.purchase.supplierName,
      subtotal: widget.purchase.subtotal,
      discount: widget.purchase.discount,
      gstAmount: widget.purchase.gstAmount,
      grandTotal: widget.purchase.grandTotal,
      paidAmount: widget.purchase.paidAmount,
      balanceDue: widget.purchase.balanceDue,
      paymentMode: widget.purchase.paymentMode,
      accountId: widget.purchase.accountId,
      accountName: widget.purchase.accountName,
      notes: widget.purchase.notes,
      status: widget.purchase.status,
      date: widget.purchase.date,
      items: items,
    );
  }

  void _showProDialog() {
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
          'Premium purchase bill templates are only available for PRO subscribers. '
          'Upgrade your subscription to unlock all professional designs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black87),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Upgrade Now', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _previewTemplate() {
    final templates = [
      ('Classic Blue', 'Traditional business layout with deep blue accents and clean lines. (FREE)', Colors.blue),
      ('Modern Indigo', 'Bold indigo banner header with white contrast typography and rounded grids. (PRO Only)', Colors.indigo),
      ('Minimalist Charcoal', 'Elegant grayscale spacing with fine divider lines for a modern style. (PRO Only)', Colors.grey.shade700),
      ('Crimson Premium', 'High-contrast dark crimson bands and corporate styling. (PRO Only)', Colors.red),
    ];

    final (name, desc, color) = templates[_selectedTemplateId];

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
                  Icon(Icons.receipt_long_rounded, color: color, size: 40),
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
              final isPro = ref.read(subscriptionServiceProvider).isPro;
              if (_selectedTemplateId > 0 && !isPro) {
                _showProDialog();
              } else {
                final business = ref.read(currentBusinessProvider);
                if (business == null) return;
                final p = await _loadWithItems();
                await PurchaseInvoiceService.generateAndPrintPurchase(
                  business: business,
                  purchase: p,
                  templateId: _selectedTemplateId,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPro = ref.watch(subscriptionServiceProvider).isPro;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Template selector
        DropdownButton<int>(
          value: _selectedTemplateId,
          dropdownColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF112A4A)
              : Colors.white,
          underline: const SizedBox(),
          items: const [
            DropdownMenuItem(value: 0, child: Text('Classic (Free)', style: TextStyle(fontSize: 12))),
            DropdownMenuItem(value: 1, child: Text('Modern Indigo (PRO)', style: TextStyle(fontSize: 12))),
            DropdownMenuItem(value: 2, child: Text('Minimalist (PRO)', style: TextStyle(fontSize: 12))),
            DropdownMenuItem(value: 3, child: Text('Crimson (PRO)', style: TextStyle(fontSize: 12))),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _selectedTemplateId = val);
          },
        ),
        const SizedBox(width: 4),
        // Preview
        IconButton(
          icon: const Icon(Icons.preview_rounded, color: Colors.blueAccent),
          tooltip: 'Preview Layout',
          onPressed: _previewTemplate,
        ),
        // Print
        IconButton(
          icon: const Icon(Icons.print_rounded),
          tooltip: 'Print Bill',
          onPressed: () async {
            if (_selectedTemplateId > 0 && !isPro) {
              _showProDialog();
              return;
            }
            final business = ref.read(currentBusinessProvider);
            if (business == null) return;
            final p = await _loadWithItems();
            await PurchaseInvoiceService.generateAndPrintPurchase(
              business: business,
              purchase: p,
              templateId: _selectedTemplateId,
            );
          },
        ),
        // Export PDF
        IconButton(
          icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary),
          tooltip: 'Export PDF',
          onPressed: () async {
            if (_selectedTemplateId > 0 && !isPro) {
              _showProDialog();
              return;
            }
            final business = ref.read(currentBusinessProvider);
            if (business == null) return;
            final p = await _loadWithItems();
            await PurchaseInvoiceService.exportPurchasePDF(
              business: business,
              purchase: p,
              templateId: _selectedTemplateId,
            );
          },
        ),
      ],
    );
  }
}

// ── Detail Header ────────────────────────────────────────────────────────────

class _DetailHeader extends StatelessWidget {
  final PurchaseModel purchase;
  final bool isDark;
  const _DetailHeader({required this.purchase, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        children: [
          _infoRow('Supplier', purchase.supplierName ?? 'Direct Purchase'),
          _infoRow('Account', purchase.accountName ?? 'Default'),
          const Divider(height: 32),
          _infoRow('Date', DateFormatter.toDisplay(purchase.date)),
          const Divider(height: 32),
          _infoRow('Total Amount', CurrencyFormatter.format(purchase.grandTotal), isBold: true),
          _infoRow('Paid Amount', CurrencyFormatter.format(purchase.paidAmount), color: AppColors.success),
          _infoRow('Balance Due', CurrencyFormatter.format(purchase.balanceDue), color: purchase.balanceDue > 0 ? AppColors.error : null, isBold: true),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.w900 : FontWeight.w700, fontSize: isBold ? 16 : 14, color: color)),
        ],
      ),
    );
  }
}

// ── Items List ───────────────────────────────────────────────────────────────

class _ItemsList extends ConsumerWidget {
  final int purchaseId;
  final bool isDark;
  const _ItemsList({required this.purchaseId, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<PurchaseItemModel>>(
      future: ref.read(purchaseRepositoryProvider).getPurchaseItems(purchaseId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final items = snapshot.data!;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Column(
            children: [
              ...items.map((item) => ListTile(
                title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${item.quantity} units @ ${CurrencyFormatter.format(item.purchasePrice)}'),
                trailing: Text(CurrencyFormatter.format(item.total), style: const TextStyle(fontWeight: FontWeight.w800)),
              )),
            ],
          ),
        );
      },
    );
  }
}

// ── Payment History ──────────────────────────────────────────────────────────

class _PaymentHistory extends ConsumerWidget {
  final int purchaseId;
  final bool isDark;
  const _PaymentHistory({required this.purchaseId, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<LedgerModel>>(
      future: ref.read(purchaseRepositoryProvider).getPurchasePaymentHistory(purchaseId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final payments = snapshot.data!;

        if (payments.isEmpty) {
          return const Center(child: Text('No payment records found', style: TextStyle(color: AppColors.textMuted)));
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: payments.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) {
            final p = payments[i];
            final isPayment = p.type == AppConstants.ledgerDebit;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Row(
                children: [
                  Icon(
                    isPayment ? Icons.payments_rounded : Icons.receipt_long_rounded,
                    color: isPayment ? AppColors.success : AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.description ?? 'Transaction', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        Text(DateFormatter.toDisplay(p.date), style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                  Text(
                    '${isPayment ? "-" : "+"} ${CurrencyFormatter.format(p.amount)}',
                    style: TextStyle(fontWeight: FontWeight.w900, color: isPayment ? AppColors.success : AppColors.textMuted, fontSize: 14),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
