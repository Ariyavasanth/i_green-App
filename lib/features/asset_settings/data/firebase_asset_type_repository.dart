import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/asset_type.dart';
import '../domain/asset_type_repository.dart';

class FirebaseAssetTypeRepository implements AssetTypeRepository {
  final FirebaseFirestore _firestore;

  FirebaseAssetTypeRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('asset_types');

  @override
  Future<List<AssetType>> getAssetTypes() async {
    final snapshot = await _ref.get();

    if (snapshot.docs.isEmpty) {
      // Seed initial default asset types into Firestore
      final nowStr = DateTime.now().toIso8601String();
      const defaultTypes = [
        ['Laptop', 'Company assigned laptop computer', 'Hardware', 'Active'],
        ['Mobile Phone', 'Company mobile smartphone or SIM card', 'Hardware', 'Active'],
        ['Monitor', 'Desktop display monitor screen', 'Peripheral', 'Active'],
        ['Keyboard', 'Mechanical or ergonomic desktop keyboard', 'Peripheral', 'Active'],
        ['Headset', 'Audio headset or noise cancelling headphones', 'Peripheral', 'Active'],
        ['Other Equipment', 'General tools, accessories or devices', 'Other', 'Active'],
      ];

      for (var i = 0; i < defaultTypes.length; i++) {
        final row = defaultTypes[i];
        final id = i + 1;
        await _ref.doc(id.toString()).set({
          'id': id,
          'name': row[0],
          'description': row[1],
          'category': row[2],
          'status': row[3],
          'created_at': nowStr,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      final seededSnapshot = await _ref.get();
      return seededSnapshot.docs
          .map((doc) => AssetType.fromMap(doc.data(), doc.id))
          .toList()
        ..sort((a, b) => a.id.compareTo(b.id));
    }

    final types = snapshot.docs
        .map((doc) => AssetType.fromMap(doc.data(), doc.id))
        .toList();
    types.sort((a, b) => a.id.compareTo(b.id));
    return types;
  }

  @override
  Future<AssetType> addAssetType(AssetType type) async {
    final nowStr = DateTime.now().toIso8601String();
    final docRef = _ref.doc();
    final parsedId = int.tryParse(docRef.id.replaceAll(RegExp(r'\D'), ''));
    final assignedId = type.id != 0
        ? type.id
        : ((parsedId != null && parsedId != 0)
            ? parsedId
            : (docRef.id.hashCode & 0x7FFFFFFF));

    final newType = type.copyWith(
      id: assignedId,
      createdAt: type.createdAt ?? nowStr,
    );

    final data = newType.toMap();
    data['created_at'] = nowStr;
    data['updated_at'] = FieldValue.serverTimestamp();

    await docRef.set(data, SetOptions(merge: true));
    return newType;
  }

  @override
  Future<void> updateAssetType(AssetType type) async {
    final snapshot =
        await _ref.where('id', isEqualTo: type.id).limit(1).get();
    String docId = snapshot.docs.isNotEmpty ? snapshot.docs.first.id : type.id.toString();

    final data = type.toMap();
    data['updated_at'] = FieldValue.serverTimestamp();
    await _ref.doc(docId).set(data, SetOptions(merge: true));
  }

  @override
  Future<void> deleteAssetType(int id) async {
    final snapshot =
        await _ref.where('id', isEqualTo: id).limit(1).get();
    if (snapshot.docs.isNotEmpty) {
      await _ref.doc(snapshot.docs.first.id).delete();
      return;
    }
    await _ref.doc(id.toString()).delete();
  }
}
