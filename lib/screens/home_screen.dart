import 'package:flutter/material.dart';
import 'package:haseeb/models/activity.dart';
import 'package:haseeb/widgets/activity_card_widget.dart';
import 'package:haseeb/widgets/radial_bar_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Simple in-memory demo activities. In your app these come from Hive/ActivityManager.
  final List<_ActivityItem> _activities = [
    _ActivityItem(
      id: 'a1',
      name: 'Pushups',
      pinned: false,
      total: 100,
      done: 30,
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      type: ActivityType.count,
    ),
    _ActivityItem(
      id: 'a2',
      name: 'Running',
      pinned: true,
      total: 60,
      done: 20,
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      type: ActivityType.time,
    ),
    _ActivityItem(
      id: 'a3',
      name: 'Meditation',
      pinned: false,
      total: 30,
      done: 10,
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      type: ActivityType.time,
    ),
    _ActivityItem(
      id: 'a4',
      name: 'Study',
      pinned: true,
      total: 120,
      done: 60,
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      type: ActivityType.time,
    ),
  ];

  double get _completionPercent {
    // demo: percent of pinned activities relative to total
    if (_activities.isEmpty) return 0.0;
    final pinned = _activities.where((a) => a.pinned).length;
    return pinned / _activities.length;
  }

  void _pin(String id) {
    setState(() {
      final idx = _activities.indexWhere((a) => a.id == id);
      if (idx != -1) _activities[idx] = _activities[idx].copyWith(pinned: true);
    });
  }

  void _unpin(String id) {
    setState(() {
      final idx = _activities.indexWhere((a) => a.id == id);
      if (idx != -1)
        _activities[idx] = _activities[idx].copyWith(pinned: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pinned = _activities.where((a) => a.pinned).toList();
    final unpinned = _activities.where((a) => !a.pinned).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Sections inside a single scroll view area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    // Radial bar centered at top
                    Center(
                      child: SizedBox(
                        width: double.infinity,
                        height: 300,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            RadialBarWidget(
                              total: 1440,
                              done: 200,
                              title: 'Minutes utilized',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Pinned',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._buildListSection(pinned, true),
                    const SizedBox(height: 16),
                    const Text(
                      'Other Activities',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._buildListSection(unpinned, false),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildListSection(
    List<_ActivityItem> items,
    bool currentlyPinnedSection,
  ) {
    if (items.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            currentlyPinnedSection ? 'No pinned activities' : 'No activities',
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      ];
    }
    return items.map((item) {
      return Dismissible(
        key: ValueKey(item.id),
        background: Container(
          color: Colors.green,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 16),
          child: const Icon(Icons.push_pin, color: Colors.white),
        ),
        secondaryBackground: Container(
          color: Colors.orange,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          child: const Icon(Icons.push_pin_outlined, color: Colors.white),
        ),
        confirmDismiss: (direction) async {
          // Swipe right -> pin, Swipe left -> unpin
          if (direction == DismissDirection.startToEnd) {
            _pin(item.id);
            return false; // don't remove from list, just update
          } else if (direction == DismissDirection.endToStart) {
            _unpin(item.id);
            return false;
          }
          return false;
        },
        child: ActivityCardWidget(
          title: item.name,
          total: item.total,
          done: item.done,
          timestamp: item.timestamp,
          type: item.type,
        ),
      );
    }).toList();
  }
}

class _ActivityItem {
  final String id;
  final String name;
  final bool pinned;
  final int total;
  final int done;
  final DateTime timestamp;
  final ActivityType type;

  _ActivityItem({
    required this.id,
    required this.name,
    this.pinned = false,
    this.total = 0,
    this.done = 0,
    DateTime? timestamp,
    this.type = ActivityType.count,
  }) : timestamp = timestamp ?? DateTime.now();

  _ActivityItem copyWith({
    String? id,
    String? name,
    bool? pinned,
    int? total,
    int? done,
    DateTime? timestamp,
    ActivityType? type,
  }) {
    return _ActivityItem(
      id: id ?? this.id,
      name: name ?? this.name,
      pinned: pinned ?? this.pinned,
      total: total ?? this.total,
      done: done ?? this.done,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
    );
  }
}

class _RadialPainter extends CustomPainter {
  final double percent; // 0.0 - 1.0

  _RadialPainter(this.percent);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 6;

    final basePaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;

    final progressPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -3.14 / 2,
        endAngle: -3.14 / 2 + 2 * 3.14 * percent,
        colors: [Colors.blue, Colors.lightBlueAccent],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, basePaint);

    final rect = Rect.fromCircle(center: center, radius: radius);
    final startAngle = -3.14 / 2;
    final sweep = 2 * 3.14 * percent;
    canvas.drawArc(rect, startAngle, sweep, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _RadialPainter oldDelegate) =>
      oldDelegate.percent != percent;
}
