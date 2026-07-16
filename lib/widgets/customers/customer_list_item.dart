import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../models/customer.dart';

class CustomerListCard extends StatelessWidget {
  const CustomerListCard({required this.customer, required this.selected, required this.onSelected, super.key});
  final Customer customer;
  final bool selected;
  final ValueChanged<bool?> onSelected;

  @override Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: CheckboxListTile(
        value: selected, onChanged: onSelected, controlAffinity: ListTileControlAffinity.leading,
        title: Text(customer.displayName, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.active)),
        subtitle: Padding(padding: const EdgeInsets.only(top: 6), child: Text([customer.companyName, customer.email, customer.workPhone].where((e) => e.isNotEmpty).join('\n'))),
        secondary: Text(money.format(customer.receivables), style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
