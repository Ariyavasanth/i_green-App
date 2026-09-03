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
import '../../features/employee/presentation/my_profile_page.dart';
import '../../features/employee/domain/employee.dart';
import '../../features/employee/presentation/employee_registration_page.dart';
import '../../features/leave/presentation/leave_page.dart';
import '../../features/leave/presentation/leave_management_page.dart';
import '../../features/attendance/presentation/attendance_page.dart';
import '../../features/attendance_management/presentation/attendance_management_page.dart';
import '../../features/attendance_settings/presentation/attendance_settings_page.dart';
import '../../features/task_management/presentation/task_board_page.dart';
import '../../features/task_management/presentation/my_tasks_page.dart';
import '../../features/time_clocking/presentation/time_clocking_page.dart';
import '../../features/site_visit_attendance/presentation/site_visit_attendance_page.dart';
import '../../features/site_visit_attendance_management/presentation/site_visit_attendance_management_page.dart';
import '../../features/asset_settings/presentation/asset_settings_page.dart';
import '../../features/salary_settings/presentation/salary_settings_page.dart';
import '../../features/asset_management/presentation/asset_management_page.dart';
import '../../features/on_duty/presentation/on_duty_page.dart';
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
import '../../features/payroll/presentation/employee_payslip_list_screen.dart';
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
import '../../features/authentication/providers/authentication_providers.dart';
import '../../features/employee/providers/employee_providers.dart';

String? _getRequiredPermissionForPath(String path) {
  if (path == '/home') return 'Home';
  if (path == '/organization-management') return 'Organization Management';
  if (path == '/organization-structure') return 'Organization Structure';
  if (path == '/employee' || path == '/employee-management') return 'Employee Management';
  if (path == '/responses') return 'Responses';
  if (path == '/leave' || path == '/leave-management') return 'Leave Management';
  if (path == '/attendance') return 'Attendance';
  if (path == '/attendance-settings') return 'Attendance Settings';
  if (path == '/attendance-management') return 'Attendance Management';
  if (path == '/on-duty' || path == '/my-on-duty') return 'On-Duty';
  if (path == '/on-duty-management') return 'On-Duty Management';
  if (path == '/my-tasks') return 'My Tasks';
  if (path == '/time-clocking') return 'Time Clocking';
  if (path == '/tasks-and-timesheets') return 'Tasks and Clocking Management';
  if (path == '/site-visit-attendance') return 'Site Visit Attendance';
  if (path == '/site-visit-attendance-management') return 'Site Visit Attendance Management';
  if (path == '/permission') return 'Permission';
  if (path == '/permission-management') return 'Permission Management';
  if (path == '/salary-settings') return 'Salary Settings';
  if (path == '/asset-settings') return 'Asset Settings';
  if (path == '/asset-management') return 'Asset Management';
  if (path == '/my-asset') return 'My Asset';
  if (path == '/loan') return 'Loan';
  if (path == '/loan-management') return 'Loan Management';
  if (path == '/my-exit') return 'My Exit';
  if (path == '/exit-management') return 'Exit Management';
  if (path == '/incentive') return 'Incentive Request';
  if (path == '/incentive-management') return 'Incentive Management';
  if (path == '/my-payslips') return 'My Payslips';
  if (path == '/payroll') return 'Payroll';
  if (path == '/payroll-history') return 'Payroll History';
  if (path == '/payroll-settings') return 'Payroll Settings';
  if (path == '/items') return 'Items';
  if (path == '/inventory-adjustments') return 'Inventory Adjustments';
  if (path == '/customers') return 'Customers';
  if (path == '/quotes') return 'Quotes';
  if (path == '/sales-orders') return 'Sales Orders';
  if (path == '/invoices') return 'Invoices';
  if (path == '/delivery-challans') return 'Delivery Challans';
  if (path == '/payments-received') return 'Payments Received';
  if (path == '/credit-notes') return 'Credit Notes';
  if (path == '/eway-bills') return 'e-Way Bills';
  if (path == '/vendors') return 'Vendors';
  if (path == '/expenses') return 'Expenses';
  if (path == '/purchase-orders') return 'Purchase Orders';
  if (path == '/bills') return 'Bills';
  return null;
}

String _getFirstAllowedPath(Employee emp) {
  if (emp.isSuperAdmin) return '/home';

  const permissionToPath = <String, String>{
    'home': '/home',
    'leave management': '/leave-management',
    'leave': '/leave-management',
    'attendance': '/attendance',
    'attendance management': '/attendance-management',
    'attendance settings': '/attendance-settings',
    'on-duty': '/on-duty',
    'on duty': '/on-duty',
    'my on-duty': '/on-duty',
    'on-duty management': '/on-duty-management',
    'my tasks': '/my-tasks',
    'time clocking': '/time-clocking',
    'clocking': '/time-clocking',
    'tasks and clocking management': '/tasks-and-timesheets',
    'tasks & timesheets': '/tasks-and-timesheets',
    'tasks and timesheets': '/tasks-and-timesheets',
    'site visit attendance': '/site-visit-attendance',
    'site visit attendance management': '/site-visit-attendance-management',
    'employee management': '/employee-management',
    'responses': '/responses',
    'permission': '/permission',
    'permission management': '/permission-management',
    'salary settings': '/salary-settings',
    'asset settings': '/asset-settings',
    'asset management': '/asset-management',
    'my asset': '/my-asset',
    'loan': '/loan',
    'loan management': '/loan-management',
    'my exit': '/my-exit',
    'exit management': '/exit-management',
    'incentive request': '/incentive',
    'incentive management': '/incentive-management',
    'my payslips': '/my-payslips',
    'payroll': '/payroll',
    'payroll history': '/payroll-history',
    'payroll settings': '/payroll-settings',
    'organization management': '/organization-management',
    'organization structure': '/organization-structure',
    'items': '/items',
    'inventory adjustments': '/inventory-adjustments',
    'customers': '/customers',
    'quotes': '/quotes',
    'sales orders': '/sales-orders',
    'invoices': '/invoices',
    'delivery challans': '/delivery-challans',
    'payments received': '/payments-received',
    'credit notes': '/credit-notes',
    'e-way bills': '/eway-bills',
    'vendors': '/vendors',
    'expenses': '/expenses',
    'purchase orders': '/purchase-orders',
    'bills': '/bills',
  };

  for (final entry in permissionToPath.entries) {
    if (emp.hasPermission(entry.key)) {
      return entry.value;
    }
  }

  return '/login';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      final path = state.uri.path;
      if (path == '/login' || path.startsWith('/employee/register')) {
        return null;
      }

      final emailOrId = ref.read(currentUserEmailProvider);
      if (emailOrId == null || emailOrId.trim().isEmpty) {
        return '/login';
      }

      final currentEmp = ref.read(currentEmployeeProvider);
      if (currentEmp == null) return null;

      // Super Admin has unrestricted access to all routes
      if (currentEmp.isSuperAdmin) return null;

      final requiredPerm = _getRequiredPermissionForPath(path);
      if (requiredPerm != null && !currentEmp.hasPermission(requiredPerm)) {
        final fallback = _getFirstAllowedPath(currentEmp);
        if (fallback != path) {
          return fallback;
        }
      }

      return null;
    },
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
          GoRoute(path: '/my-profile', builder: (_, _) => const MyProfilePage()),
          GoRoute(path: '/profile', builder: (_, _) => const MyProfilePage()),
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
            path: '/time-clocking',
            builder: (_, _) => const TimeClockingPage(),
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
                builder: (_, state) {
                  final extra = state.extra as Map<String, dynamic>?;
                  return ApplyPermissionPage(
                    initialFromTime: extra?['fromTime'] as TimeOfDay?,
                    initialToTime: extra?['toTime'] as TimeOfDay?,
                  );
                },
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
            path: '/on-duty',
            builder: (_, _) => const OnDutyPage(),
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
            path: '/my-payslips',
            builder: (_, _) => const EmployeePayslipListScreen(),
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
                builder: (context, state) {
                  final extraMap = state.extra as Map<String, dynamic>?;
                  final stockEntry = extraMap?['stockEntry'] as StockEntry?;
                  final readOnly = extraMap?['readOnly'] as bool? ?? (stockEntry != null);
                  return AddStockPage(stockEntry: stockEntry, readOnly: readOnly);
                },
              ),
              GoRoute(
                path: 'add-material',
                builder: (context, state) {
                  final extraMap = state.extra as Map<String, dynamic>?;
                  final material = extraMap?['material'] as MaterialItem?;
                  final readOnly = extraMap?['readOnly'] as bool? ?? (material != null);
                  return AddMaterialPage(material: material, readOnly: readOnly);
                },
              ),
              GoRoute(
                path: 'move-stock',
                builder: (_, _) => const MoveStockPage(),
              ),
              GoRoute(
                path: 'history',
                builder: (_, _) => const FullInventoryHistoryPage(),
              ),
              GoRoute(
                path: 'requests',
                builder: (_, _) => const MaterialRequestsPage(),
              ),
              GoRoute(
                path: 'request-material',
                builder: (_, _) => const RequestMaterialPage(),
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
