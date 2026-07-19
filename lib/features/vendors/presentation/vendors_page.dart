import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../screens/vendors/vendors_list_screen.dart';
import '../providers/vendor_providers.dart';

class VendorsPage extends ConsumerWidget {
  const VendorsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendors = ref.watch(vendorsProvider);
    return vendors.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Center(child: Text('Unable to load vendors: $error')),
      data: (rows) => VendorsListScreen(
        vendors: rows
            .map(
              (vendor) => VendorListItem(
                id: vendor.id.toString(),
                name: vendor.name,
                companyName: vendor.companyName,
                email: vendor.email,
                workPhone: vendor.workPhone,
                payables: vendor.payables,
                gstTreatment: vendor.gstTreatment == 'Unregistered Business'
                    ? VendorGstTreatment.unregistered
                    : VendorGstTreatment.registeredRegular,
              ),
            )
            .toList(growable: false),
        onRefresh: () => ref.refresh(vendorsProvider.future),
        onNewVendor: () => context.push('/vendors/new'),
      ),
    );
  }
}
