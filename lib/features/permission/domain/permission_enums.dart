enum PermissionType {
  lateArrival,
  earlyDeparture,
  personalWork,
  other;

  String get label {
    switch (this) {
      case PermissionType.lateArrival:
        return 'Late Arrival';
      case PermissionType.earlyDeparture:
        return 'Early Departure';
      case PermissionType.personalWork:
        return 'Personal Work';
      case PermissionType.other:
        return 'Other';
    }
  }

  static PermissionType fromString(String value) {
    switch (value.trim().toLowerCase()) {
      case 'late arrival':
      case 'latearrival':
        return PermissionType.lateArrival;
      case 'early departure':
      case 'earlydeparture':
        return PermissionType.earlyDeparture;
      case 'personal work':
      case 'personalwork':
        return PermissionType.personalWork;
      default:
        return PermissionType.other;
    }
  }
}

enum PermissionStatus {
  draft,
  pending,
  approved,
  rejected,
  cancelled,
  emergencyPending;

  String get label {
    switch (this) {
      case PermissionStatus.draft:
        return 'Draft';
      case PermissionStatus.pending:
        return 'Pending';
      case PermissionStatus.approved:
        return 'Approved';
      case PermissionStatus.rejected:
        return 'Rejected';
      case PermissionStatus.cancelled:
        return 'Cancelled';
      case PermissionStatus.emergencyPending:
        return 'Emergency Pending';
    }
  }

  static PermissionStatus fromString(String value) {
    switch (value.trim().toLowerCase()) {
      case 'draft':
        return PermissionStatus.draft;
      case 'pending':
        return PermissionStatus.pending;
      case 'approved':
        return PermissionStatus.approved;
      case 'rejected':
        return PermissionStatus.rejected;
      case 'cancelled':
        return PermissionStatus.cancelled;
      case 'emergencypending':
      case 'emergency_pending':
      case 'emergency pending':
        return PermissionStatus.emergencyPending;
      default:
        return PermissionStatus.pending;
    }
  }
}

enum PayrollTreatment {
  paid,
  lop,
  unspecified;

  String get label {
    switch (this) {
      case PayrollTreatment.paid:
        return 'Paid Permission';
      case PayrollTreatment.lop:
        return 'Loss of Pay (LOP)';
      case PayrollTreatment.unspecified:
        return 'Unspecified';
    }
  }

  static PayrollTreatment fromString(String value) {
    switch (value.trim().toLowerCase()) {
      case 'paid':
        return PayrollTreatment.paid;
      case 'lop':
        return PayrollTreatment.lop;
      default:
        return PayrollTreatment.unspecified;
    }
  }
}
