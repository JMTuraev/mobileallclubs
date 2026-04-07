class PaymentAmounts {
  const PaymentAmounts({
    required this.cash,
    required this.terminal,
    required this.click,
    required this.debt,
    required this.total,
  });

  final num cash;
  final num terminal;
  final num click;
  final num debt;
  final num total;

  num get paidTotal => cash + terminal + click + debt;

  num get remaining => total - paidTotal;

  bool get usesDebt => debt > 0;

  bool get hasPositiveAmount => paidTotal > 0;

  bool get isBalanced => total > 0 && remaining.abs() < 0.01;

  Map<String, num> toJson() {
    return {'cash': cash, 'terminal': terminal, 'click': click, 'debt': debt};
  }
}
