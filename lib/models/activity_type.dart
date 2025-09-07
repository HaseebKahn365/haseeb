import 'package:hive/hive.dart';

part 'activity_type.g.dart';

@HiveType(typeId: 5)
enum ActivityType {
  @HiveField(0)
  COUNT,
  @HiveField(1)
  DURATION,
}
