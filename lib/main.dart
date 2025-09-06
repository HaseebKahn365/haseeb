import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haseeb/screens/home_screen.dart';

void main() {
  runApp(const ProviderScope(child: MainApp()));
}

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: HomeScreen(),
    );
  }

  void sendMessage(String message, WidgetRef ref) {
    final chatStateNotifier = ref.read(chatStateNotifierProvider.notifier);
    final logStateNotifier = ref.read(logStateNotifierProvider.notifier);

    chatStateNotifier.addUserMessage(message);
    logStateNotifier.logUserText(message);
    chatStateNotifier.addLlmMessage(message, MessageState.complete);
    logStateNotifier.logLlmText(message);
  }
}

final chatStateNotifierProvider =
    StateNotifierProvider<ChatStateNotifier, List<String>>((ref) {
      return ChatStateNotifier();
    });

final logStateNotifierProvider =
    StateNotifierProvider<LogStateNotifier, List<String>>((ref) {
      return LogStateNotifier();
    });

class ChatStateNotifier extends StateNotifier<List<String>> {
  ChatStateNotifier() : super([]);

  void addUserMessage(String message) {
    state = [...state, 'User: $message'];
  }

  void addLlmMessage(String message, MessageState state) {
    this.state = [...this.state, 'LLM: $message'];
  }
}

class LogStateNotifier extends StateNotifier<List<String>> {
  LogStateNotifier() : super([]);

  void logUserText(String message) {
    state = [...state, 'Log User: $message'];
  }

  void logLlmText(String message) {
    state = [...state, 'Log LLM: $message'];
  }
}

enum MessageState { complete, streaming }
