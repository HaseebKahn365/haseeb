Scenario 4: Data Correction
User: "I made a mistake in my last study entry"
Agent should:
1.	Call removeLastRecord() for the study activity
2.	Ask for correct details to add new record
3.	Call addTimeActivityRecord() with corrected information


Future<Map<String, dynamic>> correctLastActivityRecord({
  required String activityName,
  Map<String, dynamic>? correctionDetails,
}) async {
  try {
    // Step 1: Find the activity
    final activities = activityBox.values.where((a) => a.name.toLowerCase() == activityName.toLowerCase()).toList();
    
    if (activities.isEmpty) {
      return {
        'success': false,
        'action': 'find_activity',
        'error': 'Activity not found: $activityName',
        'suggestions': _findSimilarActivityNames(activityName),
      };
    }

    final activity = activities.first;
    final activityId = activity.id;

    // Step 2: Remove the last record
    final removalSuccess = removeLastRecord(activityId);
    
    if (!removalSuccess) {
      return {
        'success': false,
        'action': 'remove_record',
        'error': 'No records found to remove for $activityName',
        'activityId': activityId,
      };
    }

    // Step 3: If correction details provided, add corrected record
    Map<String, dynamic>? addedRecord;
    if (correctionDetails != null) {
      addedRecord = await _addCorrectedRecord(activity, correctionDetails);
    }

    return {
      'success': true,
      'action': removalSuccess && addedRecord != null ? 'remove_and_add' : 'remove_only',
      'activityName': activity.name,
      'activityType': activity.type == ActivityType.time ? 'time' : 'count',
      'activityId': activityId,
      'removedRecord': true,
      'addedRecord': addedRecord,
      'message': _generateSuccessMessage(activity, correctionDetails != null),
    };

  } catch (e) {
    return {
      'success': false,
      'action': 'error',
      'error': 'Failed to correct record: ${e.toString()}',
      'activityName': activityName,
    };
  }
}

// Helper method to add corrected record
Future<Map<String, dynamic>?> _addCorrectedRecord(Activity activity, Map<String, dynamic> correctionDetails) async {
  try {
    if (activity.type == ActivityType.time) {
      // Validate required fields for time activity
      if (correctionDetails['newStartStr'] == null || correctionDetails['newEndStr'] == null) {
        throw Exception('Missing required fields for time activity: startStr and endStr');
      }

      final productiveMinutes = correctionDetails['newProductiveMinutes'] ?? 
          _calculateMinutesBetween(correctionDetails['newStartStr'], correctionDetails['newEndStr']);

      final recordId = addTimeActivityRecord(
        parentId: activity.id,
        startStr: correctionDetails['newStartStr'],
        expectedEndStr: correctionDetails['newEndStr'],
        productiveMinutes: productiveMinutes,
        actualEndStr: correctionDetails['newEndStr'],
      );

      return {
        'type': 'time',
        'recordId': recordId,
        'start': correctionDetails['newStartStr'],
        'end': correctionDetails['newEndStr'],
        'productiveMinutes': productiveMinutes,
      };
    } else {
      // Count activity
      final timestamp = correctionDetails['newTimestampStr'] ?? _getCurrentTimestamp();
      
      if (correctionDetails['newCount'] == null) {
        throw Exception('Missing required field for count activity: count');
      }

      final recordId = addCountActivityRecord(
        parentId: activity.id,
        timestampStr: timestamp,
        count: correctionDetails['newCount'],
      );

      return {
        'type': 'count',
        'recordId': recordId,
        'timestamp': timestamp,
        'count': correctionDetails['newCount'],
      };
    }
  } catch (e) {
    throw Exception('Failed to add corrected record: ${e.toString()}');
  }
}

// Helper method to generate success message
String _generateSuccessMessage(Activity activity, bool recordAdded) {
  final activityType = activity.type == ActivityType.time ? 'time' : 'count';
  
  if (recordAdded) {
    return 'Successfully removed the last ${activity.name} record and added the corrected version.';
  } else {
    return 'Successfully removed the last ${activity.name} record. '
           'You can now add the correct information when ready.';
  }
}

// Helper methods (reuse from previous implementation)
String _getCurrentTimestamp() {
  return DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
}

int _calculateMinutesBetween(String startStr, String endStr) {
  final format = DateFormat('yyyy-MM-dd HH:mm:ss');
  final start = format.parseStrict(startStr);
  final end = format.parseStrict(endStr);
  return end.difference(start).inMinutes;
}

List<String> _findSimilarActivityNames(String searchName) {
  final allNames = activityBox.values.map((a) => a.name).toList();
  final searchLower = searchName.toLowerCase();
  
  return allNames.where((name) => 
    name.toLowerCase().contains(searchLower) ||
    searchLower.contains(name.toLowerCase())
  ).toList();
}

