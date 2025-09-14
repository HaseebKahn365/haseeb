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
