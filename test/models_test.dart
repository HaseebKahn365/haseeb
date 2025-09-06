import 'package:flutter_test/flutter_test.dart';
import 'package:haseeb/models/activity.dart';
import 'package:haseeb/models/activity_type.dart';
import 'package:haseeb/models/count_activity.dart';
import 'package:haseeb/models/custom_list.dart';
import 'package:haseeb/models/duration_activity.dart';
import 'package:haseeb/models/planned_activity.dart';

void main() {
  group('Activity Models Tests', () {
    test('Activity model should create correctly', () {
      final timestamp = DateTime.now();
      final activity = Activity(
        id: 'test_id',
        title: 'Test Activity',
        timestamp: timestamp,
      );

      expect(activity.id, 'test_id');
      expect(activity.title, 'Test Activity');
      expect(activity.timestamp, timestamp);
    });

    test('CountActivity should inherit from Activity', () {
      final timestamp = DateTime.now();
      final countActivity = CountActivity(
        id: 'count_id',
        title: 'Pushups',
        timestamp: timestamp,
        totalCount: 100,
        doneCount: 50,
      );

      expect(countActivity.id, 'count_id');
      expect(countActivity.title, 'Pushups');
      expect(countActivity.timestamp, timestamp);
      expect(countActivity.totalCount, 100);
      expect(countActivity.doneCount, 50);
    });

    test('DurationActivity should inherit from Activity', () {
      final timestamp = DateTime.now();
      final durationActivity = DurationActivity(
        id: 'duration_id',
        title: 'Running',
        timestamp: timestamp,
        totalDuration: 120,
        doneDuration: 60,
      );

      expect(durationActivity.id, 'duration_id');
      expect(durationActivity.title, 'Running');
      expect(durationActivity.timestamp, timestamp);
      expect(durationActivity.totalDuration, 120);
      expect(durationActivity.doneDuration, 60);
    });

    test('PlannedActivity should inherit from Activity', () {
      final timestamp = DateTime.now();
      final plannedActivity = PlannedActivity(
        id: 'planned_id',
        title: 'Study Session',
        timestamp: timestamp,
        description: 'Study for exam',
        type: ActivityType.COUNT,
        estimatedCompletionDuration: 90,
      );

      expect(plannedActivity.id, 'planned_id');
      expect(plannedActivity.title, 'Study Session');
      expect(plannedActivity.timestamp, timestamp);
      expect(plannedActivity.description, 'Study for exam');
      expect(plannedActivity.type, ActivityType.COUNT);
      expect(plannedActivity.estimatedCompletionDuration, 90);
    });

    test('CustomList should create correctly', () {
      final activities = [
        CountActivity(
          id: '1',
          title: 'Pushups',
          timestamp: DateTime.now(),
          totalCount: 100,
          doneCount: 50,
        ),
        DurationActivity(
          id: '2',
          title: 'Running',
          timestamp: DateTime.now(),
          totalDuration: 120,
          doneDuration: 60,
        ),
      ];

      final customList = CustomList(
        title: 'My Activities',
        activities: activities,
      );

      expect(customList.title, 'My Activities');
      expect(customList.activities.length, 2);
      expect(customList.activities[0].title, 'Pushups');
      expect(customList.activities[1].title, 'Running');
    });

    test('ActivityType enum should have correct values', () {
      expect(ActivityType.COUNT, ActivityType.COUNT);
      expect(ActivityType.DURATION, ActivityType.DURATION);
    });
  });
}
