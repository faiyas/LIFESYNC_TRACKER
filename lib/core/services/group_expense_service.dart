class SplitSettlement {
  final String fromPerson;
  final String toPerson;
  final double amount;

  SplitSettlement({
    required this.fromPerson,
    required this.toPerson,
    required this.amount,
  });
}

class GroupExpenseService {
  static List<SplitSettlement> calculateOptimalSettlements(Map<String, double> netBalances) {
    final debtors = <MapEntry<String, double>>[];
    final creditors = <MapEntry<String, double>>[];

    netBalances.forEach((person, balance) {
      if (balance < -0.01) {
        debtors.add(MapEntry(person, -balance));
      } else if (balance > 0.01) {
        creditors.add(MapEntry(person, balance));
      }
    });

    debtors.sort((a, b) => b.value.compareTo(a.value));
    creditors.sort((a, b) => b.value.compareTo(a.value));

    final settlements = <SplitSettlement>[];
    int dIdx = 0;
    int cIdx = 0;

    while (dIdx < debtors.length && cIdx < creditors.length) {
      final debtor = debtors[dIdx];
      final creditor = creditors[cIdx];

      final minAmount = debtor.value < creditor.value ? debtor.value : creditor.value;

      settlements.add(
        SplitSettlement(
          fromPerson: debtor.key,
          toPerson: creditor.key,
          amount: minAmount,
        ),
      );

      debtors[dIdx] = MapEntry(debtor.key, debtor.value - minAmount);
      creditors[cIdx] = MapEntry(creditor.key, creditor.value - minAmount);

      if (debtors[dIdx].value < 0.01) dIdx++;
      if (creditors[cIdx].value < 0.01) cIdx++;
    }

    return settlements;
  }
}
