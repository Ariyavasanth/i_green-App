class AppNotification {
  final String id;
  final String title;
  final String message;
  final String type; // 'od_request', 'leave_request', 'incentive_request'
  final String requiredPermission;
  final String? senderId;
  final String? senderName;
  final String route;
  final DateTime createdAt;
  final List<String> readByEmployeeIds;
  final Map<String, dynamic> metadata;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.requiredPermission,
    this.senderId,
    this.senderName,
    required this.route,
    required this.createdAt,
    this.readByEmployeeIds = const [],
    this.metadata = const {},
  });

  bool isReadBy(String employeeId) {
    return readByEmployeeIds.contains(employeeId);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      'required_permission': requiredPermission,
      'sender_id': senderId,
      'sender_name': senderName,
      'route': route,
      'created_at': createdAt.toIso8601String(),
      'read_by_employee_ids': readByEmployeeIds,
      'metadata': metadata,
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parsedDate;
    final rawDate = map['created_at'];
    if (rawDate != null) {
      if (rawDate is String) {
        parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
      } else {
        // If Firestore Timestamp or dynamic
        try {
          parsedDate = (rawDate as dynamic).toDate();
        } catch (_) {
          parsedDate = DateTime.now();
        }
      }
    } else {
      parsedDate = DateTime.now();
    }

    final readByRaw = map['read_by_employee_ids'];
    List<String> readByList = [];
    if (readByRaw is List) {
      readByList = readByRaw.map((e) => e.toString()).toList();
    }

    final metaRaw = map['metadata'];
    Map<String, dynamic> metaMap = {};
    if (metaRaw is Map) {
      metaMap = Map<String, dynamic>.from(metaRaw);
    }

    return AppNotification(
      id: docId.isNotEmpty ? docId : (map['id']?.toString() ?? ''),
      title: map['title']?.toString() ?? '',
      message: map['message']?.toString() ?? '',
      type: map['type']?.toString() ?? '',
      requiredPermission: map['required_permission']?.toString() ?? '',
      senderId: map['sender_id']?.toString(),
      senderName: map['sender_name']?.toString(),
      route: map['route']?.toString() ?? '',
      createdAt: parsedDate,
      readByEmployeeIds: readByList,
      metadata: metaMap,
    );
  }

  AppNotification copyWith({
    String? id,
    String? title,
    String? message,
    String? type,
    String? requiredPermission,
    String? senderId,
    String? senderName,
    String? route,
    DateTime? createdAt,
    List<String>? readByEmployeeIds,
    Map<String, dynamic>? metadata,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      requiredPermission: requiredPermission ?? this.requiredPermission,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      route: route ?? this.route,
      createdAt: createdAt ?? this.createdAt,
      readByEmployeeIds: readByEmployeeIds ?? this.readByEmployeeIds,
      metadata: metadata ?? this.metadata,
    );
  }
}

