import 'package:hive/hive.dart';

import 'activity.dart';
import 'activity_type.dart';

part 'planned_activity.g.dart';

@HiveType(typeId: 3)
class PlannedActivity extends Activity {
  @HiveField(3)
  String description;

  @HiveField(4)
  ActivityType type;

  @HiveField(5)
  int estimatedCompletionDuration; // in minutes

  PlannedActivity({
    required super.id,
    required super.title,
    required super.timestamp,
    required this.description,
    required this.type,
    required this.estimatedCompletionDuration,
  });
}
