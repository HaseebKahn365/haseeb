import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  ChatMessage copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    List<Widget>? widgets,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      widgets: widgets ?? this.widgets,
    );
  }
}

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String currentInput;

  ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.currentInput = '',
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? currentInput,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      currentInput: currentInput ?? this.currentInput,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier() : super(ChatState());

  void addMessage(ChatMessage message) {
    state = state.copyWith(messages: [...state.messages, message]);
  }

  void updateLastMessage(ChatMessage message) {
    if (state.messages.isNotEmpty) {
      final updatedMessages = [...state.messages];
      updatedMessages[updatedMessages.length - 1] = message;
      state = state.copyWith(messages: updatedMessages);
    }
  }

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  void setCurrentInput(String input) {
    state = state.copyWith(currentInput: input);
  }

  void clearMessages() {
    state = state.copyWith(messages: []);
  }

  void updateCurrentInput(String input) {
    state = state.copyWith(currentInput: input);
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier();
});
