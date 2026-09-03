/// Centralized App Permissions definitions for production-ready
/// Granular Permission-Based Access Control (PBAC / RBAC).
class AppPermissions {
  AppPermissions._();

  // Overview
  static const String home = 'Home';

  // Organization
  static const String organizationManagement = 'Organization Management';
  static const String organizationStructure = 'Organization Structure';

  // Employee
  static const String employeeManagement = 'Employee Management';
  static const String responses = 'Responses';

  // Attendance & Time Tracking
  static const String attendance = 'Attendance';
  static const String attendanceManagement = 'Attendance Management';
  static const String attendanceSettings = 'Attendance Settings';
  static const String onDuty = 'On-Duty';
  static const String onDutyManagement = 'On-Duty Management';
  static const String siteVisitAttendance = 'Site Visit Attendance';
  static const String siteVisitAttendanceManagement = 'Site Visit Attendance Management';

  // Task Management
  static const String myTasks = 'My Tasks';
  static const String timeClocking = 'Time Clocking';
  static const String tasksAndClockingManagement = 'Tasks and Clocking Management';

  // Leave & Permissions
  static const String leaveManagement = 'Leave Management';
  static const String permission = 'Permission';
  static const String permissionManagement = 'Permission Management';

  // Compensation, Assets & HR
  static const String salarySettings = 'Salary Settings';
  static const String assetSettings = 'Asset Settings';
  static const String assetManagement = 'Asset Management';
  static const String myAsset = 'My Asset';
  static const String loan = 'Loan';
  static const String loanManagement = 'Loan Management';
  static const String incentiveRequest = 'Incentive Request';
  static const String incentiveManagement = 'Incentive Management';
  static const String myExit = 'My Exit';
  static const String exitManagement = 'Exit Management';
  static const String myPayslips = 'My Payslips';
  static const String payroll = 'Payroll';
  static const String payrollHistory = 'Payroll History';
  static const String payrollSettings = 'Payroll Settings';

  // Inventory & Stock
  static const String items = 'Items';
  static const String inventoryAdjustments = 'Inventory Adjustments';

  // Sales
  static const String customers = 'Customers';
  static const String quotes = 'Quotes';
  static const String salesOrders = 'Sales Orders';
  static const String invoices = 'Invoices';
  static const String deliveryChallans = 'Delivery Challans';
  static const String paymentsReceived = 'Payments Received';
  static const String creditNotes = 'Credit Notes';
  static const String ewayBills = 'e-Way Bills';

  // Purchase
  static const String vendors = 'Vendors';
  static const String expenses = 'Expenses';
  static const String purchaseOrders = 'Purchase Orders';
  static const String bills = 'Bills';

  /// Complete list of all system permissions.
  static const List<String> allPermissions = [
    home,
    organizationManagement,
    organizationStructure,
    responses,
    employeeManagement,
    attendance,
    attendanceManagement,
    attendanceSettings,
    onDuty,
    onDutyManagement,
    myTasks,
    timeClocking,
    tasksAndClockingManagement,
    siteVisitAttendance,
    siteVisitAttendanceManagement,
    leaveManagement,
    permission,
    permissionManagement,
    salarySettings,
    assetSettings,
    assetManagement,
    myAsset,
    loan,
    incentiveRequest,
    incentiveManagement,
    myExit,
    exitManagement,
    myPayslips,
    payroll,
    payrollHistory,
    payrollSettings,
    loanManagement,
    items,
    inventoryAdjustments,
    customers,
    quotes,
    salesOrders,
    invoices,
    deliveryChallans,
    paymentsReceived,
    creditNotes,
    ewayBills,
    vendors,
    expenses,
    purchaseOrders,
    bills,
  ];

  /// Categorized permissions for User Management & Permissions UI.
  static const Map<String, List<String>> permissionsByCategory = {
    'OVERVIEW': [
      home,
    ],
    'ORGANIZATION': [
      organizationManagement,
      organizationStructure,
    ],
    'EMPLOYEE MANAGEMENT': [
      employeeManagement,
      responses,
    ],
    'ATTENDANCE & TIME CLOCKING': [
      attendance,
      attendanceManagement,
      attendanceSettings,
      onDuty,
      onDutyManagement,
      siteVisitAttendance,
      siteVisitAttendanceManagement,
    ],
    'TASK MANAGEMENT': [
      myTasks,
      timeClocking,
      tasksAndClockingManagement,
    ],
    'LEAVE & PERMISSIONS': [
      leaveManagement,
      permission,
      permissionManagement,
    ],
    'PAYROLL & COMPENSATION': [
      payroll,
      payrollHistory,
      payrollSettings,
      myPayslips,
      salarySettings,
    ],
    'ASSETS & LOANS': [
      assetManagement,
      myAsset,
      assetSettings,
      loan,
      loanManagement,
      incentiveRequest,
      incentiveManagement,
      myExit,
      exitManagement,
    ],
    'INVENTORY': [
      items,
      inventoryAdjustments,
    ],
    'SALES': [
      customers,
      quotes,
      salesOrders,
      invoices,
      deliveryChallans,
      paymentsReceived,
      creditNotes,
      ewayBills,
    ],
    'PURCHASE & EXPENSES': [
      vendors,
      expenses,
      purchaseOrders,
      bills,
    ],
  };
}
