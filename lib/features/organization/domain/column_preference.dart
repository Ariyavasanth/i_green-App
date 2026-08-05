import 'dart:convert';

class ColumnPreference {
  const ColumnPreference({
    required this.tableId,
    required this.visibleColumns,
    required this.columnOrder,
  });

  final String tableId;
  final List<String> visibleColumns;
  final List<String> columnOrder;

  ColumnPreference copyWith({
    String? tableId,
    List<String>? visibleColumns,
    List<String>? columnOrder,
  }) {
    return ColumnPreference(
      tableId: tableId ?? this.tableId,
      visibleColumns: visibleColumns ?? this.visibleColumns,
      columnOrder: columnOrder ?? this.columnOrder,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'table_id': tableId,
      'visible_columns': jsonEncode(visibleColumns),
      'column_order': jsonEncode(columnOrder),
    };
  }

  factory ColumnPreference.fromMap(Map<String, dynamic> map) {
    List<String> decodeList(dynamic raw) {
      if (raw == null) return [];
      if (raw is String) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            return decoded
                .where((e) => e != null)
                .map((e) => e.toString())
                .toList();
          }
        } catch (_) {}
        if (raw.contains(',')) {
          return raw.split(',').where((e) => e.trim().isNotEmpty).map((e) => e.trim()).toList();
        } else if (raw.trim().isNotEmpty) {
          return [raw.trim()];
        }
      }
      if (raw is List) {
        return raw.where((e) => e != null).map((e) => e.toString()).toList();
      }
      return [];
    }

    return ColumnPreference(
      tableId: map['table_id']?.toString() ?? '',
      visibleColumns: decodeList(map['visible_columns']),
      columnOrder: decodeList(map['column_order']),
    );
  }
}
