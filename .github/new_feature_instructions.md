These are just the instructions for implementing tool Calling and should be not copied Verbaratim.

Only use these instructions for implementing the new feature an our activities app.

6. Implementing tool handling
In this step, you'll implement handlers for the function calls coming from Gemini. This completes the circle of communication between natural language inputs and concrete application features, allowing the LLM to directly manipulate your UI based on user descriptions.

What you'll learn in this step
Understanding the complete function calling pipeline in LLM applications
Processing function calls from Gemini in a Flutter application
Implementing function handlers that modify application state
Handling function responses and returning results to the LLM
Creating a complete communication flow between LLM and UI
Logging function calls and responses for transparency
Understanding the function calling pipeline
Before diving into implementation, let's understand the complete function calling pipeline:

The end-to-end flow
User input: User describes a color in natural language (e.g., "forest green")
LLM processing: Gemini analyzes the description and decides to call the set_color function
Function call generation: Gemini creates a structured JSON with parameters (red, green, blue values)
Function call reception: Your app receives this structured data from Gemini
Function execution: Your app executes the function with the provided parameters
State update: The function updates your app's state (changing the displayed color)
Response generation: Your function returns results back to the LLM
Response incorporation: The LLM incorporates these results into its final response
UI update: Your UI reacts to the state change, displaying the new color
The complete communication cycle is essential for proper LLM integration. When an LLM makes a function call, it doesn't simply send the request and move on. Instead, it waits for your application to execute the function and return results. The LLM then uses these results to formulate its final response, creating a natural conversation flow that acknowledges the actions taken.

Implement function handlers
Let's update your lib/services/gemini_tools.dart file to add handlers for function calls:

lib/services/gemini_tools.dart

import 'package:colorist_ui/colorist_ui.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'gemini_tools.g.dart';

class GeminiTools {
  GeminiTools(this.ref);

  final Ref ref;

  FunctionDeclaration get setColorFuncDecl => FunctionDeclaration(
    'set_color',
    'Set the color of the display square based on red, green, and blue values.',
    parameters: {
      'red': Schema.number(description: 'Red component value (0.0 - 1.0)'),
      'green': Schema.number(description: 'Green component value (0.0 - 1.0)'),
      'blue': Schema.number(description: 'Blue component value (0.0 - 1.0)'),
    },
  );

  List<Tool> get tools => [
    Tool.functionDeclarations([setColorFuncDecl]),
  ];

  Map<String, Object?> handleFunctionCall(                           // Add from here
    String functionName,
    Map<String, Object?> arguments,
  ) {
    final logStateNotifier = ref.read(logStateNotifierProvider.notifier);
    logStateNotifier.logFunctionCall(functionName, arguments);
    return switch (functionName) {
      'set_color' => handleSetColor(arguments),
      _ => handleUnknownFunction(functionName),
    };
  }

  Map<String, Object?> handleSetColor(Map<String, Object?> arguments) {
    final colorStateNotifier = ref.read(colorStateNotifierProvider.notifier);
    final red = (arguments['red'] as num).toDouble();
    final green = (arguments['green'] as num).toDouble();
    final blue = (arguments['blue'] as num).toDouble();
    final functionResults = {
      'success': true,
      'current_color': colorStateNotifier
          .updateColor(red: red, green: green, blue: blue)
          .toLLMContextMap(),
    };

    final logStateNotifier = ref.read(logStateNotifierProvider.notifier);
    logStateNotifier.logFunctionResults(functionResults);
    return functionResults;
  }

  Map<String, Object?> handleUnknownFunction(String functionName) {
    final logStateNotifier = ref.read(logStateNotifierProvider.notifier);
    logStateNotifier.logWarning('Unsupported function call $functionName');
    return {
      'success': false,
      'reason': 'Unsupported function call $functionName',
    };
  }                                                                  // To here.
}

@riverpod
GeminiTools geminiTools(Ref ref) => GeminiTools(ref);
Understanding the function handlers
Let's break down what these function handlers do:

handleFunctionCall: A central dispatcher that:
Logs the function call for transparency in the log panel
Routes to the appropriate handler based on the function name
Returns a structured response that will be sent back to the LLM
handleSetColor: The specific handler for your set_color function that:
Extracts RGB values from the arguments map
Converts them to the expected types (doubles)
Updates the application's color state using the colorStateNotifier
Creates a structured response with success status and current color information
Logs the function results for debugging
handleUnknownFunction: A fallback handler for unknown functions that:
Logs a warning about the unsupported function
Returns an error response to the LLM
The handleSetColor function is particularly important as it bridges the gap between the LLM's natural language understanding and concrete UI changes.

Note: The names of function calls, or tools, that we supply to Firebase AI Logic in Firebase need not map one-to-one to a function name in your application. The set_color function name is an arbitrary string that the LLM will use to call the function.

Update the Gemini chat service to process function calls and responses
Now, let's update the lib/services/gemini_chat_service.dart file to process function calls from the LLM responses and send the results back to the LLM:

lib/services/gemini_chat_service.dart

import 'dart:async';

import 'package:colorist_ui/colorist_ui.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../providers/gemini.dart';
import 'gemini_tools.dart';                                          // Add this import

part 'gemini_chat_service.g.dart';

class GeminiChatService {
  GeminiChatService(this.ref);
  final Ref ref;

  Future<void> sendMessage(String message) async {
    final chatSession = await ref.read(chatSessionProvider.future);
    final chatStateNotifier = ref.read(chatStateNotifierProvider.notifier);
    final logStateNotifier = ref.read(logStateNotifierProvider.notifier);

    chatStateNotifier.addUserMessage(message);
    logStateNotifier.logUserText(message);
    final llmMessage = chatStateNotifier.createLlmMessage();
    try {
      final response = await chatSession.sendMessage(Content.text(message));

      final responseText = response.text;
      if (responseText != null) {
        logStateNotifier.logLlmText(responseText);
        chatStateNotifier.appendToMessage(llmMessage.id, responseText);
      }

      if (response.functionCalls.isNotEmpty) {                       // Add from here
        final geminiTools = ref.read(geminiToolsProvider);
        final functionResultResponse = await chatSession.sendMessage(
          Content.functionResponses([
            for (final functionCall in response.functionCalls)
              FunctionResponse(
                functionCall.name,
                geminiTools.handleFunctionCall(
                  functionCall.name,
                  functionCall.args,
                ),
              ),
          ]),
        );
        final responseText = functionResultResponse.text;
        if (responseText != null) {
          logStateNotifier.logLlmText(responseText);
          chatStateNotifier.appendToMessage(llmMessage.id, responseText);
        }
      }                                                              // To here.
    } catch (e, st) {
      logStateNotifier.logError(e, st: st);
      chatStateNotifier.appendToMessage(
        llmMessage.id,
        "\nI'm sorry, I encountered an error processing your request. "
        "Please try again.",
      );
    } finally {
      chatStateNotifier.finalizeMessage(llmMessage.id);
    }
  }
}

@riverpod
GeminiChatService geminiChatService(Ref ref) => GeminiChatService(ref);
Understanding the flow of communication
The key addition here is the complete handling of function calls and responses:


if (response.functionCalls.isNotEmpty) {
  final geminiTools = ref.read(geminiToolsProvider);
  final functionResultResponse = await chatSession.sendMessage(
    Content.functionResponses([
      for (final functionCall in response.functionCalls)
        FunctionResponse(
          functionCall.name,
          geminiTools.handleFunctionCall(
            functionCall.name,
            functionCall.args,
          ),
        ),
    ]),
  );
  final responseText = functionResultResponse.text;
  if (responseText != null) {
    logStateNotifier.logLlmText(responseText);
    chatStateNotifier.appendToMessage(llmMessage.id, responseText);
  }
}
This code:

Checks if the LLM response contains any function calls
For each function call, invokes your handleFunctionCall method with the function name and arguments
Collects the results of each function call
Sends these results back to the LLM using Content.functionResponses
Processes the LLM's response to the function results
Updates the UI with the final response text
This creates a round trip flow:

User → LLM: Requests a color
LLM → App: Function calls with parameters
App → User: New color displayed
App → LLM: Function results
LLM → User: Final response incorporating function results
Generate Riverpod code
Run the build runner command to generate the needed Riverpod code:


dart run build_runner build --delete-conflicting-outputs
Run and test the complete flow
Now run your application:


flutter run -d DEVICE
Colorist App Screenshot showing the Gemini LLM responding with a function call

Try entering various color descriptions:

"I'd like a deep crimson red"
"Show me a calming sky blue"
"Give me the color of fresh mint leaves"
"I want to see a warm sunset orange"
"Make it a rich royal purple"
Now you should see:

Your message appearing in the chat interface
Gemini's response appearing in the chat
Function calls being logged in the log panel
Function results being logged immediately after
The color rectangle updating to display the described color
RGB values updating to show the new color's components
Gemini's final response appearing, often commenting on the color that was set
The log panel provides insight into what's happening behind the scenes. You'll see:

The exact function calls Gemini is making
The parameters it's choosing for each RGB value
The results your function is returning
The follow-up responses from Gemini
The color state notifier
The colorStateNotifier you're using to update colors is part of the colorist_ui package. It manages:

The current color displayed in the UI
The color history (last 10 colors)
Notification of state changes to UI components
When you call updateColor with new RGB values, it:

Creates a new ColorData object with the provided values
Updates the current color in the app state
Adds the color to the history
Triggers UI updates through Riverpod's state management
The UI components in the colorist_ui package watch this state and automatically update when it changes, creating a reactive experience.

Understanding error handling
Your implementation includes robust error handling:

Try-catch block: Wraps all LLM interactions to catch any exceptions
Error logging: Records errors in the log panel with stack traces
User feedback: Provides a friendly error message in the chat
State cleanup: Finalizes the message state even if an error occurs
This ensures the app remains stable and provides appropriate feedback even when issues occur with the LLM service or function execution.

The power of function calling for user experience
What you've accomplished here demonstrates how LLMs can create powerful natural interfaces:

Natural language interface: Users express intent in everyday language
Intelligent interpretation: The LLM translates vague descriptions into precise values
Direct manipulation: The UI updates in response to natural language
Contextual responses: The LLM provides conversational context about the changes
Low cognitive load: Users don't need to understand RGB values or color theory
This pattern of using LLM function calling to bridge natural language and UI actions can be extended to countless other domains beyond color selection.

What's next?
In the next step, you'll enhance the user experience by implementing streaming responses. Rather than waiting for the complete response, you'll process text chunks and function calls as they are received, creating a more responsive and engaging application.

Troubleshooting
Function call issues
If Gemini isn't calling your functions or parameters are incorrect:

Verify your function declaration matches what's described in the system prompt
Check that parameter names and types are consistent
Ensure your system prompt explicitly instructs the LLM to use the tool
Verify the function name in your handler matches exactly what's in the declaration
Examine the log panel for detailed information on function calls
Function response issues
If function results aren't being properly sent back to the LLM:

Check that your function returns a properly formatted Map
Verify that the Content.functionResponses is being constructed correctly
Look for any errors in the log related to function responses
Ensure you're using the same chat session for the response
Color display issues
If colors aren't displaying correctly:

Ensure RGB values are properly converted to doubles (LLM might send them as integers)
Verify that values are in the expected range (0.0 to 1.0)
Check that the color state notifier is being called correctly
Examine the log for the exact values being passed to the function
General problems
For general issues:

Examine the logs for errors or warnings
Verify Firebase AI Logic connectivity
Check for any type mismatches in function parameters
Ensure all Riverpod generated code is up to date
Key concepts learned
Implementing a complete function calling pipeline in Flutter
Creating full communication between an LLM and your application
Processing structured data from LLM responses
Sending function results back to the LLM for incorporation into responses
Using the log panel to gain visibility into LLM-application interactions
Connecting natural language inputs to concrete UI changes