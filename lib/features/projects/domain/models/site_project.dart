import 'deduction_entry.dart';
import 'project_document.dart';
import 'tender_description_item.dart';

class SiteProject {
  SiteProject({
    this.id = '',
    required this.employeeName,
    this.employeeId,
    required this.clientName,
    this.clientId,
    this.generalDetails = '',
    this.place = '',
    required this.generalCode,
    this.subOrOwn = 'Own',
    this.state = '',
    this.district = '',
    this.area = '',
    required this.projectCode,
    // Section 3 – Tender Type (extended)
    this.tenderType = '',
    this.qualified = '',
    this.tenderCategory = '',
    this.tenderAmount = 0.0,
    this.approximateProjectValue = 0.0,
    this.actualProjectValue = 0.0,
    // Section 4 – Tender Spec / Enquiry Spec
    this.tenderSpecRemark = '',
    this.tenderSpecDocuments = const [],
    // Section 4b – Tender Description
    this.tenderDescriptions = const [],
    // Section 5 – Assigned To
    List<String>? assignedToEmployeeNames,
    List<String>? assignedToEmployeeIds,
    String? assignedToEmployeeName,
    String? assignedToEmployeeId,
    // Section 6 – Opening Date
    this.openingDate,
    this.openingDateRemark = '',
    // Section 7 – Closing Date
    this.closingDate,
    this.closingDateRemark = '',
    // Section 8 – BQR
    this.bqrRemark = '',
    this.bqrDocuments = const [],
    // Section 9 – EMD / EMD Exemption
    this.emdRemark = '',
    this.emdDocuments = const [],
    // Section 10 – Tender Lost
    this.tenderLostRemark = '',
    this.tenderLostStatus = '',
    this.competitorName = '',
    this.quotedAmount = 0.0,
    // Section 11 – SD Date / Bank Guarantee / Bill Deduction
    this.sdDateRemark = '',
    this.sdDateDocuments = const [],
    // Section 12 – BOQ
    this.boqRemark = '',
    this.boqDocuments = const [],
    // Section 13 – Project Details
    this.projectDetailsRemark = '',
    this.projectDetailsDocuments = const [],
    // Section 14 – Work Order / LOA
    this.workOrderRemark = '',
    this.workOrderDocuments = const [],
    // Section 15 – Profile Drawing
    this.profileDrawingRemark = '',
    this.profileDrawingDocuments = const [],
    // Section 16 – Agreement
    this.agreementRemark = '',
    this.agreementDocuments = const [],
    // Section 17 – Supply of Materials with Budget
    this.supplyMaterialsRemark = '',
    this.supplyMaterialsDocuments = const [],
    // Section 18 – Sub Contract
    this.subContract = 'No',
    // Section 19 – Our Scope of Work
    this.scopeOfWorkRemark = '',
    this.scopeItems = const [],
    this.otherScope = '',
    // Section 20 – Own Machine or Subcontract
    this.ownMachineRemark = '',
    this.ownOrSubcontract = '',
    // Section 21 – Billing Details
    this.billingDetailsRemark = '',
    this.billingDetailsDocuments = const [],
    // Section 22 – Flow of Bills
    this.flowOfBillsRemark = '',
    this.flowOfBillsStatus = '',
    // Section 23 – Payment Received & Deductions
    this.paymentReceivedRemark = '',
    this.paymentAmount = 0.0,
    this.deductions = const [],
    // Section 24 – EMD Retention Receivable Date
    this.emdRetentionRemark = '',
    this.emdRetentionAmount = 0.0,
    this.emdRetentionDate,
    this.emdRetentionDocuments = const [],
    // Section 25 – SD Retention Receivable Date
    this.sdRetentionRemark = '',
    this.sdRetentionAmount = 0.0,
    this.sdRetentionDate,
    this.sdRetentionDocuments = const [],
    // Section 26 – Other Retention Receivable Date
    this.otherRetentionRemark = '',
    this.otherRetentionAmount = 0.0,
    this.otherRetentionDate,
    this.otherRetentionDocuments = const [],
    this.otherRetentionDocumentLabel = '',
    // Metadata
    this.status = 'Active',
    required this.createdAt,
    required this.updatedAt,
    this.createdBy = '',
    this.updatedBy,
    this.updatedByName,
  })  : assignedToEmployeeNames = assignedToEmployeeNames ??
            (assignedToEmployeeName != null && assignedToEmployeeName.isNotEmpty
                ? [assignedToEmployeeName]
                : const []),
        assignedToEmployeeIds = assignedToEmployeeIds ??
            (assignedToEmployeeId != null && assignedToEmployeeId.isNotEmpty
                ? [assignedToEmployeeId]
                : const []);

  final String id;

  // Section 1 – General Code
  final String employeeName;
  final String? employeeId;
  final String clientName;
  final int? clientId;
  final String generalDetails;
  final String place;
  final String generalCode;

  // Section 2 – Project Code
  final String subOrOwn;
  final String state;
  final String district;
  final String area;
  final String projectCode;

  // Section 3 – Tender Type (extended)
  final String tenderType;
  final String qualified;
  final String tenderCategory;
  final double tenderAmount;
  final double approximateProjectValue;
  final double actualProjectValue;

  // Section 4 – Tender Spec / Enquiry Spec
  final String tenderSpecRemark;
  final List<ProjectDocument> tenderSpecDocuments;

  // Section 4b – Tender Description
  final List<TenderDescriptionItem> tenderDescriptions;

  // Section 5 – Assigned To (Supports Multiple Employees)
  final List<String> assignedToEmployeeNames;
  final List<String> assignedToEmployeeIds;

  String get assignedToEmployeeName =>
      assignedToEmployeeNames.isNotEmpty ? assignedToEmployeeNames.join(', ') : '';
  String? get assignedToEmployeeId =>
      assignedToEmployeeIds.isNotEmpty ? assignedToEmployeeIds.join(', ') : null;

  // Section 6 – Opening Date
  final DateTime? openingDate;
  final String openingDateRemark;

  // Section 7 – Closing Date
  final DateTime? closingDate;
  final String closingDateRemark;

  // Section 8 – BQR
  final String bqrRemark;
  final List<ProjectDocument> bqrDocuments;

  // Section 9 – EMD / EMD Exemption
  final String emdRemark;
  final List<ProjectDocument> emdDocuments;

  // Section 10 – Tender Lost
  final String tenderLostRemark;
  final String tenderLostStatus;
  final String competitorName;
  final double quotedAmount;

  // Section 11 – SD Date / Bank Guarantee / Bill Deduction
  final String sdDateRemark;
  final List<ProjectDocument> sdDateDocuments;

  // Section 12 – BOQ
  final String boqRemark;
  final List<ProjectDocument> boqDocuments;

  // Section 13 – Project Details
  final String projectDetailsRemark;
  final List<ProjectDocument> projectDetailsDocuments;

  // Section 14 – Work Order / LOA
  final String workOrderRemark;
  final List<ProjectDocument> workOrderDocuments;

  // Section 15 – Profile Drawing
  final String profileDrawingRemark;
  final List<ProjectDocument> profileDrawingDocuments;

  // Section 16 – Agreement
  final String agreementRemark;
  final List<ProjectDocument> agreementDocuments;

  // Section 17 – Supply of Materials with Budget
  final String supplyMaterialsRemark;
  final List<ProjectDocument> supplyMaterialsDocuments;

  // Section 18 – Sub Contract
  final String subContract;

  // Section 19 – Our Scope of Work
  final String scopeOfWorkRemark;
  final List<String> scopeItems;
  final String otherScope;

  // Section 20 – Own Machine or Subcontract
  final String ownMachineRemark;
  final String ownOrSubcontract;

  // Section 21 – Billing Details
  final String billingDetailsRemark;
  final List<ProjectDocument> billingDetailsDocuments;

  // Section 22 – Flow of Bills
  final String flowOfBillsRemark;
  final String flowOfBillsStatus;

  // Section 23 – Payment Received & Deductions
  final String paymentReceivedRemark;
  final double paymentAmount;
  final List<DeductionEntry> deductions;

  // Section 24 – EMD Retention Receivable Date
  final String emdRetentionRemark;
  final double emdRetentionAmount;
  final DateTime? emdRetentionDate;
  final List<ProjectDocument> emdRetentionDocuments;

  // Section 25 – SD Retention Receivable Date
  final String sdRetentionRemark;
  final double sdRetentionAmount;
  final DateTime? sdRetentionDate;
  final List<ProjectDocument> sdRetentionDocuments;

  // Section 26 – Other Retention Receivable Date
  final String otherRetentionRemark;
  final double otherRetentionAmount;
  final DateTime? otherRetentionDate;
  final List<ProjectDocument> otherRetentionDocuments;
  final String otherRetentionDocumentLabel;

  // Metadata
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String? updatedBy;
  final String? updatedByName;

  Map<String, dynamic> toJson() => {
        'id': id,
        'employee_name': employeeName,
        'employee_id': employeeId,
        'client_name': clientName,
        'client_id': clientId,
        'general_details': generalDetails,
        'place': place,
        'general_code': generalCode,
        'sub_or_own': subOrOwn,
        'state': state,
        'district': district,
        'area': area,
        'project_code': projectCode,
        // Tender Type
        'tender_type': tenderType,
        'qualified': qualified,
        'tender_category': tenderCategory,
        'tender_amount': tenderAmount,
        'approximate_project_value': approximateProjectValue,
        'actual_project_value': actualProjectValue,
        // Tender Spec
        'tender_spec_remark': tenderSpecRemark,
        'tender_spec_documents':
            tenderSpecDocuments.map((d) => d.toJson()).toList(),
        // Tender Descriptions
        'tender_descriptions':
            tenderDescriptions.map((t) => t.toJson()).toList(),
        // Assigned To
        'assigned_to_employee_name': assignedToEmployeeName,
        'assigned_to_employee_id': assignedToEmployeeId,
        'assigned_to_employee_names': assignedToEmployeeNames,
        'assigned_to_employee_ids': assignedToEmployeeIds,
        // Opening Date
        'opening_date': openingDate?.toIso8601String(),
        'opening_date_remark': openingDateRemark,
        // Closing Date
        'closing_date': closingDate?.toIso8601String(),
        'closing_date_remark': closingDateRemark,
        // BQR
        'bqr_remark': bqrRemark,
        'bqr_documents': bqrDocuments.map((d) => d.toJson()).toList(),
        // EMD
        'emd_remark': emdRemark,
        'emd_documents': emdDocuments.map((d) => d.toJson()).toList(),
        // Tender Lost
        'tender_lost_remark': tenderLostRemark,
        'tender_lost_status': tenderLostStatus,
        'competitor_name': competitorName,
        'quoted_amount': quotedAmount,
        // SD Date
        'sd_date_remark': sdDateRemark,
        'sd_date_documents': sdDateDocuments.map((d) => d.toJson()).toList(),
        // BOQ
        'boq_remark': boqRemark,
        'boq_documents': boqDocuments.map((d) => d.toJson()).toList(),
        // Project Details
        'project_details_remark': projectDetailsRemark,
        'project_details_documents':
            projectDetailsDocuments.map((d) => d.toJson()).toList(),
        // Work Order
        'work_order_remark': workOrderRemark,
        'work_order_documents':
            workOrderDocuments.map((d) => d.toJson()).toList(),
        // Profile Drawing
        'profile_drawing_remark': profileDrawingRemark,
        'profile_drawing_documents':
            profileDrawingDocuments.map((d) => d.toJson()).toList(),
        // Agreement
        'agreement_remark': agreementRemark,
        'agreement_documents':
            agreementDocuments.map((d) => d.toJson()).toList(),
        // Supply Materials
        'supply_materials_remark': supplyMaterialsRemark,
        'supply_materials_documents':
            supplyMaterialsDocuments.map((d) => d.toJson()).toList(),
        // Sub Contract
        'sub_contract': subContract,
        // Scope of Work
        'scope_of_work_remark': scopeOfWorkRemark,
        'scope_items': scopeItems,
        'other_scope': otherScope,
        // Own Machine
        'own_machine_remark': ownMachineRemark,
        'own_or_subcontract': ownOrSubcontract,
        // Billing Details
        'billing_details_remark': billingDetailsRemark,
        'billing_details_documents':
            billingDetailsDocuments.map((d) => d.toJson()).toList(),
        // Flow of Bills
        'flow_of_bills_remark': flowOfBillsRemark,
        'flow_of_bills_status': flowOfBillsStatus,
        // Payment
        'payment_received_remark': paymentReceivedRemark,
        'payment_amount': paymentAmount,
        'deductions': deductions.map((d) => d.toJson()).toList(),
        // EMD Retention
        'emd_retention_remark': emdRetentionRemark,
        'emd_retention_amount': emdRetentionAmount,
        'emd_retention_date': emdRetentionDate?.toIso8601String(),
        'emd_retention_documents':
            emdRetentionDocuments.map((d) => d.toJson()).toList(),
        // SD Retention
        'sd_retention_remark': sdRetentionRemark,
        'sd_retention_amount': sdRetentionAmount,
        'sd_retention_date': sdRetentionDate?.toIso8601String(),
        'sd_retention_documents':
            sdRetentionDocuments.map((d) => d.toJson()).toList(),
        // Other Retention
        'other_retention_remark': otherRetentionRemark,
        'other_retention_amount': otherRetentionAmount,
        'other_retention_date': otherRetentionDate?.toIso8601String(),
        'other_retention_documents':
            otherRetentionDocuments.map((d) => d.toJson()).toList(),
        'other_retention_document_label': otherRetentionDocumentLabel,
        // Metadata
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'created_by': createdBy,
        'updated_by': updatedBy,
        'updated_by_name': updatedByName,
      };

  factory SiteProject.fromJson(Map<String, dynamic> json, {String? docId}) {
    List<ProjectDocument> parseDocList(dynamic raw) {
      if (raw is List) {
        return raw
            .map((item) =>
                ProjectDocument.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
      return const [];
    }

    List<TenderDescriptionItem> parseTenderDescriptions(dynamic raw) {
      if (raw is List) {
        return raw
            .map((item) => TenderDescriptionItem.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList();
      }
      return const [];
    }

    List<DeductionEntry> parseDeductions(dynamic raw) {
      if (raw is List) {
        return raw
            .map((item) =>
                DeductionEntry.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
      return const [];
    }

    List<String> parseStringList(dynamic raw, String? fallbackSingle) {
      if (raw is List) {
        return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
      }
      if (fallbackSingle != null && fallbackSingle.isNotEmpty) {
        return [fallbackSingle];
      }
      return const [];
    }

    final assignedNames = parseStringList(
      json['assigned_to_employee_names'],
      json['assigned_to_employee_name'] as String?,
    );
    final assignedIds = parseStringList(
      json['assigned_to_employee_ids'],
      json['assigned_to_employee_id']?.toString(),
    );

    return SiteProject(
      id: docId ?? (json['id'] as String? ?? ''),
      employeeName: json['employee_name'] as String? ?? '',
      employeeId: json['employee_id']?.toString(),
      clientName: json['client_name'] as String? ?? '',
      clientId: json['client_id'] is num
          ? (json['client_id'] as num).toInt()
          : int.tryParse(json['client_id']?.toString() ?? ''),
      generalDetails: json['general_details'] as String? ?? '',
      place: json['place'] as String? ?? '',
      generalCode: json['general_code'] as String? ?? '',
      subOrOwn: json['sub_or_own'] as String? ?? 'Own',
      state: json['state'] as String? ?? '',
      district: json['district'] as String? ?? '',
      area: json['area'] as String? ?? '',
      projectCode: json['project_code'] as String? ?? '',
      // Tender Type
      tenderType: json['tender_type'] as String? ?? '',
      qualified: json['qualified'] as String? ?? '',
      tenderCategory: json['tender_category'] as String? ?? '',
      tenderAmount: (json['tender_amount'] as num?)?.toDouble() ?? 0.0,
      approximateProjectValue:
          (json['approximate_project_value'] as num?)?.toDouble() ?? 0.0,
      actualProjectValue:
          (json['actual_project_value'] as num?)?.toDouble() ?? 0.0,
      // Tender Spec
      tenderSpecRemark: json['tender_spec_remark'] as String? ?? '',
      tenderSpecDocuments: parseDocList(json['tender_spec_documents']),
      // Tender Descriptions
      tenderDescriptions: parseTenderDescriptions(json['tender_descriptions']),
      // Assigned To
      assignedToEmployeeNames: assignedNames,
      assignedToEmployeeIds: assignedIds,
      assignedToEmployeeName:
          assignedNames.isNotEmpty ? assignedNames.join(', ') : '',
      assignedToEmployeeId:
          assignedIds.isNotEmpty ? assignedIds.join(', ') : null,
      // Opening Date
      openingDate: json['opening_date'] != null
          ? DateTime.tryParse(json['opening_date'].toString())
          : null,
      openingDateRemark: json['opening_date_remark'] as String? ?? '',
      // Closing Date
      closingDate: json['closing_date'] != null
          ? DateTime.tryParse(json['closing_date'].toString())
          : null,
      closingDateRemark: json['closing_date_remark'] as String? ?? '',
      // BQR
      bqrRemark: json['bqr_remark'] as String? ?? '',
      bqrDocuments: parseDocList(json['bqr_documents']),
      // EMD
      emdRemark: json['emd_remark'] as String? ?? '',
      emdDocuments: parseDocList(json['emd_documents']),
      // Tender Lost
      tenderLostRemark: json['tender_lost_remark'] as String? ?? '',
      tenderLostStatus: json['tender_lost_status'] as String? ?? '',
      competitorName: json['competitor_name'] as String? ?? '',
      quotedAmount: (json['quoted_amount'] as num?)?.toDouble() ?? 0.0,
      // SD Date
      sdDateRemark: json['sd_date_remark'] as String? ?? '',
      sdDateDocuments: parseDocList(json['sd_date_documents']),
      // BOQ
      boqRemark: json['boq_remark'] as String? ?? '',
      boqDocuments: parseDocList(json['boq_documents']),
      // Project Details
      projectDetailsRemark: json['project_details_remark'] as String? ?? '',
      projectDetailsDocuments:
          parseDocList(json['project_details_documents']),
      // Work Order
      workOrderRemark: json['work_order_remark'] as String? ?? '',
      workOrderDocuments: parseDocList(json['work_order_documents']),
      // Profile Drawing
      profileDrawingRemark: json['profile_drawing_remark'] as String? ?? '',
      profileDrawingDocuments:
          parseDocList(json['profile_drawing_documents']),
      // Agreement
      agreementRemark: json['agreement_remark'] as String? ?? '',
      agreementDocuments: parseDocList(json['agreement_documents']),
      // Supply Materials
      supplyMaterialsRemark:
          json['supply_materials_remark'] as String? ?? '',
      supplyMaterialsDocuments:
          parseDocList(json['supply_materials_documents']),
      // Sub Contract
      subContract: json['sub_contract'] as String? ?? 'No',
      // Scope of Work
      scopeOfWorkRemark: json['scope_of_work_remark'] as String? ?? '',
      scopeItems: parseStringList(json['scope_items'], null),
      otherScope: json['other_scope'] as String? ?? '',
      // Own Machine
      ownMachineRemark: json['own_machine_remark'] as String? ?? '',
      ownOrSubcontract: json['own_or_subcontract'] as String? ?? '',
      // Billing Details
      billingDetailsRemark: json['billing_details_remark'] as String? ?? '',
      billingDetailsDocuments:
          parseDocList(json['billing_details_documents']),
      // Flow of Bills
      flowOfBillsRemark: json['flow_of_bills_remark'] as String? ?? '',
      flowOfBillsStatus: json['flow_of_bills_status'] as String? ?? '',
      // Payment
      paymentReceivedRemark:
          json['payment_received_remark'] as String? ?? '',
      paymentAmount: (json['payment_amount'] as num?)?.toDouble() ?? 0.0,
      deductions: parseDeductions(json['deductions']),
      // EMD Retention
      emdRetentionRemark: json['emd_retention_remark'] as String? ?? '',
      emdRetentionAmount:
          (json['emd_retention_amount'] as num?)?.toDouble() ?? 0.0,
      emdRetentionDate: json['emd_retention_date'] != null
          ? DateTime.tryParse(json['emd_retention_date'].toString())
          : null,
      emdRetentionDocuments: parseDocList(json['emd_retention_documents']),
      // SD Retention
      sdRetentionRemark: json['sd_retention_remark'] as String? ?? '',
      sdRetentionAmount:
          (json['sd_retention_amount'] as num?)?.toDouble() ?? 0.0,
      sdRetentionDate: json['sd_retention_date'] != null
          ? DateTime.tryParse(json['sd_retention_date'].toString())
          : null,
      sdRetentionDocuments: parseDocList(json['sd_retention_documents']),
      // Other Retention
      otherRetentionRemark:
          json['other_retention_remark'] as String? ?? '',
      otherRetentionAmount:
          (json['other_retention_amount'] as num?)?.toDouble() ?? 0.0,
      otherRetentionDate: json['other_retention_date'] != null
          ? DateTime.tryParse(json['other_retention_date'].toString())
          : null,
      otherRetentionDocuments:
          parseDocList(json['other_retention_documents']),
      otherRetentionDocumentLabel:
          json['other_retention_document_label'] as String? ?? '',
      // Metadata
      status: json['status'] as String? ?? 'Active',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      createdBy: json['created_by'] as String? ?? '',
      updatedBy: json['updated_by'] as String?,
      updatedByName: json['updated_by_name'] as String?,
    );
  }

  SiteProject copyWith({
    String? id,
    String? employeeName,
    String? employeeId,
    String? clientName,
    int? clientId,
    String? generalDetails,
    String? place,
    String? generalCode,
    String? subOrOwn,
    String? state,
    String? district,
    String? area,
    String? projectCode,
    // Tender Type
    String? tenderType,
    String? qualified,
    String? tenderCategory,
    double? tenderAmount,
    double? approximateProjectValue,
    double? actualProjectValue,
    // Tender Spec
    String? tenderSpecRemark,
    List<ProjectDocument>? tenderSpecDocuments,
    // Tender Descriptions
    List<TenderDescriptionItem>? tenderDescriptions,
    // Assigned To
    List<String>? assignedToEmployeeNames,
    List<String>? assignedToEmployeeIds,
    String? assignedToEmployeeName,
    String? assignedToEmployeeId,
    // Opening Date
    DateTime? openingDate,
    String? openingDateRemark,
    // Closing Date
    DateTime? closingDate,
    String? closingDateRemark,
    // BQR
    String? bqrRemark,
    List<ProjectDocument>? bqrDocuments,
    // EMD
    String? emdRemark,
    List<ProjectDocument>? emdDocuments,
    // Tender Lost
    String? tenderLostRemark,
    String? tenderLostStatus,
    String? competitorName,
    double? quotedAmount,
    // SD Date
    String? sdDateRemark,
    List<ProjectDocument>? sdDateDocuments,
    // BOQ
    String? boqRemark,
    List<ProjectDocument>? boqDocuments,
    // Project Details
    String? projectDetailsRemark,
    List<ProjectDocument>? projectDetailsDocuments,
    // Work Order
    String? workOrderRemark,
    List<ProjectDocument>? workOrderDocuments,
    // Profile Drawing
    String? profileDrawingRemark,
    List<ProjectDocument>? profileDrawingDocuments,
    // Agreement
    String? agreementRemark,
    List<ProjectDocument>? agreementDocuments,
    // Supply Materials
    String? supplyMaterialsRemark,
    List<ProjectDocument>? supplyMaterialsDocuments,
    // Sub Contract
    String? subContract,
    // Scope of Work
    String? scopeOfWorkRemark,
    List<String>? scopeItems,
    String? otherScope,
    // Own Machine
    String? ownMachineRemark,
    String? ownOrSubcontract,
    // Billing Details
    String? billingDetailsRemark,
    List<ProjectDocument>? billingDetailsDocuments,
    // Flow of Bills
    String? flowOfBillsRemark,
    String? flowOfBillsStatus,
    // Payment
    String? paymentReceivedRemark,
    double? paymentAmount,
    List<DeductionEntry>? deductions,
    // EMD Retention
    String? emdRetentionRemark,
    double? emdRetentionAmount,
    DateTime? emdRetentionDate,
    List<ProjectDocument>? emdRetentionDocuments,
    // SD Retention
    String? sdRetentionRemark,
    double? sdRetentionAmount,
    DateTime? sdRetentionDate,
    List<ProjectDocument>? sdRetentionDocuments,
    // Other Retention
    String? otherRetentionRemark,
    double? otherRetentionAmount,
    DateTime? otherRetentionDate,
    List<ProjectDocument>? otherRetentionDocuments,
    String? otherRetentionDocumentLabel,
    // Metadata
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    String? updatedByName,
  }) {
    return SiteProject(
      id: id ?? this.id,
      employeeName: employeeName ?? this.employeeName,
      employeeId: employeeId ?? this.employeeId,
      clientName: clientName ?? this.clientName,
      clientId: clientId ?? this.clientId,
      generalDetails: generalDetails ?? this.generalDetails,
      place: place ?? this.place,
      generalCode: generalCode ?? this.generalCode,
      subOrOwn: subOrOwn ?? this.subOrOwn,
      state: state ?? this.state,
      district: district ?? this.district,
      area: area ?? this.area,
      projectCode: projectCode ?? this.projectCode,
      tenderType: tenderType ?? this.tenderType,
      qualified: qualified ?? this.qualified,
      tenderCategory: tenderCategory ?? this.tenderCategory,
      tenderAmount: tenderAmount ?? this.tenderAmount,
      approximateProjectValue:
          approximateProjectValue ?? this.approximateProjectValue,
      actualProjectValue: actualProjectValue ?? this.actualProjectValue,
      tenderSpecRemark: tenderSpecRemark ?? this.tenderSpecRemark,
      tenderSpecDocuments: tenderSpecDocuments ?? this.tenderSpecDocuments,
      tenderDescriptions: tenderDescriptions ?? this.tenderDescriptions,
      assignedToEmployeeNames:
          assignedToEmployeeNames ?? this.assignedToEmployeeNames,
      assignedToEmployeeIds:
          assignedToEmployeeIds ?? this.assignedToEmployeeIds,
      assignedToEmployeeName:
          assignedToEmployeeName ?? this.assignedToEmployeeName,
      assignedToEmployeeId: assignedToEmployeeId ?? this.assignedToEmployeeId,
      openingDate: openingDate ?? this.openingDate,
      openingDateRemark: openingDateRemark ?? this.openingDateRemark,
      closingDate: closingDate ?? this.closingDate,
      closingDateRemark: closingDateRemark ?? this.closingDateRemark,
      bqrRemark: bqrRemark ?? this.bqrRemark,
      bqrDocuments: bqrDocuments ?? this.bqrDocuments,
      emdRemark: emdRemark ?? this.emdRemark,
      emdDocuments: emdDocuments ?? this.emdDocuments,
      tenderLostRemark: tenderLostRemark ?? this.tenderLostRemark,
      tenderLostStatus: tenderLostStatus ?? this.tenderLostStatus,
      competitorName: competitorName ?? this.competitorName,
      quotedAmount: quotedAmount ?? this.quotedAmount,
      sdDateRemark: sdDateRemark ?? this.sdDateRemark,
      sdDateDocuments: sdDateDocuments ?? this.sdDateDocuments,
      boqRemark: boqRemark ?? this.boqRemark,
      boqDocuments: boqDocuments ?? this.boqDocuments,
      projectDetailsRemark: projectDetailsRemark ?? this.projectDetailsRemark,
      projectDetailsDocuments:
          projectDetailsDocuments ?? this.projectDetailsDocuments,
      workOrderRemark: workOrderRemark ?? this.workOrderRemark,
      workOrderDocuments: workOrderDocuments ?? this.workOrderDocuments,
      profileDrawingRemark: profileDrawingRemark ?? this.profileDrawingRemark,
      profileDrawingDocuments:
          profileDrawingDocuments ?? this.profileDrawingDocuments,
      agreementRemark: agreementRemark ?? this.agreementRemark,
      agreementDocuments: agreementDocuments ?? this.agreementDocuments,
      supplyMaterialsRemark:
          supplyMaterialsRemark ?? this.supplyMaterialsRemark,
      supplyMaterialsDocuments:
          supplyMaterialsDocuments ?? this.supplyMaterialsDocuments,
      subContract: subContract ?? this.subContract,
      scopeOfWorkRemark: scopeOfWorkRemark ?? this.scopeOfWorkRemark,
      scopeItems: scopeItems ?? this.scopeItems,
      otherScope: otherScope ?? this.otherScope,
      ownMachineRemark: ownMachineRemark ?? this.ownMachineRemark,
      ownOrSubcontract: ownOrSubcontract ?? this.ownOrSubcontract,
      billingDetailsRemark: billingDetailsRemark ?? this.billingDetailsRemark,
      billingDetailsDocuments:
          billingDetailsDocuments ?? this.billingDetailsDocuments,
      flowOfBillsRemark: flowOfBillsRemark ?? this.flowOfBillsRemark,
      flowOfBillsStatus: flowOfBillsStatus ?? this.flowOfBillsStatus,
      paymentReceivedRemark:
          paymentReceivedRemark ?? this.paymentReceivedRemark,
      paymentAmount: paymentAmount ?? this.paymentAmount,
      deductions: deductions ?? this.deductions,
      emdRetentionRemark: emdRetentionRemark ?? this.emdRetentionRemark,
      emdRetentionAmount: emdRetentionAmount ?? this.emdRetentionAmount,
      emdRetentionDate: emdRetentionDate ?? this.emdRetentionDate,
      emdRetentionDocuments:
          emdRetentionDocuments ?? this.emdRetentionDocuments,
      sdRetentionRemark: sdRetentionRemark ?? this.sdRetentionRemark,
      sdRetentionAmount: sdRetentionAmount ?? this.sdRetentionAmount,
      sdRetentionDate: sdRetentionDate ?? this.sdRetentionDate,
      sdRetentionDocuments: sdRetentionDocuments ?? this.sdRetentionDocuments,
      otherRetentionRemark: otherRetentionRemark ?? this.otherRetentionRemark,
      otherRetentionAmount: otherRetentionAmount ?? this.otherRetentionAmount,
      otherRetentionDate: otherRetentionDate ?? this.otherRetentionDate,
      otherRetentionDocuments:
          otherRetentionDocuments ?? this.otherRetentionDocuments,
      otherRetentionDocumentLabel:
          otherRetentionDocumentLabel ?? this.otherRetentionDocumentLabel,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedByName: updatedByName ?? this.updatedByName,
    );
  }
}
