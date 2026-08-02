import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/app_shell/presentation/app_shell.dart';
import '../../features/app_shell/presentation/section_page.dart';
import '../../features/books/domain/books_repository.dart';
import '../../features/books/presentation/books_forms.dart';
import '../../features/books/presentation/books_pages.dart';
import '../../features/books/presentation/inventory_adjustments_page.dart';
import '../../features/books/presentation/add_stock_page.dart';
import '../../features/books/presentation/add_material_page.dart';
import '../../features/books/presentation/move_stock_page.dart';
import '../../features/books/presentation/request_material_page.dart';
import '../../features/books/presentation/return_material_page.dart';
import '../../features/quotes/presentation/quote_form_screen.dart';
import '../../features/vendors/presentation/vendors_page.dart';
import '../../features/expenses/presentation/expenses_page.dart';
import '../../features/purchase_orders/presentation/new_purchase_order_page.dart';
import '../../features/purchase_orders/presentation/purchase_orders_page.dart';
import '../../features/bills/presentation/bills_page.dart';
import '../../features/bills/presentation/new_bill_page.dart';
import '../../features/organization/presentation/organization_management_page.dart';
import '../../features/organization/presentation/organization_structure_page.dart';
import '../../features/employee/presentation/responses_page.dart';
import '../../features/employee/presentation/employee_management_page.dart';
import '../../features/employee/domain/employee.dart';
import '../../features/employee/presentation/employee_registration_page.dart';
import '../../features/leave/presentation/leave_page.dart';
import '../../features/leave/presentation/leave_management_page.dart';
import '../../features/attendance/presentation/attendance_page.dart';
import '../../features/attendance_management/presentation/attendance_management_page.dart';
import '../../features/attendance_settings/presentation/attendance_settings_page.dart';
import '../../features/face_registration/presentation/face_registration_page.dart';
import '../../features/asset_settings/presentation/asset_settings_page.dart';
import '../../features/asset_management/presentation/asset_management_page.dart';
import '../../screens/login_screen.dart';
import '../../screens/customers/active_customers_list.dart';
import '../../screens/customers/new_customer_form.dart';
import '../../screens/vendors/new_vendor_form.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/employee/register/:linkId',
        builder: (_, state) {
          final rawAcceptedId = state.uri.queryParameters['acceptedId'];
          final acceptedEmpId = rawAcceptedId != null ? int.tryParse(rawAcceptedId) : null;
          final acceptedLinkId = state.uri.queryParameters['acceptedLinkId'];
          return EmployeeRegistrationPage(
            linkId: state.pathParameters['linkId'] ?? '',
            employee: state.extra is Employee ? state.extra as Employee : null,
            acceptedEmpId: acceptedEmpId,
            acceptedLinkId: acceptedLinkId,
          );
        },
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(currentLocation: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const HomePage()),
          GoRoute(
            path: '/organization-management',
            builder: (_, _) => const OrganizationManagementPage(),
          ),
          GoRoute(
            path: '/organization-structure',
            builder: (_, _) => const OrganizationStructurePage(),
          ),
          GoRoute(
            path: '/employee',
            builder: (_, _) => const EmployeeManagementPage(),
          ),
          GoRoute(
            path: '/employee-management',
            builder: (_, _) => const EmployeeManagementPage(),
          ),
          GoRoute(
            path: '/responses',
            builder: (_, _) => const ResponsesPage(),
          ),
          GoRoute(
            path: '/leave',
            builder: (_, _) => const LeavePage(),
          ),
          GoRoute(
            path: '/attendance',
            builder: (_, _) => const AttendancePage(),
          ),
          GoRoute(
            path: '/attendance-settings',
            builder: (_, _) => const AttendanceSettingsPage(),
          ),
          GoRoute(
            path: '/face-registration',
            builder: (_, _) => const FaceRegistrationPage(),
          ),
          GoRoute(
            path: '/attendance-management',
            builder: (_, _) => const AttendanceManagementPage(),
          ),
          GoRoute(
            path: '/leave-management',
            builder: (_, _) => const LeaveManagementPage(),
          ),
          GoRoute(
            path: '/asset-settings',
            builder: (_, _) => const AssetSettingsPage(),
          ),
          GoRoute(
            path: '/asset-management',
            builder: (_, _) => const AssetManagementPage(),
          ),
          GoRoute(
            path: '/loan',
            builder: (_, _) => const SectionPage(title: 'Loan'),
          ),
          GoRoute(
            path: '/pay-slip',
            builder: (_, _) => const SectionPage(title: 'Pay Slip'),
          ),
          GoRoute(
            path: '/items',
            builder: (_, _) => const ItemsPage(),
            routes: [
              GoRoute(path: 'new', builder: (_, _) => const NewItemPage()),
              GoRoute(
                path: 'request-material',
                builder: (_, _) => const RequestMaterialPage(),
              ),
              GoRoute(
                path: 'return',
                builder: (_, _) => const ReturnMaterialPage(),
              ),
            ],
          ),
          GoRoute(
            path: '/customers',
            builder: (_, _) => const ActiveCustomersList(),
            routes: [
              GoRoute(path: 'new', builder: (_, _) => const NewCustomerForm()),
            ],
          ),
          GoRoute(
            path: '/quotes',
            builder: (_, _) =>
                const TransactionsPage(type: TransactionType.quote),
            routes: [
              GoRoute(path: 'new', builder: (_, _) => const QuoteFormScreen()),
            ],
          ),
          GoRoute(
            path: '/sales-orders',
            builder: (_, _) =>
                const TransactionsPage(type: TransactionType.salesOrder),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, _) =>
                    const NewTransactionPage(type: TransactionType.salesOrder),
              ),
            ],
          ),
          GoRoute(
            path: '/invoices',
            builder: (_, _) =>
                const TransactionsPage(type: TransactionType.invoice),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, _) =>
                    const NewTransactionPage(type: TransactionType.invoice),
              ),
            ],
          ),
          GoRoute(
            path: '/delivery-challans',
            builder: (_, _) => const SectionPage(title: 'Delivery Challans'),
          ),
          GoRoute(
            path: '/payments-received',
            builder: (_, _) => const SectionPage(title: 'Payments Received'),
          ),
          GoRoute(
            path: '/credit-notes',
            builder: (_, _) => const SectionPage(title: 'Credit Notes'),
          ),
          GoRoute(
            path: '/e-way-bills',
            builder: (_, _) => const SectionPage(title: 'e-Way Bills'),
          ),
          GoRoute(
            path: '/vendors',
            builder: (_, _) => const VendorsPage(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, _) => const NewVendorForm(),
              ),
            ],
          ),
          GoRoute(
            path: '/expenses',
            builder: (_, _) => const ExpensesPage(),
          ),
          GoRoute(
            path: '/purchase-orders',
            builder: (_, _) => const PurchaseOrdersPage(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, _) => const NewPurchaseOrderPage(),
              ),
            ],
          ),
          GoRoute(
            path: '/bills',
            builder: (_, _) => const BillsPage(),
            routes: [
              GoRoute(path: 'new', builder: (_, _) => const NewBillPage()),
            ],
          ),
          GoRoute(
            path: '/inventory-adjustments',
            builder: (_, _) => const InventoryAdjustmentDashboardPage(),
            routes: [
              GoRoute(
                path: 'add-stock',
                builder: (_, _) => const AddStockPage(),
              ),
              GoRoute(
                path: 'add-material',
                builder: (_, _) => const AddMaterialPage(),
              ),
              GoRoute(
                path: 'move-stock',
                builder: (_, _) => const MoveStockPage(),
              ),
              GoRoute(
                path: 'new',
                builder: (_, _) => const NewAdjustmentPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
