import 'package:hive/hive.dart';

import 'activity.dart';

part 'count_activity.g.dart';

@HiveType(typeId: 1)
class CountActivity extends Activity {
  @HiveField(3)
  int totalCount;

  @HiveField(4)
  int doneCount;

  CountActivity({
    required super.id,
    required super.title,
    required super.timestamp,
    required this.totalCount,
    required this.doneCount,
  });
}
