import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/asset_category.dart';
import '../domain/asset_category_repository.dart';

class FirebaseAssetCategoryRepository implements AssetCategoryRepository {
  final FirebaseFirestore _firestore;

  FirebaseAssetCategoryRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('asset_categories');

  @override
  Future<List<AssetCategory>> getAssetCategories() async {
    final snapshot = await _ref.get();

    if (snapshot.docs.isEmpty) {
      final nowStr = DateTime.now().toIso8601String();
      const defaultCategories = [
        ['Hardware', 'Physical equipment and devices'],
        ['Peripheral', 'External devices and accessories'],
        ['Software', 'Software licenses and applications'],
        ['Network', 'Network devices and components'],
        ['Other', 'Other tools and equipment'],
      ];

      for (var i = 0; i < defaultCategories.length; i++) {
        final row = defaultCategories[i];
        final id = i + 1;
        await _ref.doc(id.toString()).set({
          'id': id,
          'name': row[0],
          'description': row[1],
          'created_at': nowStr,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      final seededSnapshot = await _ref.get();
      return seededSnapshot.docs
          .map((doc) => AssetCategory.fromMap(doc.data(), doc.id))
          .toList()
        ..sort((a, b) => a.id.compareTo(b.id));
    }

    final categories = snapshot.docs
        .map((doc) => AssetCategory.fromMap(doc.data(), doc.id))
        .toList();
    categories.sort((a, b) => a.id.compareTo(b.id));
    return categories;
  }

  @override
  Future<AssetCategory> addAssetCategory(AssetCategory category) async {
    final nowStr = DateTime.now().toIso8601String();
    final docRef = _ref.doc();
    final parsedId = int.tryParse(docRef.id.replaceAll(RegExp(r'\D'), ''));
    final assignedId = category.id != 0
        ? category.id
        : ((parsedId != null && parsedId != 0)
            ? parsedId
            : (docRef.id.hashCode & 0x7FFFFFFF));

    final newCategory = category.copyWith(
      id: assignedId,
      createdAt: category.createdAt ?? nowStr,
    );

    final data = newCategory.toMap();
    data['created_at'] = nowStr;
    data['updated_at'] = FieldValue.serverTimestamp();

    await docRef.set(data, SetOptions(merge: true));
    return newCategory;
  }

  @override
  Future<void> updateAssetCategory(AssetCategory category) async {
    final snapshot =
        await _ref.where('id', isEqualTo: category.id).limit(1).get();
    String docId = snapshot.docs.isNotEmpty ? snapshot.docs.first.id : category.id.toString();

    final data = category.toMap();
    data['updated_at'] = FieldValue.serverTimestamp();
    await _ref.doc(docId).set(data, SetOptions(merge: true));
  }

  @override
  Future<void> deleteAssetCategory(int id) async {
    final snapshot =
        await _ref.where('id', isEqualTo: id).limit(1).get();
    if (snapshot.docs.isNotEmpty) {
      await _ref.doc(snapshot.docs.first.id).delete();
      return;
    }
    await _ref.doc(id.toString()).delete();
  }
}
