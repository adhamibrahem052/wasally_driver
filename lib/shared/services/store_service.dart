import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/store_models.dart';

class StoreService {
  final SupabaseClient _supabase;
  StoreService(this._supabase);

  Future<List<StoreModel>> getStores() async {
    final response = await _supabase.from('stores').select().eq('is_active', true);
    return (response as List).map((m) => StoreModel.fromMap(m)).toList();
  }

  Future<List<ProductModel>> getStoreProducts(String storeId) async {
    final response = await _supabase
        .from('products')
        .select()
        .eq('store_id', storeId)
        .eq('is_available', true);
    return (response as List).map((m) => ProductModel.fromMap(m)).toList();
  }

  Future<List<ProductModel>> searchProducts(String query) async {
    final response = await _supabase
        .from('products')
        .select('*, stores(name)')
        .eq('is_available', true)
        .ilike('name', '%$query%');
    return (response as List).map((m) => ProductModel.fromMap(m)).toList();
  }

  Future<List<CategoryModel>> getCategories() async {
    final response = await _supabase
        .from('categories')
        .select()
        .eq('is_active', true)
        .order('sort_order');
    return (response as List).map((m) => CategoryModel.fromMap(m)).toList();
  }
}
