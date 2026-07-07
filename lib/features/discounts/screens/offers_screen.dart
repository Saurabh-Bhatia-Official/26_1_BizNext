// lib/features/discounts/screens/offers_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/notification_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../models/offer.dart';
import '../providers/discount_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../../core/services/media_upload_service.dart';

class OffersScreen extends ConsumerStatefulWidget {
  const OffersScreen({super.key});

  @override
  ConsumerState<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends ConsumerState<OffersScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final offers = ref.watch(offersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredOffers = offers.where((o) => o.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Offers & Promotions',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : AppColors.textLight,
                        ),
                      ),
                      const Text(
                        'Manage discounts, festival offers, and loyalty rewards',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddOfferDialog(context, ref),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create New Offer'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Search Offers',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: filteredOffers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.local_offer_outlined, size: 64, color: AppColors.textMuted.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          Text(_searchQuery.isEmpty ? 'No offers created yet' : 'No offers found matching "$_searchQuery"', style: const TextStyle(color: AppColors.textMuted, fontSize: 16)),
                        ],
                      ),
                    )
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 400,
                        mainAxisSpacing: 20,
                        crossAxisSpacing: 20,
                        mainAxisExtent: 340,
                      ),
                      itemCount: filteredOffers.length,
                      itemBuilder: (context, index) {
                        final offer = filteredOffers[index];
                        return _OfferCard(offer: offer);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showAddOfferDialog(BuildContext context, WidgetRef ref, [Offer? offer]) {
  showDialog(
    context: context,
    builder: (ctx) => _AddOfferDialog(offer: offer),
  );
}

class _AddOfferDialog extends ConsumerStatefulWidget {
  final Offer? offer;
  const _AddOfferDialog({this.offer});

  @override
  ConsumerState<_AddOfferDialog> createState() => _AddOfferDialogState();
}

class _AddOfferDialogState extends ConsumerState<_AddOfferDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _valCtrl;
  late TextEditingController _minAmountCtrl;
  late TextEditingController _buyQtyCtrl;
  late TextEditingController _getQtyCtrl;
  
  String _offerType = 'bill_amount';
  String _discountType = 'percentage';
  String _applyTo = 'all';
  List<int> _selectedProductIds = [];
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchQuery = '';
  String? _posterPath;

  @override
  void initState() {
    super.initState();
    final o = widget.offer;
    _nameCtrl = TextEditingController(text: o?.name);
    _valCtrl = TextEditingController(text: o?.discountValue.toString() ?? '0');
    _minAmountCtrl = TextEditingController(text: o?.minAmount.toString() ?? '0');
    _buyQtyCtrl = TextEditingController(text: o?.buyQty.toString() ?? '0');
    _getQtyCtrl = TextEditingController(text: o?.getQty.toString() ?? '0');
    
    if (o != null) {
      _offerType = o.offerType;
      _discountType = o.discountType;
      _applyTo = o.applyTo;
      if (o.targetId != null) {
        _selectedProductIds = [o.targetId!];
      }
      _startDate = o.startDate;
      _endDate = o.endDate;
      _posterPath = o.posterPath;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _valCtrl.dispose();
    _minAmountCtrl.dispose();
    _buyQtyCtrl.dispose();
    _getQtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider).asData?.value ?? [];

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      title: Text(widget.offer == null ? 'Create New Offer' : 'Edit Offer', style: const TextStyle(fontWeight: FontWeight.w900)),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Offer Name*',
                    prefixIcon: const Icon(Icons.label_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _offerType,
                  decoration: InputDecoration(
                    labelText: 'Offer Type',
                    prefixIcon: const Icon(Icons.category_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'bill_amount', child: Text('Bill Amount Discount')),
                    DropdownMenuItem(value: 'buy_x_get_y', child: Text('Buy X Get Y (BOGO)')),
                    DropdownMenuItem(value: 'festival', child: Text('Festival Promo')),
                    DropdownMenuItem(value: 'product_discount', child: Text('Product Discount')),
                  ],
                  onChanged: (v) => setState(() => _offerType = v!),
                ),
                const SizedBox(height: 16),
                if (_offerType == 'bill_amount') ...[
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _discountType,
                          decoration: InputDecoration(
                            labelText: 'Disc. Type',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'percentage', child: Text('%')),
                            DropdownMenuItem(value: 'fixed', child: Text('Flat')),
                          ],
                          onChanged: (v) => setState(() => _discountType = v!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _valCtrl,
                          decoration: InputDecoration(
                            labelText: _discountType == 'percentage' ? 'Percent' : 'Amount',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _minAmountCtrl,
                    decoration: InputDecoration(
                      labelText: 'Min. Bill Amount',
                      prefixIcon: const Icon(Icons.payments_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
                if (_offerType == 'product_discount') ...[
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _discountType,
                          decoration: const InputDecoration(labelText: 'Disc. Type'),
                          items: const [
                            DropdownMenuItem(value: 'percentage', child: Text('%')),
                            DropdownMenuItem(value: 'fixed', child: Text('Flat')),
                          ],
                          onChanged: (v) => setState(() => _discountType = v!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _valCtrl,
                          decoration: InputDecoration(labelText: _discountType == 'percentage' ? 'Percent' : 'Amount'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ],
                if (_offerType == 'festival') ...[
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _discountType,
                          decoration: const InputDecoration(labelText: 'Disc. Type'),
                          items: const [
                            DropdownMenuItem(value: 'percentage', child: Text('%')),
                            DropdownMenuItem(value: 'fixed', child: Text('Flat')),
                          ],
                          onChanged: (v) => setState(() => _discountType = v!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _valCtrl,
                          decoration: InputDecoration(labelText: _discountType == 'percentage' ? 'Festival Discount (%)' : 'Festival Discount Amount'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _minAmountCtrl,
                    decoration: const InputDecoration(labelText: 'Min. Amount to Qualify', prefixIcon: Icon(Icons.star_rounded)),
                    keyboardType: TextInputType.number,
                  ),
                ],
                if (_offerType == 'buy_x_get_y') ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _buyQtyCtrl,
                          decoration: const InputDecoration(labelText: 'Buy Qty'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _getQtyCtrl,
                          decoration: const InputDecoration(labelText: 'Get Free Qty'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _applyTo,
                  decoration: const InputDecoration(labelText: 'Apply To', prefixIcon: Icon(Icons.center_focus_strong_rounded)),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Products')),
                    DropdownMenuItem(value: 'product', child: Text('Specific Product')),
                  ],
                  onChanged: (v) => setState(() {
                    _applyTo = v!;
                    if (_applyTo == 'all') _selectedProductIds.clear();
                  }),
                ),
                if (_applyTo == 'product') ...[
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Select Products', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textLight)),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Search Products',
                      prefixIcon: Icon(Icons.search_rounded),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.lightBorder),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView.builder(
                      itemCount: products.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase())).length,
                      itemBuilder: (context, index) {
                        final filtered = products.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
                        final p = filtered[index];
                        return CheckboxListTile(
                          title: Text(p.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: Text(p.categoryName ?? 'General', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          value: _selectedProductIds.contains(p.id),
                          activeColor: AppColors.primary,
                          dense: true,
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selectedProductIds.add(p.id!);
                              } else {
                                _selectedProductIds.remove(p.id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  if (_selectedProductIds.isEmpty)
                     const Padding(
                       padding: EdgeInsets.only(top: 8), 
                       child: Align(
                         alignment: Alignment.centerLeft, 
                         child: Text('Please select at least one product', style: TextStyle(color: AppColors.error, fontSize: 12))
                       )
                     ),
                ],
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Promotion Poster', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textLight)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (_posterPath != null) ...[
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: FileImage(File(_posterPath!)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    ElevatedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(type: FileType.image);
                        if (result != null && result.files.single.path != null) {
                          setState(() => _posterPath = result.files.single.path);
                          final finalUrl = await MediaUploadService.uploadMedia(result.files.single.path!);
                          if (mounted && finalUrl != result.files.single.path) {
                            setState(() => _posterPath = finalUrl);
                          }
                        }
                      },
                      icon: const Icon(Icons.upload_rounded),
                      label: Text(_posterPath == null ? 'Upload Poster' : 'Change Poster'),
                    ),
                    if (_posterPath != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => setState(() => _posterPath = null),
                        icon: const Icon(Icons.delete_rounded, color: AppColors.error),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Start Date', style: TextStyle(fontSize: 12)),
                        subtitle: Text(_startDate?.toString().split(' ')[0] ?? 'Pick date'),
                        onTap: () async {
                          final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                          if (d != null) setState(() => _startDate = d);
                        },
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('End Date', style: TextStyle(fontSize: 12)),
                        subtitle: Text(_endDate?.toString().split(' ')[0] ?? 'Pick date'),
                        onTap: () async {
                          final d = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 30)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                          if (d != null) setState(() => _endDate = d);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            if (!_formKey.currentState!.validate()) return;
            if (_applyTo == 'product' && _selectedProductIds.isEmpty) return;
            
            final baseOffer = Offer(
              id: widget.offer?.id,
              businessId: ref.read(activeBusinessIdProvider),
              name: _nameCtrl.text,
              offerType: _offerType,
              discountType: _discountType,
              discountValue: double.tryParse(_valCtrl.text) ?? 0,
              minAmount: double.tryParse(_minAmountCtrl.text) ?? 0,
              buyQty: double.tryParse(_buyQtyCtrl.text) ?? 0,
              getQty: double.tryParse(_getQtyCtrl.text) ?? 0,
              applyTo: _applyTo,
              targetId: null,
              startDate: _startDate,
              endDate: _endDate,
              createdAt: widget.offer?.createdAt ?? DateTime.now(),
              posterPath: _posterPath,
            );
            
            if (_applyTo == 'product') {
               for (final pId in _selectedProductIds) {
                  final offer = baseOffer.copyWith(targetId: pId);
                  if (widget.offer == null) {
                      await ref.read(offersProvider.notifier).addOffer(offer);
                  } else {
                      if (pId == _selectedProductIds.first) {
                          await ref.read(offersProvider.notifier).updateOffer(offer.copyWith(id: widget.offer!.id));
                      } else {
                          await ref.read(offersProvider.notifier).addOffer(offer.copyWith(id: null));
                      }
                  }
               }
            } else {
               if (widget.offer == null) {
                 await ref.read(offersProvider.notifier).addOffer(baseOffer);
               } else {
                 await ref.read(offersProvider.notifier).updateOffer(baseOffer);
               }
            }
            
            if (context.mounted) {
              Navigator.pop(context);
              AppAlert.success(ref, widget.offer == null ? 'Offer created!' : 'Offer updated!');
            }
          },
          child: Text(widget.offer == null ? 'Create Offer' : 'Save Changes'),
        ),
      ],
    );
  }
}

class _OfferCard extends ConsumerWidget {
  final Offer offer;
  const _OfferCard({required this.offer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (offer.posterPath != null) ...[
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: isDark ? Colors.black.withValues(alpha: 0.2) : AppColors.lightBg,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(offer.posterPath!),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  offer.offerType.toUpperCase().replaceAll('_', ' '),
                  style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ),
              Switch.adaptive(
                value: offer.isActive,
                onChanged: (v) {
                  ref.read(offersProvider.notifier).updateOffer(offer.copyWith(isActive: v));
                },
                activeTrackColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            offer.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              _getOfferDescription(offer, ref),
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                offer.endDate != null ? 'Ends: ${offer.endDate!.toString().split(' ')[0]}' : 'No expiry',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _showViewOfferDialog(context, ref, offer),
                    icon: const Icon(Icons.visibility_outlined, color: AppColors.primary, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () => _showAddOfferDialog(context, ref, offer),
                    icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () => ref.read(offersProvider.notifier).deleteOffer(offer.id!),
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getOfferDescription(Offer offer, WidgetRef ref) {
    String suffix = '';
    if (offer.applyTo == 'product') {
      final products = ref.read(productsProvider).asData?.value ?? [];
      final p = products.where((element) => element.id == offer.targetId).firstOrNull;
      suffix = p != null ? ' on ${p.name}' : ' on specific product';
    }

    switch (offer.offerType) {
      case 'buy_x_get_y':
        return 'Buy ${offer.buyQty.toInt()} get ${offer.getQty.toInt()} free$suffix';
      case 'bill_amount':
        return '${offer.discountValue}${offer.discountType == 'percentage' ? '%' : ' off'} on bills above ₹${offer.minAmount}$suffix';
      default:
        return '${offer.discountValue}${offer.discountType == 'percentage' ? '%' : ' off'} discount$suffix';
    }
  }
}

void _showViewOfferDialog(BuildContext context, WidgetRef ref, Offer offer) {
  showDialog(
    context: context,
    builder: (ctx) => _ViewOfferDialog(offer: offer),
  );
}

class _ViewOfferDialog extends ConsumerWidget {
  final Offer offer;
  const _ViewOfferDialog({required this.offer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final products = ref.watch(productsProvider).asData?.value ?? [];
    
    String description = '';
    if (offer.applyTo == 'product') {
      final p = products.where((element) => element.id == offer.targetId).firstOrNull;
      description = offer.getOfferDescription(p?.name);
    } else {
      description = offer.getOfferDescription(null);
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(offer.name, style: const TextStyle(fontWeight: FontWeight.w900)),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (offer.posterPath != null) ...[
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: isDark ? Colors.black.withValues(alpha: 0.2) : AppColors.lightBg,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      File(offer.posterPath!),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                'Type: ${offer.offerType.toUpperCase().replaceAll('_', ' ')}',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Text(
                'Validity: ${offer.startDate != null ? offer.startDate!.toString().split(' ')[0] : 'N/A'} to ${offer.endDate != null ? offer.endDate!.toString().split(' ')[0] : 'N/A'}',
                style: const TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 8),
              Text(
                'Status: ${offer.isActive ? 'Active' : 'Inactive'}',
                style: TextStyle(color: offer.isActive ? AppColors.success : AppColors.error, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}
