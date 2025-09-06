import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/gemini.dart';

class AgentChatScreen extends ConsumerWidget {
  const AgentChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatSessionAsync = ref.watch(chatSessionProvider);

    return chatSessionAsync.when(
      data: (chatSession) => ChatInterface(chatSession: chatSession),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }
}

class ChatInterface extends StatefulWidget {
  final ChatSession chatSession;

  const ChatInterface({required this.chatSession, super.key});

  @override
  State<ChatInterface> createState() => _ChatInterfaceState();
}

class _ChatInterfaceState extends State<ChatInterface> {
  final TextEditingController _controller = TextEditingController();
  String _response = '';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Enter your message',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              final message = _controller.text;
              if (message.isNotEmpty) {
                final response = await widget.chatSession.sendMessage(
                  Content.text(message),
                );
                setState(() {
                  _response = response.text ?? 'No response';
                });
              }
            },
            child: const Text('Send'),
          ),
          const SizedBox(height: 16),
          Text('Response: $_response'),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
