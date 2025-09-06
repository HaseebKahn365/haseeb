import 'package:flutter/material.dart';

import '../widgets/activity_card_widget.dart';
import '../widgets/export_data_widget.dart';
import '../widgets/markdown_widget.dart';
import '../widgets/radial_bar_widget.dart';

class WidgetPreviewScreen extends StatelessWidget {
  const WidgetPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _buildSectionHeader('Radial Bar Widget'),
        const RadialBarWidget(total: 100, done: 75, title: 'Pushups Progress'),
        const RadialBarWidget(total: 50, done: 50, title: 'Completed Task'),

        _buildSectionHeader('Activity Card Widget'),
        ActivityCardWidget(
          title: 'Morning Run',
          total: 60,
          done: 45,
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          type: 'DURATION',
        ),
        ActivityCardWidget(
          title: 'Pushups',
          total: 100,
          done: 85,
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          type: 'COUNT',
        ),

        _buildSectionHeader('Markdown Widget'),
        const MarkdownWidget(
          content: '''
# Welcome to Activity Tracker

This is a **markdown widget** that can display:

- **Bold text**
- *Italic text*
- `Code snippets`
- Lists and more!

## Features
- Real-time progress tracking
- Customizable themes
- Export functionality

> This is a blockquote example
            ''',
        ),

        _buildSectionHeader('Export Data Widget'),
        const ExportDataWidget(
          data:
              'id,title,timestamp,type,total,done\n1,Pushups,2025-09-06T10:00:00Z,COUNT,100,85\n2,Running,2025-09-06T08:00:00Z,DURATION,60,45',
          filename: 'activity_export.csv',
        ),

        _buildSectionHeader('Interactive Examples'),
        _buildInteractiveSection(context),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.grey[100],
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildInteractiveSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Interactive Demo',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Radial Bar Widget - Shows progress visualization',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.pie_chart),
                label: const Text('Test Radial Bar'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Activity Card Widget - Displays activity summary',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.card_membership),
                label: const Text('Test Activity Card'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Markdown Widget - Renders formatted text'),
                    ),
                  );
                },
                icon: const Icon(Icons.text_fields),
                label: const Text('Test Markdown'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Export Widget - Handles data sharing'),
                    ),
                  );
                },
                icon: const Icon(Icons.share),
                label: const Text('Test Export'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
