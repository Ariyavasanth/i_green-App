import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../screens/vendors/new_vendor_form.dart';
import '../../../screens/vendors/vendors_list_screen.dart';
import '../domain/vendor.dart';
import '../providers/vendor_providers.dart';

class VendorsPage extends ConsumerWidget {
  const VendorsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendorsState = ref.watch(vendorsProvider);
    return vendorsState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Center(child: Text('Unable to load vendors: $error')),
      data: (rows) {
        final itemMap = <String, Vendor>{};
        for (final v in rows) {
          itemMap[v.id.toString()] = v;
        }

        return VendorsListScreen(
          vendors: rows
              .map(
                (vendor) => VendorListItem(
                  id: vendor.id.toString(),
                  vendorCode: vendor.vendorCode,
                  name: vendor.name,
                  companyName: vendor.companyName,
                  email: vendor.email,
                  workPhone: vendor.workPhone,
                  status: vendor.status,
                  payables: vendor.payables,
                  gstTreatment: vendor.gstTreatment == 'Unregistered Business'
                      ? VendorGstTreatment.unregistered
                      : VendorGstTreatment.registeredRegular,
                ),
              )
              .toList(growable: false),
          onRefresh: () => ref.refresh(vendorsProvider.future),
          onNewVendor: () => context.push('/vendors/new'),
          onVendorTap: (item) {
            final vendor = itemMap[item.id];
            if (vendor != null) {
              _openEditModal(context, ref, vendor);
            }
          },
          onVendorAction: (item, action) async {
            final vendor = itemMap[item.id];
            if (vendor == null) return;

            if (action == 'edit' || action == 'view') {
              _openEditModal(context, ref, vendor);
            } else if (action == 'delete') {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Vendor'),
                  content: Text('Are you sure you want to delete "${vendor.displayName}"?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await ref.read(vendorRepositoryProvider).deleteVendor(vendor.id);
                ref.refresh(vendorsProvider);
                ref.refresh(activeVendorsProvider);
              }
            }
          },
        );
      },
    );
  }

  void _openEditModal(BuildContext context, WidgetRef ref, Vendor vendor) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NewVendorForm(vendorToEdit: vendor),
      ),
    );
  }
}
