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
  ]),
];
