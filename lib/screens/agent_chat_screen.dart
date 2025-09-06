import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/gemini.dart';
import '../widgets/activity_card_widget.dart';
import '../widgets/markdown_widget.dart';
import '../widgets/radial_bar_widget.dart';

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

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<Widget> widgets;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.widgets = const [],
  });
}

class ChatInterface extends StatefulWidget {
  final ChatSession chatSession;

  const ChatInterface({required this.chatSession, super.key});

  @override
  State<ChatInterface> createState() => _ChatInterfaceState();
}

class _ChatInterfaceState extends State<ChatInterface> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildWelcomeMessage()
                : _buildMessagesList(),
          ),
          if (_isLoading) _buildLoadingIndicator(),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildWelcomeMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Welcome to Proactive!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'I\'m your AI activity assistant. Ask me to update activities, show progress, or export data.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Try asking:',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• "Update my pushups to 50 done"',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    '• "Show my running progress"',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    '• "Export completed activities"',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _buildMessageBubble(message);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Card(
          elevation: 2,
          color: message.isUser
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.text.isNotEmpty)
                  Text(
                    message.text,
                    style: TextStyle(
                      color: message.isUser
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                if (message.widgets.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...message.widgets,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Proactive is thinking...',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Ask Proactive anything...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withOpacity(0.5),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 12),
          FloatingActionButton(
            onPressed: _isLoading ? null : _sendMessage,
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: text,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _isLoading = true;
    });

    _controller.clear();

    try {
      final response = await widget.chatSession.sendMessage(Content.text(text));
      await _handleResponse(response);
    } catch (e) {
      setState(() {
        _messages.add(
          ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: 'Sorry, I encountered an error: $e',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleResponse(GenerateContentResponse response) async {
    final text = response.text ?? '';
    final widgets = <Widget>[];

    // Handle function calls
    if (response.functionCalls.isNotEmpty) {
      for (final call in response.functionCalls) {
        final result = await _executeFunctionCall(call);
        if (result != null) {
          widgets.add(result);
        }
      }
    }

    setState(() {
      _messages.add(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: text,
          isUser: false,
          timestamp: DateTime.now(),
          widgets: widgets,
        ),
      );
    });
  }

  Future<Widget?> _executeFunctionCall(FunctionCall call) async {
    switch (call.name) {
      case 'display_radial_bar':
        final args = call.args;
        return RadialBarWidget(
          total: (args['total'] as num?)?.toInt() ?? 100,
          done: (args['done'] as num?)?.toInt() ?? 0,
          title: args['title'] as String? ?? 'Progress',
        );

      case 'display_activity_card':
        final args = call.args;
        return ActivityCardWidget(
          title: args['title'] as String? ?? 'Activity',
          total: (args['total'] as num?)?.toInt() ?? 0,
          done: (args['done'] as num?)?.toInt() ?? 0,
          timestamp: DateTime.parse(
            args['timestamp'] as String? ?? DateTime.now().toIso8601String(),
          ),
          type: args['type'] as String? ?? 'COUNT',
        );

      case 'send_markdown':
        final args = call.args;
        return MarkdownWidget(content: args['text'] as String? ?? '');

      default:
        return null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
