class RestorationIncidentItem {
  final String incidentId;
  final DateTime incidentDate;
  final String remarks;
  final double restorationCost;
  final List<String> photoUrls;

  const RestorationIncidentItem({
    required this.incidentId,
    required this.incidentDate,
    required this.remarks,
    required this.restorationCost,
    this.photoUrls = const [],
  });

  Map<String, dynamic> toJson() => {
        'incident_id': incidentId,
        'incident_date': incidentDate.toIso8601String(),
        'remarks': remarks,
        'restoration_cost': restorationCost,
        'photo_urls': photoUrls,
      };

  factory RestorationIncidentItem.fromJson(Map<String, dynamic> json) =>
      RestorationIncidentItem(
        incidentId: json['incident_id'] as String? ?? '',
        incidentDate: json['incident_date'] != null
            ? DateTime.tryParse(json['incident_date'].toString()) ?? DateTime.now()
            : DateTime.now(),
        remarks: json['remarks'] as String? ?? '',
        restorationCost: (json['restoration_cost'] as num?)?.toDouble() ?? 0.0,
        photoUrls: (json['photo_urls'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      );
}

class ProjectIncentiveRecord {
  final String id;
  final String projectId;
  final String projectCode;
  final String projectName;
  final String clientName;
  final List<String> assignedEmployeeNames;
  final List<String> assignedEmployeeIds;
  final String division;
  final double contractValue;

  // 1. Daily Progress Details
  final double totalQuantityTarget;
  final double approvedQuantityDone;
  final String unit;
  final int approvedEntriesCount;
  final double baseProgressIncentive;
  final double progressCompletionPercentage;

  // 2. Timely Bill Submission Details
  final bool isBillSubmitted;
  final String flowOfBillsStatus;
  final DateTime? billTargetDate;
  final DateTime? billSubmissionDate;
  final bool isBillTimely;
  final double billTimelinessMultiplier; // e.g. 1.10 for on-time, 0.85 for delayed
  final double timelyBillAdjustmentAmount;

  // 3. Payment Collection Details
  final double paymentCollectedAmount;
  final double paymentCollectionPercentage;
  final double paymentCollectionFactor; // e.g. 1.0 or pro-rata based on threshold
  final double paymentCollectionAdjustmentAmount;

  // 4. Incident & Disqualification Engine
  final int incidentCount;
  final bool isDisqualified;
  final String disqualificationReason;
  final DateTime? disqualificationDate;

  // 5. Track Restoration Costs Separately (Dedicated damage tracking)
  final double totalRestorationCost;
  final List<RestorationIncidentItem> restorationIncidents;

  // 6. Final Calculation Summary
  final double grossEarnedIncentive;
  final double netPayableIncentive; // 0.0 if disqualified, else gross
  final String status; // 'ELIGIBLE', 'DISQUALIFIED', 'ON_HOLD', 'PAID'
  final DateTime calculatedAt;
  final String remarks;

  const ProjectIncentiveRecord({
    required this.id,
    required this.projectId,
    required this.projectCode,
    required this.projectName,
    required this.clientName,
    this.assignedEmployeeNames = const [],
    this.assignedEmployeeIds = const [],
    this.division = '',
    this.contractValue = 0.0,
    // Daily progress
    this.totalQuantityTarget = 0.0,
    this.approvedQuantityDone = 0.0,
    this.unit = 'metres',
    this.approvedEntriesCount = 0,
    this.baseProgressIncentive = 0.0,
    this.progressCompletionPercentage = 0.0,
    // Timely bill submission
    this.isBillSubmitted = false,
    this.flowOfBillsStatus = '',
    this.billTargetDate,
    this.billSubmissionDate,
    this.isBillTimely = false,
    this.billTimelinessMultiplier = 1.0,
    this.timelyBillAdjustmentAmount = 0.0,
    // Payment collection
    this.paymentCollectedAmount = 0.0,
    this.paymentCollectionPercentage = 0.0,
    this.paymentCollectionFactor = 1.0,
    this.paymentCollectionAdjustmentAmount = 0.0,
    // Disqualification
    this.incidentCount = 0,
    this.isDisqualified = false,
    this.disqualificationReason = '',
    this.disqualificationDate,
    // Restoration costs tracked separately
    this.totalRestorationCost = 0.0,
    this.restorationIncidents = const [],
    // Final
    this.grossEarnedIncentive = 0.0,
    this.netPayableIncentive = 0.0,
    this.status = 'ELIGIBLE',
    required this.calculatedAt,
    this.remarks = '',
  });

  bool get hasRestorationCosts => totalRestorationCost > 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'project_id': projectId,
        'project_code': projectCode,
        'project_name': projectName,
        'client_name': clientName,
        'assigned_employee_names': assignedEmployeeNames,
        'assigned_employee_ids': assignedEmployeeIds,
        'division': division,
        'contract_value': contractValue,
        'total_quantity_target': totalQuantityTarget,
        'approved_quantity_done': approvedQuantityDone,
        'unit': unit,
        'approved_entries_count': approvedEntriesCount,
        'base_progress_incentive': baseProgressIncentive,
        'progress_completion_percentage': progressCompletionPercentage,
        'is_bill_submitted': isBillSubmitted,
        'flow_of_bills_status': flowOfBillsStatus,
        'bill_target_date': billTargetDate?.toIso8601String(),
        'bill_submission_date': billSubmissionDate?.toIso8601String(),
        'is_bill_timely': isBillTimely,
        'bill_timeliness_multiplier': billTimelinessMultiplier,
        'timely_bill_adjustment_amount': timelyBillAdjustmentAmount,
        'payment_collected_amount': paymentCollectedAmount,
        'payment_collection_percentage': paymentCollectionPercentage,
        'payment_collection_factor': paymentCollectionFactor,
        'payment_collection_adjustment_amount': paymentCollectionAdjustmentAmount,
        'incident_count': incidentCount,
        'is_disqualified': isDisqualified,
        'disqualification_reason': disqualificationReason,
        'disqualification_date': disqualificationDate?.toIso8601String(),
        'total_restoration_cost': totalRestorationCost,
        'restoration_incidents':
            restorationIncidents.map((i) => i.toJson()).toList(),
        'gross_earned_incentive': grossEarnedIncentive,
        'net_payable_incentive': netPayableIncentive,
        'status': status,
        'calculated_at': calculatedAt.toIso8601String(),
        'remarks': remarks,
      };

  factory ProjectIncentiveRecord.fromJson(Map<String, dynamic> json, [String? docId]) =>
      ProjectIncentiveRecord(
        id: docId ?? json['id'] as String? ?? '',
        projectId: json['project_id'] as String? ?? '',
        projectCode: json['project_code'] as String? ?? '',
        projectName: json['project_name'] as String? ?? '',
        clientName: json['client_name'] as String? ?? '',
        assignedEmployeeNames: (json['assigned_employee_names'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        assignedEmployeeIds: (json['assigned_employee_ids'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        division: json['division'] as String? ?? '',
        contractValue: (json['contract_value'] as num?)?.toDouble() ?? 0.0,
        totalQuantityTarget: (json['total_quantity_target'] as num?)?.toDouble() ?? 0.0,
        approvedQuantityDone:
            (json['approved_quantity_done'] as num?)?.toDouble() ?? 0.0,
        unit: json['unit'] as String? ?? 'metres',
        approvedEntriesCount:
            (json['approved_entries_count'] as num?)?.toInt() ?? 0,
        baseProgressIncentive:
            (json['base_progress_incentive'] as num?)?.toDouble() ?? 0.0,
        progressCompletionPercentage:
            (json['progress_completion_percentage'] as num?)?.toDouble() ?? 0.0,
        isBillSubmitted: json['is_bill_submitted'] as bool? ?? false,
        flowOfBillsStatus: json['flow_of_bills_status'] as String? ?? '',
        billTargetDate: json['bill_target_date'] != null
            ? DateTime.tryParse(json['bill_target_date'].toString())
            : null,
        billSubmissionDate: json['bill_submission_date'] != null
            ? DateTime.tryParse(json['bill_submission_date'].toString())
            : null,
        isBillTimely: json['is_bill_timely'] as bool? ?? false,
        billTimelinessMultiplier:
            (json['bill_timeliness_multiplier'] as num?)?.toDouble() ?? 1.0,
        timelyBillAdjustmentAmount:
            (json['timely_bill_adjustment_amount'] as num?)?.toDouble() ?? 0.0,
        paymentCollectedAmount:
            (json['payment_collected_amount'] as num?)?.toDouble() ?? 0.0,
        paymentCollectionPercentage:
            (json['payment_collection_percentage'] as num?)?.toDouble() ?? 0.0,
        paymentCollectionFactor:
            (json['payment_collection_factor'] as num?)?.toDouble() ?? 1.0,
        paymentCollectionAdjustmentAmount:
            (json['payment_collection_adjustment_amount'] as num?)?.toDouble() ?? 0.0,
        incidentCount: (json['incident_count'] as num?)?.toInt() ?? 0,
        isDisqualified: json['is_disqualified'] as bool? ?? false,
        disqualificationReason: json['disqualification_reason'] as String? ?? '',
        disqualificationDate: json['disqualification_date'] != null
            ? DateTime.tryParse(json['disqualification_date'].toString())
            : null,
        totalRestorationCost:
            (json['total_restoration_cost'] as num?)?.toDouble() ?? 0.0,
        restorationIncidents: (json['restoration_incidents'] as List?)
                ?.map((e) =>
                    RestorationIncidentItem.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        grossEarnedIncentive:
            (json['gross_earned_incentive'] as num?)?.toDouble() ?? 0.0,
        netPayableIncentive:
            (json['net_payable_incentive'] as num?)?.toDouble() ?? 0.0,
        status: json['status'] as String? ?? 'ELIGIBLE',
        calculatedAt: json['calculated_at'] != null
            ? DateTime.tryParse(json['calculated_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
        remarks: json['remarks'] as String? ?? '',
      );

  ProjectIncentiveRecord copyWith({
    String? id,
    String? projectId,
    String? projectCode,
    String? projectName,
    String? clientName,
    List<String>? assignedEmployeeNames,
    List<String>? assignedEmployeeIds,
    String? division,
    double? contractValue,
    double? totalQuantityTarget,
    double? approvedQuantityDone,
    String? unit,
    int? approvedEntriesCount,
    double? baseProgressIncentive,
    double? progressCompletionPercentage,
    bool? isBillSubmitted,
    String? flowOfBillsStatus,
    DateTime? billTargetDate,
    DateTime? billSubmissionDate,
    bool? isBillTimely,
    double? billTimelinessMultiplier,
    double? timelyBillAdjustmentAmount,
    double? paymentCollectedAmount,
    double? paymentCollectionPercentage,
    double? paymentCollectionFactor,
    double? paymentCollectionAdjustmentAmount,
    int? incidentCount,
    bool? isDisqualified,
    String? disqualificationReason,
    DateTime? disqualificationDate,
    double? totalRestorationCost,
    List<RestorationIncidentItem>? restorationIncidents,
    double? grossEarnedIncentive,
    double? netPayableIncentive,
    String? status,
    DateTime? calculatedAt,
    String? remarks,
  }) {
    return ProjectIncentiveRecord(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      projectCode: projectCode ?? this.projectCode,
      projectName: projectName ?? this.projectName,
      clientName: clientName ?? this.clientName,
      assignedEmployeeNames: assignedEmployeeNames ?? this.assignedEmployeeNames,
      assignedEmployeeIds: assignedEmployeeIds ?? this.assignedEmployeeIds,
      division: division ?? this.division,
      contractValue: contractValue ?? this.contractValue,
      totalQuantityTarget: totalQuantityTarget ?? this.totalQuantityTarget,
      approvedQuantityDone: approvedQuantityDone ?? this.approvedQuantityDone,
      unit: unit ?? this.unit,
      approvedEntriesCount: approvedEntriesCount ?? this.approvedEntriesCount,
      baseProgressIncentive: baseProgressIncentive ?? this.baseProgressIncentive,
      progressCompletionPercentage:
          progressCompletionPercentage ?? this.progressCompletionPercentage,
      isBillSubmitted: isBillSubmitted ?? this.isBillSubmitted,
      flowOfBillsStatus: flowOfBillsStatus ?? this.flowOfBillsStatus,
      billTargetDate: billTargetDate ?? this.billTargetDate,
      billSubmissionDate: billSubmissionDate ?? this.billSubmissionDate,
      isBillTimely: isBillTimely ?? this.isBillTimely,
      billTimelinessMultiplier:
          billTimelinessMultiplier ?? this.billTimelinessMultiplier,
      timelyBillAdjustmentAmount:
          timelyBillAdjustmentAmount ?? this.timelyBillAdjustmentAmount,
      paymentCollectedAmount:
          paymentCollectedAmount ?? this.paymentCollectedAmount,
      paymentCollectionPercentage:
          paymentCollectionPercentage ?? this.paymentCollectionPercentage,
      paymentCollectionFactor:
          paymentCollectionFactor ?? this.paymentCollectionFactor,
      paymentCollectionAdjustmentAmount:
          paymentCollectionAdjustmentAmount ?? this.paymentCollectionAdjustmentAmount,
      incidentCount: incidentCount ?? this.incidentCount,
      isDisqualified: isDisqualified ?? this.isDisqualified,
      disqualificationReason:
          disqualificationReason ?? this.disqualificationReason,
      disqualificationDate: disqualificationDate ?? this.disqualificationDate,
      totalRestorationCost: totalRestorationCost ?? this.totalRestorationCost,
      restorationIncidents: restorationIncidents ?? this.restorationIncidents,
      grossEarnedIncentive: grossEarnedIncentive ?? this.grossEarnedIncentive,
      netPayableIncentive: netPayableIncentive ?? this.netPayableIncentive,
      status: status ?? this.status,
      calculatedAt: calculatedAt ?? this.calculatedAt,
      remarks: remarks ?? this.remarks,
    );
  }
}
