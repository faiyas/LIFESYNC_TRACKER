enum ReceiptType {
  fuel,
  transit,
  restaurant,
  supermarket,
  pharmacy,
  utility,
  upiPayment,
  general,
}

class DetectedPayment {
  final double? amount;
  final String? merchant;
  final String? accountEnding; // e.g. "XX1234", "4582"
  final DateTime? date;
  final String? transactionId;
  final String? upiId;
  final String? upiApp; // 'Google Pay', 'PhonePe', 'Paytm', 'BHIM', 'CRED', 'Amazon Pay', etc.
  final String? paymentMethod;
  final bool isIncome; // true if received/credited, false if paid/debited
  final ReceiptType receiptType;
  final String receiptTypeDisplayName;
  final String? journeyRoute;
  final String? fuelDetails;
  final String? ticketNumber;
  final String? itemSummary;
  final String suggestedCategory;
  final String suggestedIncomeSource;
  final double confidence;
  final String rawText;
  final String? imagePath;
  final bool isValidPayment;

  const DetectedPayment({
    this.amount,
    this.merchant,
    this.accountEnding,
    this.date,
    this.transactionId,
    this.upiId,
    this.upiApp,
    this.paymentMethod,
    this.isIncome = false,
    this.receiptType = ReceiptType.general,
    this.receiptTypeDisplayName = '🧾 General Receipt',
    this.journeyRoute,
    this.fuelDetails,
    this.ticketNumber,
    this.itemSummary,
    this.suggestedCategory = 'Other',
    this.suggestedIncomeSource = 'Other',
    this.confidence = 0.0,
    this.rawText = '',
    this.imagePath,
    this.isValidPayment = false,
  });

  DetectedPayment copyWith({
    double? amount,
    String? merchant,
    String? accountEnding,
    DateTime? date,
    String? transactionId,
    String? upiId,
    String? upiApp,
    String? paymentMethod,
    bool? isIncome,
    ReceiptType? receiptType,
    String? receiptTypeDisplayName,
    String? journeyRoute,
    String? fuelDetails,
    String? ticketNumber,
    String? itemSummary,
    String? suggestedCategory,
    String? suggestedIncomeSource,
    double? confidence,
    String? rawText,
    String? imagePath,
    bool? isValidPayment,
  }) {
    return DetectedPayment(
      amount: amount ?? this.amount,
      merchant: merchant ?? this.merchant,
      accountEnding: accountEnding ?? this.accountEnding,
      date: date ?? this.date,
      transactionId: transactionId ?? this.transactionId,
      upiId: upiId ?? this.upiId,
      upiApp: upiApp ?? this.upiApp,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isIncome: isIncome ?? this.isIncome,
      receiptType: receiptType ?? this.receiptType,
      receiptTypeDisplayName: receiptTypeDisplayName ?? this.receiptTypeDisplayName,
      journeyRoute: journeyRoute ?? this.journeyRoute,
      fuelDetails: fuelDetails ?? this.fuelDetails,
      ticketNumber: ticketNumber ?? this.ticketNumber,
      itemSummary: itemSummary ?? this.itemSummary,
      suggestedCategory: suggestedCategory ?? this.suggestedCategory,
      suggestedIncomeSource: suggestedIncomeSource ?? this.suggestedIncomeSource,
      confidence: confidence ?? this.confidence,
      rawText: rawText ?? this.rawText,
      imagePath: imagePath ?? this.imagePath,
      isValidPayment: isValidPayment ?? this.isValidPayment,
    );
  }
}
