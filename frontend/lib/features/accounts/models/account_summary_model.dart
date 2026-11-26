// lib/features/accounts/models/account_summary_model.dart

class AccountSummaryModel {
  final double cashInHand;
  final double totalReceivable;
  final double totalPayable;
  final double totalExpenses;
  final double totalIncome;

  AccountSummaryModel({
    required this.cashInHand,
    required this.totalReceivable,
    required this.totalPayable,
    required this.totalExpenses,
    required this.totalIncome,
  });

  factory AccountSummaryModel.zero() => AccountSummaryModel(
    cashInHand: 0,
    totalReceivable: 0,
    totalPayable: 0,
    totalExpenses: 0,
    totalIncome: 0,
  );
}
