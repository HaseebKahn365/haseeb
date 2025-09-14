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
        ],
      ),
    );
  }
}
