import 'package:flutter_test/flutter_test.dart';
import 'package:lifesync_tracker/features/payment_scanner/models/detected_payment.dart';
import 'package:lifesync_tracker/features/payment_scanner/services/payment_parser_service.dart';
import 'package:lifesync_tracker/features/payment_scanner/services/payment_merchant_learning_service.dart';
import 'package:lifesync_tracker/services/dynamic_option_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PaymentParserService Tests', () {
    final parser = PaymentParserService();

    test('Parses Google Pay UPI Screenshot accurately', () {
      const sampleGPay = '''
Payment Successful
Paid to Swiggy India
Amount ₹486.00
Date: 24 Aug 2026
UPI Ref No 421890123456
Paid via Google Pay UPI
swiggy@icici
      ''';

      final detected = parser.parse(sampleGPay);
      expect(detected.isValidPayment, isTrue);
      expect(detected.amount, 486.00);
      expect(detected.merchant, contains('Swiggy'));
      expect(detected.suggestedCategory, 'Food');
      expect(detected.paymentMethod, 'UPI');
      expect(detected.transactionId, '421890123456');
      expect(detected.isIncome, isFalse);
    });

    test('Parses PhonePe multi-line layout with newline Rupee symbol', () {
      const samplePhonePe = '''
Transaction Successful
Paid to
Starbucks Coffee
₹
1,250.00
Debited from XX1234
UTR: 987654321012
24-08-2026
      ''';

      final detected = parser.parse(samplePhonePe);
      expect(detected.isValidPayment, isTrue);
      expect(detected.amount, 1250.00);
      expect(detected.suggestedCategory, 'Food');
      expect(detected.transactionId, '987654321012');
    });

    test('Fixes Rupee Symbol OCR Misidentified as 2 or 7 (2 500 / 7 500)', () {
      const sampleOcrMisread2 = '''
Payment Successful
Paid to Swiggy India
2 486.00
Date: 24 Aug 2026
UPI Ref No 421890123456
Paid via Google Pay UPI
      ''';

      final detected2 = parser.parse(sampleOcrMisread2);
      expect(detected2.amount, 486.00);

      const sampleOcrMisread7 = '''
Payment Successful
Paid to Apollo Pharmacy
7 350.00
Date: 24 Aug 2026
UPI Ref No 421890123456
      ''';

      final detected7 = parser.parse(sampleOcrMisread7);
      expect(detected7.amount, 350.00);
      expect(detected7.suggestedCategory, 'Health');
    });

    test('Cross-validates header amount when OCR reads ₹ as 2 or 7 attached to number', () {
      const sampleHeaderMisread = '''
Google Pay
2500
Completed
Paid to Sri Sai Restaurant
Amount: ₹500.00
UPI Ref: 982173918231
      ''';

      final detected = parser.parse(sampleHeaderMisread);
      expect(detected.amount, 500.0);
      expect(detected.merchant, contains('Sri Sai'));
      expect(detected.suggestedCategory, 'Food');
    });

    test('Preserves genuine 2000s and 7000s amounts accurately', () {
      const sampleGenuine2500 = '''
Payment Successful
Paid to Electronics Store
Amount ₹2,500.00
Date: 24 Aug 2026
UPI Ref No 421890123456
      ''';

      final detected = parser.parse(sampleGenuine2500);
      expect(detected.amount, 2500.00);
      expect(detected.suggestedCategory, 'Shopping');
    });

    test('Parses Google Pay sent payment to individual with +91 phone number header accurately', () {
      const sampleGPayWithPhone = '''
To mohammed faroz
+91 63694 17139
₹1,000
Pay again
Completed
30 Aug 2026, 5:08 pm
State Bank of India 0532
UPI transaction ID
624287108497
To: MOHAMMED FAROZ M
Google Pay • mohammedfarozktm-1@okicici
From: MOHAMED FAIYAS M (State Bank of India)
Google Pay • mohamedfaiyas11@oksbi
Google transaction ID
CICAgLi_juWrDA
POWERED BY UPI
GPay
      ''';

      final detected = parser.parse(sampleGPayWithPhone);
      expect(detected.isValidPayment, isTrue);
      expect(detected.isIncome, isFalse);
      expect(detected.amount, 1000.0);
      expect(detected.merchant?.toLowerCase(), contains('mohammed faroz'));
      expect(detected.paymentMethod, 'UPI');
      expect(detected.upiApp, 'Google Pay');
      expect(detected.transactionId, '624287108497');
    });

    test('Detects Income & Credit accurately from Google Pay, PhonePe, Paytm, Bank SMS', () {
      // 1. Google Pay Received with + ₹
      const sampleGPayCredit = '''
Rahul Sharma
+ ₹1,200
Completed
24 Aug 2026, 5:25 pm
State Bank of India 0532
UPI transaction ID: 623718920192
Received from: Rahul Sharma
      ''';

      final gpayCredit = parser.parse(sampleGPayCredit);
      expect(gpayCredit.isValidPayment, isTrue);
      expect(gpayCredit.isIncome, isTrue);
      expect(gpayCredit.amount, 1200.0);
      expect(gpayCredit.merchant, contains('Rahul Sharma'));

      // 2. PhonePe Received where Sender Bank is mentioned as Debited
      const samplePhonePeCredit = '''
Transaction Details
Received from Ramesh Kumar
₹500.00
Credited to State Bank of India XX1234
Debited from HDFC Bank XX9876
UTR: 829102938102
      ''';

      final phonepeCredit = parser.parse(samplePhonePeCredit);
      expect(phonepeCredit.isValidPayment, isTrue);
      expect(phonepeCredit.isIncome, isTrue);
      expect(phonepeCredit.amount, 500.0);
      expect(phonepeCredit.merchant, contains('Ramesh Kumar'));

      // 3. Paytm Money Received
      const samplePaytmCredit = '''
Money Received Successfully
From Priya Sundaram
+ ₹450
Received in Paytm Payments Bank
UPI Ref: 981273918231
      ''';

      final paytmCredit = parser.parse(samplePaytmCredit);
      expect(paytmCredit.isValidPayment, isTrue);
      expect(paytmCredit.isIncome, isTrue);
      expect(paytmCredit.amount, 450.0);
      expect(paytmCredit.merchant, contains('Priya Sundaram'));

      // 4. Bank SMS Credit Alert
      const sampleBankSmsCredit = '''
Dear Customer, your A/C ending XX0532 is CREDITED with INR 15,000.00 on 24-Aug-2026 by Info: UPI/Salary.
      ''';

      final bankCredit = parser.parse(sampleBankSmsCredit);
      expect(bankCredit.isValidPayment, isTrue);
      expect(bankCredit.isIncome, isTrue);
      expect(bankCredit.amount, 15000.0);
      expect(bankCredit.suggestedIncomeSource, 'Salary');
    });

    test('Parses Bus Ticket accurately with Fare, Route, and PNR', () {
      const sampleBusTicket = '''
KSRTC E-TICKET PASSENGER COPY
Trip: Bengaluru to Chennai
Departure: 24-08-2026 22:30
PNR: 8492019283
Seat No: 14, 15
Total Fare: ₹ 850.00
Conductor ID: 4021
      ''';

      final detected = parser.parse(sampleBusTicket);
      expect(detected.isValidPayment, isTrue);
      expect(detected.receiptType, ReceiptType.transit);
      expect(detected.amount, 850.0);
      expect(detected.suggestedCategory, 'Transport');
      expect(detected.journeyRoute, contains('Bengaluru ➔ Chennai'));
      expect(detected.ticketNumber, '8492019283');
      expect(detected.merchant, contains('KSRTC'));
    });

    test('Parses Indian Railways UTS ATVM Train Ticket accurately', () {
      const sampleUtsTicket = '''
SECOND ORDINARY JOURNEY ATVM
CHIDAMBARAM TO TIRUPPADIRIPPUL KM 43
ADULT: 1 CHILD: 0
Commence Journey Within 3Hrs or Dep. of First Train
UTS NO : CXRZEE0147
Rs. 10/-
SAC: 996411 IR: 33AAAGM0289C1ZQ INDIAN RAILWAYS
S Card No: SR0252240 MODE: CARD
      ''';

      final detected = parser.parse(sampleUtsTicket);
      expect(detected.isValidPayment, isTrue);
      expect(detected.receiptType, ReceiptType.transit);
      expect(detected.amount, 10.0);
      expect(detected.suggestedCategory, 'Transport');
      expect(detected.journeyRoute, contains('CHIDAMBARAM ➔ TIRUPPADIRIPPUL'));
      expect(detected.ticketNumber, 'CXRZEE0147');
      expect(detected.merchant, contains('Indian Railways'));
      expect(detected.paymentMethod, 'Debit Card');
    });

    test('Parses Petrol / Fuel Bill accurately with Volume in Litres and Pump Name', () {
      const sampleFuelBill = '''
INDIAN OIL CORPORATION LTD
SRI SAI PETROLEUM FILLING STATION
Date: 24/08/2026 18:45
Nozzle: 02
Fuel: Petrol
Volume: 14.63 Ltrs
Rate/L: ₹102.50
Total Sale: ₹ 1500.00
Tax Invoice Ref: IOCL849201
      ''';

      final detected = parser.parse(sampleFuelBill);
      expect(detected.isValidPayment, isTrue);
      expect(detected.receiptType, ReceiptType.fuel);
      expect(detected.amount, 1500.0);
      expect(detected.suggestedCategory, 'Transport');
      expect(detected.fuelDetails, contains('14.63 L'));
      expect(detected.fuelDetails, contains('102.50'));
      expect(detected.merchant, contains('Indian Oil'));
    });

    test('Parses Restaurant Bill with Grand Total and Table Info', () {
      const sampleRestaurant = '''
SRI SAI BHAVAN RESTAURANT
GSTIN: 29ABCDE1234F1Z5
FSSAI: 11223344556677
Table No: 08
Date: 24-Aug-2026
1 x Masala Dosa - 90
2 x Filter Coffee - 60
1 x Special Meals - 180
CGST 2.5%: 8.25
SGST 2.5%: 8.25
Grand Total: ₹ 346.50
Thank you! Visit Again
      ''';

      final detected = parser.parse(sampleRestaurant);
      expect(detected.isValidPayment, isTrue);
      expect(detected.receiptType, ReceiptType.restaurant);
      expect(detected.amount, 346.50);
      expect(detected.suggestedCategory, 'Food');
      expect(detected.merchant, contains('SRI SAI BHAVAN'));
    });

    test('Parses Supermarket Grocery Bill with Net Payable', () {
      const sampleSupermarket = '''
DMART HYPERMARKET
Total Items: 12
MRP Total: ₹ 2800.00
Total Savings: ₹ 450.00
Net Payable: ₹ 2350.00
Cashier: POS-04
      ''';

      final detected = parser.parse(sampleSupermarket);
      expect(detected.isValidPayment, isTrue);
      expect(detected.receiptType, ReceiptType.supermarket);
      expect(detected.amount, 2350.0);
      expect(detected.suggestedCategory, 'Shopping');
      expect(detected.merchant, contains('DMart'));
    });

    test('Parses Google Pay August Transaction History Statement containing multiple transactions', () {
      const sampleStatement = '''
Search transactions
Status  Payment method  Date

2026
August  + ₹6,921.82

Sri Sai Restaurant
24 August
₹280

Jio Prepaid
23 August
₹900.90

M S SDK ENTERPRISES
22 August
₹145

Tamilnadu State Transport Corporation Ltd Villupuram
22 August
₹90

Muthukumaran Rajangam
21 August
₹10

You have an unopened reward!
Scratch to reveal

Raja Pichai
20 August
₹20

Shameem Mubarak Ali
20 August
₹60

Yacoob Khan
19 August
+ ₹160

VRM TRADERS
19 August
₹10

Siva Sakthi Stores
19 August
₹10

HAJA A
19 August
₹250

S BASKARAN
18 August
₹80

ATHERAI VEG RESTAURA
18 August
₹80

SAMSUDEEN M
17 August
₹150

padmavathy D
17 August
₹200

NEW ROYAL BOUTIQUE
17 August
₹5

MISS MEGALA R
17 August
₹50

Mr AROKIYAMRAJ SO GNANAPRAKASAM
17 August
₹20

VIKRAM SINGH
17 August
₹30

Mr J JANAKIRAMAN
15 August
₹100
      ''';

      final items = parser.parseMultipleOrStatement(sampleStatement);
      expect(items.length, greaterThanOrEqualTo(19));

      // Check specific items
      final restaurant = items.firstWhere((i) => i.merchant!.contains('Sri Sai Restaurant'));
      expect(restaurant.amount, 280.0);
      expect(restaurant.isIncome, isFalse);
      expect(restaurant.suggestedCategory, 'Food');
      expect(restaurant.date?.day, 24);
      expect(restaurant.date?.month, 8);

      final jio = items.firstWhere((i) => i.merchant!.contains('Jio'));
      expect(jio.amount, 900.90);
      expect(jio.isIncome, isFalse);
      expect(jio.suggestedCategory, 'Bills');

      final income = items.firstWhere((i) => i.merchant!.contains('Yacoob Khan'));
      expect(income.amount, 160.0);
      expect(income.isIncome, isTrue);
    });

    test('Detects categories correctly across multiple merchants', () {
      expect(parser.detectCategory('Zomato Delivery'), 'Food');
      expect(parser.detectCategory('Ola Cabs'), 'Transport');
      expect(parser.detectCategory('Amazon Shopping'), 'Shopping');
      expect(parser.detectCategory('DMart Ready'), 'Shopping');
      expect(parser.detectCategory('Zepto Quick'), 'Shopping');
      expect(parser.detectCategory('Netflix India'), 'Entertainment');
      expect(parser.detectCategory('Apollo Pharmacy'), 'Health');
      expect(parser.detectCategory('BESCOM Electricity Bill'), 'Bills');
      expect(parser.detectCategory('Indian Oil Petrol Pump'), 'Transport');
      expect(parser.detectCategory('Coursera Course Tuition'), 'Education');
      expect(parser.detectCategory('Naturals Salon and Spa'), 'Personal Care');
      expect(parser.detectCategory('Agoda Resort Booking'), 'Travel');
      expect(parser.detectCategory('Unknown Merchant'), 'Other');
    });

    test('Parses receipts with new receiver and payer patterns', () {
      const sampleReceiverPattern = '''
Paid successfully to
Blue Tokai Coffee Roasters
UPI ID: bluetokai@icici
₹340.00
Completed on 25 Aug 2026
''';
      final res1 = parser.parse(sampleReceiverPattern);
      expect(res1.isValidPayment, isTrue);
      expect(res1.merchant, 'Blue Tokai Coffee Roasters');
      expect(res1.suggestedCategory, 'Food');

      const samplePayerPattern = '''
Payment received from
Rohit Sharma
₹1,500.00
Transaction ID: T2608251234
''';
      final res2 = parser.parse(samplePayerPattern);
      expect(res2.isValidPayment, isTrue);
      expect(res2.isIncome, isTrue);
      expect(res2.merchant, 'Rohit Sharma');
      expect(res2.suggestedIncomeSource, 'Other');

      const sampleUnknownPattern = '''
Paid to
Random Mysterious Shop
₹50.00
''';
      final res3 = parser.parse(sampleUnknownPattern);
      expect(res3.isValidPayment, isTrue);
      expect(res3.merchant, 'Random Mysterious Shop');
      expect(res3.suggestedCategory, 'Other');
    });
  });

  group('PaymentMerchantLearningService Tests', () {
    final learningService = PaymentMerchantLearningService.instance;

    test('Normalizes merchant names accurately', () {
      expect(learningService.normalizeMerchantName('UPI/123/SWIGGY BANGALORE'), 'Swiggy');
      expect(learningService.normalizeMerchantName('Paid to Starbucks Coffee'), 'Starbucks');
      expect(learningService.normalizeMerchantName('DMART HYPERMARKET'), 'DMart');
      expect(learningService.normalizeMerchantName('Apollo Pharmacy Indiranagar'), 'Apollo Pharmacy');
      expect(learningService.normalizeMerchantName('IOCL PETROL PUMP'), 'Indian Oil');
    });

    test('Calculates merchant spending group totals and averages', () {
      final payments = [
        DetectedPayment(
          amount: 500,
          merchant: 'DMart',
          date: DateTime.now(),
          paymentMethod: 'UPI',
          isIncome: false,
          receiptType: ReceiptType.supermarket,
          receiptTypeDisplayName: 'Supermarket',
          suggestedCategory: 'Shopping',
          suggestedIncomeSource: 'Other',
          confidence: 1.0,
          rawText: '',
          isValidPayment: true,
        ),
        DetectedPayment(
          amount: 1500,
          merchant: 'DMart',
          date: DateTime.now(),
          paymentMethod: 'UPI',
          isIncome: false,
          receiptType: ReceiptType.supermarket,
          receiptTypeDisplayName: 'Supermarket',
          suggestedCategory: 'Shopping',
          suggestedIncomeSource: 'Other',
          confidence: 1.0,
          rawText: '',
          isValidPayment: true,
        ),
        DetectedPayment(
          amount: 250,
          merchant: 'Swiggy',
          date: DateTime.now(),
          paymentMethod: 'UPI',
          isIncome: false,
          receiptType: ReceiptType.restaurant,
          receiptTypeDisplayName: 'Restaurant',
          suggestedCategory: 'Food',
          suggestedIncomeSource: 'Other',
          confidence: 1.0,
          rawText: '',
          isValidPayment: true,
        ),
      ];

      final summaries = learningService.calculateMerchantSummary(payments);
      expect(summaries.length, 2);

      final dmartSummary = summaries.firstWhere((s) => s.merchantName == 'DMart');
      expect(dmartSummary.count, 2);
      expect(dmartSummary.totalAmount, 2000.0);
      expect(dmartSummary.averageAmount, 1000.0);

      final swiggySummary = summaries.firstWhere((s) => s.merchantName == 'Swiggy');
      expect(swiggySummary.count, 1);
      expect(swiggySummary.totalAmount, 250.0);
    });
  });

  group('DynamicOptionService Constants Test', () {
    test('Dynamic option type constants are well-defined', () {
      expect(DynamicOptionService.typeExpenseCategory, 'expense_category');
      expect(DynamicOptionService.typePaymentMethod, 'payment_method');
      expect(DynamicOptionService.typeIncomeSource, 'income_source');
      expect(DynamicOptionService.typeReminderCategory, 'reminder_category');
      expect(DynamicOptionService.typeTodoCategory, 'todo_category');
      expect(DynamicOptionService.typeBillCategory, 'bill_category');
      expect(DynamicOptionService.typeDocumentCategory, 'document_category');
      expect(DynamicOptionService.typeTripCategory, 'trip_category');
    });
  });
}
