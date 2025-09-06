4. Effective prompting for color descriptions
In this step, you'll create and implement a system prompt that guides Gemini in interpreting color descriptions. System prompts are a powerful way to customize LLM behavior for specific tasks without changing your code.

What you'll learn in this step
Understanding system prompts and their importance in LLM applications
Crafting effective prompts for domain-specific tasks
Loading and using system prompts in a Flutter app
Guiding an LLM to provide consistently formatted responses
Testing how system prompts affect LLM behavior
Understanding system prompts
Before diving into implementation, let's understand what system prompts are and why they're important:

What are system prompts?
A system prompt is a special type of instruction given to an LLM that sets the context, behavior guidelines, and expectations for its responses. Unlike user messages, system prompts:

Establish the LLM's role and persona
Define specialized knowledge or capabilities
Provide formatting instructions
Set constraints on responses
Describe how to handle various scenarios
Think of a system prompt as giving the LLM its "job description" - it tells the model how to behave throughout the conversation.

Why system prompts matter
System prompts are critical for creating consistent, useful LLM interactions because they:

Ensure consistency: Guide the model to provide responses in a consistent format
Improve relevance: Focus the model on your specific domain (in your case, colors)
Establish boundaries: Define what the model should and shouldn't do
Enhance user experience: Create a more natural, helpful interaction pattern
Reduce post-processing: Get responses in formats that are easier to parse or display
For your Colorist app, you need the LLM to consistently interpret color descriptions and provide RGB values in a specific format.

Create a system prompt asset
First, you'll create a system prompt file that will be loaded at runtime. This approach allows you to modify the prompt without recompiling your app.

Create a new file assets/system_prompt.md with the following content:

assets/system_prompt.md

# Colorist System Prompt

You are a color expert assistant integrated into a desktop app called Colorist. Your job is to interpret natural language color descriptions and provide the appropriate RGB values that best represent that description.

## Your Capabilities

You are knowledgeable about colors, color theory, and how to translate natural language descriptions into specific RGB values. When users describe a color, you should:

1. Analyze their description to understand the color they are trying to convey
2. Determine the appropriate RGB values (values should be between 0.0 and 1.0)
3. Respond with a conversational explanation and explicitly state the RGB values

## How to Respond to User Inputs

When users describe a color:

1. First, acknowledge their color description with a brief, friendly response
2. Interpret what RGB values would best represent that color description
3. Always include the RGB values clearly in your response, formatted as: `RGB: (red=X.X, green=X.X, blue=X.X)`
4. Provide a brief explanation of your interpretation

Example:
User: "I want a sunset orange"
You: "Sunset orange is a warm, vibrant color that captures the golden-red hues of the setting sun. It combines a strong red component with moderate orange tones.

RGB: (red=1.0, green=0.5, blue=0.25)

I've selected values with high red, moderate green, and low blue to capture that beautiful sunset glow. This creates a warm orange with a slightly reddish tint, reminiscent of the sun low on the horizon."

## When Descriptions are Unclear

If a color description is ambiguous or unclear, please ask the user clarifying questions, one at a time.

## Important Guidelines

- Always keep RGB values between 0.0 and 1.0
- Always format RGB values as: `RGB: (red=X.X, green=X.X, blue=X.X)` for easy parsing
- Provide thoughtful, knowledgeable responses about colors
- When possible, include color psychology, associations, or interesting facts about colors
- Be conversational and engaging in your responses
- Focus on being helpful and accurate with your color interpretations
Understanding the system prompt structure
Let's break down what this prompt does:

Definition of role: Establishes the LLM as a "color expert assistant"
Task explanation: Defines the primary task as interpreting color descriptions into RGB values
Response format: Specifies exactly how RGB values should be formatted for consistency
Example exchange: Provides a concrete example of the expected interaction pattern
Edge case handling: Instructs how to handle unclear descriptions
Constraints and guidelines: Sets boundaries like keeping RGB values between 0.0 and 1.0
This structured approach ensures the LLM's responses will be consistent, informative, and formatted in a way that would be easy to parse if you wanted to extract the RGB values programmatically.

Update pubspec.yaml
Now, update the bottom of your pubspec.yaml to include the assets directory:

pubspec.yaml

flutter:
  uses-material-design: true

  assets:
    - assets/
Run flutter pub get to refresh the asset bundle.

Create a system prompt provider
Create a new file lib/providers/system_prompt.dart to load the system prompt:

lib/providers/system_prompt.dart

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'system_prompt.g.dart';

@riverpod
Future<String> systemPrompt(Ref ref) =>
    rootBundle.loadString('assets/system_prompt.md');
This provider uses Flutter's asset loading system to read the prompt file at runtime.

Update the Gemini model provider
Now modify your lib/providers/gemini.dart file to include the system prompt:

lib/providers/gemini.dart

import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../firebase_options.dart';
import 'system_prompt.dart';                                          // Add this import

part 'gemini.g.dart';

@riverpod
Future<FirebaseApp> firebaseApp(Ref ref) =>
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

@riverpod
Future<GenerativeModel> geminiModel(Ref ref) async {
  await ref.watch(firebaseAppProvider.future);
  final systemPrompt = await ref.watch(systemPromptProvider.future);  // Add this line

  final model = FirebaseAI.googleAI().generativeModel(
    model: 'gemini-2.0-flash',
    systemInstruction: Content.system(systemPrompt),                  // And this line
  );
  return model;
}

@Riverpod(keepAlive: true)
Future<ChatSession> chatSession(Ref ref) async {
  final model = await ref.watch(geminiModelProvider.future);
  return model.startChat();
}
The key change is adding systemInstruction: Content.system(systemPrompt) when creating the generative model. This tells Gemini to use your instructions as the system prompt for all interactions in this chat session.

Generate Riverpod code
Run the build runner command to generate the needed Riverpod code:


dart run build_runner build --delete-conflicting-outputs
Run and test the application
Now run your application:


flutter run -d DEVICE
Colorist App Screenshot showing the Gemini LLM responding with a response in character for a color selection app

Try testing it with various color descriptions:

"I'd like a sky blue"
"Give me a forest green"
"Make a vibrant sunset orange"
"I want the color of fresh lavender"
"Show me something like a deep ocean blue"
You should notice that Gemini now responds with conversational explanations about the colors along with consistently formatted RGB values. The system prompt has effectively guided the LLM to provide the type of responses you need.

Also try asking it for content outside the context of colors. Say, the leading causes of the Wars of the Roses. You should notice a difference from the previous step.

The importance of prompt engineering for specialized tasks
System prompts are both art and science. They're a critical part of LLM integration that can dramatically affect how useful the model is for your specific application. What you've done here is a form of prompt engineering - tailoring instructions to get the model to behave in ways that suit your application's needs.

Effective prompt engineering involves:

Clear role definition: Establishing what the LLM's purpose is
Explicit instructions: Detailing exactly how the LLM should respond
Concrete examples: Showing rather than just telling what good responses look like
Edge case handling: Instructing the LLM on how to deal with ambiguous scenarios
Formatting specifications: Ensuring responses are structured in a consistent, usable way
The system prompt you've created transforms the generic capabilities of Gemini into a specialized color interpretation assistant that provides responses formatted specifically for your application's needs. This is a powerful pattern you can apply to many different domains and tasks.

What's next?
In the next step, you'll build on this foundation by adding function declarations, which allow the LLM to not just suggest RGB values, but actually call functions in your app to set the color directly. This demonstrates how LLMs can bridge the gap between natural language and concrete application features.

Troubleshooting
Asset loading issues
If you encounter errors loading the system prompt:
