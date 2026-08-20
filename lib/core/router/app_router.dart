import 'package:flutter/material.dart';
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
import '../../features/task_management/presentation/task_board_page.dart';
import '../../features/task_management/presentation/my_tasks_page.dart';
import '../../features/site_visit_attendance/presentation/site_visit_attendance_page.dart';
import '../../features/site_visit_attendance_management/presentation/site_visit_attendance_management_page.dart';
import '../../features/asset_settings/presentation/asset_settings_page.dart';
import '../../features/salary_settings/presentation/salary_settings_page.dart';
import '../../features/asset_management/presentation/asset_management_page.dart';
import '../../features/on_duty/presentation/on_duty_management_page.dart';
import '../../features/asset_management/presentation/my_asset_page.dart';
import '../../screens/login_screen.dart';
import '../../screens/customers/active_customers_list.dart';
import '../../screens/customers/new_customer_form.dart';
import '../../screens/vendors/new_vendor_form.dart';
import '../../features/payroll/presentation/payroll_dashboard_screen.dart';
import '../../features/payroll/presentation/payroll_employee_list_screen.dart';
import '../../features/payroll/presentation/generate_payroll_screen.dart';
import '../../features/payroll/presentation/payroll_details_screen.dart';
import '../../features/payroll/presentation/payslip_screen.dart';
import '../../features/payroll/presentation/payroll_history_screen.dart';
import '../../features/payroll/presentation/payroll_settings_screen.dart';
import '../../features/loan/presentation/loan_page.dart';
import '../../features/loan/presentation/loan_management_page.dart';
import '../../features/loan/presentation/create_loan_page.dart';
import '../../features/loan/presentation/loan_details_page.dart';
import '../../features/loan/domain/employee_loan.dart';
import '../../features/exit_management/presentation/exit_management_page.dart';
import '../../features/exit_management/presentation/my_exit_page.dart';
import '../../features/incentive/presentation/incentive_page.dart';
import '../../features/incentive_management/presentation/incentive_management_page.dart';
import '../../features/incentive_management/presentation/incentive_detail_page.dart';
import '../../features/incentive_management/presentation/employee_incentive_requests_page.dart';
import '../../features/permission/domain/permission_enums.dart';
import '../../features/permission/domain/permission_request.dart';
import '../../features/permission/presentation/admin_permission_management_page.dart';
import '../../features/permission/presentation/apply_emergency_permission_page.dart';
import '../../features/permission/presentation/apply_permission_page.dart';
import '../../features/permission/presentation/permission_dashboard_page.dart';
import '../../features/permission/presentation/permission_details_page.dart';

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
            path: '/attendance-management',
            builder: (_, _) => const AttendanceManagementPage(),
          ),
          GoRoute(
            path: '/my-tasks',
            builder: (_, _) => const MyTasksPage(),
          ),
          GoRoute(
            path: '/tasks-and-timesheets',
            builder: (_, state) {
              final action = state.uri.queryParameters['action'];
              final tab = state.uri.queryParameters['tab'];
              int initialTab = 0;
              if (action == 'clock_activity' || tab == '1' || tab == 'clocking') {
                initialTab = 1;
              }
              return TaskBoardPage(initialTab: initialTab);
            },
          ),
          GoRoute(
            path: '/site-visit-attendance',
            builder: (_, _) => const SiteVisitAttendancePage(),
          ),
          GoRoute(
            path: '/site-visit-attendance-management',
            builder: (_, _) => const SiteVisitAttendanceManagementPage(),
          ),
          GoRoute(
            path: '/leave-management',
            builder: (_, _) => const LeaveManagementPage(),
          ),
          GoRoute(
            path: '/permission',
            builder: (_, _) => const PermissionDashboardPage(),
            routes: [
              GoRoute(
                path: 'apply',
                builder: (_, _) => const ApplyPermissionPage(),
              ),
              GoRoute(
                path: 'emergency',
                builder: (_, state) {
                  final extra = state.extra as Map<String, dynamic>?;
                  return ApplyEmergencyPermissionPage(
                    initialDate: extra?['date'] as DateTime?,
                    initialFromTime: extra?['fromTime'] as TimeOfDay?,
                    initialToTime: extra?['toTime'] as TimeOfDay?,
                    initialType: extra?['type'] as PermissionType?,
                  );
                },
              ),
              GoRoute(
                path: 'details',
                builder: (_, state) {
                  final req = state.extra as PermissionRequest;
                  return PermissionDetailsPage(request: req);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/permission-management',
            builder: (_, _) => const AdminPermissionManagementPage(),
          ),
          GoRoute(
            path: '/on-duty-management',
            builder: (_, _) => const OnDutyManagementPage(),
          ),
          GoRoute(
            path: '/asset-settings',
            builder: (_, _) => const AssetSettingsPage(),
          ),
          GoRoute(
            path: '/salary-settings',
            builder: (_, _) => const SalarySettingsPage(),
          ),
          GoRoute(
            path: '/asset-management',
            builder: (_, _) => const AssetManagementPage(),
          ),
          GoRoute(
            path: '/my-asset',
            builder: (_, _) => const MyAssetPage(),
          ),
          GoRoute(
            path: '/loan',
            builder: (_, _) => const LoanPage(),
            routes: [
              GoRoute(
                path: 'details/:loanId',
                builder: (context, state) {
                  final loanIdStr = state.pathParameters['loanId'] ?? '';
                  final id = int.tryParse(loanIdStr) ?? 0;
                  return LoanDetailsPage(loanId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/loan-management',
            builder: (_, _) => const LoanManagementPage(),
            routes: [
              GoRoute(
                path: 'create',
                builder: (context, state) {
                  final extra = state.extra;
                  final editLoan = extra is EmployeeLoan ? extra : null;
                  return CreateLoanPage(loan: editLoan);
                },
              ),
              GoRoute(
                path: 'details/:loanId',
                builder: (context, state) {
                  final loanIdStr = state.pathParameters['loanId'] ?? '';
                  final id = int.tryParse(loanIdStr) ?? 0;
                  return LoanDetailsPage(loanId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/my-exit',
            builder: (_, _) => const MyExitPage(),
          ),
          GoRoute(
            path: '/exit-management',
            builder: (_, _) => const ExitManagementPage(),
          ),
          GoRoute(
            path: '/incentive',
            builder: (_, _) => const IncentivePage(),
          ),
          GoRoute(
            path: '/incentive-management',
            builder: (_, _) => const IncentiveManagementPage(),
            routes: [
              GoRoute(
                path: 'detail/:id',
                builder: (context, state) {
                  final idStr = state.pathParameters['id'] ?? '';
                  final id = int.tryParse(idStr) ?? 0;
                  return IncentiveDetailPage(requestId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/incentive-management/detail/:id',
            builder: (context, state) {
              final idStr = state.pathParameters['id'] ?? '';
              final id = int.tryParse(idStr) ?? 0;
              return IncentiveDetailPage(requestId: id);
            },
          ),
          GoRoute(
            path: '/incentive-management/employee-requests',
            builder: (context, state) {
              final employeeIdStr = state.uri.queryParameters['employeeId'];
              final employeeId = (employeeIdStr != null && employeeIdStr.isNotEmpty)
                  ? int.tryParse(employeeIdStr)
                  : null;
              final employeeName = state.uri.queryParameters['employeeName'] ?? '';
              final designation = state.uri.queryParameters['designation'] ?? '';
              final initialStatus = state.uri.queryParameters['status'] ?? 'All';
              return EmployeeIncentiveRequestsPage(
                employeeId: employeeId,
                employeeName: employeeName,
                designation: designation,
                initialStatus: initialStatus,
              );
            },
          ),
          GoRoute(
            path: '/payroll',
            builder: (_, _) => const PayrollDashboardScreen(),
            routes: [
              GoRoute(
                path: 'run',
                builder: (_, _) => const PayrollEmployeeListScreen(),
              ),
              GoRoute(
                path: 'generate/:employeeId',
                builder: (context, state) {
                  final employeeIdStr = state.pathParameters['employeeId'] ?? '';
                  final employeeId = int.tryParse(employeeIdStr) ?? 0;
                  return GeneratePayrollScreen(employeeId: employeeId);
                },
              ),
              GoRoute(
                path: 'details/:payrollId',
                builder: (context, state) {
                  final payrollIdStr = state.pathParameters['payrollId'] ?? '';
                  final payrollId = int.tryParse(payrollIdStr) ?? 0;
                  return PayrollDetailsScreen(payrollId: payrollId);
                },
              ),
              GoRoute(
                path: 'payslip/:payrollId',
                builder: (context, state) {
                  final payrollIdStr = state.pathParameters['payrollId'] ?? '';
                  final payrollId = int.tryParse(payrollIdStr) ?? 0;
                  return PayslipScreen(payrollId: payrollId);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/payroll-history',
            builder: (_, _) => const PayrollHistoryScreen(),
          ),
          GoRoute(
            path: '/payroll-settings',
            builder: (_, _) => const PayrollSettingsScreen(),
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
