import 'dart:developer' as developer;
import 'dart:io';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/activity.dart';
import '../models/activity_type.dart';
import '../models/count_activity.dart';
import '../models/custom_list.dart';
import '../models/duration_activity.dart';
import '../models/planned_activity.dart';
import '../providers/activity_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/gemini.dart';
import '../services/activity_service.dart';
import '../widgets/activity_card_widget.dart';
import '../widgets/export_data_widget.dart';
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

  late ActivityService _activityService;

  // Task memory system - tracks completed operations for context
  final List<Map<String, dynamic>> _taskMemory = [];

  // Normalize strings for flexible matching (remove non-alphanumerics, lowercase)
  String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  // Add task to memory for agent context
  void _addToTaskMemory(String action, Map<String, dynamic> details) {
    _taskMemory.add({
      'timestamp': DateTime.now().toIso8601String(),
      'action': action,
      'details': details,
    });
    // Keep only last 10 tasks
    if (_taskMemory.length > 10) _taskMemory.removeAt(0);
    developer.log('Added to task memory: $action - $details');
  }

  // Direct database activity search (no caching)
  List<Map<String, dynamic>> _findActivitiesByKeyword(String keyword) {
    final all = _activityService.getAllActivities();
    final activitiesData = all
        .map(
          (a) => {
            'title': a.title,
            'id': a.id,
            'type': a.runtimeType
                .toString()
                .replaceAll('Activity', '')
                .toLowerCase(),
            'total': a is CountActivity
                ? a.totalCount
                : a is DurationActivity
                ? a.totalDuration
                : a is PlannedActivity
                ? a.estimatedCompletionDuration
                : 0,
            'done': a is CountActivity
                ? a.doneCount
                : a is DurationActivity
                ? a.doneDuration
                : 0, // Planned activities don't have "done" progress
            'timestamp': a.timestamp.toIso8601String(),
            if (a is PlannedActivity) 'description': a.description,
            if (a is PlannedActivity)
              'planned_type': a.type.toString().split('.').last,
          },
        )
        .toList();

    final k = _normalize(keyword);
    final matches = activitiesData.where((a) {
      final title = (a['title'] as String?) ?? '';
      return _normalize(title).contains(k);
    }).toList();

    developer.log('Found ${matches.length} activities matching "$keyword"');
    return matches;
  }

  // Get all activities formatted for agent tools (no caching)
  List<Map<String, dynamic>> _getAllActivitiesForAgent() {
    final all = _activityService.getAllActivities();
    developer.log('Found ${all.length} activities in database');
    final formatted = all
        .map(
          (a) => {
            'title': a.title,
            'id': a.id,
            'type': a.runtimeType
                .toString()
                .replaceAll('Activity', '')
                .toLowerCase(),
            'total': a is CountActivity
                ? a.totalCount
                : a is DurationActivity
                ? a.totalDuration
                : a is PlannedActivity
                ? a.estimatedCompletionDuration
                : 0,
            'done': a is CountActivity
                ? a.doneCount
                : a is DurationActivity
                ? a.doneDuration
                : 0, // Planned activities don't have "done" progress
            'timestamp': a.timestamp.toIso8601String(),
            if (a is PlannedActivity) 'description': a.description,
            if (a is PlannedActivity)
              'planned_type': a.type.toString().split('.').last,
          },
        )
        .toList();
    developer.log('Formatted ${formatted.length} activities for agent');
    return formatted;
  }

  // Find best activity match using direct database approach
  Map<String, dynamic>? _findBestActivityMatch(String keyword) {
    final matches = _findActivitiesByKeyword(keyword);
    if (matches.isEmpty) return null;

    // Return the most recent match or first if multiple
    matches.sort(
      (a, b) => (b['timestamp'] as String).compareTo(a['timestamp'] as String),
    );
    return matches.first;
  }

  @override
  void initState() {
    super.initState();
    _activityService = ref.read(activityServiceProvider);

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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
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
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
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
                padding: const EdgeInsets.all(12),
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
                          fontSize: 14,
                          height: 1.3,
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
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Row(
        children: [
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
              size: 12,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Proactive is thinking...',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                style: TextStyle(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 6),
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
              size: 16,
            ),
          ),
          const SizedBox(width: 4),
          FloatingActionButton(
            onPressed: chatState.isLoading ? null : _sendMessage,
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            elevation: 2,
            mini: true,
            child: chatState.isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 16),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    final chatState = ref.read(chatProvider);
    if (text.isEmpty || chatState.isLoading) return;

    developer.log('Sending message: "$text"');

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
      developer.log(
        'Received response with ${response.functionCalls.length} function calls',
      );
      await _handleResponse(response);
    } catch (e) {
      developer.log('Error in AI response: $e');
      // Handle Firebase AI SDK specific errors
      String errorMessage = 'Sorry, I encountered an error: $e';
      if (e.toString().contains('FinishReason')) {
        errorMessage = 'Sorry, there was an issue with the AI response. Please try again.';
      }
      ref
          .read(chatProvider.notifier)
          .addMessage(
            ChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              text: errorMessage,
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

    try {
      // Handle function calls from the response
      if (response.functionCalls.isNotEmpty) {
        developer.log(
          'Executing ${response.functionCalls.length} function call(s)',
        );
        for (final call in response.functionCalls) {
          try {
            developer.log('Calling function: ${call.name} with args: ${call.args}');
            final result = await _executeFunctionCall(call);
            if (result != null) {
              widgets.add(result);
              developer.log('Function ${call.name} returned a widget');
            } else {
              developer.log('Function ${call.name} returned null');
            }
          } catch (e) {
            developer.log('Error executing function ${call.name}: $e');
            widgets.add(MarkdownWidget(content: '❌ Error executing ${call.name}: $e'));
          }
        }
      }
    } catch (e) {
      developer.log('Error handling function calls: $e');
      widgets.add(MarkdownWidget(content: '❌ Error processing response: $e'));
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

    // Proactive activity updates - check if user message contains update patterns
    await _performProactiveUpdate();
  }

  // Proactive update logic - collection-based approach with flexible parsing
  Future<void> _performProactiveUpdate() async {
    try {
      final chatState = ref.read(chatProvider);
      final lastUser = chatState.messages.lastWhere(
        (m) => m.isUser,
        orElse: () => ChatMessage(
          id: '',
          text: '',
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      final userText = lastUser.text.toLowerCase();

      if (userText.isEmpty) return;

      // Try smart parsing first for more natural language processing
      final result = await _parseAndUpdateActivity(userText);
      if (result == null) {
        // Successfully updated via smart parsing
        return;
      }

      // Fall back to pattern-based matching for specific cases
      // Look for percentage patterns like "50%" or "50 percent"
      final percentMatch = RegExp(
        r'(\d{1,3})\s*(?:%|percent)',
      ).firstMatch(userText);

      // Look for absolute numbers with activity keywords
      final numberMatch = RegExp(r'(\d{1,6})').firstMatch(userText);
      final keywordMatch = RegExp(
        r'pushup|pushups|push-ups|run|running|situp|sit-ups|sit ups|squats|burpees|plank|exercise',
      ).firstMatch(userText);

      // Look for zero/reset patterns
      final zeroMatch = RegExp(
        r'(zero|0|none|not done|not|no)\s*(pushup|pushups|push-ups|run|running|situp|sit-ups|sit ups|squats|burpees|plank|exercise)',
      ).firstMatch(userText);

      // Look for duration patterns like "60 minutes" or "2 hours"
      final durationMatch = RegExp(
        r'(\d{1,4})\s*(minute|minutes|hour|hours|min|mins|hr|hrs)',
      ).firstMatch(userText);
      final durationKeywordMatch = RegExp(
        r'study|studying|read|reading|meditation|meditate|work|working|exercise|exercising|time|book|learning',
      ).firstMatch(userText);

      Map<String, dynamic>? candidate;

      if (percentMatch != null) {
        final percent = int.parse(percentMatch.group(1)!);
        // Look for any COUNT activity for percentage updates
        final countActivities = _findActivitiesByKeyword('')
            .where(
              (a) =>
                  (a['type'] as String).toLowerCase() == 'count' &&
                  (a['total'] as int?) != null &&
                  (a['total'] as int) > 0,
            )
            .toList();

        if (countActivities.isNotEmpty) {
          candidate = countActivities.first;
          final total = candidate['total'] as int;
          final desiredCount = (total * percent / 100).round();

          await _updateActivityAndNotify(
            candidate,
            'done_count',
            desiredCount,
            'Updated activity to $percent%.',
          );
        }
      } else if (zeroMatch != null) {
        // Handle zero/reset patterns
        final keyword =
            zeroMatch.group(2) ??
            'pushup'; // Default to pushup if no specific keyword

        // Find activity matching the keyword using collection-based approach
        candidate = _findBestActivityMatch(keyword);

        if (candidate != null) {
          await _updateActivityAndNotify(
            candidate,
            'done_count',
            0,
            '✅ Reset "${candidate['title']}" to 0 done.',
          );
        }
      } else if (durationMatch != null && durationKeywordMatch != null) {
        // Handle duration-based updates
        final durationValue = int.parse(durationMatch.group(1)!);
        final durationUnit = durationMatch.group(2)!.toLowerCase();
        final keyword = durationKeywordMatch.group(0)!;

        // Convert to minutes if needed
        int minutes = durationValue;
        if (durationUnit.startsWith('hour') || durationUnit.startsWith('hr')) {
          minutes = durationValue * 60;
        }

        // Find duration activity matching the keyword
        candidate = _findActivitiesByKeyword(keyword)
            .where((a) => (a['type'] as String).toLowerCase() == 'duration')
            .firstOrNull;

        if (candidate != null) {
          await _updateActivityAndNotify(
            candidate,
            'done_duration',
            minutes,
            '✅ Updated "${candidate['title']}" to $minutes minutes done.',
          );
        }
      } else if (numberMatch != null && keywordMatch != null) {
        final numVal = int.parse(numberMatch.group(1)!);
        final keyword = keywordMatch.group(0)!;

        // Find activity matching the keyword using collection-based approach
        candidate = _findBestActivityMatch(keyword);

        if (candidate != null) {
          await _updateActivityAndNotify(
            candidate,
            'done_count',
            numVal,
            '✅ Updated "${candidate['title']}" to $numVal done.',
          );
        }
      }
    } catch (e) {
      developer.log('Error during proactive update: $e');
    }
  }

  // Helper to update activity and send notification
  Future<void> _updateActivityAndNotify(
    Map<String, dynamic> activity,
    String attribute,
    dynamic value,
    String message,
  ) async {
    final success = await _activityService.modifyActivityAttribute(
      activity['id'] as String,
      attribute,
      value,
    );

    if (success) {
      _addToTaskMemory('proactive_update', {
        'activity_id': activity['id'],
        'attribute': attribute,
        'value': value,
      });

      // Get updated activity from database
      final updated = _activityService.getActivity(activity['id'] as String);

      final widget = ActivityCardWidget(
        title: updated?.title ?? activity['title'] as String,
        total: updated is CountActivity
            ? updated.totalCount
            : updated is DurationActivity
            ? updated.totalDuration
            : activity['total'] as int,
        done: updated is CountActivity
            ? updated.doneCount
            : updated is DurationActivity
            ? updated.doneDuration
            : value as int,
        timestamp: updated?.timestamp ?? DateTime.now(),
        type: activity['type'] as String? ?? 'COUNT',
      );

      ref
          .read(chatProvider.notifier)
          .addMessage(
            ChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              text: message,
              isUser: false,
              timestamp: DateTime.now(),
              widgets: [widget],
            ),
          );
      _scrollToBottom();
    } else {
      developer.log('Proactive update failed for ${activity['id']}');
    }
  }

  // Intelligent parsing of natural language updates - TOOL-ORIENTED APPROACH
  Future<Widget?> _parseAndUpdateActivity(String description) async {
    // This method should NO LONGER contain hard-coded logic
    // Instead, it should delegate to the agent's tool calling system

    // Special handling for "move to active" requests
    if (description.toLowerCase().contains('move') &&
        description.toLowerCase().contains('active')) {
      // Extract planned activity identifier from the description
      final match = RegExp(r'planned_(\d+)').firstMatch(description);
      if (match != null) {
        final plannedId = match.group(0)!;

        // Delegate to the chat system to handle this via tools
        final response = await widget.chatSession.sendMessage(
          Content.text(
            'Start planned activity with ID $plannedId as a duration activity with 120 minutes target',
          ),
        );

        if (response.functionCalls.isNotEmpty) {
          final widgets = <Widget>[];
          for (final call in response.functionCalls) {
            final result = await _executeFunctionCall(call);
            if (result != null) {
              widgets.add(result);
            }
          }

          if (widgets.isNotEmpty) {
            return widgets.first;
          }
        }
      }
    }

    // Return null to indicate no processing was done
    return null;
  }

  Future<Widget?> _executeFunctionCall(FunctionCall call) async {
    switch (call.name) {
      case 'find_activity':
        final args = call.args;
        final keyword = args['keyword'] as String?;

        if (keyword == null || keyword.isEmpty) {
          developer.log('Missing keyword for find_activity');
          return MarkdownWidget(
            content: '❌ Please provide a keyword to search for activities.',
          );
        }

        try {
          final matches = _findActivitiesByKeyword(keyword);

          _addToTaskMemory('find_activity', {
            'keyword': keyword,
            'results_count': matches.length,
          });

          if (matches.isEmpty) {
            final totalActivities = _getAllActivitiesForAgent().length;
            return MarkdownWidget(
              content:
                  '❌ No activities found matching "$keyword".\n\n**Available activities:** $totalActivities total in collection.',
            );
          }

          // Return detailed activity information with exact IDs
          final activityList = matches
              .map(
                (data) =>
                    '**${data['title']}** (ID: `${data['id']}`, Type: ${data['type']?.toString().toUpperCase()}, Progress: ${data['done']}/${data['total']})',
              )
              .join('\n');

          return MarkdownWidget(
            content:
                'Found ${matches.length} activities matching "$keyword":\n\n$activityList\n\n✅ Use the exact ID above with `modify_activity` to update progress.',
          );
        } catch (e) {
          developer.log('Error finding activities: $e');
          return MarkdownWidget(content: '❌ Error searching activities: $e');
        }

      case 'get_active_activities':
        try {
          final allActivities = _getAllActivitiesForAgent();
          final activeActivities = allActivities.where((a) {
            final total = a['total'] as int? ?? 0;
            final done = a['done'] as int? ?? 0;
            return done < total; // Not completed yet
          }).toList();

          _addToTaskMemory('get_active_activities', {
            'results_count': activeActivities.length,
          });

          if (activeActivities.isEmpty) {
            return MarkdownWidget(
              content:
                  '🎉 Great! You have no active activities - everything is completed!',
            );
          }

          final activityList = activeActivities
              .map(
                (data) =>
                    '**${data['title']}** (${data['type']?.toString().toUpperCase()}) - Progress: ${data['done']}/${data['total']} (${((data['done'] as int) / (data['total'] as int) * 100).round()}%)',
              )
              .join('\n');

          return MarkdownWidget(
            content:
                '📋 **Active Activities** (${activeActivities.length} in progress):\n\n$activityList',
          );
        } catch (e) {
          developer.log('Error getting active activities: $e');
          return MarkdownWidget(
            content: '❌ Error getting active activities: $e',
          );
        }

      case 'get_completed_activities':
        try {
          final allActivities = _getAllActivitiesForAgent();
          final completedActivities = allActivities.where((a) {
            final total = a['total'] as int? ?? 0;
            final done = a['done'] as int? ?? 0;
            return done >= total; // Completed
          }).toList();

          _addToTaskMemory('get_completed_activities', {
            'results_count': completedActivities.length,
          });

          if (completedActivities.isEmpty) {
            return MarkdownWidget(
              content:
                  '📝 No completed activities yet. Keep working on your goals!',
            );
          }

          final activityList = completedActivities
              .map(
                (data) =>
                    '✅ **${data['title']}** (${data['type']?.toString().toUpperCase()}) - ${data['done']}/${data['total']}',
              )
              .join('\n');

          return MarkdownWidget(
            content:
                '🏆 **Completed Activities** (${completedActivities.length} achievements):\n\n$activityList',
          );
        } catch (e) {
          developer.log('Error getting completed activities: $e');
          return MarkdownWidget(
            content: '❌ Error getting completed activities: $e',
          );
        }

      case 'get_all_activities':
        try {
          final allActivities = _getAllActivitiesForAgent();

          _addToTaskMemory('get_all_activities', {
            'results_count': allActivities.length,
          });

          if (allActivities.isEmpty) {
            return MarkdownWidget(
              content:
                  '📝 No activities found. Create some activities to get started!',
            );
          }

          final activityList = allActivities
              .map((data) {
                final status = (data['done'] as int) >= (data['total'] as int)
                    ? '✅'
                    : '⏳';
                return '$status **${data['title']}** (${data['type']?.toString().toUpperCase()}) - ${data['done']}/${data['total']} (ID: `${data['id']}`)';
              })
              .join('\n');

          return MarkdownWidget(
            content:
                '📋 **All Activities** (${allActivities.length} total):\n\n$activityList',
          );
        } catch (e) {
          developer.log('Error getting all activities: $e');
          return MarkdownWidget(content: '❌ Error getting all activities: $e');
        }

      case 'smart_update_activity':
        final args = call.args;
        final description = args['description'] as String?;

        if (description == null || description.isEmpty) {
          return MarkdownWidget(
            content: '❌ Please provide a description of what to update.',
          );
        }

        try {
          // Parse the description intelligently
          final result = await _parseAndUpdateActivity(description);

          if (result != null) {
            return result;
          } else {
            return MarkdownWidget(
              content:
                  '❌ Could not understand the update request. Please be more specific about which activity and what value to update.',
            );
          }
        } catch (e) {
          developer.log('Error in smart update: $e');
          return MarkdownWidget(content: '❌ Error processing update: $e');
        }

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

      case 'export_data':
        final args = call.args;
        final requestedIds = args['activities'] as List<dynamic>? ?? [];

        developer.log('Export data called with args: $args');
        developer.log('Requested IDs: $requestedIds');

        try {
          List<Map<String, dynamic>> activitiesToExport;
          String exportDescription;

          if (requestedIds.isEmpty) {
            // Export all activities if no specific IDs provided
            activitiesToExport = _getAllActivitiesForAgent();
            exportDescription = 'all activities';
            developer.log('Exporting all activities: ${activitiesToExport.length} found');
          } else {
            // Export specific activities by ID
            activitiesToExport = [];
            for (final id in requestedIds) {
              final activity = _activityService.getActivity(id as String);
              if (activity != null) {
                final activityData = _getAllActivitiesForAgent().firstWhere(
                  (a) => a['id'] == id,
                  orElse: () => {},
                );
                if (activityData.isNotEmpty) {
                  activitiesToExport.add(activityData);
                }
              } else {
                developer.log('Activity with ID $id not found');
              }
            }
            exportDescription = 'selected activities';
            developer.log('Exporting specific activities: ${activitiesToExport.length} found');
          }

          if (activitiesToExport.isEmpty) {
            developer.log('No activities to export');
            return MarkdownWidget(
              content:
                  '📄 No activities found to export. Please create some activities first!',
            );
          }

          developer.log(
            'Exporting ${activitiesToExport.length} activities to CSV',
          );
          final csvData = _convertActivitiesToCSV(activitiesToExport);
          developer.log(
            'CSV data generated, length: ${csvData.length} characters',
          );

          _addToTaskMemory('export_data', {
            'exported_count': activitiesToExport.length,
            'description': exportDescription,
          });

          return ExportDataWidget(
            data: csvData,
            filename:
                'activities_export_${DateTime.now().millisecondsSinceEpoch}.csv',
          );
        } catch (e) {
          developer.log('Error exporting data: $e');
          return MarkdownWidget(content: '❌ Error exporting data: $e');
        }

      case 'modify_activity':
        final args = call.args;
        final id = args['id'] as String?;
        final attribute = args['attribute'] as String?;
        final value = args['value'];

        if (id == null || attribute == null) {
          developer.log('Missing required parameters for modify_activity');
          return null;
        }

        try {
          final success = await _activityService.modifyActivityAttribute(
            id,
            attribute,
            value,
          );
          developer.log(
            'Modified activity $id attribute $attribute to $value: $success',
          );

          if (success) {
            _addToTaskMemory('modify_activity', {
              'id': id,
              'attribute': attribute,
              'value': value,
            });

            // Return a simple confirmation widget
            return MarkdownWidget(content: '✅ Activity updated successfully!');
          } else {
            return MarkdownWidget(
              content:
                  '❌ Failed to update activity. Please check the activity ID and attribute.',
            );
          }
        } catch (e) {
          developer.log('Error modifying activity: $e');
          return MarkdownWidget(content: '❌ Error updating activity: $e');
        }

      case 'fetch_activity_data':
        final args = call.args;
        final filter = args['filter'] as Map<String, dynamic>? ?? {};

        try {
          // Get all activities directly from database
          List<Map<String, dynamic>> activities = _getAllActivitiesForAgent();

          // Apply filters to the collection (not as primary lookup)
          if (filter.containsKey('type')) {
            final type = filter['type'] as String;
            activities = activities
                .where(
                  (a) =>
                      (a['type'] as String).toUpperCase() == type.toUpperCase(),
                )
                .toList();
          }

          if (filter.containsKey('title_contains') &&
              (filter['title_contains'] as String).isNotEmpty) {
            final searchTerm = _normalize(filter['title_contains'] as String);
            activities = activities
                .where(
                  (a) => _normalize(a['title'] as String).contains(searchTerm),
                )
                .toList();
          }

          if (filter.containsKey('completion_status')) {
            final status = filter['completion_status'] as String;
            if (status == 'completed') {
              activities = activities.where((a) {
                final total = (a['total'] as int?) ?? 0;
                final done = (a['done'] as int?) ?? 0;
                return total > 0 && done >= total;
              }).toList();
            } else if (status == 'in_progress') {
              activities = activities.where((a) {
                final total = (a['total'] as int?) ?? 0;
                final done = (a['done'] as int?) ?? 0;
                return total > 0 && done < total;
              }).toList();
            }
          }

          _addToTaskMemory('fetch_activity_data', {
            'filter': filter,
            'results_count': activities.length,
          });

          developer.log(
            'Collection-based fetch: ${activities.length} activities',
          );

          if (activities.isEmpty) {
            final totalActivities = _getAllActivitiesForAgent().length;
            return MarkdownWidget(
              content:
                  'No activities found matching the criteria.\n\n**Available activities:** $totalActivities total in collection.',
            );
          }

          final activityList = activities
              .map(
                (data) =>
                    'TITLE: ${data['title']} | ID: ${data['id']} | TYPE: ${data['type']} | PROGRESS: ${data['done']}/${data['total']}',
              )
              .join('\n');

          return MarkdownWidget(
            content:
                'Found ${activities.length} activities:\n```\n$activityList\n```\n\n**To modify an activity:** Use the exact ID from "ID: " (e.g., "count_1725739200000") in the modify_activity tool.',
          );
        } catch (e) {
          developer.log('Error fetching activities: $e');
          return MarkdownWidget(content: '❌ Error fetching activities: $e');
        }

      case 'create_activity':
        final args = call.args;
        final type = args['type'] as String?;
        final title = args['title'] as String?;
        final totalValue = (args['total_value'] as num?)?.toInt();
        final description = args['description'] as String? ?? '';
        final isPlanned = args['is_planned'] as bool? ?? false;
        final plannedType = args['planned_type'] as String?;

        if (type == null || title == null || totalValue == null) {
          developer.log('Missing required parameters for create_activity');
          return null;
        }

        try {
          String id;
          if (isPlanned) {
            // Create a planned activity
            if (plannedType == null) {
              return MarkdownWidget(
                content:
                    '❌ planned_type is required when creating planned activities',
              );
            }
            id = await _activityService.createNewActivity(
              'PLANNED',
              title,
              totalValue,
              description: description,
              plannedType: plannedType,
            );
            developer.log('Created new PLANNED activity: $title with ID: $id');
          } else {
            // Create regular activity
            id = await _activityService.createNewActivity(
              type,
              title,
              totalValue,
              description: description,
            );
            developer.log('Created new $type activity: $title with ID: $id');
          }

          _addToTaskMemory('create_activity', {
            'type': isPlanned ? 'PLANNED' : type,
            'title': title,
            'total_value': totalValue,
            'id': id,
          });

          final activityTypeDisplay = isPlanned ? 'planned' : type;
          return MarkdownWidget(
            content:
                '✅ Created new $activityTypeDisplay activity: "$title" (ID: $id)',
          );
        } catch (e) {
          developer.log('Error creating activity: $e');
          return MarkdownWidget(content: '❌ Error creating activity: $e');
        }

      case 'get_planned_activities':
        try {
          final allActivities = _getAllActivitiesForAgent();
          final plannedActivities = allActivities.where((a) {
            return a['type'] == 'planned';
          }).toList();

          _addToTaskMemory('get_planned_activities', {
            'results_count': plannedActivities.length,
          });

          if (plannedActivities.isEmpty) {
            return MarkdownWidget(
              content:
                  '📅 No planned activities found. Create some planned activities to organize your future goals!',
            );
          }

          final activityList = plannedActivities
              .map(
                (data) =>
                    '📋 **${data['title']}** (ID: `${data['id']}`) - Estimated: ${data['total']} minutes\n   Description: ${data['description'] ?? 'No description'}',
              )
              .join('\n\n');

          return MarkdownWidget(
            content:
                '📅 **Planned Activities** (${plannedActivities.length} planned):\n\n$activityList',
          );
        } catch (e) {
          developer.log('Error getting planned activities: $e');
          return MarkdownWidget(
            content: '❌ Error getting planned activities: $e',
          );
        }

      case 'start_planned_activity':
        final args = call.args;
        final plannedId = args['planned_id'] as String?;
        final targetValue = (args['target_value'] as num?)?.toInt();

        if (plannedId == null || targetValue == null) {
          return MarkdownWidget(
            content:
                '❌ Please provide planned_id and target_value to start a planned activity.',
          );
        }

        try {
          final plannedActivity = _activityService.getActivity(plannedId);
          if (plannedActivity == null) {
            return MarkdownWidget(
              content: '❌ Planned activity with ID "$plannedId" not found.',
            );
          }

          if (plannedActivity is! PlannedActivity) {
            return MarkdownWidget(
              content:
                  '❌ Activity with ID "$plannedId" is not a planned activity.',
            );
          }

          // Create a new activity based on the planned one
          final plannedType = plannedActivity.type;
          String newType;

          if (plannedType == ActivityType.COUNT) {
            newType = 'COUNT';
          } else if (plannedType == ActivityType.DURATION) {
            newType = 'DURATION';
          } else {
            newType = 'DURATION'; // Default fallback
          }

          final newId = await _activityService.createNewActivity(
            newType,
            plannedActivity.title,
            targetValue,
            description: plannedActivity.description,
          );

          // Delete the planned activity after starting it
          await _activityService.deleteActivity(plannedId);

          developer.log(
            'Started planned activity $plannedId as new activity $newId',
          );

          _addToTaskMemory('start_planned_activity', {
            'planned_id': plannedId,
            'new_id': newId,
            'type': newType,
          });

          return MarkdownWidget(
            content:
                '✅ Started planned activity "${plannedActivity.title}" as new $newType activity!\n\n🎯 Target: $targetValue ${newType == 'COUNT' ? 'repetitions' : 'minutes'}\n📝 Description: ${plannedActivity.description}\n🆔 New ID: $newId',
          );
        } catch (e) {
          developer.log('Error starting planned activity: $e');
          return MarkdownWidget(
            content: '❌ Error starting planned activity: $e',
          );
        }

      case 'create_custom_list':
        final args = call.args;
        final title = args['title'] as String?;
        final activityIds =
            (args['activities'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [];

        if (title == null) {
          developer.log('Missing title for create_custom_list');
          return null;
        }

        try {
          // Fetch activities by IDs
          final activities = activityIds
              .map((id) => _activityService.getActivity(id))
              .where((activity) => activity != null)
              .cast<Activity>()
              .toList();
          final customList = CustomList(title: title, activities: activities);
          await _activityService.addCustomList(customList);
          developer.log(
            'Created custom list: $title with ${activities.length} activities',
          );
          return MarkdownWidget(
            content:
                '✅ Created custom list: "$title" with ${activities.length} activities',
          );
        } catch (e) {
          developer.log('Error creating custom list: $e');
          return MarkdownWidget(content: '❌ Error creating custom list: $e');
        }

      case 'delete_activity':
        final args = call.args;
        final id = args['id'] as String?;

        if (id == null || id.isEmpty) {
          return MarkdownWidget(
            content: '❌ Please provide an activity ID to delete.',
          );
        }

        try {
          final activity = _activityService.getActivity(id);
          if (activity == null) {
            return MarkdownWidget(
              content: '❌ Activity with ID "$id" not found.',
            );
          }

          final title = activity.title;
          await _activityService.deleteActivity(id);

          developer.log('Deleted activity: $title (ID: $id)');

          return MarkdownWidget(
            content:
                '✅ Successfully deleted activity "$title". It has been removed from all collections.',
          );
        } catch (e) {
          developer.log('Error deleting activity: $e');
          return MarkdownWidget(content: '❌ Error deleting activity: $e');
        }

      case 'suggest_activity':
        final args = call.args;
        final criteria = args['criteria'] as String? ?? '';

        try {
          final allActivities = _getAllActivitiesForAgent();
          final plannedActivities = allActivities.where((a) {
            return a['type'] == 'planned';
          }).toList();

          if (plannedActivities.isEmpty) {
            return MarkdownWidget(
              content:
                  '💡 I don\'t see any planned activities to suggest. Would you like me to help you create some goals for today?',
            );
          }

          // Simple suggestion logic - pick the first planned activity or one matching criteria
          Map<String, dynamic> selectedActivity;
          if (criteria.isNotEmpty) {
            final normalizedCriteria = _normalize(criteria);
            final matches = plannedActivities.where((a) {
              return _normalize(
                    a['title'] as String,
                  ).contains(normalizedCriteria) ||
                  _normalize(
                    a['description'] as String? ?? '',
                  ).contains(normalizedCriteria);
            }).toList();

            selectedActivity = matches.isNotEmpty
                ? matches.first
                : plannedActivities.first;
          } else {
            selectedActivity = plannedActivities.first;
          }

          // Convert planned activity to active activity
          final plannedId = selectedActivity['id'] as String;
          final title = selectedActivity['title'] as String;
          final estimatedDuration = selectedActivity['total'] as int;

          // Create new active activity based on planned activity
          final newId = await _activityService.createNewActivity(
            'DURATION',
            title,
            estimatedDuration,
            description: 'Started from planned activity',
          );

          // Delete the planned activity
          await _activityService.deleteActivity(plannedId);

          developer.log(
            'Converted planned activity $plannedId to active activity $newId',
          );

          return MarkdownWidget(
            content:
                '🎯 Perfect! I\'ve moved **"$title"** from your planned activities to today\'s active goals. You have $estimatedDuration minutes allocated for this. Ready to get started?',
          );
        } catch (e) {
          developer.log('Error suggesting activity: $e');
          return MarkdownWidget(content: '❌ Error suggesting activity: $e');
        }

      default:
        return null;
    }
  }

  String _convertActivitiesToCSV(List<dynamic> activities) {
    if (activities.isEmpty) {
      return 'Title,Type,Total,Done,Progress %,Timestamp,Status,Description\n"No activities to export","","","","","",""';
    }

    // Enhanced CSV header with description for planned activities
    final headers = [
      'Title',
      'Type',
      'Total',
      'Done',
      'Progress %',
      'Timestamp',
      'Status',
      'Description',
    ];
    final csvRows = [headers.join(',')];

    // Convert each activity to CSV row
    for (final activity in activities) {
      if (activity is Map<String, dynamic>) {
        final title = activity['title'] ?? '';
        final type = (activity['type'] ?? 'COUNT').toString().toUpperCase();
        final total = activity['total'] ?? 0;
        final done = activity['done'] ?? 0;
        final description = activity['description'] ?? '';
        final plannedType = activity['planned_type'] ?? '';

        // Handle different activity types
        String status;
        String progressText;
        if (type == 'PLANNED') {
          status = 'Planned';
          progressText = 'N/A';
        } else {
          final progress = total > 0 ? ((done / total) * 100).round() : 0;
          progressText = '$progress%';
          status = progress >= 100 ? 'Completed' : 'In Progress';
        }

        final timestamp =
            activity['timestamp'] ?? DateTime.now().toIso8601String();
        final typeDisplay = type == 'PLANNED' ? 'PLANNED ($plannedType)' : type;

        final row = [
          '"${title.replaceAll('"', '""')}"', // Escape quotes in CSV
          typeDisplay,
          total.toString(),
          done.toString(),
          progressText,
          timestamp.split('T')[0], // Just the date part
          status,
          '"${description.replaceAll('"', '""')}"', // Escape quotes in description
        ];

        csvRows.add(row.join(','));
      }
    }

    return csvRows.join('\n');
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
    developer.log('Starting audio recording');
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
      developer.log('Error starting recording', error: e);
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
    developer.log('Stopping audio recording');
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });

      if (path != null) {
        await _transcribeAudio(path);
      }
    } catch (e) {
      developer.log('Error stopping recording', error: e);
      setState(() {
        _isRecording = false;
      });
    }
  }

  Future<void> _transcribeAudio(String audioPath) async {
    developer.log('Starting audio transcription for file: $audioPath');
    try {
      // Read the audio file
      final audioFile = kIsWeb
          ? null // Web handles this differently
          : File(audioPath);

      if (kIsWeb) {
        // For web, we'll show a message for now
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(
        //     content: Text(
        //       'Web audio transcription coming soon. Please use mobile for now.',
        //     ),
        //     duration: Duration(seconds: 3),
        //   ),
        // );
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
          developer.log('Audio transcription successful: "$transcribedText"');
          _controller.text = transcribedText;
          ref.read(chatProvider.notifier).setCurrentInput(transcribedText);

          if (mounted) {
            // ScaffoldMessenger.of(context).showSnackBar(
            //   const SnackBar(
            //     content: Text('Audio transcribed successfully'),
            //     duration: Duration(seconds: 2),
            //   ),
            // );
          }
        } else {
          developer.log('Audio transcription failed - empty response');
          // if (mounted) {
          //   ScaffoldMessenger.of(context).showSnackBar(
          //     const SnackBar(
          //       content: Text('Could not transcribe audio'),
          //       duration: Duration(seconds: 2),
          //     ),
          //   );
          // }
        }

        // Clean up the temporary file
        await audioFile.delete();
      }
    } catch (e) {
      developer.log('Error transcribing audio', error: e);
      // if (mounted) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(
      //       content: Text('Transcription error: $e'),
      //       duration: const Duration(seconds: 3),
      //     ),
      //   );
      // }
    }
  }

  void _toggleRecording() {
    developer.log(
      'Toggle recording called, current state: ${_isRecording ? "recording" : "not recording"}',
    );
    if (_isRecording) {
      _stopRecording();
    } else {
      _startRecording();
    }
  }
}
