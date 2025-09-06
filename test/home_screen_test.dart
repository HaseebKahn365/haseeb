import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haseeb/models/activity.dart';
import 'package:haseeb/models/count_activity.dart';
import 'package:haseeb/models/custom_list.dart';
import 'package:haseeb/models/duration_activity.dart';
import 'package:haseeb/screens/home_screen.dart';
import 'package:haseeb/services/activity_service.dart';
import 'package:hive/hive.dart';

void main() {
  late ActivityService activityService;

  setUpAll(() async {
    // Create a temporary directory for Hive
    final tempDir = Directory.systemTemp.createTempSync(
      'hive_integration_test',
    );
    Hive.init(tempDir.path);

    // Register adapters
    Hive.registerAdapter(ActivityAdapter());
    Hive.registerAdapter(CountActivityAdapter());
    Hive.registerAdapter(DurationActivityAdapter());
    Hive.registerAdapter(CustomListAdapter());

    // Initialize service
    activityService = ActivityService();
    await activityService.init();
  });

  tearDownAll(() async {
    await Hive.close();
  });

  testWidgets('HomeScreen displays activities correctly', (
    WidgetTester tester,
  ) async {
    // Add sample data
    final pushups = CountActivity(
      id: 'pushups',
      title: 'Pushups',
      timestamp: DateTime.now(),
      totalCount: 100,
      doneCount: 75,
    );

    final running = DurationActivity(
      id: 'running',
      title: 'Running',
      timestamp: DateTime.now(),
      totalDuration: 120,
      doneDuration: 120,
    );

    final yoga = DurationActivity(
      id: 'yoga',
      title: 'Yoga',
      timestamp: DateTime.now(),
      totalDuration: 60,
      doneDuration: 60,
    );

    await activityService.addActivity(pushups);
    await activityService.addActivity(running);
    await activityService.addActivity(yoga);

    // Build the HomeScreen
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    // Wait for the widget to build and load data
    await tester.pumpAndSettle();

    // Verify that the activities are displayed
    expect(find.text('Pushups'), findsOneWidget);
    expect(find.text('Running'), findsOneWidget);
    expect(find.text('Yoga'), findsOneWidget);

    // Verify ongoing vs completed sections
    expect(find.text('Ongoing Activities'), findsOneWidget);
    expect(find.text('Completed Activities'), findsOneWidget);

    // Pushups should be in ongoing (75 < 100)
    expect(find.textContaining('75'), findsOneWidget);
    expect(find.textContaining('100'), findsOneWidget);

    // Running and Yoga should be in completed (120 == 120, 60 == 60)
    expect(find.textContaining('120'), findsWidgets); // Should find multiple
    expect(find.textContaining('60'), findsWidgets); // Should find multiple
  });

  testWidgets('HomeScreen shows radial bar', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    await tester.pumpAndSettle();

    // Verify radial bar title is displayed
    expect(find.text("Today's Tracked Time"), findsOneWidget);
  });
}
