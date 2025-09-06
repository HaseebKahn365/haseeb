import 'package:hive/hive.dart';

import 'activity.dart';

part 'custom_list.g.dart';

@HiveType(typeId: 4)
class CustomList extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  List<Activity> activities;

  CustomList({required this.title, required this.activities});
}
