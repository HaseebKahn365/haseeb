import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      home: MainScreen(
        sendMessage: (message) {
          sendMessage(message, ref);
        },
      ),
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

class MainScreen extends StatelessWidget {
  final Function(String) sendMessage;

  const MainScreen({required this.sendMessage, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Echo Chat')),
      body: ChatInterface(sendMessage: sendMessage),
    );
  }
}

class ChatInterface extends StatefulWidget {
  final Function(String) sendMessage;

  const ChatInterface({required this.sendMessage, super.key});

  @override
  State<ChatInterface> createState() => _ChatInterfaceState();
}

class _ChatInterfaceState extends State<ChatInterface> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _messages = [];

  void _handleSend() {
    final text = _controller.text;
    if (text.isNotEmpty) {
      setState(() {
        _messages.add('You: $text');
        _messages.add('Echo: $text');
      });
      widget.sendMessage(text);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              return ListTile(title: Text(_messages[index]));
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(hintText: 'Type a message'),
                ),
              ),
              IconButton(icon: const Icon(Icons.send), onPressed: _handleSend),
            ],
          ),
        ),
      ],
    );
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
