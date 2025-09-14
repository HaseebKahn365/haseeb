Scenario 5: Historical Analysis
User: "Show me my eating records from in this 7 days"
Agent should:
0.  find current datetime, then fine now -7
1.	Call fetchBetween() with date range eg "2023-09-01 00:00:00" to "2023-12-31 23:59:59"
2.	Analyze the CSV data returned
3.	Provide insights about eating habits during that period




FunctionDeclaration(
  'analyzeHistoricalData',
  'Analyze activity records within a specified date range and provide insights',
  parameters: <String, Schema>{
    'activityName': Schema.string(description: 'Name of the activity to analyze'),
    'timeRange': Schema.string(
      description: 'Time range to analyze: "last_7_days", "last_30_days", "last_3_months", "last_year", "custom"',
      enum: ['last_7_days', 'last_30_days', 'last_3_months', 'last_year', 'custom'],
    ),
    'customStartDate': Schema.string(
      description: 'Custom start date in format: yyyy-MM-dd HH:mm:ss (required if timeRange is "custom")',
      nullable: true,
    ),
    'customEndDate': Schema.string(
      description: 'Custom end date in format: yyyy-MM-dd HH:mm:ss (required if timeRange is "custom")',
      nullable: true,
    ),
  },
),
Implementation function for this tool:

dart
Future<Map<String, dynamic>> analyzeHistoricalData({
  required String activityName,
  required String timeRange,
  String? customStartDate,
  String? customEndDate,
}) async {
  try {
    // Step 0: Calculate date range based on timeRange parameter
    final now = DateTime.now();
    final DateFormat format = DateFormat('yyyy-MM-dd HH:mm:ss');
    
    late DateTime startDate;
    late DateTime endDate;

    switch (timeRange) {
      case 'last_7_days':
        startDate = now.subtract(const Duration(days: 7));
        endDate = now;
        break;
      case 'last_30_days':
        startDate = now.subtract(const Duration(days: 30));
        endDate = now;
        break;
      case 'last_3_months':
        startDate = DateTime(now.year, now.month - 3, now.day);
        endDate = now;
        break;
      case 'last_year':
        startDate = DateTime(now.year - 1, now.month, now.day);
        endDate = now;
        break;
      case 'custom':
        if (customStartDate == null || customEndDate == null) {
          throw Exception('Custom start and end dates are required for custom time range');
        }
        startDate = format.parseStrict(customStartDate);
        endDate = format.parseStrict(customEndDate);
        break;
      default:
        throw Exception('Invalid time range: $timeRange');
    }

    // Format dates for fetchBetween
    final startStr = format.format(startDate);
    final endStr = format.format(endDate);

    // Step 1: Find the activity
    final activities = activityBox.values.where((a) => a.name.toLowerCase() == activityName.toLowerCase()).toList();
    
    if (activities.isEmpty) {
      return {
        'success': false,
        'error': 'Activity not found: $activityName',
        'suggestions': _findSimilarActivityNames(activityName),
      };
    }

    final activity = activities.first;
    final activityId = activity.id;

    // Step 2: Fetch data between dates
    final data = fetchBetween(activityId, startStr, endStr);

    // Step 3: Analyze the data and generate insights
    final insights = _generateInsights(data, activity, startDate, endDate);

    return {
      'success': true,
      'activityName': activity.name,
      'activityType': activity.type == ActivityType.time ? 'time' : 'count',
      'timeRange': timeRange,
      'startDate': startStr,
      'endDate': endStr,
      'rawData': data,
      'insights': insights,
      'summary': _generateSummary(data, activity, startDate, endDate),
    };

  } catch (e) {
    return {
      'success': false,
      'error': 'Failed to analyze historical data: ${e.toString()}',
      'activityName': activityName,
      'timeRange': timeRange,
    };
  }
}

// Helper method to generate insights from the data
Map<String, dynamic> _generateInsights(Map<String, dynamic> data, Activity activity, DateTime startDate, DateTime endDate) {
  final activityType = activity.type == ActivityType.time ? 'time' : 'count';
  final total = data['total'];
  final recordCount = data['count'];
  final csvData = data['csv_data'];

  if (recordCount == 0) {
    return {
      'hasData': false,
      'message': 'No records found for the specified time period.',
    };
  }

  // Parse CSV data for deeper analysis
  final lines = csvData.split('\n');
  final records = lines.skip(1).where((line) => line.isNotEmpty).toList();

  if (activityType == 'time') {
    return _generateTimeInsights(records, total, recordCount, startDate, endDate);
  } else {
    return _generateCountInsights(records, total, recordCount, startDate, endDate);
  }
}

Map<String, dynamic> _generateTimeInsights(List<String> records, int totalMinutes, int recordCount, DateTime startDate, DateTime endDate) {
  final dailyAverages = <String, int>{};
  final sessionDurations = <int>[];
  final daysWithData = <String>{};

  for (final record in records) {
    final parts = record.split(',');
    if (parts.length >= 4) {
      final startTime = DateTime.parse(parts[1]);
      final duration = int.parse(parts[3]);
      
      // Track daily totals
      final dayKey = DateFormat('yyyy-MM-dd').format(startTime);
      dailyAverages[dayKey] = (dailyAverages[dayKey] ?? 0) + duration;
      daysWithData.add(dayKey);
      
      sessionDurations.add(duration);
    }
  }

  final totalDays = endDate.difference(startDate).inDays + 1;
  final daysWithRecords = daysWithData.length;
  final averagePerDay = daysWithRecords > 0 ? totalMinutes ~/ daysWithRecords : 0;
  final averagePerSession = recordCount > 0 ? totalMinutes ~/ recordCount : 0;

  return {
    'hasData': true,
    'totalMinutes': totalMinutes,
    'totalHours': (totalMinutes / 60).toStringAsFixed(1),
    'recordCount': recordCount,
    'daysWithRecords': daysWithRecords,
    'consistencyRate': '${((daysWithRecords / totalDays) * 100).toStringAsFixed(1)}%',
    'averagePerDay': averagePerDay,
    'averagePerSession': averagePerSession,
    'longestSession': sessionDurations.isNotEmpty ? sessionDurations.reduce((a, b) => a > b ? a : b) : 0,
    'shortestSession': sessionDurations.isNotEmpty ? sessionDurations.reduce((a, b) => a < b ? a : b) : 0,
    'trend': _calculateTrend(dailyAverages),
  };
}

Map<String, dynamic> _generateCountInsights(List<String> records, int totalCount, int recordCount, DateTime startDate, DateTime endDate) {
  final dailyTotals = <String, int>{};
  final dailyCounts = <int>[];
  final daysWithData = <String>{};

  for (final record in records) {
    final parts = record.split(',');
    if (parts.length >= 3) {
      final timestamp = DateTime.parse(parts[1]);
      final count = int.parse(parts[2]);
      
      // Track daily totals
      final dayKey = DateFormat('yyyy-MM-dd').format(timestamp);
      dailyTotals[dayKey] = (dailyTotals[dayKey] ?? 0) + count;
      daysWithData.add(dayKey);
      
      dailyCounts.add(count);
    }
  }

  final totalDays = endDate.difference(startDate).inDays + 1;
  final daysWithRecords = daysWithData.length;
  final averagePerDay = daysWithRecords > 0 ? totalCount ~/ daysWithRecords : 0;
  final averagePerRecord = recordCount > 0 ? totalCount ~/ recordCount : 0;

  return {
    'hasData': true,
    'totalCount': totalCount,
    'recordCount': recordCount,
    'daysWithRecords': daysWithRecords,
    'consistencyRate': '${((daysWithRecords / totalDays) * 100).toStringAsFixed(1)}%',
    'averagePerDay': averagePerDay,
    'averagePerRecord': averagePerRecord,
    'highestDailyTotal': dailyTotals.values.isNotEmpty ? dailyTotals.values.reduce((a, b) => a > b ? a : b) : 0,
    'lowestDailyTotal': dailyTotals.values.isNotEmpty ? dailyTotals.values.reduce((a, b) => a < b ? a : b) : 0,
    'trend': _calculateTrend(dailyTotals),
  };
}
