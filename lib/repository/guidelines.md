Scenario 7: Cleanup Operation
User: "I don't track meditation anymore, please remove it"
Agent should:
1.	Call listAllActivities() to find meditation activity ID
2.	Call removeActivity() with that ID
3.	Confirm deletion and mention how many records were removed


FunctionDeclaration(
  'removeActivityByName',
  'Remove an activity and all its associated records by activity name',
  parameters: <String, Schema>{
    'activityName': Schema.string(description: 'Name of the activity to remove'),
    'confirmationRequired': Schema.boolean(
      description: 'Whether to require confirmation before deletion (default: true)',
      nullable: true,
    ),
  },
),
Implementation function for this tool:

dart
Future<Map<String, dynamic>> removeActivityByName({
  required String activityName,
  bool confirmationRequired = true,
}) async {
  try {
    // Step 1: Find the activity by name
    final activities = activityBox.values.where((a) => a.name.toLowerCase() == activityName.toLowerCase()).toList();
    
    if (activities.isEmpty) {
      return {
        'success': false,
        'error': 'Activity not found: $activityName',
        'suggestions': _findSimilarActivityNames(activityName),
        'action': 'not_found',
      };
    }

    final activity = activities.first;
    final activityId = activity.id;

    // Step 2: Get record count before deletion for confirmation message
    final recordCount = _getAffectedRecordsCount(activityId, activity.type);

    // If confirmation is required, return preview without actually deleting
    if (confirmationRequired) {
      return {
        'success': true,
        'action': 'confirmation_required',
        'activityId': activityId,
        'activityName': activity.name,
        'activityType': activity.type == ActivityType.time ? 'time' : 'count',
        'recordCount': recordCount,
        'message': 'Found activity "$activityName" with $recordCount records. '
                   'Are you sure you want to permanently delete this activity and all its records?',
        'confirmationPrompt': 'Please confirm deletion of "$activityName" with $recordCount records',
      };
    }

    // Step 3: Remove the activity and all associated records
    final removalSuccess = removeActivity(activityId);

    if (!removalSuccess) {
      return {
        'success': false,
        'error': 'Failed to remove activity: $activityName',
        'activityId': activityId,
        'action': 'removal_failed',
      };
    }

    return {
      'success': true,
      'action': 'removed',
      'activityId': activityId,
      'activityName': activity.name,
      'activityType': activity.type == ActivityType.time ? 'time' : 'count',
      'recordsRemoved': recordCount,
      'message': 'Successfully removed activity "$activityName" and deleted $recordCount associated records.',
    };

  } catch (e) {
    return {
      'success': false,
      'error': 'Failed to remove activity: ${e.toString()}',
      'activityName': activityName,
      'action': 'error',
    };
  }
}

// Additional function for confirmed deletion
FunctionDeclaration(
  'confirmRemoveActivity',
  'Confirm and execute the removal of an activity after preview',
  parameters: <String, Schema>{
    'activityId': Schema.string(description: 'ID of the activity to remove'),
  },
),