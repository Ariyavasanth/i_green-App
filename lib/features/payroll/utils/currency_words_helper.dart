class CurrencyWordsHelper {
  /// Converts a number to Indian Rupees in words (e.g. Fifty-Four Thousand Two Hundred).
  static String formatAmountInWords(double amount) {
    final int val = amount.round();
    if (val <= 0) return 'Zero';

    final units = [
      '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
      'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
      'Seventeen', 'Eighteen', 'Nineteen'
    ];
    final tens = [
      '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
    ];

    String convertChunk(int n) {
      if (n < 20) return units[n];
      if (n < 100) {
        final t = tens[n ~/ 10];
        final u = units[n % 10];
        return u.isEmpty ? t : '$t $u';
      }
      final h = units[n ~/ 100];
      final rem = n % 100;
      if (rem == 0) return '$h Hundred';
      return '$h Hundred ${convertChunk(rem)}';
    }

    int num = val;
    final parts = <String>[];

    final crores = num ~/ 10000000;
    num %= 10000000;

    final lakhs = num ~/ 100000;
    num %= 100000;

    final thousands = num ~/ 1000;
    num %= 1000;

    final remaining = num;

    if (crores > 0) {
      parts.add('${convertChunk(crores)} Crore${crores > 1 ? 's' : ''}');
    }
    if (lakhs > 0) {
      parts.add('${convertChunk(lakhs)} Lakh${lakhs > 1 ? 's' : ''}');
    }
    if (thousands > 0) {
      parts.add('${convertChunk(thousands)} Thousand');
    }
    if (remaining > 0) {
      parts.add(convertChunk(remaining));
    }

    final words = parts.join(' ').trim();
    return words.isEmpty ? 'Zero' : words;
  }
}
