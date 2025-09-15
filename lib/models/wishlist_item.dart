import 'package:hive/hive.dart';

part 'wishlist_item.g.dart';

@HiveType(typeId: 5)
class WishlistItem extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String description;

  @HiveField(3)
  DateTime dueDate;

  @HiveField(4)
  String type; // "duration" or "count"

  @HiveField(5)
  int? count;

  @HiveField(6)
  int? duration; // in minutes

  WishlistItem({
    required this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.type,
    this.count,
    this.duration,
  });
}
