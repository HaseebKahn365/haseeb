import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:haseeb/models/activity.dart';
import 'package:haseeb/models/count_activity.dart';
import 'package:haseeb/models/custom_list.dart';
import 'package:haseeb/models/duration_activity.dart';
import 'package:haseeb/services/activity_service.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  late ActivityService activityService;
  late Box<Activity> activitiesBox;
  late Box<CustomList> customListsBox;

  setUpAll(() async {
    // Create a temporary directory for Hive
    final tempDir = Directory.systemTemp.createTempSync('hive_test');
    Hive.init(tempDir.path);

    // Register adapters
    Hive.registerAdapter(ActivityAdapter());
    Hive.registerAdapter(CountActivityAdapter());
    Hive.registerAdapter(DurationActivityAdapter());
    Hive.registerAdapter(CustomListAdapter());
  });

  setUp(() async {
    // Create a new service instance for each test
    activityService = ActivityService();

    // Initialize the service
    await activityService.init();

    // Get references to the boxes for cleanup
    activitiesBox = Hive.box<Activity>(ActivityService.activitiesBoxName);
    customListsBox = Hive.box<CustomList>(ActivityService.customListsBoxName);
  });

  tearDown(() async {
    // Clear all data after each test
    await activitiesBox.clear();
    await customListsBox.clear();
  });

  tearDownAll(() async {
    // Close all boxes after all tests
    await Hive.close();
  });

  group('ActivityService Tests', () {
    test('should initialize boxes correctly', () async {
      expect(activitiesBox.isOpen, true);
      expect(customListsBox.isOpen, true);
    });

    test('should add and get activity', () async {
      final activity = CountActivity(
        id: 'test_id',
        title: 'Test Activity',
        timestamp: DateTime.now(),
        totalCount: 100,
        doneCount: 50,
      );

      await activityService.addActivity(activity);
      final retrieved = activityService.getActivity('test_id');

      expect(retrieved, isNotNull);
      expect(retrieved!.id, 'test_id');
      expect(retrieved.title, 'Test Activity');
      expect((retrieved as CountActivity).totalCount, 100);
      expect((retrieved).doneCount, 50);
    });

    test('should return null for non-existent activity', () {
      final retrieved = activityService.getActivity('non_existent');
      expect(retrieved, isNull);
    });

    test('should update activity', () async {
      final activity = CountActivity(
        id: 'test_id',
        title: 'Test Activity',
        timestamp: DateTime.now(),
        totalCount: 100,
        doneCount: 50,
      );

      await activityService.addActivity(activity);

      // Update the activity
      activity.doneCount = 75;
      await activityService.updateActivity(activity);

      final retrieved = activityService.getActivity('test_id');
      expect((retrieved as CountActivity).doneCount, 75);
    });

    test('should delete activity', () async {
      final activity = CountActivity(
        id: 'test_id',
        title: 'Test Activity',
        timestamp: DateTime.now(),
        totalCount: 100,
        doneCount: 50,
      );

      await activityService.addActivity(activity);
      expect(activityService.getActivity('test_id'), isNotNull);

      await activityService.deleteActivity('test_id');
      expect(activityService.getActivity('test_id'), isNull);
    });

    test('should get all activities', () async {
      final activity1 = CountActivity(
        id: 'id1',
        title: 'Activity 1',
        timestamp: DateTime.now(),
        totalCount: 100,
        doneCount: 50,
      );

      final activity2 = DurationActivity(
        id: 'id2',
        title: 'Activity 2',
        timestamp: DateTime.now(),
        totalDuration: 120,
        doneDuration: 60,
      );

      await activityService.addActivity(activity1);
      await activityService.addActivity(activity2);

      final allActivities = activityService.getAllActivities();
      expect(allActivities.length, 2);
      expect(allActivities[0].id, 'id1');
      expect(allActivities[1].id, 'id2');
    });

    test('should add and get custom list', () async {
      final activities = [
        CountActivity(
          id: '1',
          title: 'Pushups',
          timestamp: DateTime.now(),
          totalCount: 100,
          doneCount: 50,
        ),
      ];

      final customList = CustomList(title: 'My List', activities: activities);

      await activityService.addCustomList(customList);
      final retrieved = activityService.getCustomList('My List');

      expect(retrieved, isNotNull);
      expect(retrieved!.title, 'My List');
      expect(retrieved.activities.length, 1);
      expect(retrieved.activities[0].title, 'Pushups');
    });

    test('should update custom list', () async {
      final customList = CustomList(title: 'My List', activities: []);

      await activityService.addCustomList(customList);

      // Update the custom list
      customList.activities.add(
        CountActivity(
          id: '1',
          title: 'New Activity',
          timestamp: DateTime.now(),
          totalCount: 50,
          doneCount: 25,
        ),
      );
      await activityService.updateCustomList(customList);

      final retrieved = activityService.getCustomList('My List');
      expect(retrieved!.activities.length, 1);
      expect(retrieved.activities[0].title, 'New Activity');
    });

    test('should delete custom list', () async {
      final customList = CustomList(title: 'My List', activities: []);

      await activityService.addCustomList(customList);
      expect(activityService.getCustomList('My List'), isNotNull);

      await activityService.deleteCustomList('My List');
      expect(activityService.getCustomList('My List'), isNull);
    });

    test('should get all custom lists', () async {
      final list1 = CustomList(title: 'List 1', activities: []);
      final list2 = CustomList(title: 'List 2', activities: []);

      await activityService.addCustomList(list1);
      await activityService.addCustomList(list2);

      final allLists = activityService.getAllCustomLists();
      expect(allLists.length, 2);
      expect(allLists.map((list) => list.title), contains('List 1'));
      expect(allLists.map((list) => list.title), contains('List 2'));
    });

    test('should persist data across service instances', () async {
      final activity = CountActivity(
        id: 'persistent_id',
        title: 'Persistent Activity',
        timestamp: DateTime.now(),
        totalCount: 100,
        doneCount: 50,
      );

      await activityService.addActivity(activity);

      // Create a new service instance
      final newService = ActivityService();
      await newService.init();

      final retrieved = newService.getActivity('persistent_id');
      expect(retrieved, isNotNull);
      expect(retrieved!.title, 'Persistent Activity');
    });
  });
}
