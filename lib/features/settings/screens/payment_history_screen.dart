import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/theme/app_theme.dart';

class PaymentHistoryScreen extends ConsumerStatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  ConsumerState<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends ConsumerState<PaymentHistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    final subService = ref.read(subscriptionServiceProvider);
    // In a real app, you would retrieve the actual token from Auth provider
    final token = "dummy_token_12345";
    
    final history = await subService.getPaymentHistory(token);
    if (mounted) {
      setState(() {
        _history = history;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment History', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const Center(
                  child: Text(
                    'No payment history found.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final tx = _history[index];
                    final date = DateTime.tryParse(tx['date'] ?? '');
                    final dateStr = date != null ? DateFormat.yMMMd().format(date) : 'Unknown Date';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.greenAccent,
                          child: Icon(Icons.receipt_long, color: Colors.white),
                        ),
                        title: Text(tx['plan'] ?? 'Subscription', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('$dateStr\nID: ${tx['id']}'),
                        isThreeLine: true,
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              tx['amount'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              tx['status'] ?? '',
                              style: TextStyle(
                                color: (tx['status'] == 'Success') ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
