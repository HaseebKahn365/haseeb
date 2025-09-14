import 'package:haseeb/models/activity.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

class ActivityManager {
  final Box<Activity> activityBox;
  final Box<TimeActivity> timeActivityBox;
  final Box<CountActivity> countActivityBox;

  ActivityManager({
    required this.activityBox,
    required this.timeActivityBox,
    required this.countActivityBox,
  });

  // Date verifier method
  bool verifyDates(List<String> dateStrings) {
    final format = DateFormat('yyyy-MM-dd HH:mm:ss');

    for (String dateStr in dateStrings) {
      try {
        format.parseStrict(dateStr);
      } catch (e) {
        return false;
      }
    }
    return true;
  }

  // Fetch data between dates
  Map<String, dynamic> fetchBetween(
    String activityId,
    String startDateStr,
    String endDateStr,
  ) {
    if (!verifyDates([startDateStr, endDateStr])) {
      throw ArgumentError('Invalid date format. Use yyyy-MM-dd HH:mm:ss');
    }

    final format = DateFormat('yyyy-MM-dd HH:mm:ss');
    final startDate = format.parseStrict(startDateStr);
    final endDate = format.parseStrict(endDateStr);

    final activity = activityBox.get(activityId);
    if (activity == null) {
      throw Exception('Activity not found');
    }

    if (activity.type == ActivityType.time) {
      return _fetchTimeActivitiesBetween(activityId, startDate, endDate);
    } else {
      return _fetchCountActivitiesBetween(activityId, startDate, endDate);
    }
  }

  Map<String, dynamic> _fetchTimeActivitiesBetween(
    String activityId,
    DateTime startDate,
    DateTime endDate,
  ) {
    final activities = timeActivityBox.values
        .where(
          (activity) =>
              activity.parentId == activityId &&
              activity.start.isAfter(startDate) &&
              activity.start.isBefore(endDate),
        )
        .toList();

    int totalMinutes = activities.fold(
      0,
      (sum, activity) => sum + activity.productiveMinutes,
    );
    int recordCount = activities.length;

    String csvData =
        'record_id,start,expected_end,productive_minutes,actual_end\n';
    for (var activity in activities) {
      csvData +=
          '${activity.recordId},${activity.start},${activity.expectedEnd},'
          '${activity.productiveMinutes},${activity.actualEnd ?? ""}\n';
    }

    return {
      'total': totalMinutes,
      'count': recordCount,
      'csv_data': csvData,
      'type': 'minutes',
    };
  }

  Map<String, dynamic> _fetchCountActivitiesBetween(
    String activityId,
    DateTime startDate,
    DateTime endDate,
  ) {
    final activities = countActivityBox.values
        .where(
          (activity) =>
              activity.parentId == activityId &&
              activity.timestamp.isAfter(startDate) &&
              activity.timestamp.isBefore(endDate),
        )
        .toList();

    int totalCount = activities.fold(
      0,
      (sum, activity) => sum + activity.count,
    );
    int recordCount = activities.length;

    String csvData = 'record_id,timestamp,count\n';
    for (var activity in activities) {
      csvData +=
          '${activity.recordId},${activity.timestamp},${activity.count}\n';
    }

    return {
      'total': totalCount,
      'count': recordCount,
      'csv_data': csvData,
      'type': 'count',
    };
  }

  /// Return detailed aggregated info for an activity across several time spans.
  Map<String, dynamic> getActivityInfo(String activityId) {
    final activity = activityBox.get(activityId);
    if (activity == null) {
      throw Exception('Activity not found with ID: $activityId');
    }

    final now = DateTime.now();

    // Define date ranges (inclusive start, inclusive end)
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final weekEnd = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day + 6,
      23,
      59,
      59,
      999,
    );

    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(
      now.year,
      now.month + 1,
      1,
    ).subtract(Duration(milliseconds: 1));

    final yearStart = DateTime(now.year, 1, 1);
    final yearEnd = DateTime(now.year, 12, 31, 23, 59, 59, 999);

    if (activity.type == ActivityType.time) {
      return _getTimeActivityInfo(
        activity,
        todayStart,
        todayEnd,
        weekStart,
        weekEnd,
        monthStart,
        monthEnd,
        yearStart,
        yearEnd,
      );
    } else {
      return _getCountActivityInfo(
        activity,
        todayStart,
        todayEnd,
        weekStart,
        weekEnd,
        monthStart,
        monthEnd,
        yearStart,
        yearEnd,
      );
    }
  }

  Map<String, dynamic> _getTimeActivityInfo(
    Activity activity,
    DateTime todayStart,
    DateTime todayEnd,
    DateTime weekStart,
    DateTime weekEnd,
    DateTime monthStart,
    DateTime monthEnd,
    DateTime yearStart,
    DateTime yearEnd,
  ) {
    final timeActivities = timeActivityBox.values
        .where((record) => record.parentId == activity.id)
        .toList();

    final totalRecords = timeActivities.length;
    final totalMinutes = timeActivities.fold(
      0,
      (sum, record) => sum + record.productiveMinutes,
    );

    final todayMinutes = timeActivities
        .where(
          (record) =>
              !record.start.isBefore(todayStart) &&
              !record.start.isAfter(todayEnd),
        )
        .fold(0, (sum, record) => sum + record.productiveMinutes);

    final weekMinutes = timeActivities
        .where(
          (record) =>
              !record.start.isBefore(weekStart) &&
              !record.start.isAfter(weekEnd),
        )
        .fold(0, (sum, record) => sum + record.productiveMinutes);

    final monthMinutes = timeActivities
        .where(
          (record) =>
              !record.start.isBefore(monthStart) &&
              !record.start.isAfter(monthEnd),
        )
        .fold(0, (sum, record) => sum + record.productiveMinutes);

    final yearMinutes = timeActivities
        .where(
          (record) =>
              !record.start.isBefore(yearStart) &&
              !record.start.isAfter(yearEnd),
        )
        .fold(0, (sum, record) => sum + record.productiveMinutes);

    return {
      'activity_id': activity.id,
      'activity_name': activity.name,
      'activity_type': 'time',
      'total_records': totalRecords,
      'total_minutes': totalMinutes,
      'time_periods': {
        'today': {
          'records': timeActivities
              .where(
                (record) =>
                    !record.start.isBefore(todayStart) &&
                    !record.start.isAfter(todayEnd),
              )
              .length,
          'minutes': todayMinutes,
          'start_date': todayStart.toIso8601String(),
          'end_date': todayEnd.toIso8601String(),
        },
        'this_week': {
          'records': timeActivities
              .where(
                (record) =>
                    !record.start.isBefore(weekStart) &&
                    !record.start.isAfter(weekEnd),
              )
              .length,
          'minutes': weekMinutes,
          'start_date': weekStart.toIso8601String(),
          'end_date': weekEnd.toIso8601String(),
        },
        'this_month': {
          'records': timeActivities
              .where(
                (record) =>
                    !record.start.isBefore(monthStart) &&
                    !record.start.isAfter(monthEnd),
              )
              .length,
          'minutes': monthMinutes,
          'start_date': monthStart.toIso8601String(),
          'end_date': monthEnd.toIso8601String(),
        },
        'this_year': {
          'records': timeActivities
              .where(
                (record) =>
                    !record.start.isBefore(yearStart) &&
                    !record.start.isAfter(yearEnd),
              )
              .length,
          'minutes': yearMinutes,
          'start_date': yearStart.toIso8601String(),
          'end_date': yearEnd.toIso8601String(),
        },
      },
      'last_updated': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> _getCountActivityInfo(
    Activity activity,
    DateTime todayStart,
    DateTime todayEnd,
    DateTime weekStart,
    DateTime weekEnd,
    DateTime monthStart,
    DateTime monthEnd,
    DateTime yearStart,
    DateTime yearEnd,
  ) {
    final countActivities = countActivityBox.values
        .where((record) => record.parentId == activity.id)
        .toList();

    final totalRecords = countActivities.length;
    final totalCount = countActivities.fold(
      0,
      (sum, record) => sum + record.count,
    );

    final todayCount = countActivities
        .where(
          (record) =>
              !record.timestamp.isBefore(todayStart) &&
              !record.timestamp.isAfter(todayEnd),
        )
        .fold(0, (sum, record) => sum + record.count);

    final weekCount = countActivities
        .where(
          (record) =>
              !record.timestamp.isBefore(weekStart) &&
              !record.timestamp.isAfter(weekEnd),
        )
        .fold(0, (sum, record) => sum + record.count);

    final monthCount = countActivities
        .where(
          (record) =>
              !record.timestamp.isBefore(monthStart) &&
              !record.timestamp.isAfter(monthEnd),
        )
        .fold(0, (sum, record) => sum + record.count);

    final yearCount = countActivities
        .where(
          (record) =>
              !record.timestamp.isBefore(yearStart) &&
              !record.timestamp.isAfter(yearEnd),
        )
        .fold(0, (sum, record) => sum + record.count);

    return {
      'activity_id': activity.id,
      'activity_name': activity.name,
      'activity_type': 'count',
      'total_records': totalRecords,
      'total_count': totalCount,
      'time_periods': {
        'today': {
          'records': countActivities
              .where(
                (record) =>
                    !record.timestamp.isBefore(todayStart) &&
                    !record.timestamp.isAfter(todayEnd),
              )
              .length,
          'count': todayCount,
          'start_date': todayStart.toIso8601String(),
          'end_date': todayEnd.toIso8601String(),
        },
        'this_week': {
          'records': countActivities
              .where(
                (record) =>
                    !record.timestamp.isBefore(weekStart) &&
                    !record.timestamp.isAfter(weekEnd),
              )
              .length,
          'count': weekCount,
          'start_date': weekStart.toIso8601String(),
          'end_date': weekEnd.toIso8601String(),
        },
        'this_month': {
          'records': countActivities
              .where(
                (record) =>
                    !record.timestamp.isBefore(monthStart) &&
                    !record.timestamp.isAfter(monthEnd),
              )
              .length,
          'count': monthCount,
          'start_date': monthStart.toIso8601String(),
          'end_date': monthEnd.toIso8601String(),
        },
        'this_year': {
          'records': countActivities
              .where(
                (record) =>
                    !record.timestamp.isBefore(yearStart) &&
                    !record.timestamp.isAfter(yearEnd),
              )
              .length,
          'count': yearCount,
          'start_date': yearStart.toIso8601String(),
          'end_date': yearEnd.toIso8601String(),
        },
      },
      'last_updated': DateTime.now().toIso8601String(),
    };
  }

  // (Intentionally left no-format helper here — formatting can be done by callers if needed)

  // Add a new activity
  String addActivity(String name, ActivityType type) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final activity = Activity(id: id, name: name, type: type);
    activityBox.put(id, activity);
    return id;
  }

  // Remove an activity
  bool removeActivity(String activityId) {
    final activity = activityBox.get(activityId);
    if (activity == null) return false;

    // Cascade delete all records
    if (activity.type == ActivityType.time) {
      final records = timeActivityBox.values
          .where((record) => record.parentId == activityId)
          .toList();
      for (var record in records) {
        timeActivityBox.delete(record.recordId);
      }
    } else {
      final records = countActivityBox.values
          .where((record) => record.parentId == activityId)
          .toList();
      for (var record in records) {
        countActivityBox.delete(record.recordId);
      }
    }

    activityBox.delete(activityId);
    return true;
  }

  // Remove last inserted record for an activity
  bool removeLastRecord(String activityId) {
    final activity = activityBox.get(activityId);
    if (activity == null) return false;

    if (activity.type == ActivityType.time) {
      final records = timeActivityBox.values
          .where((record) => record.parentId == activityId)
          .toList();
      if (records.isEmpty) return false;

      records.sort((a, b) => b.start.compareTo(a.start));
      timeActivityBox.delete(records.first.recordId);
    } else {
      final records = countActivityBox.values
          .where((record) => record.parentId == activityId)
          .toList();
      if (records.isEmpty) return false;

      records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      countActivityBox.delete(records.first.recordId);
    }

    return true;
  }

  // Add a time activity record
  String addTimeActivityRecord({
    required String parentId,
    required String startStr,
    required String expectedEndStr,
    required int productiveMinutes,
    String? actualEndStr,
  }) {
    if (!verifyDates([startStr, expectedEndStr])) {
      throw ArgumentError('Invalid date format. Use yyyy-MM-dd HH:mm:ss');
    }

    if (actualEndStr != null && !verifyDates([actualEndStr])) {
      throw ArgumentError('Invalid date format. Use yyyy-MM-dd HH:mm:ss');
    }

    final format = DateFormat('yyyy-MM-dd HH:mm:ss');
    final recordId = DateTime.now().millisecondsSinceEpoch.toString();

    final activity = activityBox.get(parentId);
    if (activity == null) {
      throw Exception('Parent activity not found');
    }

    final record = TimeActivity(
      parentId: parentId,
      recordId: recordId,
      start: format.parseStrict(startStr),
      expectedEnd: format.parseStrict(expectedEndStr),
      productiveMinutes: productiveMinutes,
      actualEnd: actualEndStr != null ? format.parseStrict(actualEndStr) : null,
      name: activity.name,
    );

    timeActivityBox.put(recordId, record);
    return recordId;
  }

  // Add a count activity record
  String addCountActivityRecord({
    required String parentId,
    required String timestampStr,
    required int count,
  }) {
    if (!verifyDates([timestampStr])) {
      throw ArgumentError('Invalid date format. Use yyyy-MM-dd HH:mm:ss');
    }

    final format = DateFormat('yyyy-MM-dd HH:mm:ss');
    final recordId = DateTime.now().millisecondsSinceEpoch.toString();

    final activity = activityBox.get(parentId);
    if (activity == null) {
      throw Exception('Parent activity not found');
    }

    final record = CountActivity(
      parentId: parentId,
      recordId: recordId,
      timestamp: format.parseStrict(timestampStr),
      count: count,
      name: activity.name,
    );

    countActivityBox.put(recordId, record);
    return recordId;
  }

  // Update an activity and cascade changes
  bool updateActivity(String activityId, String newName) {
    final activity = activityBox.get(activityId);
    if (activity == null) return false;

    // Update the main activity
    final updatedActivity = Activity(
      id: activityId,
      name: newName,
      type: activity.type,
    );
    activityBox.put(activityId, updatedActivity);

    // Cascade update to all records
    if (activity.type == ActivityType.time) {
      final records = timeActivityBox.values
          .where((record) => record.parentId == activityId)
          .toList();

      for (var record in records) {
        final updatedRecord = TimeActivity(
          parentId: record.parentId,
          recordId: record.recordId,
          start: record.start,
          expectedEnd: record.expectedEnd,
          productiveMinutes: record.productiveMinutes,
          actualEnd: record.actualEnd,
          name: newName,
        );
        timeActivityBox.put(record.recordId, updatedRecord);
      }
    } else {
      final records = countActivityBox.values
          .where((record) => record.parentId == activityId)
          .toList();

      for (var record in records) {
        final updatedRecord = CountActivity(
          parentId: record.parentId,
          recordId: record.recordId,
          timestamp: record.timestamp,
          count: record.count,
          name: newName,
        );
        countActivityBox.put(record.recordId, updatedRecord);
      }
    }

    return true;
  }

  /// Find an activity by keyword (case-insensitive) and return a simplified
  /// Map containing only the activity id, name and type.
  ///
  /// Returns a Map with keys: id, name, type. Throws [Exception] if no
  /// activity matches the keyword.
  Map<String, dynamic> findActivityByKeyword(String keyword) {
    final lower = keyword.toLowerCase();

    Activity? match;
    for (var a in activityBox.values) {
      if (a.name.toLowerCase().contains(lower)) {
        match = a;
        break;
      }
    }

    if (match == null) {
      throw Exception('Activity not found');
    }

    return {
      'id': match.id,
      'name': match.name,
      'type': match.type == ActivityType.time ? 'time' : 'count',
    };
  }
}
