import 'asset_category.dart';

abstract class AssetCategoryRepository {
  Future<List<AssetCategory>> getAssetCategories();
  Future<AssetCategory> addAssetCategory(AssetCategory category);
  Future<void> updateAssetCategory(AssetCategory category);
  Future<void> deleteAssetCategory(int id);
}
