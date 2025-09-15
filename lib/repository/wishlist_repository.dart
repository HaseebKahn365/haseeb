import 'package:haseeb/models/wishlist_item.dart';
import 'package:hive/hive.dart';

class WishlistRepository {
  static const String boxName = 'wishlistBox';

  late final Box<WishlistItem> box;

  WishlistRepository._(this.box);

  static Future<WishlistRepository> init() async {
    final box = await Hive.openBox<WishlistItem>(boxName);
    return WishlistRepository._(box);
  }

  List<WishlistItem> getAllItems() {
    return box.values.toList();
  }

  WishlistItem? getItem(String id) {
    return box.get(id);
  }

  Future<void> addItem(WishlistItem item) async {
    await box.put(item.id, item);
  }

  Future<void> updateItem(String id, WishlistItem updated) async {
    await box.put(id, updated);
  }

  Future<void> deleteItem(String id) async {
    await box.delete(id);
  }
}
