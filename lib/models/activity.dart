import 'package:hive/hive.dart';

part 'activity.g.dart';

// Enum to identify activity type
@HiveType(typeId: 0)
enum ActivityType {
  @HiveField(0)
  count,

  @HiveField(1)
  time,
}

// Base Activity class
@HiveType(typeId: 1)
class Activity {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final ActivityType type;

  Activity({required this.id, required this.name, required this.type});
}

// Time-based activity
@HiveType(typeId: 2)
class TimeActivity extends Activity {
  @HiveField(3)
  final String parentId; // Reference to parent activity

  @HiveField(4)
  final String recordId; // Unique identifier for this record

  @HiveField(5)
  final DateTime start;

  @HiveField(6)
  final DateTime expectedEnd;

  @HiveField(7)
  final int productiveMinutes;

  @HiveField(8)
  final DateTime? actualEnd;

  TimeActivity({
    required this.parentId,
    required this.recordId,
    required this.start,
    required this.expectedEnd,
    required this.productiveMinutes,
    this.actualEnd,
    required super.name,
  }) : super(id: parentId, type: ActivityType.time);
}

// Count-based activity
@HiveType(typeId: 3)
class CountActivity extends Activity {
  @HiveField(3)
  final String parentId; // Reference to parent activity

  @HiveField(4)
  final String recordId; // Unique identifier for this record

  @HiveField(5)
  final DateTime timestamp;

  @HiveField(6)
  final int count;

  CountActivity({
    required this.parentId,
    required this.recordId,
    required this.timestamp,
    required this.count,
    required super.name,
  }) : super(id: parentId, type: ActivityType.count);
}
