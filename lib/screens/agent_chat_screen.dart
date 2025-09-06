import 'dart:io';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../providers/chat_provider.dart';
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

class ChatInterface extends ConsumerStatefulWidget {
  final ChatSession chatSession;

  const ChatInterface({required this.chatSession, super.key});

  @override
  ConsumerState<ChatInterface> createState() => _ChatInterfaceState();
}

class _ChatInterfaceState extends ConsumerState<ChatInterface> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Audio recording variables
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    // Initialize text controller with current input from global state
    final chatState = ref.read(chatProvider);
    _controller.text = chatState.currentInput;

    // Listen to text controller changes
    _controller.addListener(() {
      final currentText = _controller.text;
      final globalText = ref.read(chatProvider).currentInput;
      if (currentText != globalText) {
        ref.read(chatProvider.notifier).setCurrentInput(currentText);
      }
    });

    // Scroll to bottom after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: chatState.messages.isEmpty
                ? _buildWelcomeMessage()
                : _buildMessagesList(chatState.messages),
          ),
          if (chatState.isLoading) _buildLoadingIndicator(),
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

  Widget _buildMessagesList(List<ChatMessage> messages) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return _buildMessageBubble(message);
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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
    final chatState = ref.watch(chatProvider);

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
                onChanged: (value) {
                  ref.read(chatProvider.notifier).setCurrentInput(value);
                },
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
          // Microphone button
          FloatingActionButton(
            onPressed: _toggleRecording,
            backgroundColor: _isRecording
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.secondary,
            foregroundColor: _isRecording
                ? Theme.of(context).colorScheme.onError
                : Theme.of(context).colorScheme.onSecondary,
            elevation: 2,
            mini: true,
            child: Icon(
              _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            onPressed: chatState.isLoading ? null : _sendMessage,
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            elevation: 2,
            child: chatState.isLoading
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
    final chatState = ref.read(chatProvider);
    if (text.isEmpty || chatState.isLoading) return;

    // Add user message to global state
    ref
        .read(chatProvider.notifier)
        .addMessage(
          ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: text,
            isUser: true,
            timestamp: DateTime.now(),
          ),
        );
    _scrollToBottom();

    // Set loading state
    ref.read(chatProvider.notifier).setLoading(true);

    _controller.clear();
    ref.read(chatProvider.notifier).setCurrentInput('');

    try {
      final response = await widget.chatSession.sendMessage(Content.text(text));
      await _handleResponse(response);
    } catch (e) {
      ref
          .read(chatProvider.notifier)
          .addMessage(
            ChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              text: 'Sorry, I encountered an error: $e',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
      _scrollToBottom();
    } finally {
      ref.read(chatProvider.notifier).setLoading(false);
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
    final shouldShowText =
        cleanText.isNotEmpty && (widgets.isEmpty || cleanText.length > 10);

    ref
        .read(chatProvider.notifier)
        .addMessage(
          ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: shouldShowText ? cleanText : '',
            isUser: false,
            timestamp: DateTime.now(),
            widgets: widgets,
          ),
        );
    _scrollToBottom();
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

  Future<void> _startRecording() async {
    try {
      // Request microphone permission
      if (await _audioRecorder.hasPermission()) {
        // Get temporary directory for recording
        final directory = kIsWeb
            ? null // Web handles this differently
            : await getTemporaryDirectory();

        final path = kIsWeb
            ? 'recording.webm'
            : '${directory!.path}/recording.m4a';

        // Start recording
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            numChannels: 1,
            sampleRate: 16000,
          ),
          path: path,
        );

        setState(() {
          _isRecording = true;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Microphone permission is required for voice input',
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('Error starting recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recording error: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });

      if (path != null) {
        await _transcribeAudio(path);
      }
    } catch (e) {
      print('Error stopping recording: $e');
      setState(() {
        _isRecording = false;
      });
    }
  }

  Future<void> _transcribeAudio(String audioPath) async {
    try {
      // Read the audio file
      final audioFile = kIsWeb
          ? null // Web handles this differently
          : File(audioPath);

      if (kIsWeb) {
        // For web, we'll show a message for now
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Web audio transcription coming soon. Please use mobile for now.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      if (audioFile != null && await audioFile.exists()) {
        final audioBytes = await audioFile.readAsBytes();

        // Create content with audio for Firebase AI
        final content = Content.multi([
          InlineDataPart('audio/m4a', audioBytes),
          TextPart(
            'Please transcribe this audio to text. Return only the transcribed text without any additional commentary.',
          ),
        ]);

        // Get the model from the provider
        final model = await ref.read(geminiModelProvider.future);

        final response = await model.generateContent([content]);
        final transcribedText = response.text?.trim() ?? '';

        if (transcribedText.isNotEmpty) {
          _controller.text = transcribedText;
          ref.read(chatProvider.notifier).setCurrentInput(transcribedText);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Audio transcribed successfully'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not transcribe audio'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }

        // Clean up the temporary file
        await audioFile.delete();
      }
    } catch (e) {
      print('Error transcribing audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transcription error: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _toggleRecording() {
    if (_isRecording) {
      _stopRecording();
    } else {
      _startRecording();
    }
  }
}
