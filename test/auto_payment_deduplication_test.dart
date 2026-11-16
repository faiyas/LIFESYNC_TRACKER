import 'package:flutter_test/flutter_test.dart';
import 'package:lifesync_tracker/features/payment_scanner/models/detected_payment.dart';
import 'package:lifesync_tracker/features/payment_scanner/services/payment_deduplication_engine.dart';
import 'package:lifesync_tracker/features/payment_scanner/services/payment_parser_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PaymentDeduplicationEngine & Multi-Channel Failover Tests', () {
    final parser = PaymentParserService();
    final dedup = PaymentDeduplicationEngine.instance;

    setUp(() {
      dedup.resetDuplicateStats();
    });

    test('Parses bank SMS and blocks duplicate if notification arrived first', () async {
      // 1. Channel 2 (Notification) arrives first:
      const notifText = 'Google Pay: Paid ₹350.00 to Chai Point UPI Ref 9988776655';
      final notifPayment = parser.parse(notifText);
      expect(notifPayment.isValidPayment, isTrue);
      expect(notifPayment.amount, 350.0);

      // Register the notification payment
      dedup.registerProcessedPayment(notifPayment);

      // 2. Channel 1 (Bank SMS) arrives 15 seconds later for the same payment:
      const bankSmsText = 'Sender: HDFCBK\nRs 350.00 debited from A/C XX1234 on 13-Nov-26 to CHAI POINT UPI Ref 9988776655';
      final smsPayment = parser.parse(bankSmsText);
      expect(smsPayment.isValidPayment, isTrue);
      expect(smsPayment.amount, 350.0);

      // Deduplication check MUST detect duplicate
      final checkResult = await dedup.checkDuplicate(smsPayment);
      expect(checkResult.isDuplicate, isTrue);
      expect(checkResult.reason, contains('9988776655'));
    });

    test('Fuzzy merchant deduplication blocks duplicate even without transaction ID', () async {
      final now = DateTime.now();

      // First payment from UPI notification
      final p1 = DetectedPayment(
        amount: 520.0,
        merchant: 'Swiggy',
        date: now,
        isValidPayment: true,
      );
      dedup.registerProcessedPayment(p1);

      // Second payment from Bank SMS with slight name variation on the same date
      final p2 = DetectedPayment(
        amount: 520.0,
        merchant: 'BUNDL TECHNOLOGIES - SWIGGY UPI',
        date: now,
        isValidPayment: true,
      );

      final checkResult = await dedup.checkDuplicate(p2);
      expect(checkResult.isDuplicate, isTrue);
      expect(dedup.duplicatesPreventedCount, greaterThan(0));
    });

    test('Legitimate different payment is NOT blocked as duplicate', () async {
      final now = DateTime.now();

      final p1 = DetectedPayment(
        amount: 150.0,
        merchant: 'Uber',
        date: now,
        transactionId: 'TXN_UBER_111',
        isValidPayment: true,
      );
      dedup.registerProcessedPayment(p1);

      final p2 = DetectedPayment(
        amount: 850.0,
        merchant: 'Supermarket Groceries',
        date: now,
        transactionId: 'TXN_GROCERY_222',
        isValidPayment: true,
      );

      final checkResult = await dedup.checkDuplicate(p2);
      expect(checkResult.isDuplicate, isFalse);
    });

    test('Merchant normalizer cleans corporate and UPI tags', () {
      expect(PaymentDeduplicationEngine.normalizeMerchant('Swiggy Private Limited UPI'), 'swiggy');
      expect(PaymentDeduplicationEngine.normalizeMerchant('Paid to Starbucks Coffee Pvt Ltd'), 'starbucks coffee');
      expect(PaymentDeduplicationEngine.normalizeMerchant('INDIAN OIL CORP LTD - FUEL'), 'indian oil fuel');
    });

    test('Promotional and marketing notifications are strictly rejected', () {
      const promoAd = 'Make playtime extra fun for your little ones, with toys starting at just ₹109! 😍';
      expect(parser.isPaymentScreenshot(promoAd), isFalse);

      const discountAd = 'Flat 50% discount on food orders upto ₹150! Use code TASTY';
      expect(parser.isPaymentScreenshot(discountAd), isFalse);
    });

    test('Strict financial actions (debited, credited, paid to) are accepted', () {
      const debitNotif = 'Google Pay: Paid ₹250.00 to Chai Point. UPI Ref: 123456';
      expect(parser.isPaymentScreenshot(debitNotif), isTrue);

      const creditNotif = 'HDFC Alert: INR 5,000.00 credited to A/C XX1234 on 13-Nov-26';
      expect(parser.isPaymentScreenshot(creditNotif), isTrue);
    });
  });
}

