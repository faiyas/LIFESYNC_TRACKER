import '../models/detected_payment.dart';
import 'payment_merchant_learning_service.dart';

class PaymentParserService {
  bool isPaymentScreenshot(String text) {
    final lower = text.toLowerCase();

    // 1. Immediately reject marketing, promotional ads, or shopping sales
    const promoBlocklist = [
      'starting at',
      'starts at',
      'starting from',
      'start at',
      'flat off',
      'upto',
      'up to',
      'discount',
      '% off',
      'coupon',
      'promo code',
      'use code',
      'sale is live',
      'deal of the day',
      'shop now',
      'order now',
      'buy now',
      'extra fun',
      'playtime',
      'toys',
      'cashback upto',
      'spin & win',
      'trending',
      'recommend',
      'exclusive offer',
      'wishlist',
      'cart',
    ];
    for (final promo in promoBlocklist) {
      if (lower.contains(promo)) {
        return false;
      }
    }

    // 2. Strict financial confirmation indicators (debited, credited, paid to, received, upi ref, txn id)
    const keywords = [
      'payment successful',
      'payment success',
      'paid successfully',
      'paid to',
      'sent to',
      'paying to',
      'upi ref',
      'transaction id',
      'txn id',
      'debited',
      'debited from',
      'debited by',
      'debited for',
      'credited',
      'credited to',
      'credited with',
      'credit alert',
      'received from',
      'money received',
      'payment received',
      'you received',
      'transferred to your account',
      'transferred from',
      'paid to you',
      'sent you',
      'deposit successful',
      'amount credited',
      'transfer successful',
      'google pay',
      'gpay',
      'phonepe',
      'paytm',
      'cred',
      'bhim',
      'amazon pay',
      'money sent',
      'bill paid',
      'recharge successful',
      'payment done',
      'amount paid',
      'bank transfer',
      'cr to a/c',
      'inward remittance',
      'cashback received',
      'refund received',
      'petrol',
      'diesel',
      'fuel',
      'iocl',
      'bpcl',
      'hpcl',
      'indian oil',
      'bharat petroleum',
      'hindustan petroleum',
      'bus ticket',
      'ksrtc',
      'tnstc',
      'bmtc',
      'setc',
      'redbus',
      'irctc',
      'fare',
      'grand total',
      'tax invoice',
      'net payable',
      'net amount',
      'fssai',
      'table no',
    ];

    for (final keyword in keywords) {
      if (lower.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  DetectedPayment parse(String text, {String? imagePath}) {
    final isValid = isPaymentScreenshot(text);
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();

    final receiptType = _detectReceiptType(normalized);
    final receiptTypeDisplayName = _getReceiptTypeDisplayName(receiptType);

    final isIncome = _detectIsIncome(normalized);
    final amount = _extractAmount(normalized);
    final upiId = _extractUpiId(normalized);
    final accountEnding = _extractAccountEnding(normalized);
    final merchantRaw = isIncome
        ? _extractPayer(normalized) ?? _extractMerchant(normalized, receiptType)
        : _extractMerchant(normalized, receiptType);
    final merchant = merchantRaw != null
        ? PaymentMerchantLearningService.instance.normalizeMerchantName(merchantRaw)
        : null;

    final transactionId = _extractTransactionId(normalized);
    final date = _extractDate(normalized);
    final paymentMethod = _detectPaymentMethod(normalized, receiptType);
    final upiApp = _detectUpiApp(normalized, upiId);

    // Specialized receipt extractors
    final fuelDetails = receiptType == ReceiptType.fuel ? _extractFuelDetails(normalized) : null;
    final transitDetails = receiptType == ReceiptType.transit ? _extractTransitDetails(normalized) : null;
    final restaurantDetails = receiptType == ReceiptType.restaurant ? _extractRestaurantDetails(normalized) : null;

    final journeyRoute = transitDetails?['route'];
    final ticketNumber = transitDetails?['ticketNumber'] ?? _extractInvoiceNumber(normalized);
    final itemSummary = restaurantDetails?['items'] ?? fuelDetails;

    // Automatic category assignment
    final suggestedCategory = _detectCategoryWithReceiptType(merchant, receiptType, normalized);
    final suggestedIncomeSource = detectIncomeSource(merchant, normalized);

    final confidence = _calculateConfidence(
      amount: amount,
      merchant: merchant,
      transactionId: transactionId ?? ticketNumber,
      paymentMethod: paymentMethod,
      isValid: isValid,
    );

    return DetectedPayment(
      amount: amount,
      merchant: merchant,
      accountEnding: accountEnding,
      date: date ?? DateTime.now(),
      transactionId: transactionId ?? ticketNumber,
      upiId: upiId,
      upiApp: upiApp,
      paymentMethod: paymentMethod,
      isIncome: isIncome,
      receiptType: receiptType,
      receiptTypeDisplayName: isIncome ? '🟢 Credit / Received' : receiptTypeDisplayName,
      journeyRoute: journeyRoute,
      fuelDetails: fuelDetails,
      ticketNumber: ticketNumber,
      itemSummary: itemSummary,
      suggestedCategory: suggestedCategory,
      suggestedIncomeSource: suggestedIncomeSource,
      confidence: confidence,
      rawText: text,
      imagePath: imagePath,
      isValidPayment: isValid || amount != null,
    );
  }

  ReceiptType _detectReceiptType(String text) {
    final lower = text.toLowerCase();

    // 1. Petrol / Fuel Bills
    if (lower.contains('petrol') ||
        lower.contains('diesel') ||
        lower.contains('fuel') ||
        lower.contains('iocl') ||
        lower.contains('bpcl') ||
        lower.contains('hpcl') ||
        lower.contains('indian oil') ||
        lower.contains('bharat petroleum') ||
        lower.contains('hindustan petroleum') ||
        lower.contains('shell petrol') ||
        lower.contains('nayara energy') ||
        lower.contains('nozzle') ||
        lower.contains('pump no') ||
        lower.contains('density:') ||
        (lower.contains('volume') && lower.contains('ltrs')) ||
        (lower.contains('rate/l') || lower.contains('rate/ltr'))) {
      return ReceiptType.fuel;
    }

    // 2. Bus / Transit / Train Tickets
    if (lower.contains('ksrtc') ||
        lower.contains('tnstc') ||
        lower.contains('bmtc') ||
        lower.contains('setc') ||
        lower.contains('msrtc') ||
        lower.contains('apsrtc') ||
        lower.contains('redbus') ||
        lower.contains('abhibus') ||
        lower.contains('irctc') ||
        lower.contains('railway') ||
        lower.contains('railways') ||
        lower.contains('uts') ||
        lower.contains('atvm') ||
        lower.contains('bus ticket') ||
        lower.contains('train ticket') ||
        lower.contains('ordinary journey') ||
        lower.contains('second ordinary') ||
        lower.contains('commence journey') ||
        lower.contains('passenger') ||
        lower.contains('boarding point') ||
        lower.contains('dep time') ||
        lower.contains('seat no') ||
        lower.contains('total fare') ||
        lower.contains('fare:') ||
        lower.contains('stage:') ||
        lower.contains('conductor') ||
        lower.contains('toll plaza') ||
        lower.contains('fastag')) {
      return ReceiptType.transit;
    }

    // 3. Restaurant / Dining / Food Bills
    if (lower.contains('restaurant') ||
        lower.contains('hotel ') ||
        lower.contains('cafe') ||
        lower.contains('bhavan') ||
        lower.contains('swiggy') ||
        lower.contains('zomato') ||
        lower.contains('fssai') ||
        lower.contains('table no') ||
        lower.contains('steward') ||
        lower.contains('waiter') ||
        lower.contains('kot no') ||
        lower.contains('food bill') ||
        lower.contains('dining') ||
        lower.contains('take away') ||
        lower.contains('biryani') ||
        lower.contains('tandoori') ||
        lower.contains('dosa') ||
        lower.contains('starbucks') ||
        lower.contains('mcdonald')) {
      return ReceiptType.restaurant;
    }

    // 4. Supermarket / Grocery Retail
    if (lower.contains('dmart') ||
        lower.contains('d-mart') ||
        lower.contains('reliance fresh') ||
        lower.contains('reliance smart') ||
        lower.contains('supermarket') ||
        lower.contains('hypermarket') ||
        lower.contains('more retail') ||
        lower.contains('spencer') ||
        lower.contains('groceries') ||
        lower.contains('total savings') ||
        lower.contains('you saved') ||
        lower.contains('total items:') ||
        lower.contains('blinkit') ||
        lower.contains('zepto') ||
        lower.contains('bigbasket')) {
      return ReceiptType.supermarket;
    }

    // 5. Pharmacy / Medical Receipts
    if (lower.contains('pharmacy') ||
        lower.contains('chemist') ||
        lower.contains('druggist') ||
        lower.contains('apollo') ||
        lower.contains('medplus') ||
        lower.contains('hospital') ||
        lower.contains('clinic') ||
        lower.contains('patient') ||
        lower.contains('doctor') ||
        lower.contains('medicines') ||
        lower.contains('prescription') ||
        lower.contains('dl no:') ||
        lower.contains('rx')) {
      return ReceiptType.pharmacy;
    }

    // 6. Utility Bills
    if (lower.contains('electricity bill') ||
        lower.contains('bescom') ||
        lower.contains('tangedco') ||
        lower.contains('water supply') ||
        lower.contains('broadband bill') ||
        lower.contains('bill period')) {
      return ReceiptType.utility;
    }

    // 7. UPI / Digital Payments
    if (lower.contains('upi') ||
        lower.contains('gpay') ||
        lower.contains('phonepe') ||
        lower.contains('paytm') ||
        lower.contains('cred') ||
        lower.contains('bhim') ||
        lower.contains('google pay') ||
        lower.contains('debited') ||
        lower.contains('credited') ||
        lower.contains('completed') ||
        lower.contains('payment successful')) {
      return ReceiptType.upiPayment;
    }

    return ReceiptType.general;
  }

  String _getReceiptTypeDisplayName(ReceiptType type) {
    switch (type) {
      case ReceiptType.fuel:
        return '⛽ Petrol / Fuel Bill';
      case ReceiptType.transit:
        return '🚌 Bus / Transit Ticket';
      case ReceiptType.restaurant:
        return '🍽️ Restaurant Bill';
      case ReceiptType.supermarket:
        return '🛒 Grocery / Supermarket';
      case ReceiptType.pharmacy:
        return '💊 Pharmacy / Medical Bill';
      case ReceiptType.utility:
        return '💡 Utility / Service Bill';
      case ReceiptType.upiPayment:
        return '📱 UPI / Digital Payment';
      case ReceiptType.general:
        return '🧾 General Receipt';
    }
  }

  String? _extractAccountEnding(String text) {
    final lower = text.toLowerCase();
    // Patterns like: "A/C ending in 4582", "A/C XX1234", "A/c ...1234", "Card ending 8811", "debited from ...1234"
    final regex = RegExp(
      r'(?:a\/c|account|acct|card|debited from|credited to|debited).*?(?:ending|no\.?|#|x+|\.\.\.)?\s*[:\s]*([xX\*\.]*\d{3,4})\b',
      caseSensitive: false,
    );
    final match = regex.firstMatch(lower);
    if (match != null) {
      final digits = match.group(1)?.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits != null && digits.length >= 3) {
        return digits;
      }
    }
    return null;
  }

  bool _detectIsIncome(String text) {
    final lower = text.toLowerCase();

    // 1. Explicit debit check
    final hasDebitWord = lower.contains('debited') ||
        lower.contains('paid to') ||
        lower.contains('paid successfully') ||
        lower.contains('payment successful') ||
        lower.contains('payment of') ||
        lower.contains('you paid') ||
        lower.contains('transferred from your account') ||
        lower.contains('transferred to') ||
        lower.contains('spent on') ||
        lower.contains('spent at') ||
        lower.contains('spent inr') ||
        lower.contains('spent rs') ||
        lower.contains('charged') ||
        lower.contains('card charged') ||
        lower.contains('deducted') ||
        lower.contains('autopay') ||
        lower.contains('purchase of') ||
        lower.contains('bill payment') ||
        lower.contains('withdrawn from') ||
        lower.contains('cash withdrawal') ||
        lower.contains('atm withdrawal') ||
        lower.contains('dr by') ||
        lower.contains('dr of') ||
        lower.contains(' dr.') ||
        lower.contains(' dr ');

    // 2. Explicit credit check
    final hasCreditWord = lower.contains('credited') ||
        lower.contains('received from') ||
        lower.contains('money received') ||
        lower.contains('payment received') ||
        lower.contains('you received') ||
        lower.contains('salary') ||
        lower.contains('salary credit') ||
        lower.contains('cashback') ||
        lower.contains('refund') ||
        lower.contains('inward remittance') ||
        lower.contains('inward transfer') ||
        lower.contains('neft credit') ||
        lower.contains('imps credit') ||
        lower.contains('rtgs') ||
        lower.contains('amount credited') ||
        lower.contains('deposit successful') ||
        lower.contains('deposit of') ||
        lower.contains('cr by') ||
        lower.contains('cr of') ||
        lower.contains(' cr.') ||
        lower.contains(' cr ');

    if (hasCreditWord && !hasDebitWord) {
      return true;
    }
    if (hasDebitWord && !hasCreditWord) {
      return false;
    }
    if (hasCreditWord && hasDebitWord) {
      if (lower.contains('credited to') || lower.contains('credited with') || lower.contains('amount credited')) {
        return true;
      }
      return false;
    }

    // 3. Positive currency sign
    if (RegExp(r'\+\s*(?:[₹\u20B9]|Rs\.?|INR)\s*\d+', caseSensitive: false).hasMatch(text) ||
        text.contains('+ ₹') ||
        text.contains('+₹')) {
      return true;
    }

    // 4. Fallback patterns
    if (lower.contains('received from') ||
        lower.contains('money received') ||
        lower.contains('credit alert') ||
        lower.contains('paid to you') ||
        lower.contains('sent you') ||
        lower.contains('money added to') ||
        lower.contains('received in paytm') ||
        lower.contains('received in google pay') ||
        lower.contains('received in phonepe')) {
      return true;
    }

    if (RegExp(r'(?:a\/c|account|acct|balance).*?\b(?:credited|credited with|cr\b|deposit)\b', caseSensitive: false).hasMatch(lower)) {
      return true;
    }

    return false;
  }

  String? _detectUpiApp(String text, String? upiId) {
    final lower = text.toLowerCase();
    final vpa = upiId?.toLowerCase() ?? '';

    // Check VPA handles first
    if (vpa.contains('@okaxis') || vpa.contains('@okhdfcbank') || vpa.contains('@okicici') || vpa.contains('@oksbi')) {
      return 'Google Pay';
    }
    if (vpa.contains('@ybl') || vpa.contains('@ibl') || vpa.contains('@axl') || vpa.contains('@yblupi')) {
      return 'PhonePe';
    }
    if (vpa.contains('@paytm') || vpa.contains('@ptaxis') || vpa.contains('@ptyes')) {
      return 'Paytm';
    }
    if (vpa.contains('@axiscred') || vpa.contains('@cred')) {
      return 'CRED';
    }
    if (vpa.contains('@apl') || vpa.contains('@rapl') || vpa.contains('@yapl')) {
      return 'Amazon Pay';
    }
    if (vpa.contains('@superyes') || vpa.contains('@superaxis')) {
      return 'Super.money';
    }
    if (vpa.contains('@naviaxis')) {
      return 'Navi';
    }
    if (vpa.contains('@upi') || vpa.contains('@npci')) {
      return 'BHIM';
    }

    // Check UI signatures & text
    if (lower.contains('google transaction id') || lower.contains('gpay') || lower.contains('google pay') || (lower.contains('completed') && lower.contains('state bank of india') && lower.contains('upi transaction id'))) {
      return 'Google Pay';
    }
    if (lower.contains('phonepe') || lower.contains('transfer details') || lower.contains('utr:')) {
      return 'PhonePe';
    }
    if (lower.contains('paytm') || lower.contains('paytm payments bank') || lower.contains('money sent successfully') || lower.contains('upi ref no')) {
      return 'Paytm';
    }
    if (lower.contains('cred pay') || lower.contains('cred')) {
      return 'CRED';
    }
    if (lower.contains('amazon pay') || lower.contains('amazon.in')) {
      return 'Amazon Pay';
    }
    if (lower.contains('bhim') || lower.contains('bhim upi')) {
      return 'BHIM';
    }
    if (lower.contains('yono') || (lower.contains('state bank of india') && lower.contains('sbi'))) {
      return 'SBI YONO';
    }
    if (lower.contains('payzapp')) {
      return 'HDFC PayZapp';
    }
    if (lower.contains('imobile')) {
      return 'ICICI iMobile';
    }

    if (lower.contains('upi')) {
      return 'UPI';
    }

    return null;
  }

  String? _extractPayer(String text) {
    final regexes = [
      RegExp(r'(?:Received from|Money received from|Payment received from|Payment of\s*[\d,₹Rs.]+\s*received from|Payment from)\s*[:\-]?\s*([A-Za-z0-9 .&_\-\n\x27\u2019(),/]+)', caseSensitive: false),
      RegExp(r'(?:Transferred from|Transfer from|Transferred by|Transfer by|Sent by|Money sent by)\s*[:\-]?\s*([A-Za-z0-9 .&_\-\n\x27\u2019(),/]+)', caseSensitive: false),
      RegExp(r'(?:Sender Name|Sender\x27?s? Name|Sender|Payer Name|Payer\x27?s? Name|Payer)\s*[:\-]?\s*([A-Za-z0-9 .&_\-\n\x27\u2019(),/]+)', caseSensitive: false),
      RegExp(r'(?:Remitter Name|Remitter\x27?s? Name|Remitter|Remitting Account Name)\s*[:\-]?\s*([A-Za-z0-9 .&_\-\n\x27\u2019(),/]+)', caseSensitive: false),
      RegExp(r'(?:Credited from|Credit from|Received in your account from|Inward remittance from)\s*[:\-]?\s*([A-Za-z0-9 .&_\-\n\x27\u2019(),/]+)', caseSensitive: false),
      RegExp(r'(?:^|\n)\s*(?:From|Received by)\s*[:\-]?\s*([A-Za-z0-9 .&_\-\n\x27\u2019(),/]+)', caseSensitive: false),
      RegExp(r'([A-Za-z0-9 .&_\-\x27\u2019(),/]+)\s+(?:sent you|paid you)', caseSensitive: false),
    ];

    for (final regex in regexes) {
      final match = regex.firstMatch(text);
      if (match != null) {
        var name = match.group(1)!.trim();
        if (name.contains('\n')) {
          final parts = name.split('\n').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
          name = parts.isNotEmpty ? parts.first : name;
        }
        name = name.split(RegExp(r'\s+(?:Amount|Date|UPI|Ref|Txn|Via|INR|₹|Rs|Using|Credited|Completed|Successful|\+91|\+[0-9]+)'))[0].trim();
        name = name.replaceAll(RegExp(r'^[:\-]+|[:\-]+$'), '').trim();
        if (name.isNotEmpty &&
            name.length > 1 &&
            !name.toLowerCase().startsWith('state bank') &&
            !name.toLowerCase().startsWith('your account') &&
            !name.toLowerCase().startsWith('bank account')) {
          return name;
        }
      }
    }

    // Fallback: check if UPI ID username can be extracted
    final upiId = _extractUpiId(text);
    if (upiId != null && upiId.contains('@')) {
      final handle = upiId.split('@').first.trim();
      if (!RegExp(r'^\d{10,12}$').hasMatch(handle)) {
        final cleanHandle = handle.replaceAll(RegExp(r'[._\-]'), ' ').trim();
        if (cleanHandle.length >= 3) {
          final words = cleanHandle
              .split(' ')
              .where((w) => w.isNotEmpty)
              .map((w) => w[0].toUpperCase() + (w.length > 1 ? w.substring(1) : ''))
              .join(' ');
          return words;
        }
      }
    }

    return null;
  }

  String detectIncomeSource(String? payer, String text) {
    final combined = '${payer ?? ''} $text'.toLowerCase();

    if (combined.contains('salary') || combined.contains('payroll') || combined.contains('wages') || combined.contains('employer') || combined.contains('pvt ltd') || combined.contains('technologies') || combined.contains('corp')) {
      return 'Salary';
    }
    if (combined.contains('freelance') || combined.contains('client') || combined.contains('project') || combined.contains('consulting') || combined.contains('upwork') || combined.contains('fiverr') || combined.contains('contract')) {
      return 'Freelance';
    }
    if (combined.contains('dividend') || combined.contains('zerodha') || combined.contains('groww') || combined.contains('interest') || combined.contains('mutual fund') || combined.contains('stock') || combined.contains('crypto') || combined.contains('trading')) {
      return 'Investments';
    }
    if (combined.contains('rent') || combined.contains('tenant') || combined.contains('rental') || combined.contains('lease') || combined.contains('flat') || combined.contains('house rent')) {
      return 'Rental';
    }
    if (combined.contains('bonus') || combined.contains('cashback') || combined.contains('reward') || combined.contains('gift') || combined.contains('coupon')) {
      return 'Bonus';
    }
    if (combined.contains('refund') || combined.contains('reversal') || combined.contains('failed txn refund')) {
      return 'Refund';
    }
    if (combined.contains('invoice') || combined.contains('customer') || combined.contains('sales') || combined.contains('store') || combined.contains('shop') || combined.contains('business') || combined.contains('merchant settlement')) {
      return 'Business';
    }

    return 'Other';
  }

  /// Extracts transaction amount with multi-pass decontamination of OCR Rupee symbol misreads (2/7/z/?/*).
  double? _extractAmount(String text) {
    final decontaminated = _decontaminateRupeeArtifacts(text);
    final cleanText = decontaminated.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // Priority 1: Bill & Invoice Total Keywords (Grand Total, Net Payable, Total Fare, Total Sale, etc.)
    final invoiceTotalRegexes = [
      RegExp(r'(?:Grand Total|GRAND TOTAL|Grand Total\s*\(₹\)|Total Amount|Total Amt|Net Payable|Net Amount|Total Fare|Fare Amount|Sale Amount|Total Sale|Amount Payable|Total Due|Total Bill|Bill Amount)[\s:\-=₹\u20B9RsINR\*\?~]*([0-9]+(?:,[0-9]+)*(?:\.[0-9]{1,2})?)', caseSensitive: false),
      RegExp(r'(?:Total|TOTAL|Fare|FARE)[\s:\-=₹\u20B9RsINR\*\?~]+([0-9]+(?:,[0-9]+)*(?:\.[0-9]{1,2})?)', caseSensitive: false),
    ];

    for (final reg in invoiceTotalRegexes) {
      final matches = reg.allMatches(cleanText);
      if (matches.isNotEmpty) {
        for (final m in matches) {
          final raw = m.group(1)?.replaceAll(',', '');
          if (raw != null) {
            final val = double.tryParse(raw);
            if (val != null && val > 0 && !_isDateOrTimeOrAccount(cleanText, raw) && !_isPhoneNumberOrContact(cleanText, raw)) {
              return _crossValidateMisreadRupee(val, cleanText);
            }
          }
        }
      }
    }

    // Priority 2: Currency symbol matched amounts (₹, \u20B9, Rs., Rs, INR) - NEVER match standalone + or * as currency
    final currencyRegex = RegExp(
      r'(?:[\u20B9₹]|Rs\.?|INR)[\s]*([0-9]+(?:,[0-9]+)*(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    );

    final currencyMatches = currencyRegex.allMatches(cleanText);
    if (currencyMatches.isNotEmpty) {
      for (final m in currencyMatches) {
        final raw = m.group(1)?.replaceAll(',', '');
        if (raw != null) {
          final val = double.tryParse(raw);
          if (val != null && val > 0 && !_isDateOrTimeOrAccount(cleanText, raw) && !_isPhoneNumberOrContact(cleanText, raw)) {
            return _crossValidateMisreadRupee(val, cleanText);
          }
        }
      }
    }

    // Priority 2B: Postfix currency (500 INR, 250 Rs, 1200 ₹) & Action-adjacent amount
    final postfixAndActionRegex = RegExp(
      r'(?:([0-9]+(?:,[0-9]+)*(?:\.[0-9]{1,2})?)\s*(?:[\u20B9₹]|Rs\.?|INR)|(?:debited with|debited by|spent|withdrawn|credited with|credited by|payment of|purchase of|charge of|amount of)\s*(?:[\u20B9₹]|Rs\.?|INR)?\s*([0-9]+(?:,[0-9]+)*(?:\.[0-9]{1,2})?))',
      caseSensitive: false,
    );
    final postfixMatches = postfixAndActionRegex.allMatches(cleanText);
    for (final pm in postfixMatches) {
      final raw = (pm.group(1) ?? pm.group(2))?.replaceAll(',', '');
      if (raw != null) {
        final val = double.tryParse(raw);
        if (val != null && val > 0 && !_isDateOrTimeOrAccount(cleanText, raw) && !_isPhoneNumberOrContact(cleanText, raw)) {
          return _crossValidateMisreadRupee(val, cleanText);
        }
      }
    }

    // Priority 3: Status Adjacency (Google Pay / PhonePe format: amount before "Completed" / "Pay again" / "Paid to")
    final lines = cleanText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].toLowerCase();
      if (line.contains('completed') || line.contains('pay again') || line.contains('successful') || line.contains('paid to') || line.contains('payment received') || line.contains('received from')) {
        // Look 1 line before
        if (i > 0) {
          final prevVal = _parseNumericLine(lines[i - 1]);
          if (prevVal != null && prevVal > 0 && !_isDateOrTimeOrAccount(cleanText, lines[i - 1]) && !_isPhoneNumberOrContact(cleanText, lines[i - 1])) {
            return _crossValidateMisreadRupee(prevVal, cleanText);
          }
        }
        // Look 2 lines before (e.g. amount -> "Pay again" -> "Completed")
        if (i > 1) {
          final prev2Val = _parseNumericLine(lines[i - 2]);
          if (prev2Val != null && prev2Val > 0 && !_isDateOrTimeOrAccount(cleanText, lines[i - 2]) && !_isPhoneNumberOrContact(cleanText, lines[i - 2])) {
            return _crossValidateMisreadRupee(prev2Val, cleanText);
          }
        }
        // Look 1 line after
        if (i + 1 < lines.length) {
          final nextVal = _parseNumericLine(lines[i + 1]);
          if (nextVal != null && nextVal > 0 && !_isDateOrTimeOrAccount(cleanText, lines[i + 1]) && !_isPhoneNumberOrContact(cleanText, lines[i + 1])) {
            return _crossValidateMisreadRupee(nextVal, cleanText);
          }
        }
      }
    }

    // Priority 4: Standalone line numeric parser
    for (final line in lines) {
      final val = _parseNumericLine(line);
      if (val != null && val > 0 && !_isDateOrTimeOrAccount(cleanText, line) && !_isPhoneNumberOrContact(cleanText, line)) {
        return _crossValidateMisreadRupee(val, cleanText);
      }
    }

    return null;
  }

  /// Normalizes OCR text where Rupee symbol was separated as a distinct character (e.g. `2 500.00` or `7 500.00`)
  String _decontaminateRupeeArtifacts(String text) {
    // 1. Separate leading OCR artifacts (2 , 7 , z , Z , ? , * , ~ , >) followed by amount (excluding phone numbers starting with +91)
    var result = text.replaceAllMapped(
      RegExp(r'(?:^|\n|[\s:])(?<!\+)([27zZ\?~*>])\s+([0-9]+(?:,[0-9]+)*(?:\.[0-9]{1,2})?)\b'),
      (m) => '${m.group(0)!.startsWith('\n') ? '\n' : ' '}₹ ${m.group(2)}',
    );

    // 2. Multi-line standalone Rupee symbol followed by number
    result = result.replaceAllMapped(
      RegExp(r'([₹\u20B9RsINR\*\?~])\n\s*([0-9]+(?:,[0-9]+)*(?:\.[0-9]{1,2})?)'),
      (m) => '₹ ${m.group(2)}',
    );

    return result;
  }

  /// Cross-validates amount if OCR read leading `2` or `7` as part of the number instead of `₹`
  double _crossValidateMisreadRupee(double amount, String fullText) {
    final str = amount % 1 == 0 ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);

    // If the text explicitly contains ₹[amount] with comma or exact formatted currency, it's genuine!
    final formattedWithComma = amount >= 1000
        ? '${(amount / 1000).floor()},${(amount % 1000).toInt().toString().padLeft(3, '0')}'
        : null;
    if (formattedWithComma != null && fullText.contains(formattedWithComma)) {
      return amount;
    }

    if (fullText.contains('₹$str') ||
        fullText.contains('₹ $str') ||
        fullText.contains('Rs. $str') ||
        fullText.contains('Rs $str') ||
        fullText.contains('INR $str')) {
      return amount;
    }

    // Check if the amount has 3+ digits starting with 2 or 7 (e.g. 2500, 7500, 250.00, 750.00)
    // and there is an independent mention of the stripped amount with ₹ or Rs or explicit Amount label
    if (str.startsWith('2') || str.startsWith('7')) {
      final strippedStr = str.substring(1);
      final strippedVal = double.tryParse(strippedStr);

      if (strippedVal != null && strippedVal > 0) {
        final strippedInt = strippedVal.toInt().toString();

        // Check if secondary context explicitly contains the stripped number with currency
        final hasSecondaryCurrency = RegExp(
          '(?:₹|\\u20B9|Rs\\.?|INR)\\s*$strippedInt(?:\\.00)?\\b',
          caseSensitive: false,
        ).hasMatch(fullText);

        final hasExplicitSubTotal = RegExp(
          '(?:Amount|Total|Fare|Net Payable|Transfer|Paid|Credited|Debited)[\\s:=₹\\u20B9RsINR\\-]*$strippedInt(?:\\.00)?\\b',
          caseSensitive: false,
        ).hasMatch(fullText);

        if (hasSecondaryCurrency || hasExplicitSubTotal) {
          return strippedVal;
        }
      }
    }

    return amount;
  }

  double? _parseNumericLine(String line) {
    var cleaned = line.replaceAll(RegExp(r'[₹\u20B9RsINR\*\?~,\s]'), '').trim();
    if (RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(cleaned)) {
      final val = double.tryParse(cleaned);
      if (val != null && val > 0 && val < 5000000) {
        return val;
      }
    }
    return null;
  }

  bool _isPhoneNumberOrContact(String fullText, String candidate) {
    final clean = candidate.replaceAll(RegExp(r'[\s,\-]'), '');
    final num = double.tryParse(clean);
    if (num == null) return false;

    // 1. Country code "91" in "+91 ..." or "+ 91 ..."
    if (clean == '91') {
      if (RegExp(r'\+\s*91\b').hasMatch(fullText)) {
        return true;
      }
    }

    // 2. Full 10-digit mobile number (e.g. 6369417139, 9876543210)
    if (clean.length == 10 && (clean.startsWith('6') || clean.startsWith('7') || clean.startsWith('8') || clean.startsWith('9'))) {
      return true;
    }

    // 3. 12-digit number starting with 91 (e.g. 916369417139)
    if (clean.length == 12 && clean.startsWith('91')) {
      return true;
    }

    // 4. Check if candidate is part of a phone line (e.g. "+91 63694 17139")
    final phoneMatches = RegExp(r'(?:\+91|91)?[\s\-]?[6-9]\d{4}[\s\-]?\d{5}').allMatches(fullText);
    for (final pm in phoneMatches) {
      final phoneStr = pm.group(0)!;
      if (phoneStr.contains(candidate)) {
        return true;
      }
    }

    return false;
  }

  bool _isDateOrTimeOrAccount(String fullText, String candidate) {
    if (_isPhoneNumberOrContact(fullText, candidate)) return true;

    final num = double.tryParse(candidate.replaceAll(',', ''));
    if (num == null) return false;

    // Check if it represents a year
    if (num >= 2020 && num <= 2035) {
      if (fullText.contains(candidate)) {
        final yearPattern = RegExp(r'(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|202[0-9]|203[0-9])', caseSensitive: false);
        if (yearPattern.hasMatch(fullText)) {
          return true;
        }
      }
    }

    // Check if it's bank account suffix (e.g. "State Bank of India 0532" or "A/c ... 0532")
    if (candidate.length == 4 && num < 10000) {
      final bankAccountRegex = RegExp(r'(?:Bank|A\/c|Account|Card|SBI|HDFC|ICICI|Axis|Ending in)\s*(?:[xX*]*\s*)?' + candidate, caseSensitive: false);
      if (bankAccountRegex.hasMatch(fullText)) {
        return true;
      }
    }

    return false;
  }

  String? _extractFuelDetails(String text) {
    String? volume;
    String? rate;
    String fuelType = 'Petrol';

    final lower = text.toLowerCase();
    if (lower.contains('diesel')) {
      fuelType = 'Diesel';
    } else if (lower.contains('cng')) {
      fuelType = 'CNG';
    } else if (lower.contains('power') || lower.contains('speed') || lower.contains('extra premium')) {
      fuelType = 'Premium Petrol';
    }

    final volMatch = RegExp(r'(?:Volume|Qty|Quantity|Liters|Litres|Ltrs)[\s:\-]*([0-9]+\.?[0-9]*)\s*(?:L|Ltr|Ltrs)?', caseSensitive: false).firstMatch(text);
    if (volMatch != null) {
      volume = '${volMatch.group(1)} L';
    }

    final rateMatch = RegExp(r'(?:Rate|Price|Unit Price|Rate\/L|Rate\/Ltr)[\s:\-₹\u20B9Rs]*([0-9]+\.?[0-9]*)', caseSensitive: false).firstMatch(text);
    if (rateMatch != null) {
      rate = '₹${rateMatch.group(1)}/L';
    }

    if (volume != null && rate != null) {
      return '$fuelType ($volume @ $rate)';
    } else if (volume != null) {
      return '$fuelType ($volume)';
    }
    return fuelType;
  }

  Map<String, String?> _extractTransitDetails(String text) {
    String? route;
    String? ticketNumber;

    // Route matching (e.g. Bengaluru to Chennai, Chennai -> Bangalore, CHIDAMBARAM TO TIRUPPADIRIPPUL)
    final routeMatch = RegExp(
      r'(?:Trip|Route|From)?[\s:\-]*\b([A-Za-z]+)\s*(?:to|->|➔|\bTO\b)\s*([A-Za-z]+)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (routeMatch != null) {
      final from = routeMatch.group(1)!.trim();
      final to = routeMatch.group(2)!.trim();
      if (from.toLowerCase() != 'paid' &&
          to.toLowerCase() != 'completed' &&
          from.toLowerCase() != 'e' &&
          to.toLowerCase() != 'ticket' &&
          from.toLowerCase() != 'happy' &&
          to.toLowerCase() != 'journey') {
        route = '$from ➔ $to';
      }
    }

    // PNR or Ticket Number (e.g. UTS NO : CXRZEE0147, PNR: 829102, Ticket No: 4021)
    final tktMatch = RegExp(
      r'(?:UTS NO|UTS|PNR|Ticket No|Tkt No|Ticket ID|Pass No|Booking ID|Booking Ref)[\s:\-]*([A-Za-z0-9]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (tktMatch != null) {
      ticketNumber = tktMatch.group(1);
    }

    return {'route': route, 'ticketNumber': ticketNumber};
  }

  Map<String, String?> _extractRestaurantDetails(String text) {
    String? table;
    final tableMatch = RegExp(r'(?:Table No|Table|Tbl)[\s:\-]*([0-9A-Za-z]+)', caseSensitive: false).firstMatch(text);
    if (tableMatch != null) {
      table = 'Table ${tableMatch.group(1)}';
    }
    return {'table': table};
  }

  String? _extractInvoiceNumber(String text) {
    final invMatch = RegExp(
      r'(?:Invoice No|Inv No|Bill No|Bill #|Receipt No|Ref No)[\s:\-]*([A-Za-z0-9\/\-]+)',
      caseSensitive: false,
    ).firstMatch(text);
    return invMatch?.group(1);
  }

  String? _extractMerchant(String text, ReceiptType receiptType) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    // Priority 1: Explicit Receiver keywords
    final regexes = [
      RegExp(r'(?:Paid to|Paying to|Paid successfully to|Successfully paid to|Payment to|Payment done to|Payment of\s*[\d,₹Rs.]+\s*to)\s*[:\-]?\s*([A-Za-z0-9 .&_\-\n\x27\u2019(),/]+)', caseSensitive: false),
      RegExp(r'(?:Transferred to|Transfer to|Money sent to|Sent to|You paid|You sent)\s*[:\-]?\s*([A-Za-z0-9 .&_\-\n\x27\u2019(),/]+)', caseSensitive: false),
      RegExp(r'(?:Recipient Name|Recipient\x27?s? Name|Recipient|Receiver Name|Receiver\x27?s? Name|Receiver)\s*[:\-]?\s*([A-Za-z0-9 .&_\-\n\x27\u2019(),/]+)', caseSensitive: false),
      RegExp(r'(?:Payee Name|Payee\x27?s? Name|Payee|Beneficiary Name|Beneficiary\x27?s? Name|Beneficiary)\s*[:\-]?\s*([A-Za-z0-9 .&_\-\n\x27\u2019(),/]+)', caseSensitive: false),
      RegExp(r'(?:Merchant Name|Merchant|Store|Vendor|Billed to|Bill to|A\/c Name|Account Name)\s*[:\-]?\s*([A-Za-z0-9 .&_\-\n\x27\u2019(),/]+)', caseSensitive: false),
      RegExp(r'(?:Credited to|Credit to)\s*[:\-]?\s*(?:account of\s*)?([A-Za-z0-9 .&_\-\n\x27\u2019(),/]+)', caseSensitive: false),
      RegExp(r'(?:^|\n)\s*\bTo\b\s*[:\-]?\s*([A-Za-z0-9 .&_\-\n\x27\u2019(),/]+)', caseSensitive: false),
    ];

    for (final reg in regexes) {
      final match = reg.firstMatch(text);
      if (match != null) {
        var name = match.group(1)!.trim();
        if (name.contains('\n')) {
          final parts = name.split('\n').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
          name = parts.isNotEmpty ? parts.first : name;
        }
        name = name.split(RegExp(r'\s+(?:Amount|Date|UPI|Ref|Txn|Via|INR|₹|Rs|Using|Completed|Successful|\+91|\+[0-9]+)'))[0].trim();
        name = name.replaceAll(RegExp(r'^[:\-]+|[:\-]+$'), '').trim();
        if (name.isNotEmpty &&
            name.length > 1 &&
            !name.toLowerCase().startsWith('state bank') &&
            !name.toLowerCase().startsWith('your account') &&
            !name.toLowerCase().startsWith('upi id') &&
            !name.toLowerCase().startsWith('account no') &&
            !name.toLowerCase().startsWith('bank account')) {
          return name;
        }
      }
    }

    // Priority 2: Specialized physical receipt parsers (when no digital "Paid to" is present)
    // 1. If Fuel Bill: Look for petrol pump agency in top lines
    if (receiptType == ReceiptType.fuel) {
      for (int i = 0; i < lines.length && i < 4; i++) {
        final line = lines[i];
        final lower = line.toLowerCase();
        if (lower.contains('indian oil') ||
            lower.contains('bharat petroleum') ||
            lower.contains('hindustan petroleum') ||
            lower.contains('petroleum') ||
            lower.contains('filling') ||
            lower.contains('auto care') ||
            lower.contains('fuel') ||
            lower.contains('iocl') ||
            lower.contains('bpcl') ||
            lower.contains('hpcl') ||
            lower.contains('shell') ||
            lower.contains('service station')) {
          return line;
        }
      }
      if (lines.isNotEmpty) return lines.first;
    }

    // 2. If Bus / Transit / Train: Look for transport operator or Indian Railways
    if (receiptType == ReceiptType.transit) {
      final lowerFull = text.toLowerCase();
      if (lowerFull.contains('indian railways') || lowerFull.contains('railway') || lowerFull.contains('uts') || lowerFull.contains('atvm')) {
        final route = _extractTransitDetails(text)['route'];
        if (route != null && route.isNotEmpty) {
          return 'Indian Railways ($route)';
        }
        return 'Indian Railways UTS';
      }

      for (int i = 0; i < lines.length && i < 5; i++) {
        final line = lines[i];
        final lower = line.toLowerCase();
        if (lower.contains('happy journey') || lower.contains('wish you') || lower.contains('subha yatra')) {
          continue;
        }
        if (lower.contains('ksrtc') || lower.contains('tnstc') || lower.contains('bmtc') || lower.contains('setc') || lower.contains('travels') || lower.contains('redbus') || lower.contains('irctc') || lower.contains('transport')) {
          return line;
        }
      }
      if (lines.isNotEmpty) {
        for (final l in lines) {
          if (!l.toLowerCase().contains('happy journey') && !l.toLowerCase().contains('second ordinary')) {
            return l;
          }
        }
        return lines.first;
      }
    }

    // 3. If Restaurant: First meaningful header line is usually the restaurant name
    if (receiptType == ReceiptType.restaurant && lines.isNotEmpty) {
      for (final l in lines.take(3)) {
        final lower = l.toLowerCase();
        if (!lower.contains('tax invoice') &&
            !lower.contains('bill') &&
            !lower.contains('fssai') &&
            !lower.contains('payment') &&
            !lower.contains('google pay') &&
            !lower.contains('phonepe') &&
            !lower.contains('paytm') &&
            !lower.contains('completed')) {
          return l;
        }
      }
    }

    // 4. If Supermarket: First non-empty header line
    if (receiptType == ReceiptType.supermarket && lines.isNotEmpty) {
      for (final l in lines.take(3)) {
        final lower = l.toLowerCase();
        if (!lower.contains('tax invoice') &&
            !lower.contains('bill') &&
            !lower.contains('payment') &&
            !lower.contains('google pay') &&
            !lower.contains('phonepe')) {
          return l;
        }
      }
      return lines.first;
    }

    // Priority 3: Top line before amount / Completed in UPI apps
    for (int i = 0; i < lines.length && i < 4; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();
      if (!lower.contains('completed') &&
          !lower.contains('payment') &&
          !lower.contains('google pay') &&
          !lower.contains('phonepe') &&
          !lower.contains('paytm') &&
          !lower.contains('tax invoice') &&
          !RegExp(r'^[0-9₹\u20B9\s,.]+$').hasMatch(line) &&
          line.length > 2) {
        return line;
      }
    }

    // Priority 4: Fallback to UPI ID handle if present
    final upiId = _extractUpiId(text);
    if (upiId != null && upiId.contains('@')) {
      final handle = upiId.split('@').first.trim();
      if (!RegExp(r'^\d{10,12}$').hasMatch(handle)) {
        final cleanHandle = handle.replaceAll(RegExp(r'[._\-]'), ' ').trim();
        if (cleanHandle.length >= 3) {
          final words = cleanHandle
              .split(' ')
              .where((w) => w.isNotEmpty)
              .map((w) => w[0].toUpperCase() + (w.length > 1 ? w.substring(1) : ''))
              .join(' ');
          return words;
        }
      }
    }

    return null;
  }

  String? _extractTransactionId(String text) {
    final regexes = [
      RegExp(r'(?:UPI transaction ID|UPI Ref No|Txn ID|Transaction ID|UPI Reference No|UTR|Ref No)[\s:\-]*([A-Za-z0-9]+)', caseSensitive: false),
      RegExp(r'\b(UPI\d{8,20}|\d{12})\b'),
    ];

    for (final reg in regexes) {
      final match = reg.firstMatch(text);
      if (match != null) {
        return match.group(1) ?? match.group(0);
      }
    }
    return null;
  }

  String? _extractUpiId(String text) {
    final regex = RegExp(
      r'\b[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}\b',
      caseSensitive: false,
    );
    return regex.firstMatch(text)?.group(0);
  }

  DateTime? _extractDate(String text) {
    final now = DateTime.now();

    // DD/MM/YYYY or DD-MM-YYYY
    final numRegex = RegExp(r'\b(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})\b');
    final numMatch = numRegex.firstMatch(text);
    if (numMatch != null) {
      try {
        final day = int.parse(numMatch.group(1)!);
        final month = int.parse(numMatch.group(2)!);
        var year = int.parse(numMatch.group(3)!);
        if (year < 100) year += 2000;
        if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          final dt = DateTime(year, month, day);
          if (dt.isBefore(now.add(const Duration(days: 1))) && dt.isAfter(now.subtract(const Duration(days: 365)))) {
            return dt;
          }
        }
      } catch (_) {}
    }

    // 11 Aug 2026 or 11 August 2026 or Aug 11, 2026
    final textRegex = RegExp(
      r'\b(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*[\s,]+(\d{4})\b',
      caseSensitive: false,
    );
    final textMatch = textRegex.firstMatch(text);
    if (textMatch != null) {
      try {
        final day = int.parse(textMatch.group(1)!);
        final monthStr = textMatch.group(2)!.toLowerCase();
        final year = int.parse(textMatch.group(3)!);
        const months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
        final month = months.indexOf(monthStr) + 1;
        if (month > 0 && day >= 1 && day <= 31) {
          final dt = DateTime(year, month, day);
          if (dt.isBefore(now.add(const Duration(days: 1))) && dt.isAfter(now.subtract(const Duration(days: 365)))) {
            return dt;
          }
        }
      } catch (_) {}
    }

    return now;
  }

  String? _detectPaymentMethod(String text, [ReceiptType? receiptType]) {
    final lower = text.toLowerCase();
    if (lower.contains('credit card') || lower.contains('creditcard')) return 'Credit Card';
    if (lower.contains('debit card') || lower.contains('debitcard') || lower.contains('mode:card') || lower.contains('mode: card') || lower.contains('mode : card') || lower.contains('s card no')) {
      return 'Debit Card';
    }
    if (lower.contains('card')) return 'Card';
    if (lower.contains('net banking') || lower.contains('bank transfer') || lower.contains('neft') || lower.contains('imps') || lower.contains('rtgs')) {
      return 'Bank Transfer';
    }
    if (lower.contains('cash')) return 'Cash';
    if (lower.contains('upi') || lower.contains('gpay') || lower.contains('phonepe') || lower.contains('paytm') || lower.contains('cred') || lower.contains('bhim')) {
      return 'UPI';
    }
    if (receiptType == ReceiptType.fuel || receiptType == ReceiptType.transit || receiptType == ReceiptType.restaurant) {
      return 'Cash';
    }
    return 'UPI';
  }

  String _detectCategoryWithReceiptType(String? merchant, ReceiptType type, String fullText) {
    switch (type) {
      case ReceiptType.fuel:
      case ReceiptType.transit:
        return 'Transport';
      case ReceiptType.restaurant:
        return 'Food';
      case ReceiptType.supermarket:
        return 'Shopping';
      case ReceiptType.pharmacy:
        return 'Health';
      case ReceiptType.utility:
        return 'Bills';
      default:
        return detectCategory(merchant ?? fullText);
    }
  }

  String detectCategory(String? merchant) {
    if (merchant == null || merchant.isEmpty) return 'Other';
    final name = merchant.toLowerCase();

    // 1. Food & Dining
    if (name.contains('swiggy') ||
        name.contains('zomato') ||
        name.contains('restaurant') ||
        name.contains('cafe') ||
        name.contains('food') ||
        name.contains('bakery') ||
        name.contains('sweets') ||
        name.contains('mcdonald') ||
        name.contains('kfc') ||
        name.contains('domino') ||
        name.contains('pizza') ||
        name.contains('burger') ||
        name.contains('tea') ||
        name.contains('coffee') ||
        name.contains('starbucks') ||
        name.contains('bhavan') ||
        name.contains('hotel') ||
        name.contains('canteen') ||
        name.contains('mess') ||
        name.contains('biryani') ||
        name.contains('dosa') ||
        name.contains('juice') ||
        name.contains('tiffin') ||
        name.contains('kitchen') ||
        name.contains('anand') ||
        name.contains('haldiram') ||
        name.contains('a2b') ||
        name.contains('sagar') ||
        name.contains('barbeque') ||
        name.contains('subway') ||
        name.contains('chai')) {
      return 'Food';
    }

    // 2. Transport & Travel & Fuel
    if (name.contains('uber') ||
        name.contains('ola') ||
        name.contains('rapido') ||
        name.contains('namma yatri') ||
        name.contains('metro') ||
        name.contains('transit') ||
        name.contains('transport') ||
        name.contains('railway') ||
        name.contains('irctc') ||
        name.contains('flight') ||
        name.contains('indigo') ||
        name.contains('air india') ||
        name.contains('petrol') ||
        name.contains('diesel') ||
        name.contains('fuel') ||
        name.contains('hpcl') ||
        name.contains('bpcl') ||
        name.contains('iocl') ||
        name.contains('indian oil') ||
        name.contains('bharat petroleum') ||
        name.contains('hindustan petroleum') ||
        name.contains('shell') ||
        name.contains('nayara') ||
        name.contains('ksrtc') ||
        name.contains('tnstc') ||
        name.contains('bmtc') ||
        name.contains('setc') ||
        name.contains('redbus') ||
        name.contains('toll') ||
        name.contains('fastag') ||
        name.contains('parking') ||
        name.contains('cab') ||
        name.contains('auto')) {
      return 'Transport';
    }

    // 3. Shopping & Groceries
    if (name.contains('amazon') ||
        name.contains('flipkart') ||
        name.contains('myntra') ||
        name.contains('ajio') ||
        name.contains('meesho') ||
        name.contains('nykaa') ||
        name.contains('tata cliq') ||
        name.contains('mart') ||
        name.contains('bazaar') ||
        name.contains('store') ||
        name.contains('supermarket') ||
        name.contains('boutique') ||
        name.contains('dmart') ||
        name.contains('d-mart') ||
        name.contains('blinkit') ||
        name.contains('zepto') ||
        name.contains('instamart') ||
        name.contains('bigbasket') ||
        name.contains('bb daily') ||
        name.contains('reliance fresh') ||
        name.contains('reliance smart') ||
        name.contains('more retail') ||
        name.contains('spencer') ||
        name.contains('zara') ||
        name.contains('h&m') ||
        name.contains('trends') ||
        name.contains('max fashion') ||
        name.contains('westside') ||
        name.contains('pantaloons') ||
        name.contains('zudio') ||
        name.contains('decathlon') ||
        name.contains('croma') ||
        name.contains('vijay sales') ||
        name.contains('reliance digital') ||
        name.contains('retail') ||
        name.contains('kirana') ||
        name.contains('provision')) {
      return 'Shopping';
    }

    // 4. Entertainment & OTT
    if (name.contains('netflix') ||
        name.contains('spotify') ||
        name.contains('prime') ||
        name.contains('hotstar') ||
        name.contains('sonyliv') ||
        name.contains('zee5') ||
        name.contains('cinema') ||
        name.contains('pvr') ||
        name.contains('inox') ||
        name.contains('cinepolis') ||
        name.contains('bookmyshow') ||
        name.contains('game') ||
        name.contains('steam') ||
        name.contains('playstation') ||
        name.contains('movie')) {
      return 'Entertainment';
    }

    // 5. Health & Medical
    if (name.contains('hospital') ||
        name.contains('pharmacy') ||
        name.contains('medical') ||
        name.contains('doctor') ||
        name.contains('apollo') ||
        name.contains('practo') ||
        name.contains('medplus') ||
        name.contains('pharmeasy') ||
        name.contains('1mg') ||
        name.contains('netmeds') ||
        name.contains('clinic') ||
        name.contains('dental') ||
        name.contains('diagnostic') ||
        name.contains('lab') ||
        name.contains('health')) {
      return 'Health';
    }

    // 6. Bills & Utilities & Recharge
    if (name.contains('electric') ||
        name.contains('bescom') ||
        name.contains('tangedco') ||
        name.contains('msedcl') ||
        name.contains('water') ||
        name.contains('gas') ||
        name.contains('broadband') ||
        name.contains('wifi') ||
        name.contains('jio') ||
        name.contains('airtel') ||
        name.contains('vodafone') ||
        RegExp(r'\bvi\b').hasMatch(name) ||
        name.contains('bsnl') ||
        name.contains('act fiber') ||
        name.contains('hathway') ||
        name.contains('tata play') ||
        name.contains('dth') ||
        name.contains('recharge') ||
        name.contains('maintenance') ||
        name.contains('rent') ||
        name.contains('bill')) {
      return 'Bills';
    }

    // 7. Education
    if (name.contains('school') ||
        name.contains('college') ||
        name.contains('university') ||
        name.contains('tuition') ||
        name.contains('udemy') ||
        name.contains('coursera') ||
        name.contains('course') ||
        name.contains('academy') ||
        name.contains('unacademy') ||
        name.contains('byju') ||
        name.contains('stationery') ||
        name.contains('bookstore') ||
        name.contains('textbook') ||
        RegExp(r'\bbooks?\b').hasMatch(name)) {
      return 'Education';
    }

    // 8. Personal Care & Grooming
    if (name.contains('salon') ||
        name.contains('spa') ||
        name.contains('barber') ||
        name.contains('parlour') ||
        name.contains('parlor') ||
        name.contains('haircut') ||
        name.contains('beauty') ||
        name.contains('grooming')) {
      return 'Personal Care';
    }

    // 9. Travel & Stays
    if (name.contains('makemytrip') ||
        name.contains('goibibo') ||
        name.contains('airbnb') ||
        name.contains('agoda') ||
        name.contains('booking.com') ||
        name.contains('resort') ||
        name.contains('lodge') ||
        name.contains('trip') ||
        name.contains('tour')) {
      return 'Travel';
    }

    return 'Other';
  }

  double _calculateConfidence({
    double? amount,
    String? merchant,
    String? transactionId,
    String? paymentMethod,
    bool isValid = false,
  }) {
    double score = 0.0;
    if (amount != null && amount > 0) score += 0.45;
    if (merchant != null && merchant.isNotEmpty) score += 0.25;
    if (transactionId != null && transactionId.isNotEmpty) score += 0.15;
    if (paymentMethod != null) score += 0.10;
    if (isValid) score += 0.05;
    return score.clamp(0.0, 1.0);
  }

  /// Parses a multi-transaction statement (e.g. Google Pay, PhonePe history screens)
  /// or falls back to a single receipt parse if only one transaction is present.
  List<DetectedPayment> parseMultipleOrStatement(String text, {String? imagePath}) {
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
    final statementItems = _parseTransactionStatement(normalized, imagePath: imagePath);
    if (statementItems.length > 1) {
      return statementItems;
    }
    return [parse(text, imagePath: imagePath)];
  }

  List<DetectedPayment> _parseTransactionStatement(String text, {String? imagePath}) {
    final rawLines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final List<DetectedPayment> results = [];

    // Detect statement year (e.g. "2026", "2025") or fallback to current year
    int statementYear = DateTime.now().year;
    final yearMatch = RegExp(r'\b(202[0-9]|203[0-9])\b').firstMatch(text);
    if (yearMatch != null) {
      statementYear = int.tryParse(yearMatch.group(1)!) ?? statementYear;
    }

    // Filter out UI noise header lines
    final filteredLines = <String>[];
    for (final line in rawLines) {
      final lower = line.toLowerCase();
      if (lower.startsWith('search') ||
          lower == 'status' ||
          lower == 'payment method' ||
          lower == 'date' ||
          lower.contains('unopened reward') ||
          lower.contains('scratch to reveal') ||
          lower.contains('all transactions') ||
          lower.contains('transaction history') ||
          RegExp(r'^(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s*[\+\-]?\s*[₹\u20B9RsINR\d,.]+$', caseSensitive: false).hasMatch(line)) {
        continue;
      }
      filteredLines.add(line);
    }

    final dateRegex = RegExp(
      r'\b(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*(?:\s+(\d{4}))?\b|\b(\d{1,2})[\/\-](\d{1,2})(?:[\/\-](\d{2,4}))?\b',
      caseSensitive: false,
    );

    int i = 0;
    while (i < filteredLines.length) {
      final line = filteredLines[i];

      String? merchantName;
      DateTime? txnDate;
      double? txnAmount;
      bool isIncome = false;

      final dateMatch = dateRegex.firstMatch(line);
      if (dateMatch != null) {
        // Date found on line i
        txnDate = _parseDateFromMatch(dateMatch, statementYear);

        // Merchant is line i - 1
        if (i > 0) {
          merchantName = _cleanMerchantLine(filteredLines[i - 1]);
        }

        // Check if amount is on line i after date
        final lineWithoutDate = line.replaceFirst(dateMatch.group(0)!, '').trim();
        final amtMatchInLine = _extractAmountAndSign(lineWithoutDate);
        if (amtMatchInLine != null) {
          txnAmount = amtMatchInLine.amount;
          isIncome = amtMatchInLine.isIncome;
          i += 1;
        } else if (i + 1 < filteredLines.length) {
          final nextAmt = _extractAmountAndSign(filteredLines[i + 1]);
          if (nextAmt != null) {
            txnAmount = nextAmt.amount;
            isIncome = nextAmt.isIncome;
            i += 2;
          } else {
            i += 1;
          }
        } else {
          i += 1;
        }
      } else {
        // Check if line i is an amount
        final amtMatch = _extractAmountAndSign(line);
        if (amtMatch != null && i >= 2) {
          final prevDateMatch = dateRegex.firstMatch(filteredLines[i - 1]);
          if (prevDateMatch != null) {
            txnDate = _parseDateFromMatch(prevDateMatch, statementYear);
            merchantName = _cleanMerchantLine(filteredLines[i - 2]);
            txnAmount = amtMatch.amount;
            isIncome = amtMatch.isIncome;
          }
        }
        i += 1;
      }

      if (merchantName != null && merchantName.isNotEmpty && txnAmount != null && txnAmount > 0) {
        final lower = merchantName.toLowerCase();
        if (!lower.startsWith('august') &&
            !lower.startsWith('july') &&
            !lower.startsWith('september') &&
            !lower.startsWith('october') &&
            !lower.startsWith('november') &&
            !lower.startsWith('december') &&
            !lower.startsWith('january') &&
            !lower.startsWith('february') &&
            !lower.startsWith('march') &&
            !lower.startsWith('april') &&
            !lower.startsWith('may') &&
            !lower.startsWith('june') &&
            !RegExp(r'^[0-9₹\u20B9\s,.]+$').hasMatch(merchantName) &&
            !results.any((r) => r.merchant == merchantName && r.amount == txnAmount && r.date?.day == txnDate?.day)) {
          
          final normalizedMerchant = PaymentMerchantLearningService.instance.normalizeMerchantName(merchantName);
          final category = _detectCategoryWithReceiptType(normalizedMerchant, ReceiptType.upiPayment, normalizedMerchant);
          final incomeSource = detectIncomeSource(normalizedMerchant, normalizedMerchant);

          results.add(
            DetectedPayment(
              amount: txnAmount,
              merchant: normalizedMerchant,
              date: txnDate ?? DateTime.now(),
              paymentMethod: 'UPI',
              isIncome: isIncome,
              receiptType: ReceiptType.upiPayment,
              receiptTypeDisplayName: isIncome ? '🟢 UPI Credit / Received' : '🔴 UPI Debit / Expense',
              suggestedCategory: category,
              suggestedIncomeSource: incomeSource,
              confidence: 0.92,
              rawText: '$normalizedMerchant | ₹$txnAmount | ${txnDate?.toIso8601String()}',
              imagePath: imagePath,
              isValidPayment: true,
            ),
          );
        }
      }
    }

    return results;
  }

  String _cleanMerchantLine(String line) {
    var cleaned = line.trim();
    // Strip leading avatar characters or icons
    cleaned = cleaned.replaceAll(RegExp(r'^[A-Za-z0-9]\s+(?=[A-Za-z])'), '');
    return cleaned;
  }

  DateTime _parseDateFromMatch(RegExpMatch match, int defaultYear) {
    try {
      if (match.group(1) != null && match.group(2) != null) {
        final day = int.parse(match.group(1)!);
        final monthStr = match.group(2)!.toLowerCase();
        final year = match.group(3) != null ? int.parse(match.group(3)!) : defaultYear;
        const months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
        final month = months.indexOf(monthStr.substring(0, 3)) + 1;
        if (month > 0 && day >= 1 && day <= 31) {
          return DateTime(year, month, day);
        }
      } else if (match.group(4) != null && match.group(5) != null) {
        final day = int.parse(match.group(4)!);
        final month = int.parse(match.group(5)!);
        var year = match.group(6) != null ? int.parse(match.group(6)!) : defaultYear;
        if (year < 100) year += 2000;
        if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          return DateTime(year, month, day);
        }
      }
    } catch (_) {}
    return DateTime.now();
  }

  _ParsedAmountSign? _extractAmountAndSign(String text) {
    final clean = text.trim();
    final hasPlus = clean.startsWith('+') || clean.contains('+ ₹') || clean.contains('+₹') || clean.contains('Received');
    var numStr = clean.replaceAll(RegExp(r'[\+\-₹\u20B9RsINR\*\?~,\s]'), '');
    if (RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(numStr)) {
      final val = double.tryParse(numStr);
      if (val != null && val > 0 && val < 5000000) {
        return _ParsedAmountSign(val, hasPlus);
      }
    }
    return null;
  }
}

class _ParsedAmountSign {
  final double amount;
  final bool isIncome;
  const _ParsedAmountSign(this.amount, this.isIncome);
}
