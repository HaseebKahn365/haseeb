FunctionDeclaration(
  'logDailyActivities',
  'Log multiple daily activities including count-based and time-based activities in a single call',
  parameters: <String, Schema>{
    'countActivities': Schema.array(
      description: 'List of count-based activities to log',
      items: Schema.object(
        properties: {
          'activityName': Schema.string(description: 'Name of the count activity'),
          'count': Schema.number(description: 'Count value'),
          'timestampStr': Schema.string(description: 'Timestamp in format: yyyy-MM-dd HH:mm:ss', nullable: true),
        },
      ),
    ),
    'timeActivities': Schema.array(
      description: 'List of time-based activities to log',
      items: Schema.object(
        properties: {
          'activityName': Schema.string(description: 'Name of the time activity'),
          'startStr': Schema.string(description: 'Start time in format: yyyy-MM-dd HH:mm:ss'),
          'endStr': Schema.string(description: 'End time in format: yyyy-MM-dd HH:mm:ss'),
          'productiveMinutes': Schema.number(description: 'Productive minutes spent', nullable: true),
        },
      ),
    ),
  },
),
Implementation function for this tool:

dart
Future<Map<String, dynamic>> logDailyActivities({
  required List<Map<String, dynamic>> countActivities,
  required List<Map<String, dynamic>> timeActivities,
}) async {
  final results = {
    'successful': [],
    'failed': [],
  };

  // Process count activities
  for (var activity in countActivities) {
    try {
      final activityId = _findActivityIdByName(activity['activityName'], ActivityType.count);
      final timestamp = activity['timestampStr'] ?? _getCurrentTimestamp();
      
      final recordId = addCountActivityRecord(
        parentId: activityId,
        timestampStr: timestamp,
        count: activity['count'],
      );
      
      results['successful'].add({
        'type': 'count',
        'activity': activity['activityName'],
        'recordId': recordId,
        'timestamp': timestamp,
        'count': activity['count'],
      });
    } catch (e) {
      results['failed'].add({
        'type': 'count',
        'activity': activity['activityName'],
        'error': e.toString(),
      });
    }
  }

  // Process time activities
  for (var activity in timeActivities) {
    try {
      final activityId = _findActivityIdByName(activity['activityName'], ActivityType.time);
      final productiveMinutes = activity['productiveMinutes'] ?? 
          _calculateMinutesBetween(activity['startStr'], activity['endStr']);
      
      final recordId = addTimeActivityRecord(
        parentId: activityId,
        startStr: activity['startStr'],
        expectedEndStr: activity['endStr'],
        productiveMinutes: productiveMinutes,
        actualEndStr: activity['endStr'],
      );
      
      results['successful'].add({
        'type': 'time',
        'activity': activity['activityName'],
        'recordId': recordId,
        'start': activity['startStr'],
        'end': activity['endStr'],
        'minutes': productiveMinutes,
      });
    } catch (e) {
      results['failed'].add({
        'type': 'time',
        'activity': activity['activityName'],
        'error': e.toString(),
      });
    }
  }

  return results;
}

// Helper methods
String _findActivityIdByName(String name, ActivityType type) {
  final activities = activityBox.values.where((a) => a.name == name && a.type == type).toList();
  if (activities.isEmpty) {
    throw Exception('Activity not found: $name (${type == ActivityType.time ? 'time' : 'count'})');
  }
  return activities.first.id;
}

String _getCurrentTimestamp() {
  return DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
}

int _calculateMinutesBetween(String startStr, String endStr) {
  final format = DateFormat('yyyy-MM-dd HH:mm:ss');
  final start = format.parseStrict(startStr);
  final end = format.parseStrict(endStr);
  return end.difference(start).inMinutes;
}
Example usage by the agent for the user query:

dart
// Agent would call this based on user input
final result = await logDailyActivities(
  countActivities: [
    {
      'activityName': 'Pushups',
      'count': 50,
      'timestampStr': '2023-10-05 15:30:00', // Current time
    }
  ],
  timeActivities: [
    {
      'activityName': 'Study',
      'startStr': '2023-10-05 14:00:00',
      'endStr': '2023-10-05 16:00:00',
      'productiveMinutes': 120,
    }
  ],
);