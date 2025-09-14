import 'package:firebase_ai/firebase_ai.dart';

final toolsForLLM = [
  Tool.functionDeclarations([
    FunctionDeclaration(
      'displayHelloWorld',
      'Displays a simple "Hello, World!" message',
      parameters: <String, Schema>{},
    ),
    FunctionDeclaration(
      'addTool',
      'Adds two numbers together and returns the sum',
      parameters: <String, Schema>{
        'a': Schema.number(description: 'First number to add'),
        'b': Schema.number(description: 'Second number to add'),
      },
    ),
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
