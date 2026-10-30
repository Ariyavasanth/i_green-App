class FundRequestItem {
  final String id;
  final String category;
  final String subCategory;
  final String comments;
  final double amount;

  const FundRequestItem({
    required this.id,
    required this.category,
    required this.subCategory,
    required this.comments,
    required this.amount,
  });

  FundRequestItem copyWith({
    String? id,
    String? category,
    String? subCategory,
    String? comments,
    double? amount,
  }) {
    return FundRequestItem(
      id: id ?? this.id,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      comments: comments ?? this.comments,
      amount: amount ?? this.amount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'subCategory': subCategory,
      'comments': comments,
      'amount': amount,
    };
  }

  factory FundRequestItem.fromMap(Map<String, dynamic> map) {
    return FundRequestItem(
      id: (map['id'] ?? '').toString(),
      category: (map['category'] ?? '').toString(),
      subCategory: (map['subCategory'] ?? map['sub_category'] ?? '').toString(),
      comments: (map['comments'] ?? map['comment'] ?? '').toString(),
      amount: (map['amount'] is num) ? (map['amount'] as num).toDouble() : (double.tryParse('${map['amount']}') ?? 0.0),
    );
  }
}

