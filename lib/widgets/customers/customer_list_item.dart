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
    final secondary = [
      if (customer.gstin.isNotEmpty) 'GSTIN: ${customer.gstin}',
      if (customer.placeOfSupply.isNotEmpty) 'Place of supply: ${customer.placeOfSupply}',
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Checkbox(value: selected, onChanged: onSelected, visualDensity: VisualDensity.compact),
          const SizedBox(width: 4),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(customer.displayName, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.active)),
            if (secondary.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(secondary.join('\n'))),
          ])),
          const SizedBox(width: 12),
          Text(money.format(customer.receivables), style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
