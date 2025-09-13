import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/activity_card_widget.dart';
import '../widgets/export_data_widget.dart';
import '../widgets/radial_bar_widget.dart';

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
  late String systemPrompt;

  @override
  void initState() {
    super.initState();
    _initializeAsync();
  }

  Future<void> _initializeAsync() async {
    dev.log('initState: initializing Firebase AI generative model');
    systemPrompt = await rootBundle.loadString('assets/system_prompt.md');
    _firebaseAI = FirebaseAI.googleAI();
    dev.log('initState: FirebaseAI.googleAI() returned');
    _model = _firebaseAI.generativeModel(
      systemInstruction: Content.system(systemPrompt),
      model: 'gemini-2.5-flash',
      tools: [
        Tool.functionDeclarations([
          // Existing tools: displayHelloWorld, addTool, markdownWidget
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

          // NEW UI widget tools for rendering in-chat widgets
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
    dev.log('initState: generative model configured with tools');
    // Load persisted messages so chat state is preserved across screen switches
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
      await prefs.setStringList('agent_chat_messages', list);
      dev.log('_saveMessages: persisted ${list.length} messages');
    } catch (e) {
      dev.log('_saveMessages: error saving messages -> $e');
    }
  }

  Future<void> _loadMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('agent_chat_messages') ?? [];
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

      // If the function call corresponds to a widget render, create a widget message
      final widgetTools = {
        'renderRadialBar',
        'renderActivityCard',
        'renderMarkdown',
        'initiateDataExport',
      };

      if (widgetTools.contains(call.name)) {
        dev.log('handleFunctionCall: mapping ${call.name} to widget message');

        // Normalize args (call.args is non-nullable from the SDK)
        final args = Map<String, dynamic>.from(call.args);

        // Add a widget message to the chat history
        final widgetMessage = ChatMessage(
          text: '',
          isUser: false,
          timestamp: DateTime.now(),
          widgetType: call.name,
          widgetData: args,
        );
        _addMessage(widgetMessage);

        // Create function response confirming rendering
        final functionResponse = Content.functionResponse(call.name, {
          'status': 'rendered',
        });

        dev.log(
          'handleFunctionCall: sending function response confirmation for ${call.name}',
        );
        _streamSubscription?.cancel();

        // Continue the stream with the confirmation
        _streamSubscription = chat
            .sendMessageStream(functionResponse)
            .listen(
              (GenerateContentResponse response) {
                dev.log(
                  'post-function stream: received response -> text length=${response.text?.length ?? 0} functionCalls=${response.functionCalls.length}',
                );
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
                dev.log('post-function stream: onDone');
                setState(() {
                  _isStreaming = false;
                });
                _streamSubscription?.cancel();
              },
              onError: (error) {
                dev.log('post-function stream: onError -> $error');
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

      // Fallback: execute function locally and send the result back
      dev.log('handleFunctionCall: executing local function ${call.name}');
      final result = await _executeFunction(call);
      dev.log('handleFunctionCall: result from ${call.name} -> $result');

      final functionResponse = Content.functionResponse(call.name, {
        'result': result,
      });

      dev.log('handleFunctionCall: created function response for ${call.name}');
      _streamSubscription?.cancel();

      _streamSubscription = chat
          .sendMessageStream(functionResponse)
          .listen(
            (GenerateContentResponse response) {
              dev.log(
                'post-function stream: received response -> text length=${response.text?.length ?? 0} functionCalls=${response.functionCalls.length}',
              );
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
              dev.log('post-function stream: onDone');
              setState(() {
                _isStreaming = false;
              });
              _streamSubscription?.cancel();
            },
            onError: (error) {
              dev.log('post-function stream: onError -> $error');
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
            final typeStr = data['type']?.toString() ?? 'COUNT';
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
  final String? widgetType; // e.g. renderRadialBar, renderActivityCard
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
