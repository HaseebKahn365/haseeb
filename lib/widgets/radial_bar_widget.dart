import 'package:flutter/material.dart';

class RadialBarWidget extends StatelessWidget {
  final int total;
  final int done;
  final String title;

  const RadialBarWidget({
    super.key,
    required this.total,
    required this.done,
    this.title = 'Progress',
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? done / total : 0.0;
    final percentage = (progress * 100).round();

    return Card(
      elevation: 4,
      // margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(maxWidth: 200, maxHeight: 200),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  FractionallySizedBox(
                    widthFactor: 1.0,
                    heightFactor: 1.0,
                    child: CircularProgressIndicator(
                      year2023: false,
                      value: progress,
                      strokeWidth: 12,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress >= 1.0
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$percentage%',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$done/$total',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
