import 'dart:developer' as dev;

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haseeb/models/activity.dart';
import 'package:haseeb/providers/chat_provider.dart';
import 'package:haseeb/services/audio_transcription_service.dart';

import '../widgets/activity_card_widget.dart';
import '../widgets/export_data_widget.dart';
import '../widgets/radial_bar_widget.dart';

class AgentChatScreen extends ConsumerStatefulWidget {
  const AgentChatScreen({super.key});

  @override
  ConsumerState<AgentChatScreen> createState() => _AgentChatScreenState();
}

double _scrollPosition = 0;

enum AudioUiState { idle, recording, transcribing }

class _AgentChatScreenState extends ConsumerState<AgentChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController(
    initialScrollOffset: _scrollPosition,
    onDetach: (position) {
      _scrollPosition = position.pixels;
    },
  );

  @override
  void initState() {
    super.initState();
    // Initialize a lightweight generative model for audio transcription
    try {
      final firebaseAI = FirebaseAI.googleAI();
      final model = firebaseAI.generativeModel(
        systemInstruction: Content.system(''),
        model: 'gemini-2.5-flash',
      );
      _audioService = AudioTranscriptionService(model);
    } catch (e) {
      dev.log(
        'initState: failed to initialize audio transcription model -> $e',
      );
    }
  }

  late AudioTranscriptionService _audioService;
  AudioUiState _audioUiState = AudioUiState.idle;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final chatNotifier = ref.read(chatNotifierProvider.notifier);
    await chatNotifier.sendMessage(text);
    _controller.clear();
    _scrollToBottom();
  }

  Future<void> _toggleRecording() async {
    dev.log('_toggleRecording: current UI state=$_audioUiState');

    if (_audioUiState == AudioUiState.transcribing) {
      // don't allow toggles while transcribing
      dev.log('_toggleRecording: ignored, transcribing in progress');
      return;
    }

    if (_audioUiState == AudioUiState.recording) {
      // stop recording and immediately show transcribing state
      setState(() {
        _audioUiState = AudioUiState.transcribing;
      });

      try {
        final text = await _audioService.stopAndTranscribe();
        if (!mounted) return;

        _controller.text = text;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: text.length),
        );

        dev.log(
          '_toggleRecording: transcription inserted, length=${text.length}',
        );
      } catch (e) {
        dev.log('_toggleRecording: stop/transcribe error -> $e');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Transcription failed: $e')));
        }
      } finally {
        if (mounted) {
          setState(() => _audioUiState = AudioUiState.idle);
        }
      }
    } else {
      // idle -> start recording
      try {
        await _audioService.startRecording();
        if (!mounted) return;
        setState(() => _audioUiState = AudioUiState.recording);
        dev.log('_toggleRecording: recording started');
      } catch (e) {
        dev.log('_toggleRecording: startRecording error -> $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not start recording: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatNotifierProvider);

    // Auto-scroll when new messages are added
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (chatState.messages.isNotEmpty) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: chatState.messages.isEmpty
                ? _buildWelcomeMessage()
                : _buildMessagesList(chatState.messages),
          ),
          _buildInputArea(chatState.isStreaming),
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
              Icons.smart_toy,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'AI Agent Assistant',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Start a conversation to see the agent execute tools in real-time!',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList(List<ChatMessage> messages) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        return _buildMessageBubble(messages[index]);
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
          color: message.isUser
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: message.isUser
                ? SelectableText(
                    selectionControls: CupertinoTextSelectionControls(),
                    selectionColor: Theme.of(context).colorScheme.error,
                    cursorColor: Theme.of(context).colorScheme.error,

                    message.text,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : _buildAgentContent(message),
          ),
        ),
      ),
    );
  }

  Widget _buildAgentContent(ChatMessage message) {
    // If this message is a widget message, map to the corresponding widget
    if (message.widgetType != null && message.widgetData != null) {
      final type = message.widgetType!;
      final data = message.widgetData!;

      try {
        switch (type) {
          case 'renderRadialBar':
            final total = (data['total'] is num)
                ? (data['total'] as num).toInt()
                : int.tryParse('${data['total']}') ?? 0;
            final done = (data['done'] is num)
                ? (data['done'] as num).toInt()
                : int.tryParse('${data['done']}') ?? 0;
            final title = data['title']?.toString() ?? 'Progress';
            return RadialBarWidget(total: total, done: done, title: title);

          case 'renderActivityCard':
            final title = data['title']?.toString() ?? 'Activity';
            final total = (data['total'] is num)
                ? (data['total'] as num).toInt()
                : int.tryParse('${data['total']}') ?? 0;
            final done = (data['done'] is num)
                ? (data['done'] as num).toInt()
                : int.tryParse('${data['done']}') ?? 0;
            DateTime timestamp;
            if (data['timestamp'] is String) {
              timestamp =
                  DateTime.tryParse(data['timestamp']) ?? DateTime.now();
            } else if (data['timestamp'] is num) {
              timestamp = DateTime.fromMillisecondsSinceEpoch(
                (data['timestamp'] as num).toInt(),
              );
            } else {
              timestamp = DateTime.now();
            }
            final typeStr = (data['type']?.toString().toUpperCase() == 'COUNT')
                ? ActivityType.count
                : ActivityType.time;
            return ActivityCardWidget(
              title: title,
              total: total,
              done: done,
              timestamp: timestamp,
              type: typeStr,
            );

          case 'initiateDataExport':
            final csv =
                data['csv']?.toString() ?? data['data']?.toString() ?? '';
            final filename = data['filename']?.toString() ?? 'export.csv';
            return ExportDataWidget(data: csv, filename: filename);

          case 'renderMarkdown':
            final md = data['content']?.toString() ?? message.text;
            return MarkdownBody(
              data: md,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
            );

          default:
            // Unknown widget type: fall back to text
            return MarkdownBody(
              data: message.text.isNotEmpty
                  ? message.text
                  : '**Unsupported widget: $type**',
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
            );
        }
      } catch (e) {
        dev.log('_buildAgentContent: error building widget $type -> $e');
        return MarkdownBody(
          data: message.text.isNotEmpty
              ? message.text
              : '**Widget render error: $e**',
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
        );
      }
    }

    // Default: render markdown text
    return MarkdownBody(
      data: message.text,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
    );
  }

  Widget _buildInputArea(bool isStreaming) {
    return Container(
      padding: const EdgeInsets.all(
        5,
      ), // Reduced padding for a slightly smaller/shrunk appearance
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              maxLines:
                  null, // Allows automatic expansion for multi-line input like WhatsApp
              minLines: 1, // Ensures it starts as a single line
              keyboardType: TextInputType
                  .multiline, // Enables multi-line keyboard behavior
              textInputAction: TextInputAction
                  .newline, // Allows new lines on enter; send via button
              decoration: InputDecoration(
                hintText: 'Type your message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
              ),
              // Removed onSubmitted to prevent accidental sends on enter; rely on button
            ),
          ),
          const SizedBox(width: 8),

          // Microphone button for recording
          FloatingActionButton(
            mini: true,
            elevation: 1,
            onPressed:
                (isStreaming || _audioUiState == AudioUiState.transcribing)
                ? null
                : _toggleRecording,
            tooltip: _audioUiState == AudioUiState.recording
                ? 'Stop recording'
                : _audioUiState == AudioUiState.transcribing
                ? 'Transcribing...'
                : 'Record audio message',
            backgroundColor: _audioUiState == AudioUiState.recording
                ? Colors.redAccent
                : _audioUiState == AudioUiState.transcribing
                ? Colors.orangeAccent
                : null,
            child: Icon(
              _audioUiState == AudioUiState.recording
                  ? Icons.stop
                  : _audioUiState == AudioUiState.transcribing
                  ? Icons.hourglass_top
                  : Icons.mic,
            ),
          ),
          const SizedBox(width: 8),
          (isStreaming)
              ? Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                )
              : FloatingActionButton(
                  elevation: 1,
                  onPressed: isStreaming ? null : _sendMessage,
                  child: const Icon(Icons.send),
                ),
        ],
      ),
    );
  }
}
