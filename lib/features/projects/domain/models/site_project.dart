import 'project_document.dart';

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
    this.tenderType = '',
    this.tenderSpecRemark = '',
    this.tenderSpecDocuments = const [],
    List<String>? assignedToEmployeeNames,
    List<String>? assignedToEmployeeIds,
    String? assignedToEmployeeName,
    String? assignedToEmployeeId,
    this.openingDate,
    this.openingDateRemark = '',
    this.closingDate,
    this.closingDateRemark = '',
    this.bqrRemark = '',
    this.bqrDocuments = const [],
    this.emdRemark = '',
    this.emdDocuments = const [],
    this.status = 'Active',
    required this.createdAt,
    required this.updatedAt,
    this.createdBy = '',
  })  : assignedToEmployeeNames = assignedToEmployeeNames ??
            (assignedToEmployeeName != null && assignedToEmployeeName.isNotEmpty
                ? [assignedToEmployeeName]
                : const []),
        assignedToEmployeeIds = assignedToEmployeeIds ??
            (assignedToEmployeeId != null && assignedToEmployeeId.isNotEmpty
                ? [assignedToEmployeeId]
                : const []);

  final String id;
  // Section 1 - General Code
  final String employeeName;
  final String? employeeId;
  final String clientName;
  final int? clientId;
  final String generalDetails;
  final String place;
  final String generalCode;

  // Section 2 - Project Code
  final String subOrOwn;
  final String state;
  final String district;
  final String area;
  final String projectCode;

  // Section 3 - Tender Type
  final String tenderType;

  // Section 4 - Tender Spec / Enquiry Spec
  final String tenderSpecRemark;
  final List<ProjectDocument> tenderSpecDocuments;

  // Section 5 - Assigned To (Supports Multiple Employees)
  final List<String> assignedToEmployeeNames;
  final List<String> assignedToEmployeeIds;

  String get assignedToEmployeeName =>
      assignedToEmployeeNames.isNotEmpty ? assignedToEmployeeNames.join(', ') : '';
  String? get assignedToEmployeeId =>
      assignedToEmployeeIds.isNotEmpty ? assignedToEmployeeIds.join(', ') : null;

  // Section 6 - Opening Date
  final DateTime? openingDate;
  final String openingDateRemark;

  // Section 7 - Closing Date
  final DateTime? closingDate;
  final String closingDateRemark;

  // Section 8 - BQR
  final String bqrRemark;
  final List<ProjectDocument> bqrDocuments;

  // Section 9 - EMD / EMD Exemption
  final String emdRemark;
  final List<ProjectDocument> emdDocuments;

  // Metadata
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;

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
        'tender_type': tenderType,
        'tender_spec_remark': tenderSpecRemark,
        'tender_spec_documents':
            tenderSpecDocuments.map((d) => d.toJson()).toList(),
        'assigned_to_employee_name': assignedToEmployeeName,
        'assigned_to_employee_id': assignedToEmployeeId,
        'assigned_to_employee_names': assignedToEmployeeNames,
        'assigned_to_employee_ids': assignedToEmployeeIds,
        'opening_date': openingDate?.toIso8601String(),
        'opening_date_remark': openingDateRemark,
        'closing_date': closingDate?.toIso8601String(),
        'closing_date_remark': closingDateRemark,
        'bqr_remark': bqrRemark,
        'bqr_documents': bqrDocuments.map((d) => d.toJson()).toList(),
        'emd_remark': emdRemark,
        'emd_documents': emdDocuments.map((d) => d.toJson()).toList(),
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'created_by': createdBy,
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
      tenderType: json['tender_type'] as String? ?? '',
      tenderSpecRemark: json['tender_spec_remark'] as String? ?? '',
      tenderSpecDocuments: parseDocList(json['tender_spec_documents']),
      assignedToEmployeeNames: assignedNames,
      assignedToEmployeeIds: assignedIds,
      assignedToEmployeeName: assignedNames.isNotEmpty ? assignedNames.join(', ') : '',
      assignedToEmployeeId: assignedIds.isNotEmpty ? assignedIds.join(', ') : null,
      openingDate: json['opening_date'] != null
          ? DateTime.tryParse(json['opening_date'].toString())
          : null,
      openingDateRemark: json['opening_date_remark'] as String? ?? '',
      closingDate: json['closing_date'] != null
          ? DateTime.tryParse(json['closing_date'].toString())
          : null,
      closingDateRemark: json['closing_date_remark'] as String? ?? '',
      bqrRemark: json['bqr_remark'] as String? ?? '',
      bqrDocuments: parseDocList(json['bqr_documents']),
      emdRemark: json['emd_remark'] as String? ?? '',
      emdDocuments: parseDocList(json['emd_documents']),
      status: json['status'] as String? ?? 'Active',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      createdBy: json['created_by'] as String? ?? '',
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
    String? tenderType,
    String? tenderSpecRemark,
    List<ProjectDocument>? tenderSpecDocuments,
    List<String>? assignedToEmployeeNames,
    List<String>? assignedToEmployeeIds,
    String? assignedToEmployeeName,
    String? assignedToEmployeeId,
    DateTime? openingDate,
    String? openingDateRemark,
    DateTime? closingDate,
    String? closingDateRemark,
    String? bqrRemark,
    List<ProjectDocument>? bqrDocuments,
    String? emdRemark,
    List<ProjectDocument>? emdDocuments,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
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
      tenderSpecRemark: tenderSpecRemark ?? this.tenderSpecRemark,
      tenderSpecDocuments: tenderSpecDocuments ?? this.tenderSpecDocuments,
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
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
