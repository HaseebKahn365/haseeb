import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haseeb/models/activity.dart' as models_activity;
import 'package:haseeb/providers/llm_tools.dart';
import 'package:haseeb/repository/activity_manager.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? widgetType;
  final Map<String, dynamic>? widgetData;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.widgetType,
    this.widgetData,
  });

  ChatMessage copyWith({
    String? text,
    bool? isUser,
    DateTime? timestamp,
    String? widgetType,
    Map<String, dynamic>? widgetData,
  }) {
    return ChatMessage(
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      widgetType: widgetType ?? this.widgetType,
      widgetData: widgetData ?? this.widgetData,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'widgetType': widgetType,
      'widgetData': widgetData,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final widgetData = json['widgetData'];
    return ChatMessage(
      text: json['text'] as String? ?? '',
      isUser: json['isUser'] as bool? ?? false,
      timestamp: DateTime.parse(
        json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
      ),
      widgetType: json['widgetType'] as String?,
      widgetData: widgetData is Map
          ? Map<String, dynamic>.from(widgetData)
          : null,
    );
  }
}

class ChatState {
  final List<ChatMessage> messages;
  final bool isStreaming;
  final bool isInitialized;

  ChatState({
    required this.messages,
    required this.isStreaming,
    required this.isInitialized,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isStreaming,
    bool? isInitialized,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier()
    : super(ChatState(messages: [], isStreaming: false, isInitialized: false)) {
    _initialize();
  }

  FirebaseAI? _firebaseAI;
  GenerativeModel? _model;
  ChatSession? _chatSession;
  String? _systemPrompt;
  bool _messagesLoaded = false;
  StreamSubscription<GenerateContentResponse>? _streamSubscription;

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    if (state.isInitialized) {
      dev.log('Chat already initialized, skipping');
      return;
    }

    try {
      dev.log('Initializing Firebase AI generative model');
      _systemPrompt = await rootBundle.loadString('assets/system_prompt.md');
      _firebaseAI = FirebaseAI.googleAI();

      _model = _firebaseAI!.generativeModel(
        systemInstruction: Content.system(_systemPrompt!),
        model: 'gemini-2.5-flash',
        tools: toolsForLLM,
      );

      await _loadMessages();

      final history = <Content>[];
      for (final message in state.messages) {
        // Both user and agent messages are added to history as text
        history.add(Content.text(message.text));
      }

      _chatSession = _model!.startChat(history: history);

      state = state.copyWith(isInitialized: true);
      dev.log(
        'Chat session initialized with ${state.messages.length} messages',
      );
    } catch (e) {
      dev.log('Error initializing chat: $e');
    }
  }

  void addMessage(ChatMessage message) {
    if (mounted) {
      state = state.copyWith(messages: [...state.messages, message]);
      _saveMessages();
    }
  }

  void updateLastMessage(String text) {
    if (mounted && state.messages.isNotEmpty && !state.messages.last.isUser) {
      final updatedMessages = [...state.messages];
      updatedMessages[updatedMessages.length - 1] = updatedMessages.last
          .copyWith(text: updatedMessages.last.text + text);
      state = state.copyWith(messages: updatedMessages);
      _saveMessages();
    }
  }

  void setStreaming(bool isStreaming) {
    if (mounted) {
      state = state.copyWith(isStreaming: isStreaming);
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || state.isStreaming || !state.isInitialized)
      return;

    dev.log('sendMessage: user input -> $text');

    addMessage(
      ChatMessage(text: text, isUser: true, timestamp: DateTime.now()),
    );
    setStreaming(true);

    addMessage(ChatMessage(text: '', isUser: false, timestamp: DateTime.now()));

    try {
      final content = Content.text(text);

      _streamSubscription = _chatSession!
          .sendMessageStream(content)
          .listen(
            (GenerateContentResponse response) {
              if (!mounted) return;

              dev.log(
                'stream: received response -> text length=${response.text?.length ?? 0} functionCalls=${response.functionCalls.length}',
              );

              if (response.text != null && response.text!.isNotEmpty) {
                updateLastMessage(response.text!);
              }

              if (response.functionCalls.isNotEmpty) {
                for (final call in response.functionCalls) {
                  _handleFunctionCall(_chatSession!, call);
                }
              }
            },
            onDone: () {
              if (mounted) {
                setStreaming(false);
              }
              _streamSubscription?.cancel();
            },
            onError: (error) {
              dev.log('stream: onError -> $error');
              if (mounted && !error.toString().contains('Connection closed')) {
                addMessage(
                  ChatMessage(
                    text: 'Error: $error',
                    isUser: false,
                    timestamp: DateTime.now(),
                  ),
                );
              }
              if (mounted) {
                setStreaming(false);
              }
            },
          );
    } catch (e) {
      dev.log('sendMessage: exception starting chat -> $e');
      if (mounted) {
        addMessage(
          ChatMessage(
            text: 'Error starting conversation: $e',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        setStreaming(false);
      }
    }
  }

  Future<void> _handleFunctionCall(ChatSession chat, FunctionCall call) async {
    if (!mounted) return;

    try {
      dev.log(
        'handleFunctionCall: executing ${call.name} with args=${call.args}',
      );

      final widgetTools = {
        'renderRadialBar',
        'renderActivityCard',
        'renderMarkdown',
        'initiateDataExport',
      };

      if (widgetTools.contains(call.name)) {
        dev.log('handleFunctionCall: mapping ${call.name} to widget message');

        final args = Map<String, dynamic>.from(call.args);

        final widgetMessage = ChatMessage(
          text: '',
          isUser: false,
          timestamp: DateTime.now(),
          widgetType: call.name,
          widgetData: args,
        );
        addMessage(widgetMessage);

        // For widget functions, just render and don't send response back
        // This prevents infinite loops
        dev.log('handleFunctionCall: widget rendered, no response needed');
        return;
      }

      // For non-widget functions, execute and send result back
      final result = await _executeFunction(call);
      final functionResponse = Content.functionResponse(call.name, {
        'result': result,
      });

      _streamSubscription?.cancel();
      await Future.delayed(const Duration(milliseconds: 100));

      _streamSubscription = chat
          .sendMessageStream(functionResponse)
          .listen(
            (GenerateContentResponse response) {
              if (!mounted) return;

              if (response.text != null && response.text!.isNotEmpty) {
                updateLastMessage(response.text!);
              }

              if (response.functionCalls.isNotEmpty) {
                for (final newCall in response.functionCalls) {
                  _handleFunctionCall(chat, newCall);
                }
              }
            },
            onDone: () {
              if (mounted) {
                setStreaming(false);
              }
              _streamSubscription?.cancel();
            },
            onError: (error) {
              dev.log('post-function stream: onError -> $error');
              if (mounted && !error.toString().contains('Connection closed')) {
                addMessage(
                  ChatMessage(
                    text: 'Error in function response: $error',
                    isUser: false,
                    timestamp: DateTime.now(),
                  ),
                );
              }
              if (mounted) {
                setStreaming(false);
              }
            },
          );
    } catch (e) {
      dev.log('handleFunctionCall: exception executing ${call.name} -> $e');
      if (mounted) {
        addMessage(
          ChatMessage(
            text: 'Error executing function ${call.name}: $e',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        setStreaming(false);
      }
    }
  }

  Future<dynamic> _executeFunction(FunctionCall call) async {
    dev.log('_executeFunction: ${call.name} args=${call.args}');
    switch (call.name) {
      case 'currentDateTime':
        // Return current datetime. Support optional timezone and format hints.
        dev.log(
          '_executeFunction: currentDateTime called with args=${call.args}',
        );
        try {
          final args = call.args as Map<String, dynamic>;
          final tzRaw = (args['timezone'] as String?) ?? '';
          final tz = tzRaw.toLowerCase();
          final format = (args['format'] as String?)?.toLowerCase() ?? 'iso';

          DateTime nowUtc = DateTime.now().toUtc();

          // If timezone hints Pakistan/Karachi/PKT, convert to UTC+5
          if (tz.isNotEmpty &&
              (tz.contains('karachi') ||
                  tz.contains('pakistan') ||
                  tz == 'pkt')) {
            final pkTime = nowUtc.add(const Duration(hours: 5));
            if (format == 'human') {
              // e.g. 2025-09-14 19:18:54 PKT
              final human =
                  '${pkTime.year.toString().padLeft(4, '0')}-'
                  '${pkTime.month.toString().padLeft(2, '0')}-'
                  '${pkTime.day.toString().padLeft(2, '0')} '
                  '${pkTime.hour.toString().padLeft(2, '0')}:'
                  '${pkTime.minute.toString().padLeft(2, '0')}:'
                  '${pkTime.second.toString().padLeft(2, '0')} PKT';
              return human;
            }

            // default: return ISO-like with offset
            return '${pkTime.toIso8601String()}+05:00';
          }

          // default behavior: return UTC ISO 8601
          return nowUtc.toIso8601String();
        } catch (e) {
          dev.log('currentDateTime: error formatting datetime -> $e');
          return DateTime.now().toUtc().toIso8601String();
        }

      case 'addActivity':
        try {
          final args = call.args as Map<String, dynamic>;
          final name = (args['name'] as String?)?.trim() ?? '';
          final typeStr = (args['type'] as String?)?.toLowerCase() ?? 'count';
          final type = (typeStr == 'time')
              ? models_activity.ActivityType.time
              : models_activity.ActivityType.count;

          final id = DateTime.now().millisecondsSinceEpoch.toString();
          final timestamp = DateTime.now().toUtc().toIso8601String();
          final activityName = name.isEmpty ? 'New Activity' : name;

          // Prepare the structured response we'll return to the LLM
          Map<String, dynamic> buildResult({required bool persisted}) {
            final result = {
              'id': id,
              'name': activityName,
              'type': typeStr,
              'timestamp': timestamp,
              'persisted': persisted,
            };

            // Also include a markdown message the agent can display directly
            final markdown = StringBuffer();
            markdown.writeln('### Activity created');
            markdown.writeln('');
            markdown.writeln('- **ID:** `$id`');
            markdown.writeln('- **Title:** $activityName');
            markdown.writeln('- **Type:** ${typeStr.toUpperCase()}');
            markdown.writeln('- **Created at (UTC):** $timestamp');
            if (!persisted) {
              markdown.writeln('');
              markdown.writeln(
                '__Note:__ Activity saved to a temporary fallback (preferences). It will be migrated to the app database on next startup.',
              );
            }

            return {'result': result, 'message_markdown': markdown.toString()};
          }

          // Try to persist via Hive/ActivityManager if boxes are available
          try {
            // Attempt to open boxes with conventional names; if they don't exist, this may still succeed
            final activityBox = await Hive.openBox<models_activity.Activity>(
              'activities',
            );
            final timeBox = await Hive.openBox<models_activity.TimeActivity>(
              'time_activities',
            );
            final countBox = await Hive.openBox<models_activity.CountActivity>(
              'count_activities',
            );

            final manager = ActivityManager(
              activityBox: activityBox,
              timeActivityBox: timeBox,
              countActivityBox: countBox,
            );

            manager.addActivity(activityName, type);
            dev.log(
              'addActivity: persisted activity id=$id name=$activityName type=$typeStr',
            );

            final wrapped = buildResult(persisted: true);
            return jsonEncode(wrapped);
          } catch (e) {
            dev.log(
              'addActivity: could not persist activity, returning fallback -> $e',
            );

            // Fallback: save to SharedPreferences list under 'agent_added_activities'
            try {
              final prefs = await SharedPreferences.getInstance();
              final list = prefs.getStringList('agent_added_activities') ?? [];
              final entry = jsonEncode({
                'id': id,
                'name': activityName,
                'type': typeStr,
                'timestamp': timestamp,
              });
              list.add(entry);
              await prefs.setStringList('agent_added_activities', list);
              dev.log(
                'addActivity: saved to SharedPreferences fallback, id=$id',
              );
            } catch (spErr) {
              dev.log('addActivity: failed to save fallback -> $spErr');
            }

            final wrapped = buildResult(persisted: false);
            return jsonEncode(wrapped);
          }
        } catch (e) {
          dev.log('addActivity: invalid args -> $e');
          throw Exception('Invalid arguments for addActivity');
        }

      case 'markdownWidget':
        final args = call.args;
        final numberA = args['numberA'];
        final numberB = args['numberB'];
        final result = args['result'];
        return '**Calculation Result:**\n\n- First number: $numberA\n- Second number: $numberB\n- **Sum: $result**';

      default:
        throw Exception('Unknown function: ${call.name}');
    }
  }

  Future<void> _saveMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = state.messages.map((m) => jsonEncode(m.toJson())).toList();
      await prefs.setStringList('agent_chat_messages', list);
      dev.log('_saveMessages: persisted ${list.length} messages');
    } catch (e) {
      dev.log('_saveMessages: error saving messages -> $e');
    }
  }

  Future<void> _loadMessages() async {
    if (_messagesLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('agent_chat_messages') ?? [];
      final messages = list.map((s) {
        final map = jsonDecode(s) as Map<String, dynamic>;
        return ChatMessage.fromJson(map);
      }).toList();

      if (messages.isNotEmpty && mounted) {
        state = state.copyWith(messages: messages);
        dev.log('_loadMessages: restored ${messages.length} messages');
      }
      _messagesLoaded = true;
    } catch (e) {
      dev.log('_loadMessages: error loading messages -> $e');
    }
  }

  void clearChat() {
    if (mounted) {
      state = state.copyWith(messages: [], isStreaming: false);
      _messagesLoaded = false;
      _deleteFromSharedPreferences();
    }
  }

  Future<void> _deleteFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('agent_chat_messages');
      dev.log('deleteFromSharedPreferences: cleared persisted messages');
    } catch (e) {
      dev.log('deleteFromSharedPreferences: error clearing messages -> $e');
    }
  }
}

final chatNotifierProvider = StateNotifierProvider<ChatNotifier, ChatState>((
  ref,
) {
  return ChatNotifier();
});
