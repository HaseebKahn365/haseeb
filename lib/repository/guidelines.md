FunctionDeclaration(
  'listActivities',
  'Get a simple list of all available activities with their name, ID, and type',
  parameters: <String, Schema>{},
),



Implementation function for this tool:

dart
Future<Map<String, dynamic>> listActivities() async {
  try {
    final activities = activityBox.values.toList();
    
    final activityList = activities.map((activity) => {
      'id': activity.id,
      'name': activity.name,
      'type': activity.type == ActivityType.time ? 'time' : 'count',
    }).toList();

    return {
      'success': true,
      'totalActivities': activities.length,
      'activities': activityList,
      'timeBasedCount': activities.where((a) => a.type == ActivityType.time).length,
      'countBasedCount': activities.where((a) => a.type == ActivityType.count).length,
      'message': 'Found ${activities.length} activities: '
                 '${activities.where((a) => a.type == ActivityType.time).length} time-based, '
                 '${activities.where((a) => a.type == ActivityType.count).length} count-based',
    };

  } catch (e) {
    return {
      'success': false,
      'error': 'Failed to list activities: ${e.toString()}',
      'totalActivities': 0,
      'activities': [],
    };
  }
}