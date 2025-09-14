import 'package:expressive_loading_indicator/expressive_loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _presetColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.purple,
    Colors.orange,
    Colors.teal,
    Colors.amber,
    Colors.cyan,
    Colors.pink,
    Colors.brown,
    Colors.indigo,
    Colors.deepPurple,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeNotifierProvider);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Theme mode', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              ChoiceChip(
                label: const Text('System'),
                selected: themeState.mode == ThemeMode.system,
                onSelected: (_) => ref
                    .read(themeNotifierProvider.notifier)
                    .setThemeMode(ThemeMode.system),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Light'),
                selected: themeState.mode == ThemeMode.light,
                onSelected: (_) => ref
                    .read(themeNotifierProvider.notifier)
                    .setThemeMode(ThemeMode.light),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Dark'),
                selected: themeState.mode == ThemeMode.dark,
                onSelected: (_) => ref
                    .read(themeNotifierProvider.notifier)
                    .setThemeMode(ThemeMode.dark),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Text(
            'Seed color',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.count(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: _presetColors.map((c) {
                final selected = c.value == themeState.seedColor.value;
                return GestureDetector(
                  onTap: () =>
                      ref.read(themeNotifierProvider.notifier).setSeedColor(c),
                  child: Container(
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(8),
                      border: selected
                          ? Border.all(
                              color: Theme.of(context).colorScheme.outline,
                              width: 2,
                            )
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          AnimatingContainerSatisfaction(),
        ],
      ),
    );
  }
}

class AnimatingContainerSatisfaction extends StatefulWidget {
  const AnimatingContainerSatisfaction({super.key});

  @override
  State<AnimatingContainerSatisfaction> createState() =>
      _AnimatingContainerSatisfactionState();
}

class _AnimatingContainerSatisfactionState
    extends State<AnimatingContainerSatisfaction>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 150.0,
      end: 250.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return SizedBox(
            height: _animation.value,
            width: _animation.value,
            child: ExpressiveLoadingIndicator(
              // Custom color
              color: Theme.of(context).colorScheme.primary,
              // Accessibility
              semanticsLabel: 'Loading',
              semanticsValue: 'In progress',
            ),
          );
        },
      ),
    );
  }
}
