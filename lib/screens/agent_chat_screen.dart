import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:haseeb/widgets/radial_bar_widget.dart';
import 'package:haseeb/widgets/activity_card_widget.dart';
import 'package:haseeb/widgets/export_data_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AgentChatScreen extends StatefulWidget {
  const AgentChatScreen({super.key});

  @override
  State<AgentChatScreen> createState() => _AgentChatScreenState();
}

class _AgentChatScreenState extends State<AgentChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isStreaming = false;
  StreamSubscription<GenerateContentResponse>? _streamSubscription;

  // Firebase AI model
  late final FirebaseAI _firebaseAI;
  late final GenerativeModel _model;
  static const _prefsKey = 'agent_chat_messages_v1';

  @override
  void initState() {
    super.initState();
    dev.log('initState: initializing Firebase AI generative model');
    _firebaseAI = FirebaseAI.googleAI();
    // Declare the four widget tools required by the UI
    _model = _firebaseAI.generativeModel(
      model: 'gemini-2.5-flash',
      tools: [
        Tool.functionDeclarations([
          // renderRadialBar: total (number), done (number), title (string)
          FunctionDeclaration(
            'renderRadialBar',
            'Displays a radial progress bar',
            parameters: <String, Schema>{
              'total': Schema.number(description: 'Total value'),
              'done': Schema.number(description: 'Completed value'),
              'title': Schema.string(description: 'Title for the radial bar'),
            },
            // required: total, done, title (enforced at runtime)
          ),

          // renderActivityCard: title, total, done, timestamp (ISO), type
          FunctionDeclaration(
            'renderActivityCard',
            'Displays an activity summary card',
            parameters: <String, Schema>{
              'title': Schema.string(description: 'Activity title'),
              'total': Schema.number(description: 'Total target'),
              'done': Schema.number(description: 'Completed amount'),
              'timestamp': Schema.string(description: 'ISO 8601 timestamp'),
              'type': Schema.string(description: "'COUNT' or 'DURATION'"),
            },
            // required: title, total, done, timestamp, type
          ),

          // renderMarkdown: content (string)
          FunctionDeclaration(
            'renderMarkdown',
            'Renders markdown-formatted text',
            parameters: <String, Schema>{
              'content': Schema.string(description: 'Markdown content'),
            },
            // required: content
          ),

          // initiateDataExport: data (CSV string), filename
          FunctionDeclaration(
            'initiateDataExport',
            'Provides an export interface for CSV data',
            parameters: <String, Schema>{
              'data': Schema.string(description: 'CSV-formatted data'),
              'filename': Schema.string(description: 'Filename for export'),
            },
            // required: data, filename
          ),
        ]),
      ],
    );
  dev.log('initState: generative model configured with widget tools');

  // Load persisted messages (do not await here)
  _loadMessages();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _streamSubscription?.cancel();
    super.dispose();
  }

  void _addMessage(ChatMessage message) {
    setState(() {
      _messages.add(message);
    });
    dev.log('_addMessage: saving messages count=${_messages.length}');
    _saveMessages();
    _scrollToBottom();
  }

  void _updateLastMessage(String text) {
    if (_messages.isNotEmpty && !_messages.last.isUser) {
      setState(() {
        _messages.last = _messages.last.copyWith(
          text: _messages.last.text + text,
        );
      });
      dev.log('_updateLastMessage: saving messages');
      _saveMessages();
    }
  }

  Future<void> _saveMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _messages.map((m) => jsonEncode(m.toJson())).toList();
      await prefs.setStringList(_prefsKey, list);
      dev.log('_saveMessages: persisted ${list.length} messages');
    } catch (e) {
      dev.log('_saveMessages: error saving messages -> $e');
    }
  }

  Future<void> _loadMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
  final list = prefs.getStringList(_prefsKey) ?? [];
      final messages = list.map((s) {
        final map = jsonDecode(s) as Map<String, dynamic>;
        return ChatMessage.fromJson(map);
      }).toList();
      if (messages.isNotEmpty) {
        setState(() {
          _messages.clear();
          _messages.addAll(messages);
        });
        dev.log('_loadMessages: restored ${messages.length} messages');
        _scrollToBottom();
      } else {
        dev.log('_loadMessages: no messages to restore');
      }
    } catch (e) {
      dev.log('_loadMessages: error loading messages -> $e');
    }
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
    if (text.isEmpty || _isStreaming) return;

    dev.log('sendMessage: user input -> $text');
    // Add user message
    _addMessage(
      ChatMessage(text: text, isUser: true, timestamp: DateTime.now()),
    );
    _controller.clear();

    setState(() {
      _isStreaming = true;
    });

    // Add empty AI message that will be updated in real-time
    _addMessage(
      ChatMessage(text: '', isUser: false, timestamp: DateTime.now()),
    );

    try {
      // Start the streaming conversation
      dev.log('sendMessage: starting chat session');
      final chat = _model.startChat();
      dev.log('sendMessage: chat session started');
      final content = Content.text(text);
      dev.log('sendMessage: created content -> ${content.toString()}');

      // Listen to the stream
      _streamSubscription = chat
          .sendMessageStream(content)
          .listen(
            (GenerateContentResponse response) {
              dev.log(
                'stream: received response -> text length=${response.text?.length ?? 0} functionCalls=${response.functionCalls.length}',
              );
              // Handle streaming text
              if (response.text != null && response.text!.isNotEmpty) {
                dev.log('stream: appending text chunk -> ${response.text}');
                _updateLastMessage(response.text!);
              }

              // Handle function calls
              if (response.functionCalls.isNotEmpty) {
                for (final call in response.functionCalls) {
                  dev.log(
                    'stream: function call received -> ${call.name} args=${call.args}',
                  );
                  _handleFunctionCall(chat, call);
                }
              }
            },
            onDone: () {
              dev.log('stream: onDone');
              setState(() {
                _isStreaming = false;
              });
              _streamSubscription?.cancel();
            },
            onError: (error) {
              dev.log('stream: onError -> $error');
              _addMessage(
                ChatMessage(
                  text: 'Error: $error',
                  isUser: false,
                  timestamp: DateTime.now(),
                ),
              );
              setState(() {
                _isStreaming = false;
              });
            },
          );
    } catch (e) {
      dev.log('sendMessage: exception starting chat -> $e');
      _addMessage(
        ChatMessage(
          text: 'Error starting conversation: $e',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
      setState(() {
        _isStreaming = false;
      });
    }
  }

  Future<void> _handleFunctionCall(ChatSession chat, FunctionCall call) async {
    try {
      dev.log(
        'handleFunctionCall: executing ${call.name} with args=${call.args}',
      );
      // Map function calls to widget rendering
      if (call.name == 'renderRadialBar') {
        final args = call.args;
        final widgetMsg = ChatMessage(
          text: '',
          isUser: false,
          timestamp: DateTime.now(),
          widgetType: 'radial',
          widgetData: {
            'total': args['total'],
            'done': args['done'],
            'title': args['title'],
          },
        );
        _addMessage(widgetMsg);

        // Send confirmation back to model
        final functionResponse = Content.functionResponse(call.name, {
          'confirmation': 'The radial progress bar has been displayed.'
        });

        dev.log('handleFunctionCall: sent confirmation for renderRadialBar');
        _streamSubscription?.cancel();
        _streamSubscription = chat.sendMessageStream(functionResponse).listen(
          (GenerateContentResponse response) {
            if (response.text != null && response.text!.isNotEmpty) {
              _updateLastMessage(response.text!);
            }
            if (response.functionCalls.isNotEmpty) {
              for (final newCall in response.functionCalls) {
                _handleFunctionCall(chat, newCall);
              }
            }
          },
          onDone: () {
            setState(() {
              _isStreaming = false;
            });
            _streamSubscription?.cancel();
          },
          onError: (error) {
            _addMessage(
              ChatMessage(
                text: 'Error in function response: $error',
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
            setState(() {
              _isStreaming = false;
            });
          },
        );
        return;
      }

      if (call.name == 'renderActivityCard') {
        final args = call.args;
        final widgetMsg = ChatMessage(
          text: '',
          isUser: false,
          timestamp: DateTime.now(),
          widgetType: 'activity_card',
          widgetData: {
            'title': args['title'],
            'total': args['total'],
            'done': args['done'],
            'timestamp': args['timestamp'],
            'type': args['type'],
          },
        );
        _addMessage(widgetMsg);
        final functionResponse = Content.functionResponse(call.name, {
          'confirmation': 'Activity card displayed.'
        });
        _streamSubscription?.cancel();
        _streamSubscription = chat.sendMessageStream(functionResponse).listen(
          (GenerateContentResponse response) {
            if (response.text != null && response.text!.isNotEmpty) {
              _updateLastMessage(response.text!);
            }
          },
          onDone: () {
            setState(() {
              _isStreaming = false;
            });
            _streamSubscription?.cancel();
          },
          onError: (error) {
            _addMessage(
              ChatMessage(
                text: 'Error in function response: $error',
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
            setState(() {
              _isStreaming = false;
            });
          },
        );
        return;
      }

      if (call.name == 'renderMarkdown') {
        final args = call.args;
        final widgetMsg = ChatMessage(
          text: '',
          isUser: false,
          timestamp: DateTime.now(),
          widgetType: 'markdown',
          widgetData: {'content': args['content']},
        );
        _addMessage(widgetMsg);
        final functionResponse = Content.functionResponse(call.name, {
          'confirmation': 'Markdown rendered.'
        });
        _streamSubscription?.cancel();
        _streamSubscription = chat.sendMessageStream(functionResponse).listen(
          (GenerateContentResponse response) {
            if (response.text != null && response.text!.isNotEmpty) {
              _updateLastMessage(response.text!);
            }
          },
          onDone: () {
            setState(() {
              _isStreaming = false;
            });
            _streamSubscription?.cancel();
          },
          onError: (error) {
            _addMessage(
              ChatMessage(
                text: 'Error in function response: $error',
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
            setState(() {
              _isStreaming = false;
            });
          },
        );
        return;
      }

      if (call.name == 'initiateDataExport') {
        final args = call.args;
        final widgetMsg = ChatMessage(
          text: '',
          isUser: false,
          timestamp: DateTime.now(),
          widgetType: 'export',
          widgetData: {
            'data': args['data'],
            'filename': args['filename'],
          },
        );
        _addMessage(widgetMsg);
        final functionResponse = Content.functionResponse(call.name, {
          'confirmation': 'Export widget displayed.'
        });
        _streamSubscription?.cancel();
        _streamSubscription = chat.sendMessageStream(functionResponse).listen(
          (GenerateContentResponse response) {
            if (response.text != null && response.text!.isNotEmpty) {
              _updateLastMessage(response.text!);
            }
          },
          onDone: () {
            setState(() {
              _isStreaming = false;
            });
            _streamSubscription?.cancel();
          },
          onError: (error) {
            _addMessage(
              ChatMessage(
                text: 'Error in function response: $error',
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
            setState(() {
              _isStreaming = false;
            });
          },
        );
        return;
      }

      // Fallback: execute generic function
      final result = await _executeFunction(call);
      final functionResponse = Content.functionResponse(call.name, {
        'result': result,
      });
      _streamSubscription?.cancel();
      _streamSubscription = chat.sendMessageStream(functionResponse).listen((GenerateContentResponse response) {
        if (response.text != null && response.text!.isNotEmpty) {
          _updateLastMessage(response.text!);
        }
      });
    } catch (e) {
      dev.log('handleFunctionCall: exception executing ${call.name} -> $e');
      _addMessage(
        ChatMessage(
          text: 'Error executing function ${call.name}: $e',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
      setState(() {
        _isStreaming = false;
      });
    }
  }

  Future<dynamic> _executeFunction(FunctionCall call) async {
    dev.log('_executeFunction: ${call.name} args=${call.args}');
    switch (call.name) {
      case 'displayHelloWorld':
        // Simulate some processing time
        await Future.delayed(const Duration(milliseconds: 500));
        dev.log('_executeFunction: displayHelloWorld returning');
        return 'Hello, World!';

      case 'addTool':
        final args = call.args;
        final a = (args['a'] as num).toDouble();
        final b = (args['b'] as num).toDouble();
        // Simulate processing time
        await Future.delayed(const Duration(milliseconds: 300));
        dev.log('_executeFunction: addTool computed $a + $b = ${a + b}');
        return a + b;

      case 'markdownWidget':
        final args = call.args;
        final numberA = args['numberA'];
        final numberB = args['numberB'];
        final result = args['result'];
        // Return formatted markdown
        dev.log('_executeFunction: markdownWidget formatting result');
        return '**Calculation Result:**\n\n- First number: $numberA\n- Second number: $numberB\n- **Sum: $result**';

      default:
        dev.log('_executeFunction: unknown function ${call.name}');
        throw Exception('Unknown function: ${call.name}');
    }
  }

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
            ElevatedButton(
              onPressed: _isStreaming
                  ? null
                  : () {
                      _controller.text = 'Start the task';
                      _sendMessage();
                    },
              child: const Text('Start Demo'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        return _buildMessageBubble(_messages[index]);
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
                ? Text(
                    message.text,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : (message.widgetType != null
                    ? _buildWidgetFromMessage(message)
                    : MarkdownBody(
                        data: message.text,
                        styleSheet: MarkdownStyleSheet(
                          p: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      )),
          ),
        ),
      ),
    );
  }

  Widget _buildWidgetFromMessage(ChatMessage message) {
    final data = message.widgetData ?? {};
    switch (message.widgetType) {
      case 'radial':
        return RadialBarWidget(
          total: (data['total'] as num).toInt(),
          done: (data['done'] as num).toInt(),
          title: data['title'] as String? ?? 'Progress',
        );

      case 'activity_card':
        return ActivityCardWidget(
          title: data['title'] as String? ?? 'Activity',
          total: (data['total'] as num).toInt(),
          done: (data['done'] as num).toInt(),
          timestamp: DateTime.parse(data['timestamp'] as String),
          type: data['type'] as String? ?? 'COUNT',
        );

      case 'export':
        return ExportDataWidget(
          data: data['data'] as String? ?? '',
          filename: data['filename'] as String? ?? 'export.csv',
        );

      case 'markdown':
        return MarkdownBody(data: data['content'] as String? ?? '');

      default:
        return Text(message.text);
    }
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
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
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            onPressed: _isStreaming ? null : _sendMessage,
            child: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? widgetType; // 'radial', 'activity_card', 'markdown', 'export'
  final Map<String, dynamic>? widgetData;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.widgetType,
    this.widgetData,
  });

  ChatMessage copyWith({String? text, bool? isUser, DateTime? timestamp}) {
    return ChatMessage(
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      widgetType: this.widgetType,
      widgetData: this.widgetData,
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
    return ChatMessage(
      text: json['text'] as String? ?? '',
      isUser: json['isUser'] as bool? ?? false,
      timestamp: DateTime.parse(
        json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
      ),
      widgetType: json['widgetType'] as String?,
      widgetData: (json['widgetData'] as Map<String, dynamic>?) ?? null,
    );
  }
}
