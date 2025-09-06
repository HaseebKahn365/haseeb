import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase_options.dart';
import '../services/gemini_tools.dart';
import 'system_prompt.dart';

final firebaseAppProvider = FutureProvider<FirebaseApp>((ref) async {
  return Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
});

final geminiModelProvider = FutureProvider<GenerativeModel>((ref) async {
  await ref.watch(firebaseAppProvider.future);
  final systemPrompt = await ref.watch(systemPromptProvider.future);
  final geminiTools = ref.watch(geminiToolsProvider);

  final model = FirebaseAI.googleAI().generativeModel(
    model: 'gemini-2.0-flash',
    systemInstruction: Content.system(systemPrompt),
    tools: geminiTools.tools,
  );
  return model;
});

final chatSessionProvider = FutureProvider<ChatSession>((ref) async {
  final model = await ref.watch(geminiModelProvider.future);
  return model.startChat();
});
