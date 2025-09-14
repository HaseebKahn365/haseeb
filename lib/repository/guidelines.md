Agent Function Declarations (For Gemini/LLM)
Here's how you should declare these functions to your AI agent:
dart
Tool.functionDeclarations([
  // Activity Management
  FunctionDeclaration(
    'addActivity',
    'Create a new activity with specified name and type',
    parameters: <String, Schema>{
      'name': Schema.string(description: 'Name of the activity'),
      'type': Schema.string(
        description: 'Type of activity: "time" or "count"',
        enum: ['time', 'count'],
      ),
    },
  ),



Constructed Scenarios to Expose Use Cases
Scenario 1: New User Onboarding
User: "I want to start tracking my pushups and study time"
Agent should:
1.	Call addActivity('Pushups', 'count')
2.	Call addActivity('Study', 'time')
3.	Explain how to add records for each activity type
