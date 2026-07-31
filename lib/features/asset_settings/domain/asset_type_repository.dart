import 'asset_type.dart';

abstract interface class AssetTypeRepository {
  Future<List<AssetType>> getAssetTypes();
  Future<AssetType> addAssetType(AssetType type);
  Future<void> updateAssetType(AssetType type);
  Future<void> deleteAssetType(int id);
}
