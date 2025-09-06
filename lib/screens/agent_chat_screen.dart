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
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              Icons.smart_toy_rounded,
              color: Theme.of(context).colorScheme.onPrimary,
              size: 36,
            ),
          ),
          const SizedBox(height: 24),
          // Title
          Text(
            'Welcome to Proactive!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          // Subtitle
          Text(
            'Your AI-powered activity assistant is ready to help you track progress, manage goals, and stay motivated.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          // Feature cards
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Try asking:',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildExampleQuery('Update my pushups to 50 done'),
                _buildExampleQuery('Show my running progress'),
                _buildExampleQuery('Export completed activities'),
                _buildExampleQuery('Create a workout plan'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleQuery(String query) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              query,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
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
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Column(
          crossAxisAlignment: message.isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            // Message sender label
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!message.isUser) ...[
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.secondary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.smart_toy_rounded,
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    message.isUser ? 'You' : 'Proactive',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            // Message bubble
            Card(
              elevation: message.isUser ? 1 : 2,
              color: message.isUser
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: message.isUser
                      ? const Radius.circular(16)
                      : const Radius.circular(4),
                  bottomRight: message.isUser
                      ? const Radius.circular(4)
                      : const Radius.circular(16),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.text.isNotEmpty)
                      Text(
                        message.text,
                        style: TextStyle(
                          color: message.isUser
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurface,
                          fontSize: 16,
                          height: 1.4,
                        ),
                      ),
                    if (message.widgets.isNotEmpty) ...[
                      if (message.text.isNotEmpty) const SizedBox(height: 12),
                      ...message.widgets,
                    ],
                  ],
                ),
              ),
            ),
            // Timestamp
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _formatTimestamp(message.timestamp),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.smart_toy_rounded,
              color: Theme.of(context).colorScheme.onPrimary,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Ask Proactive anything...',
                  hintStyle: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
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
          ),
          const SizedBox(width: 12),
          FloatingActionButton(
            onPressed: _isLoading ? null : _sendMessage,
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            elevation: 2,
            child: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 20),
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
    final rawText = response.text ?? '';
    final widgets = <Widget>[];

    // Handle function calls from the response
    if (response.functionCalls.isNotEmpty) {
      for (final call in response.functionCalls) {
        final result = await _executeFunctionCall(call);
        if (result != null) {
          widgets.add(result);
        }
      }
    }

    // Only show text if there are no function calls or if text is meaningful
    final cleanText = _cleanTextResponse(rawText);
    final shouldShowText = cleanText.isNotEmpty && (widgets.isEmpty || cleanText.length > 10);

    setState(() {
      _messages.add(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: shouldShowText ? cleanText : '',
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

  String _cleanTextResponse(String text) {
    // Remove any remaining function call syntax or tool call artifacts
    final cleaned = text
        .replaceAll(RegExp(r"'tool_code\s*.*?(?=\s*\'|$)", dotAll: true), '')
        .replaceAll(RegExp(r'function_calls?:\s*\[.*?\]', dotAll: true), '')
        .trim();
    return cleaned.isEmpty ? '' : cleaned;
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      return '${timestamp.month}/${timestamp.day} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}
