Scenario 6: Activity Management
User: "I want to rename 'Study' to 'Focused Learning'"
Agent should:
1.	Call listAllActivities() to find the study activity ID
2.	Call updateActivity() with new name
3.	Confirm the change was successful

FunctionDeclaration(
  'renameActivity',
  'Rename an existing activity and update all associated records with the new name',
  parameters: <String, Schema>{
    'currentName': Schema.string(description: 'Current name of the activity to rename'),
    'newName': Schema.string(description: 'New name for the activity'),
  },
),

Future<Map<String, dynamic>> renameActivity({
  required String currentName,
  required String newName,
}) async {
  try {
    // Step 1: Find the activity by current name