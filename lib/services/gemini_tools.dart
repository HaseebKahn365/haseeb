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

  // Tool for finding activities by keyword (primary lookup method)
  FunctionDeclaration get findActivityFuncDecl => FunctionDeclaration(
    'find_activity',
    'COLLECTION-BASED: Searches all activities by keyword and returns exact IDs for modification. Use this BEFORE modify_activity.',
    parameters: {
      'keyword': Schema.string(
        description:
            'Keyword to search for in activity titles (e.g., "pushup", "study", "run")',
      ),
    },
  );

  // Tool for getting active (incomplete) activities
  FunctionDeclaration get getActiveActivitiesFuncDecl => FunctionDeclaration(
    'get_active_activities',
    'Returns all incomplete activities with full details (ID, title, total, done, type). Use this to see what the user is currently working on.',
    parameters: {},
  );

  // Tool for getting completed activities
  FunctionDeclaration get getCompletedActivitiesFuncDecl => FunctionDeclaration(
    'get_completed_activities',
    'Returns all completed activities with full details (ID, title, total, done, type). Use this to see what the user has finished.',
    parameters: {},
  );

  // Tool for getting ALL activities
  FunctionDeclaration get getAllActivitiesFuncDecl => FunctionDeclaration(
    'get_all_activities',
    'Returns ALL activities with complete details (ID, title, total, done, type, completion status). Use this to see everything the user has.',
    parameters: {},
  );

  // Tool for smart activity update (combines find + modify)
  FunctionDeclaration get smartUpdateActivityFuncDecl => FunctionDeclaration(
    'smart_update_activity',
    'INTELLIGENT UPDATE: Finds and updates an activity in one step. Use this for seamless updates.',
    parameters: {
      'description': Schema.string(
        description:
            'Natural description of what to update (e.g., "finished 60 minutes of study")',
      ),
    },
  );

  // Tool for fetching activity data
  FunctionDeclaration get fetchActivityDataFuncDecl => FunctionDeclaration(
    'fetch_activity_data',
    'Queries activities based on filters like type, date range, completion status, or title search.',
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
          'title_contains': Schema.string(
            description:
                'Search for activities containing this text in the title',
          ),
        },
      ),
    },
  );

  // Tool for creating activities
  FunctionDeclaration get createActivityFuncDecl => FunctionDeclaration(
    'create_activity',
    'Creates a new activity in the database.',
    parameters: {
      'type': Schema.string(
        description: 'Activity type: COUNT, DURATION, or PLANNED',
      ),
      'title': Schema.string(description: 'Activity title/name'),
      'total_value': Schema.number(
        description:
            'Target value (count or minutes for regular activities, estimated duration for planned)',
      ),
      'description': Schema.string(description: 'Optional description'),
      'is_planned': Schema.boolean(
        description:
            'Set to true to create a PlannedActivity instead of regular activity',
      ),
      'planned_type': Schema.string(
        description:
            'For planned activities only: COUNT or DURATION - what type it will become when started',
      ),
    },
  );

  // Tool for getting planned activities
  FunctionDeclaration get getPlannedActivitiesFuncDecl => FunctionDeclaration(
    'get_planned_activities',
    'Returns all planned activities with full details (ID, title, description, type, estimated duration). Use this to see what the user has planned.',
    parameters: {},
  );

  // Tool for converting planned activity to active
  FunctionDeclaration get startPlannedActivityFuncDecl => FunctionDeclaration(
    'start_planned_activity',
    'Converts a PlannedActivity into an active CountActivity or DurationActivity.',
    parameters: {
      'planned_id': Schema.string(
        description: 'ID of the planned activity to start',
      ),
      'target_value': Schema.number(
        description: 'Actual target value for the active activity',
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

  // Tool for deleting activities
  FunctionDeclaration get deleteActivityFuncDecl => FunctionDeclaration(
    'delete_activity',
    'Permanently removes an activity from all collections (planned, active, completed).',
    parameters: {
      'id': Schema.string(description: 'ID of the activity to delete'),
    },
  );

  // Tool for smart suggestions
  FunctionDeclaration get suggestActivityFuncDecl => FunctionDeclaration(
    'suggest_activity',
    'Intelligently suggests a planned activity to start today and converts it to active.',
    parameters: {
      'criteria': Schema.string(
        description:
            'Optional criteria for suggestion (e.g., "quick workout", "study session")',
      ),
    },
  );

  List<Tool> get tools => [
    Tool.functionDeclarations([
      getAllActivitiesFuncDecl,
      getActiveActivitiesFuncDecl,
      getCompletedActivitiesFuncDecl,
      getPlannedActivitiesFuncDecl,
      findActivityFuncDecl,
      smartUpdateActivityFuncDecl,
      modifyActivityFuncDecl,
      fetchActivityDataFuncDecl,
      createActivityFuncDecl,
      startPlannedActivityFuncDecl,
      deleteActivityFuncDecl,
      suggestActivityFuncDecl,
      createCustomListFuncDecl,
      displayRadialBarFuncDecl,
      displayActivityCardFuncDecl,
      sendMarkdownFuncDecl,
      exportDataFuncDecl,
    ]),
  ];
}

final geminiToolsProvider = Provider<GeminiTools>((ref) => GeminiTools(ref));
