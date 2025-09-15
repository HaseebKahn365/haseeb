import 'package:firebase_ai/firebase_ai.dart';

final toolsForLLM = [
  Tool.functionDeclarations([
    FunctionDeclaration(
      'markdownWidget',
      'Displays a formatted markdown message showing the calculation',
      parameters: <String, Schema>{
        'numberA': Schema.number(
          description: 'First number in the calculation',
        ),
        'numberB': Schema.number(
          description: 'Second number in the calculation',
        ),
        'result': Schema.number(description: 'The result of the calculation'),
      },
    ),
    FunctionDeclaration(
      'renderRadialBar',
      'Render a radial progress bar widget (total, done, title)',
      parameters: <String, Schema>{
        'total': Schema.number(description: 'Total target value'),
        'done': Schema.number(description: 'Completed value'),
        'title': Schema.string(description: 'Title to show on the radial bar'),
      },
    ),
    FunctionDeclaration(
      'renderActivityCard',
      'Render an activity summary card (title, total, done, timestamp, type)',
      parameters: <String, Schema>{
        'title': Schema.string(description: 'Activity title'),
        'total': Schema.number(description: 'Total target'),
        'done': Schema.number(description: 'Completed value'),
        'timestamp': Schema.string(
          description: 'ISO 8601 timestamp or epoch millis',
        ),
        'type': Schema.string(description: "'COUNT' or 'DURATION'"),
      },
    ),
    FunctionDeclaration(
      'currentDateTime',
      'Returns the current server datetime in ISO 8601 format',
      parameters: <String, Schema>{
        'timezone': Schema.string(
          description:
              'Optional timezone identifier, e.g., "Asia/Karachi" or "PKT"',
        ),
        'format': Schema.string(
          description: 'Optional format hint, e.g., "iso", "human"',
        ),
      },
    ),
    FunctionDeclaration(
      'addActivity',
      'Create a new activity with specified name and type',
      parameters: <String, Schema>{
        'name': Schema.string(description: 'Name of the activity'),
        'type': Schema.string(
          description: 'Type of activity: "time" or "count"',
        ),
      },
    ),
    FunctionDeclaration(
      'createWishlistItem',
      'Create a new wishlist item (goal) for the user.',
      parameters: <String, Schema>{
        'title': Schema.string(
          description: 'Title of the wishlist item (goal)',
        ),
        'description': Schema.string(description: 'Description of the goal'),
        'dueDateStr': Schema.string(
          description: 'Due date in format: yyyy-MM-dd',
        ),
        'type': Schema.string(
          description: 'Type of goal: "count" or "duration"',
        ),
        'count': Schema.number(
          description: 'Target count value for count-based goals',
          nullable: true,
        ),
        'duration': Schema.number(
          description: 'Target duration in minutes for duration-based goals',
          nullable: true,
        ),
      },
    ),
    FunctionDeclaration(
      'logDailyActivities',
      'Log multiple daily activities including count-based and time-based activities in a single call',
      parameters: <String, Schema>{
        'countActivities': Schema.array(
          description: 'List of count-based activities to log',
          items: Schema.object(
            properties: {
              'activityName': Schema.string(
                description: 'Name of the count activity',
              ),
              'count': Schema.number(description: 'Count value'),
              'timestampStr': Schema.string(
                description: 'Timestamp in format: yyyy-MM-dd HH:mm:ss',
                nullable: true,
              ),
            },
          ),
        ),
        'timeActivities': Schema.array(
          description: 'List of time-based activities to log',
          items: Schema.object(
            properties: {
              'activityName': Schema.string(
                description: 'Name of the time activity',
              ),
              'startStr': Schema.string(
                description: 'Start time in format: yyyy-MM-dd HH:mm:ss',
              ),
              'endStr': Schema.string(
                description: 'End time in format: yyyy-MM-dd HH:mm:ss',
              ),
              'productiveMinutes': Schema.number(
                description: 'Productive minutes spent',
                nullable: true,
              ),
            },
          ),
        ),
      },
    ),
    FunctionDeclaration(
      'checkActivityProgress',
      'Get progress information for a specific activity and timeframe, returns natural language explanation',
      parameters: <String, Schema>{
        'activityName': Schema.string(
          description: 'Name of the activity to check progress for',
        ),
        'timeframe': Schema.string(
          description:
              'Time period to check: "today", "this_week", "this_month", "this_year", or "all_time"',
        ),
      },
    ),
    FunctionDeclaration(
      'analyzeHistoricalData',
      'Analyze activity records within a specified date range and provide insights',
      parameters: <String, Schema>{
        'activityName': Schema.string(
          description: 'Name of the activity to analyze',
        ),
        'timeRange': Schema.string(
          description:
              'Time range to analyze: last_7_days, last_30_days, last_3_months, last_year, or custom',
        ),
        'customStartDate': Schema.string(
          description:
              'Custom start date in format: yyyy-MM-dd HH:mm:ss (required if timeRange is "custom")',
          nullable: true,
        ),
        'customEndDate': Schema.string(
          description:
              'Custom end date in format: yyyy-MM-dd HH:mm:ss (required if timeRange is "custom")',
          nullable: true,
        ),
        'days': Schema.number(
          description:
              'Optional: number of days back from now to analyze (overrides timeRange when provided)',
          nullable: true,
        ),
      },
    ),
    FunctionDeclaration(
      'renderMarkdown',
      'Render markdown-formatted content inline',
      parameters: <String, Schema>{
        'content': Schema.string(description: 'Markdown content to render'),
      },
    ),
    FunctionDeclaration(
      'initiateDataExport',
      'Render an export-data widget (CSV data + filename)',
      parameters: <String, Schema>{
        'data': Schema.string(description: 'CSV formatted data'),
        'filename': Schema.string(description: 'Filename to use for export'),
      },
    ),
    FunctionDeclaration(
      'correctLastActivityRecord',
      'Remove the last record for an activity and optionally add a corrected version',
      parameters: <String, Schema>{
        'activityName': Schema.string(
          description: 'Name of the activity to correct',
        ),
        'correctionDetails': Schema.object(
          description: 'Optional correction details to add after removal',
          nullable: true,
          properties: {
            'newStartStr': Schema.string(
              description:
                  'New start time for time activities (yyyy-MM-dd HH:mm:ss)',
              nullable: true,
            ),
            'newEndStr': Schema.string(
              description:
                  'New end time for time activities (yyyy-MM-dd HH:mm:ss)',
              nullable: true,
            ),
            'newProductiveMinutes': Schema.number(
              description: 'New productive minutes for time activities',
              nullable: true,
            ),
            'newTimestampStr': Schema.string(
              description:
                  'New timestamp for count activities (yyyy-MM-dd HH:mm:ss)',
              nullable: true,
            ),
            'newCount': Schema.number(
              description: 'New count value for count activities',
              nullable: true,
            ),
          },
        ),
      },
    ),
    FunctionDeclaration(
      'updateActivity',
      'Update the name of an existing activity. Uses ActivityManager.updateActivity under the hood',
      parameters: <String, Schema>{
        'currentName': Schema.string(
          description:
              'The current (or partial) name of the activity to update',
        ),
        'newName': Schema.string(
          description: 'The new name to assign to the activity',
        ),
      },
    ),
    FunctionDeclaration(
      'updateWishlistItem',
      'Update fields of an existing wishlist item (goal)',
      parameters: <String, Schema>{
        'id': Schema.string(description: 'ID of the wishlist item to update'),
        'updates': Schema.object(
          description: 'Fields to update',
          properties: {
            'title': Schema.string(description: 'New title', nullable: true),
            'description': Schema.string(
              description: 'New description',
              nullable: true,
            ),
            'dueDateStr': Schema.string(
              description: 'New due date in format: yyyy-MM-dd',
              nullable: true,
            ),
            'count': Schema.number(
              description: 'New remaining count value',
              nullable: true,
            ),
            'duration': Schema.number(
              description: 'New remaining duration in minutes',
              nullable: true,
            ),
          },
        ),
      },
    ),
    FunctionDeclaration(
      'removeActivity',
      'Remove an activity and all its records. Uses ActivityManager.removeActivity',
      parameters: <String, Schema>{
        'activityName': Schema.string(
          description: 'The name or keyword of the activity to remove',
        ),
        'confirm': Schema.boolean(
          description:
              'Explicit confirmation flag. Must be true to perform deletion. If omitted or false, the function should return a warning message and not delete.',
          nullable: true,
        ),
      },
    ),
    FunctionDeclaration(
      'annualReport',
      'Produce an annual summary for an activity. If year omitted, use current year',
      parameters: <String, Schema>{
        'activityName': Schema.string(
          description:
              'Name (or keyword) of the activity to summarize. If omitted or "all", report for all activities',
          nullable: true,
        ),
        'year': Schema.number(
          description: 'Four-digit year for the report, e.g., 2025',
          nullable: true,
        ),
      },
    ),
    FunctionDeclaration(
      'displayActivities',
      'Return a beautifully formatted markdown overview of activities. If activityName is provided, show details for that activity only. Optional limit to restrict number of activities.',
      parameters: <String, Schema>{
        'activityName': Schema.string(
          description:
              'Optional activity name or keyword to filter results. If omitted, list all activities.',
          nullable: true,
        ),
        'limit': Schema.number(
          description:
              'Optional maximum number of activities to include in the output',
          nullable: true,
        ),
      },
    ),
    FunctionDeclaration(
      'updateLatestRecord',
      'Update the most recent record of an activity. If recordId is provided, update that specific record instead',
      parameters: <String, Schema>{
        'activityName': Schema.string(
          description: 'Name of the activity to update',
        ),
        'updates': Schema.object(
          description: 'Fields to update in the record',
          properties: {
            'startStr': Schema.string(
              description:
                  'New start time for time-based records (format: yyyy-MM-dd HH:mm:ss)',
              nullable: true,
            ),
            'endStr': Schema.string(
              description:
                  'New end time for time-based records (format: yyyy-MM-dd HH:mm:ss)',
              nullable: true,
            ),
            'productiveMinutes': Schema.number(
              description: 'New productive minutes for time-based records',
              nullable: true,
            ),
            'timestampStr': Schema.string(
              description:
                  'New timestamp for count-based records (format: yyyy-MM-dd HH:mm:ss)',
              nullable: true,
            ),
            'count': Schema.number(
              description: 'New count value for count-based records',
              nullable: true,
            ),
          },
        ),
        'recordId': Schema.string(
          description:
              'Specific record ID to update (optional). If not provided, updates the latest record',
          nullable: true,
        ),
      },
    ),
  ]),
];
