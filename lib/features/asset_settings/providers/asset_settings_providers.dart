import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase_asset_type_repository.dart';
import '../domain/asset_type.dart';
import '../domain/asset_type_repository.dart';

final assetTypeRepositoryProvider = Provider<AssetTypeRepository>(
  (ref) => FirebaseAssetTypeRepository(),
);

final assetTypesProvider = FutureProvider<List<AssetType>>((ref) async {
  return ref.watch(assetTypeRepositoryProvider).getAssetTypes();
});

final assetTypeSearchQueryProvider = StateProvider<String>((ref) => '');
