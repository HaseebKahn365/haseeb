import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class ExportDataWidget extends StatelessWidget {
  final String data;
  final String filename;

  const ExportDataWidget({
    super.key,
    required this.data,
    this.filename = 'activity_data.csv',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.file_download,
                  color: Theme.of(context).primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Export Data',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Ready to export your activity data. This will create a CSV file with all your activity information.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _exportData(context),
                    icon: const Icon(Icons.share),
                    label: const Text('Share Data'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'File: $filename',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportData(BuildContext context) async {
    try {
      // In a real implementation, this would save to a file first
      // For now, we'll just share the data directly
      await Share.share(
        data,
        subject: 'Activity Data Export',
        sharePositionOrigin: const Rect.fromLTWH(0, 0, 10, 10),
      );

      if (context.mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('Data exported successfully!'),
        //     backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        //   ),
        // );
      }
    } catch (e) {
      if (context.mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('Export failed: $e'),
        //     backgroundColor: Theme.of(context).colorScheme.errorContainer,
        //   ),
        // );
      }
    }
  }
}
