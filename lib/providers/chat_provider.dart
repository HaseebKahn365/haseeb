import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        tools: [
          Tool.functionDeclarations([
            FunctionDeclaration(
              'displayHelloWorld',
              'Displays a simple "Hello, World!" message',
              parameters: <String, Schema>{},
            ),
            FunctionDeclaration(
              'addTool',
              'Adds two numbers together and returns the sum',
              parameters: <String, Schema>{
                'a': Schema.number(description: 'First number to add'),
                'b': Schema.number(description: 'Second number to add'),
              },
            ),
            FunctionDeclaration(
              'markdownWidget',
              'Displays a formatted markdown message showing the calculation',
              parameters: <String, Schema>{
                'numberA': Schema.number(
                  description: 'First number in the calculation',
                ),
                'numberB': Schema.number(
                  description: 'Second number in the calculation',
                ),
                'result': Schema.number(
                  description: 'The result of the calculation',
                ),
              },
            ),
            FunctionDeclaration(
              'renderRadialBar',
              'Render a radial progress bar widget (total, done, title)',
              parameters: <String, Schema>{
                'total': Schema.number(description: 'Total target value'),
                'done': Schema.number(description: 'Completed value'),
                'title': Schema.string(
                  description: 'Title to show on the radial bar',
                ),
              },
            ),
            FunctionDeclaration(
              'renderActivityCard',
              'Render an activity summary card (title, total, done, timestamp, type)',
              parameters: <String, Schema>{
                'title': Schema.string(description: 'Activity title'),
                'total': Schema.number(description: 'Total target'),
                'done': Schema.number(description: 'Completed value'),
                'timestamp': Schema.string(
                  description: 'ISO 8601 timestamp or epoch millis',
                ),
                'type': Schema.string(description: "'COUNT' or 'DURATION'"),
              },
            ),
            FunctionDeclaration(
              'renderMarkdown',
              'Render markdown-formatted content inline',
              parameters: <String, Schema>{
                'content': Schema.string(
                  description: 'Markdown content to render',
                ),
              },
            ),
            FunctionDeclaration(
              'initiateDataExport',
              'Render an export-data widget (CSV data + filename)',
              parameters: <String, Schema>{
                'data': Schema.string(description: 'CSV formatted data'),
                'filename': Schema.string(
                  description: 'Filename to use for export',
                ),
              },
            ),
          ]),
        ],
      );

      await _loadMessages();

      final history = <Content>[];
      for (final message in state.messages) {
        if (message.isUser) {
          history.add(Content.text(message.text));
        } else {
          history.add(Content.text(message.text));
        }
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
      case 'displayHelloWorld':
        return 'Hello, World!';

      case 'addTool':
        final args = call.args;
        final a = (args['a'] as num).toDouble();
        final b = (args['b'] as num).toDouble();
        return a + b;

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
