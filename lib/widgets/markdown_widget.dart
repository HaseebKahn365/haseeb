import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class MarkdownWidget extends StatelessWidget {
  final String content;

  const MarkdownWidget({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Markdown(
          data: content,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          styleSheet: MarkdownStyleSheet(
            p: Theme.of(context).textTheme.bodyMedium,
            h1: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            h2: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            h3: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            strong: const TextStyle(fontWeight: FontWeight.bold),
            em: const TextStyle(fontStyle: FontStyle.italic),
            blockquote: TextStyle(
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
            code: TextStyle(
              backgroundColor: Colors.grey[200],
              fontFamily: 'monospace',
              fontSize: 14,
            ),
            codeblockDecoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}
