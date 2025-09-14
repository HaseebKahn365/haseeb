import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:haseeb/models/activity.dart';
import 'package:haseeb/repository/activity_manager.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

void main() {
  late Directory tmpDir;
  late Box<Activity> activityBox;
  late Box<TimeActivity> timeBox;
  late Box<CountActivity> countBox;
  late ActivityManager manager;
  final format = DateFormat('yyyy-MM-dd HH:mm:ss');

  String fmt(DateTime dt) => format.format(dt);

  setUp(() async {
    // Create a temporary directory for Hive
    tmpDir = await Directory.systemTemp.createTemp('haseeb_test_');
    Hive.init(tmpDir.path);

    // Register generated adapters
    if (!Hive.isAdapterRegistered(0))
      Hive.registerAdapter(ActivityTypeAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(ActivityAdapter());
    if (!Hive.isAdapterRegistered(2))
      Hive.registerAdapter(TimeActivityAdapter());
    if (!Hive.isAdapterRegistered(3))
      Hive.registerAdapter(CountActivityAdapter());

    activityBox = await Hive.openBox<Activity>('activities_test');
    timeBox = await Hive.openBox<TimeActivity>('time_test');
    countBox = await Hive.openBox<CountActivity>('count_test');

    manager = ActivityManager(
      activityBox: activityBox,
      timeActivityBox: timeBox,
      countActivityBox: countBox,
    );
  });

  tearDown(() async {
    await activityBox.clear();
    await timeBox.clear();
    await countBox.clear();
    await Hive.close();
    try {
      await tmpDir.delete(recursive: true);
    } catch (_) {}
  });

  test('verifyDates accepts valid and rejects invalid', () {
    final good = ['2025-01-01 00:00:00', '2025-12-31 23:59:59'];
    final bad = ['2025-13-01 00:00:00', 'not-a-date'];

    expect(manager.verifyDates(good), isTrue);
    expect(manager.verifyDates(bad), isFalse);
  });

  test('addActivity and retrieve', () async {
    final id = manager.addActivity('Running', ActivityType.time);
    final stored = activityBox.get(id);
    expect(stored, isNotNull);
    expect(stored!.name, 'Running');
    expect(stored.type, ActivityType.time);
  });

  test(
    'addTimeActivityRecord and fetchBetween returns totals and csv',
    () async {
      final activityId = manager.addActivity('Focus', ActivityType.time);

      final start = DateTime.now().subtract(Duration(days: 1));
      final end = DateTime.now();

      final recordId = manager.addTimeActivityRecord(
        parentId: activityId,
        startStr: fmt(start),
        expectedEndStr: fmt(start.add(Duration(hours: 1))),
        productiveMinutes: 60,
        actualEndStr: fmt(start.add(Duration(hours: 1))),
      );

      expect(recordId, isNotNull);
      expect(timeBox.get(recordId), isNotNull);

      final res = manager.fetchBetween(
        activityId,
        fmt(start.subtract(Duration(minutes: 1))),
        fmt(end.add(Duration(minutes: 1))),
      );

      expect(res['total'], 60);
      expect(res['count'], 1);
      expect((res['csv_data'] as String).contains(recordId), isTrue);
    },
  );

  test(
    'addCountActivityRecord and fetchBetween returns totals and csv',
    () async {
      final activityId = manager.addActivity('Pushups', ActivityType.count);

      final ts = DateTime.now();

      final recordId = manager.addCountActivityRecord(
        parentId: activityId,
        timestampStr: fmt(ts),
        count: 30,
      );

      expect(recordId, isNotNull);
      expect(countBox.get(recordId), isNotNull);

      final res = manager.fetchBetween(
        activityId,
        fmt(ts.subtract(Duration(minutes: 1))),
        fmt(ts.add(Duration(minutes: 1))),
      );

      expect(res['total'], 30);
      expect(res['count'], 1);
      expect((res['csv_data'] as String).contains(recordId), isTrue);
    },
  );

  test('removeLastRecord works for time and count', () async {
    final tId = manager.addActivity('Study', ActivityType.time);
    final now = DateTime.now();

    manager.addTimeActivityRecord(
      parentId: tId,
      startStr: fmt(now.subtract(Duration(hours: 2))),
      expectedEndStr: fmt(now.subtract(Duration(hours: 1))),
      productiveMinutes: 30,
    );
    final r2 = manager.addTimeActivityRecord(
      parentId: tId,
      startStr: fmt(now.subtract(Duration(hours: 1))),
      expectedEndStr: fmt(now),
      productiveMinutes: 45,
    );

    // Should remove latest (r2)
    final removed = manager.removeLastRecord(tId);
    expect(removed, isTrue);
    expect(timeBox.get(r2), isNull);

    final cId = manager.addActivity('Squats', ActivityType.count);
    manager.addCountActivityRecord(
      parentId: cId,
      timestampStr: fmt(now.subtract(Duration(minutes: 10))),
      count: 10,
    );
    final c2 = manager.addCountActivityRecord(
      parentId: cId,
      timestampStr: fmt(now),
      count: 20,
    );

    final removed2 = manager.removeLastRecord(cId);
    expect(removed2, isTrue);
    expect(countBox.get(c2), isNull);
  });

  test('removeActivity cascades deletes records', () async {
    final aId = manager.addActivity('Meditate', ActivityType.time);
    final rec = manager.addTimeActivityRecord(
      parentId: aId,
      startStr: fmt(DateTime.now()),
      expectedEndStr: fmt(DateTime.now().add(Duration(minutes: 20))),
      productiveMinutes: 20,
    );

    expect(timeBox.get(rec), isNotNull);
    final ok = manager.removeActivity(aId);
    expect(ok, isTrue);
    expect(activityBox.get(aId), isNull);
    expect(timeBox.get(rec), isNull);
  });

  test('updateActivity updates cascade names', () async {
    final aId = manager.addActivity('OldName', ActivityType.count);
    final rec = manager.addCountActivityRecord(
      parentId: aId,
      timestampStr: fmt(DateTime.now()),
      count: 5,
    );

    expect(countBox.get(rec)!.name, 'OldName');

    final ok = manager.updateActivity(aId, 'NewName');
    expect(ok, isTrue);
    expect(activityBox.get(aId)!.name, 'NewName');
    expect(countBox.get(rec)!.name, 'NewName');
  });

  test('fetchBetween throws for invalid activity or invalid dates', () async {
    // invalid dates
    final aid = manager.addActivity('Temp', ActivityType.count);
    expect(
      () => manager.fetchBetween(aid, 'bad-date', 'also-bad'),
      throwsArgumentError,
    );

    // non-existent activity
    expect(
      () => manager.fetchBetween(
        'nope',
        fmt(DateTime.now()),
        fmt(DateTime.now()),
      ),
      throwsException,
    );
  });

  test('findActivityByKeyword returns activity json with records', () async {
    // Create a time activity with a distinctive name
    final timeId = manager.addActivity('DeepFocusSession', ActivityType.time);
    final now = DateTime.now();
    manager.addTimeActivityRecord(
      parentId: timeId,
      startStr: fmt(now.subtract(Duration(hours: 1))),
      expectedEndStr: fmt(now),
      productiveMinutes: 60,
    );

    final found = manager.findActivityByKeyword('deepfocus');
    expect(found, isA<Map<String, dynamic>>());
    expect(found['id'], timeId);
    expect(found['name'], 'DeepFocusSession');
    expect(found['type'], 'time');
    // Should not include records in the simplified response
    expect(found.containsKey('records'), isFalse);

    // Create a count activity and ensure keyword search matches case-insensitively
    final countId = manager.addActivity('MorningPushups', ActivityType.count);
    manager.addCountActivityRecord(
      parentId: countId,
      timestampStr: fmt(now),
      count: 15,
    );

    final found2 = manager.findActivityByKeyword('pushups');
    expect(found2['id'], countId);
    expect(found2['type'], 'count');
    expect(found2.containsKey('records'), isFalse);
  });
}
