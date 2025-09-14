import 'dart:developer' as dev;

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
    dev.log(
      'ActivityManager.verifyDates: Starting date verification for ${dateStrings.length} dates',
    );
    final format = DateFormat('yyyy-MM-dd HH:mm:ss');

    for (String dateStr in dateStrings) {
      try {
        dev.log(
          'ActivityManager.verifyDates: Validating date string: $dateStr',
        );
        format.parseStrict(dateStr);
        dev.log('ActivityManager.verifyDates: Date string is valid: $dateStr');
      } catch (e) {
        dev.log(
          'ActivityManager.verifyDates: Invalid date string: $dateStr, error: $e',
        );
        return false;
      }
    }
    dev.log('ActivityManager.verifyDates: All dates are valid');
    return true;
  }

  // Fetch data between dates
  Map<String, dynamic> fetchBetween(
    String activityId,
    String startDateStr,
    String endDateStr,
  ) {
    dev.log(
      'ActivityManager.fetchBetween: Starting fetch for activity: $activityId, from: $startDateStr to: $endDateStr',
    );

    if (!verifyDates([startDateStr, endDateStr])) {
      dev.log('ActivityManager.fetchBetween: Date verification failed');
      throw ArgumentError('Invalid date format. Use yyyy-MM-dd HH:mm:ss');
    }

    final format = DateFormat('yyyy-MM-dd HH:mm:ss');
    final startDate = format.parseStrict(startDateStr);
    final endDate = format.parseStrict(endDateStr);
    dev.log(
      'ActivityManager.fetchBetween: Parsed dates - start: $startDate, end: $endDate',
    );

    final activity = activityBox.get(activityId);
    if (activity == null) {
      dev.log(
        'ActivityManager.fetchBetween: Activity not found with ID: $activityId',
      );
      throw Exception('Activity not found');
    }

    dev.log(
      'ActivityManager.fetchBetween: Found activity: ${activity.name}, type: ${activity.type}',
    );

    if (activity.type == ActivityType.time) {
      dev.log('ActivityManager.fetchBetween: Fetching time activities');
      return _fetchTimeActivitiesBetween(activityId, startDate, endDate);
    } else {
      dev.log('ActivityManager.fetchBetween: Fetching count activities');
      return _fetchCountActivitiesBetween(activityId, startDate, endDate);
    }
  }

  Map<String, dynamic> _fetchTimeActivitiesBetween(
    String activityId,
    DateTime startDate,
    DateTime endDate,
  ) {
    dev.log(
      'ActivityManager._fetchTimeActivitiesBetween: Fetching time activities for $activityId between $startDate and $endDate',
    );

    final activities = timeActivityBox.values
        .where(
          (activity) =>
              activity.parentId == activityId &&
              activity.start.isAfter(startDate) &&
              activity.start.isBefore(endDate),
        )
        .toList();

    dev.log(
      'ActivityManager._fetchTimeActivitiesBetween: Found ${activities.length} time activities',
    );

    int totalMinutes = activities.fold(
      0,
      (sum, activity) => sum + activity.productiveMinutes,
    );
    int recordCount = activities.length;

    dev.log(
      'ActivityManager._fetchTimeActivitiesBetween: Total minutes: $totalMinutes, Record count: $recordCount',
    );

    String csvData =
        'record_id,start,expected_end,productive_minutes,actual_end\n';
    for (var activity in activities) {
      csvData +=
          '${activity.recordId},${activity.start},${activity.expectedEnd},'
          '${activity.productiveMinutes},${activity.actualEnd ?? ""}\n';
    }

    dev.log(
      'ActivityManager._fetchTimeActivitiesBetween: Generated CSV with ${activities.length} rows',
    );

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
    dev.log(
      'ActivityManager._fetchCountActivitiesBetween: Fetching count activities for $activityId between $startDate and $endDate',
    );

    final activities = countActivityBox.values
        .where(
          (activity) =>
              activity.parentId == activityId &&
              activity.timestamp.isAfter(startDate) &&
              activity.timestamp.isBefore(endDate),
        )
        .toList();

    dev.log(
      'ActivityManager._fetchCountActivitiesBetween: Found ${activities.length} count activities',
    );

    int totalCount = activities.fold(
      0,
      (sum, activity) => sum + activity.count,
    );
    int recordCount = activities.length;

    dev.log(
      'ActivityManager._fetchCountActivitiesBetween: Total count: $totalCount, Record count: $recordCount',
    );

    String csvData = 'record_id,timestamp,count\n';
    for (var activity in activities) {
      csvData +=
          '${activity.recordId},${activity.timestamp},${activity.count}\n';
    }

    dev.log(
      'ActivityManager._fetchCountActivitiesBetween: Generated CSV with ${activities.length} rows',
    );

    return {
      'total': totalCount,
      'count': recordCount,
      'csv_data': csvData,
      'type': 'count',
    };
  }

  /// Return detailed aggregated info for an activity across several time spans.
  Map<String, dynamic> getActivityInfo(String activityId) {
    dev.log(
      'ActivityManager.getActivityInfo: Getting activity info for ID: $activityId',
    );

    final activity = activityBox.get(activityId);
    if (activity == null) {
      dev.log(
        'ActivityManager.getActivityInfo: Activity not found with ID: $activityId',
      );
      throw Exception('Activity not found with ID: $activityId');
    }

    dev.log(
      'ActivityManager.getActivityInfo: Found activity: ${activity.name}, type: ${activity.type}',
    );

    final now = DateTime.now();
    dev.log('ActivityManager.getActivityInfo: Current time: $now');

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

    dev.log(
      'ActivityManager.getActivityInfo: Date ranges - Today: $todayStart to $todayEnd, Week: $weekStart to $weekEnd, Month: $monthStart to $monthEnd, Year: $yearStart to $yearEnd',
    );

    if (activity.type == ActivityType.time) {
      dev.log('ActivityManager.getActivityInfo: Processing time activity');
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
      dev.log('ActivityManager.getActivityInfo: Processing count activity');
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
    dev.log(
      'ActivityManager._getTimeActivityInfo: Getting time activity info for ${activity.name} (${activity.id})',
    );

    final timeActivities = timeActivityBox.values
        .where((record) => record.parentId == activity.id)
        .toList();

    dev.log(
      'ActivityManager._getTimeActivityInfo: Found ${timeActivities.length} time activity records',
    );

    final totalRecords = timeActivities.length;
    final totalMinutes = timeActivities.fold(
      0,
      (sum, record) => sum + record.productiveMinutes,
    );

    dev.log(
      'ActivityManager._getTimeActivityInfo: Total records: $totalRecords, Total minutes: $totalMinutes',
    );

    final todayMinutes = timeActivities
        .where(
          (record) =>
              !record.start.isBefore(todayStart) &&
              !record.start.isAfter(todayEnd),
        )
        .fold(0, (sum, record) => sum + record.productiveMinutes);

    dev.log(
      'ActivityManager._getTimeActivityInfo: Today minutes: $todayMinutes',
    );

    final weekMinutes = timeActivities
        .where(
          (record) =>
              !record.start.isBefore(weekStart) &&
              !record.start.isAfter(weekEnd),
        )
        .fold(0, (sum, record) => sum + record.productiveMinutes);

    dev.log('ActivityManager._getTimeActivityInfo: Week minutes: $weekMinutes');

    final monthMinutes = timeActivities
        .where(
          (record) =>
              !record.start.isBefore(monthStart) &&
              !record.start.isAfter(monthEnd),
        )
        .fold(0, (sum, record) => sum + record.productiveMinutes);

    dev.log(
      'ActivityManager._getTimeActivityInfo: Month minutes: $monthMinutes',
    );

    final yearMinutes = timeActivities
        .where(
          (record) =>
              !record.start.isBefore(yearStart) &&
              !record.start.isAfter(yearEnd),
        )
        .fold(0, (sum, record) => sum + record.productiveMinutes);

    dev.log('ActivityManager._getTimeActivityInfo: Year minutes: $yearMinutes');

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
    dev.log(
      'ActivityManager._getCountActivityInfo: Getting count activity info for ${activity.name} (${activity.id})',
    );

    final countActivities = countActivityBox.values
        .where((record) => record.parentId == activity.id)
        .toList();

    dev.log(
      'ActivityManager._getCountActivityInfo: Found ${countActivities.length} count activity records',
    );

    final totalRecords = countActivities.length;
    final totalCount = countActivities.fold(
      0,
      (sum, record) => sum + record.count,
    );

    dev.log(
      'ActivityManager._getCountActivityInfo: Total records: $totalRecords, Total count: $totalCount',
    );

    final todayCount = countActivities
        .where(
          (record) =>
              !record.timestamp.isBefore(todayStart) &&
              !record.timestamp.isAfter(todayEnd),
        )
        .fold(0, (sum, record) => sum + record.count);

    dev.log('ActivityManager._getCountActivityInfo: Today count: $todayCount');

    final weekCount = countActivities
        .where(
          (record) =>
              !record.timestamp.isBefore(weekStart) &&
              !record.timestamp.isAfter(weekEnd),
        )
        .fold(0, (sum, record) => sum + record.count);

    dev.log('ActivityManager._getCountActivityInfo: Week count: $weekCount');

    final monthCount = countActivities
        .where(
          (record) =>
              !record.timestamp.isBefore(monthStart) &&
              !record.timestamp.isAfter(monthEnd),
        )
        .fold(0, (sum, record) => sum + record.count);

    dev.log('ActivityManager._getCountActivityInfo: Month count: $monthCount');

    final yearCount = countActivities
        .where(
          (record) =>
              !record.timestamp.isBefore(yearStart) &&
              !record.timestamp.isAfter(yearEnd),
        )
        .fold(0, (sum, record) => sum + record.count);

    dev.log('ActivityManager._getCountActivityInfo: Year count: $yearCount');

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
    dev.log(
      'ActivityManager.addActivity: Adding new activity - name: $name, type: $type',
    );
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final activity = Activity(id: id, name: name, type: type);
    activityBox.put(id, activity);
    dev.log('ActivityManager.addActivity: Activity added with ID: $id');
    return id;
  }

  // Remove an activity
  bool removeActivity(String activityId) {
    dev.log(
      'ActivityManager.removeActivity: Removing activity with ID: $activityId',
    );
    final activity = activityBox.get(activityId);
    if (activity == null) {
      dev.log('ActivityManager.removeActivity: Activity not found');
      return false;
    }

    dev.log(
      'ActivityManager.removeActivity: Found activity: ${activity.name}, type: ${activity.type}',
    );

    // Cascade delete all records
    if (activity.type == ActivityType.time) {
      final records = timeActivityBox.values
          .where((record) => record.parentId == activityId)
          .toList();
      dev.log(
        'ActivityManager.removeActivity: Deleting ${records.length} time activity records',
      );
      for (var record in records) {
        timeActivityBox.delete(record.recordId);
      }
    } else {
      final records = countActivityBox.values
          .where((record) => record.parentId == activityId)
          .toList();
      dev.log(
        'ActivityManager.removeActivity: Deleting ${records.length} count activity records',
      );
      for (var record in records) {
        countActivityBox.delete(record.recordId);
      }
    }

    activityBox.delete(activityId);
    dev.log(
      'ActivityManager.removeActivity: Activity and all records deleted successfully',
    );
    return true;
  }

  // Remove last inserted record for an activity
  bool removeLastRecord(String activityId) {
    dev.log(
      'ActivityManager.removeLastRecord: Removing last record for activity ID: $activityId',
    );
    final activity = activityBox.get(activityId);
    if (activity == null) {
      dev.log('ActivityManager.removeLastRecord: Activity not found');
      return false;
    }

    if (activity.type == ActivityType.time) {
      final records = timeActivityBox.values
          .where((record) => record.parentId == activityId)
          .toList();
      if (records.isEmpty) {
        dev.log(
          'ActivityManager.removeLastRecord: No time activity records found',
        );
        return false;
      }

      records.sort((a, b) => b.start.compareTo(a.start));
      dev.log(
        'ActivityManager.removeLastRecord: Deleting time activity record: ${records.first.recordId}',
      );
      timeActivityBox.delete(records.first.recordId);
    } else {
      final records = countActivityBox.values
          .where((record) => record.parentId == activityId)
          .toList();
      if (records.isEmpty) {
        dev.log(
          'ActivityManager.removeLastRecord: No count activity records found',
        );
        return false;
      }

      records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      dev.log(
        'ActivityManager.removeLastRecord: Deleting count activity record: ${records.first.recordId}',
      );
      countActivityBox.delete(records.first.recordId);
    }

    dev.log(
      'ActivityManager.removeLastRecord: Last record removed successfully',
    );
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
    dev.log(
      'ActivityManager.addTimeActivityRecord: Adding time activity record for parent: $parentId',
    );
    dev.log(
      'ActivityManager.addTimeActivityRecord: Start: $startStr, Expected end: $expectedEndStr, Minutes: $productiveMinutes, Actual end: $actualEndStr',
    );

    if (!verifyDates([startStr, expectedEndStr])) {
      dev.log(
        'ActivityManager.addTimeActivityRecord: Date verification failed',
      );
      throw ArgumentError('Invalid date format. Use yyyy-MM-dd HH:mm:ss');
    }

    if (actualEndStr != null && !verifyDates([actualEndStr])) {
      dev.log(
        'ActivityManager.addTimeActivityRecord: Actual end date verification failed',
      );
      throw ArgumentError('Invalid date format. Use yyyy-MM-dd HH:mm:ss');
    }

    final format = DateFormat('yyyy-MM-dd HH:mm:ss');
    final recordId = DateTime.now().millisecondsSinceEpoch.toString();
    dev.log(
      'ActivityManager.addTimeActivityRecord: Generated record ID: $recordId',
    );

    final activity = activityBox.get(parentId);
    if (activity == null) {
      dev.log(
        'ActivityManager.addTimeActivityRecord: Parent activity not found',
      );
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
    dev.log(
      'ActivityManager.addTimeActivityRecord: Time activity record added successfully',
    );
    return recordId;
  }

  // Add a count activity record
  String addCountActivityRecord({
    required String parentId,
    required String timestampStr,
    required int count,
  }) {
    dev.log(
      'ActivityManager.addCountActivityRecord: Adding count activity record for parent: $parentId',
    );
    dev.log(
      'ActivityManager.addCountActivityRecord: Timestamp: $timestampStr, Count: $count',
    );

    if (!verifyDates([timestampStr])) {
      dev.log(
        'ActivityManager.addCountActivityRecord: Date verification failed',
      );
      throw ArgumentError('Invalid date format. Use yyyy-MM-dd HH:mm:ss');
    }

    final format = DateFormat('yyyy-MM-dd HH:mm:ss');
    final recordId = DateTime.now().millisecondsSinceEpoch.toString();
    dev.log(
      'ActivityManager.addCountActivityRecord: Generated record ID: $recordId',
    );

    final activity = activityBox.get(parentId);
    if (activity == null) {
      dev.log(
        'ActivityManager.addCountActivityRecord: Parent activity not found',
      );
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
    dev.log(
      'ActivityManager.addCountActivityRecord: Count activity record added successfully',
    );
    return recordId;
  }

  // Update an activity and cascade changes
  bool updateActivity(String activityId, String newName) {
    dev.log(
      'ActivityManager.updateActivity: Updating activity $activityId to new name: $newName',
    );
    final activity = activityBox.get(activityId);
    if (activity == null) {
      dev.log('ActivityManager.updateActivity: Activity not found');
      return false;
    }

    // Update the main activity
    final updatedActivity = Activity(
      id: activityId,
      name: newName,
      type: activity.type,
    );
    activityBox.put(activityId, updatedActivity);
    dev.log('ActivityManager.updateActivity: Main activity updated');

    // Cascade update to all records
    if (activity.type == ActivityType.time) {
      final records = timeActivityBox.values
          .where((record) => record.parentId == activityId)
          .toList();

      dev.log(
        'ActivityManager.updateActivity: Updating ${records.length} time activity records',
      );
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

      dev.log(
        'ActivityManager.updateActivity: Updating ${records.length} count activity records',
      );
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

    dev.log(
      'ActivityManager.updateActivity: Activity and all records updated successfully',
    );
    return true;
  }

  /// Find an activity by keyword (case-insensitive) and return a simplified
  /// Map containing only the activity id, name and type.
  ///
  /// Returns a Map with keys: id, name, type. Throws [Exception] if no
  /// activity matches the keyword.
  Map<String, dynamic> findActivityByKeyword(String keyword) {
    dev.log(
      'ActivityManager.findActivityByKeyword: Searching for activity with keyword: $keyword',
    );
    final lower = keyword.toLowerCase();

    Activity? match;
    for (var a in activityBox.values) {
      if (a.name.toLowerCase().contains(lower)) {
        match = a;
        dev.log(
          'ActivityManager.findActivityByKeyword: Found matching activity: ${a.name} (${a.id})',
        );
        break;
      }
    }

    if (match == null) {
      dev.log(
        'ActivityManager.findActivityByKeyword: No activity found matching keyword: $keyword',
      );
      throw Exception('Activity not found');
    }

    final result = {
      'id': match.id,
      'name': match.name,
      'type': match.type == ActivityType.time ? 'time' : 'count',
    };
    dev.log(
      'ActivityManager.findActivityByKeyword: Returning activity: $result',
    );
    return result;
  }
}
