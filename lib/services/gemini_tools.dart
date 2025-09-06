import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GeminiTools {
  GeminiTools(this.ref);

  final Ref ref;

  // Tool for modifying activity attributes
  FunctionDeclaration get modifyActivityFuncDecl => FunctionDeclaration(
    'modify_activity',
    'Modifies a specific attribute of an activity (e.g., done_count, title).',
    parameters: {
      'id': Schema.string(
        description: 'The unique ID of the activity to modify',
      ),
      'attribute': Schema.string(
        description: 'The attribute to modify (e.g., done_count, title)',
      ),
      'value': Schema.string(description: 'The new value for the attribute'),
    },
  );

  // Tool for fetching activity data
  FunctionDeclaration get fetchActivityDataFuncDecl => FunctionDeclaration(
    'fetch_activity_data',
    'Queries activities based on filters like type, date range, completion status.',
    parameters: {
      'filter': Schema.object(
        description: 'Filter criteria for querying activities',
        properties: {
          'type': Schema.string(
            description: 'Activity type: COUNT or DURATION',
          ),
          'date_range': Schema.string(
            description: 'Date range filter (e.g., this_week, last_month)',
          ),
          'completion_status': Schema.string(
            description: 'Completion status: completed, in_progress, or all',
          ),
        },
      ),
    },
  );

  // Tool for creating custom lists
  FunctionDeclaration get createCustomListFuncDecl => FunctionDeclaration(
    'create_custom_list',
    'Creates a new dynamic list of activities based on criteria.',
    parameters: {
      'title': Schema.string(description: 'Title for the custom list'),
      'activities': Schema.array(
        description: 'List of activity IDs to include',
        items: Schema.string(),
      ),
    },
  );

  // Tool for displaying radial bar
  FunctionDeclaration get displayRadialBarFuncDecl => FunctionDeclaration(
    'display_radial_bar',
    'Displays a visual progress bar showing completion percentage.',
    parameters: {
      'total': Schema.number(description: 'Total target value'),
      'done': Schema.number(description: 'Completed value'),
      'title': Schema.string(description: 'Title for the progress bar'),
    },
  );

  // Tool for displaying activity card
  FunctionDeclaration get displayActivityCardFuncDecl => FunctionDeclaration(
    'display_activity_card',
    'Shows a detailed card for a single activity.',
    parameters: {
      'id': Schema.string(description: 'Activity ID'),
      'title': Schema.string(description: 'Activity title'),
      'total': Schema.number(description: 'Total target value'),
      'done': Schema.number(description: 'Completed value'),
      'timestamp': Schema.string(description: 'Activity timestamp'),
      'type': Schema.string(description: 'Activity type: COUNT or DURATION'),
    },
  );

  // Tool for sending markdown responses
  FunctionDeclaration get sendMarkdownFuncDecl => FunctionDeclaration(
    'send_markdown',
    'Sends a markdown-formatted text response.',
    parameters: {
      'text': Schema.string(description: 'The markdown text to display'),
    },
  );

  // Tool for exporting data
  FunctionDeclaration get exportDataFuncDecl => FunctionDeclaration(
    'export_data',
    'Prepares activities for CSV export.',
    parameters: {
      'activities': Schema.array(
        description: 'List of activity IDs to export',
        items: Schema.string(),
      ),
    },
  );

  List<Tool> get tools => [
    Tool.functionDeclarations([
      modifyActivityFuncDecl,
      fetchActivityDataFuncDecl,
      createCustomListFuncDecl,
      displayRadialBarFuncDecl,
      displayActivityCardFuncDecl,
      sendMarkdownFuncDecl,
      exportDataFuncDecl,
    ]),
  ];
}

final geminiToolsProvider = Provider<GeminiTools>((ref) => GeminiTools(ref));
