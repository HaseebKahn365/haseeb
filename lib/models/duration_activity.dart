import 'package:hive/hive.dart';

import 'activity.dart';

part 'duration_activity.g.dart';

@HiveType(typeId: 2)
class DurationActivity extends Activity {
  @HiveField(3)
  int totalDuration; // in minutes

  @HiveField(4)
  int doneDuration; // in minutes

  DurationActivity({
    required super.id,
    required super.title,
    required super.timestamp,
    required this.totalDuration,
    required this.doneDuration,
  });
}
