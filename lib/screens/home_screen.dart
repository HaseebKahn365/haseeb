import 'package:flutter/material.dart';
import 'package:haseeb/models/activity.dart';
import 'package:haseeb/repository/activity_manager.dart';
import 'package:haseeb/widgets/activity_card_widget.dart';
import 'package:haseeb/widgets/radial_bar_widget.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Activities loaded for today's timeframe
  final List<_ActivityItem> _activities = [];

  // Persisted pinned ids
  final Set<String> _pinnedIds = {};

  @override
  void initState() {
    super.initState();
    _loadPinnedIds().then((_) => _loadTodayActivities());
  }

  Future<void> _loadPinnedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('pinned_activity_ids') ?? [];
      _pinnedIds.clear();
      _pinnedIds.addAll(list);
    } catch (e) {
      // ignore
    }
  }

  Future<void> _savePinnedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('pinned_activity_ids', _pinnedIds.toList());
    } catch (e) {
      // ignore
    }
  }

  Future<void> _loadTodayActivities() async {
    final activityBox = await Hive.openBox<Activity>('activities');
    final timeBox = await Hive.openBox<TimeActivity>('time_activities');
    final countBox = await Hive.openBox<CountActivity>('count_activities');
    final manager = ActivityManager(
      activityBox: activityBox,
      timeActivityBox: timeBox,
      countActivityBox: countBox,
    );

    final todayStart = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final todayEnd = DateTime.now();

    final List<_ActivityItem> items = [];

    for (final activity in activityBox.values) {
      bool hasTodayRecord = false;
      DateTime latestTimestamp = DateTime.now();
      int done = 0;
      int total = 0;

      if (activity.type == ActivityType.time) {
        final records = timeBox.values
            .where((r) => r.parentId == activity.id)
            .toList();
        // Check if any record's start/expectedEnd/actualEnd falls within today
        for (final r in records) {
          final start = r.start;
          final expected = r.expectedEnd;
          final actual = r.actualEnd;
          if ((start.isAfter(todayStart) && start.isBefore(todayEnd)) ||
              (expected.isAfter(todayStart) && expected.isBefore(todayEnd)) ||
              (actual != null &&
                  actual.isAfter(todayStart) &&
                  actual.isBefore(todayEnd))) {
            hasTodayRecord = true;
          }
          if (r.start.isAfter(latestTimestamp)) latestTimestamp = r.start;
        }

        if (hasTodayRecord) {
          final info = manager.getActivityInfo(activity.id);
          done = (info['time_periods']?['today']?['minutes'] as int?) ?? 0;
          total = (info['total_minutes'] as int?) ?? done;
          items.add(
            _ActivityItem(
              id: activity.id,
              name: activity.name,
              pinned: _pinnedIds.contains(activity.id),
              total: total,
              done: done,
              timestamp: latestTimestamp,
              type: ActivityType.time,
            ),
          );
        }
      } else {
        final records = countBox.values
            .where((r) => r.parentId == activity.id)
            .toList();
        for (final r in records) {
          final ts = r.timestamp;
          if (ts.isAfter(todayStart) && ts.isBefore(todayEnd)) {
            hasTodayRecord = true;
          }
          if (r.timestamp.isAfter(latestTimestamp))
            latestTimestamp = r.timestamp;
        }

        if (hasTodayRecord) {
          final info = manager.getActivityInfo(activity.id);
          done = (info['time_periods']?['today']?['count'] as int?) ?? 0;
          total = (info['total_count'] as int?) ?? done;
          items.add(
            _ActivityItem(
              id: activity.id,
              name: activity.name,
              pinned: _pinnedIds.contains(activity.id),
              total: total,
              done: done,
              timestamp: latestTimestamp,
              type: ActivityType.count,
            ),
          );
        }
      }
    }

    setState(() {
      _activities
        ..clear()
        ..addAll(items);
    });
  }

  // Generic aggregates (kept for potential future use) removed to avoid confusion.

  // Sum totals but only for time-based activities (minutes).
  int get _sumTotalMinutes {
    return _activities.fold(
      0,
      (s, a) => s + ((a.type == ActivityType.time) ? a.total : 0),
    );
  }

  // Sum done minutes but only for time-based activities (exclude count activities).
  int get _sumDoneMinutes {
    return _activities.fold(
      0,
      (s, a) => s + ((a.type == ActivityType.time) ? a.done : 0),
    );
  }

  void _pin(String id) {
    setState(() {
      final idx = _activities.indexWhere((a) => a.id == id);
      if (idx != -1) _activities[idx] = _activities[idx].copyWith(pinned: true);
      _pinnedIds.add(id);
      _savePinnedIds();
    });
  }

  void _unpin(String id) {
    setState(() {
      final idx = _activities.indexWhere((a) => a.id == id);
      if (idx != -1)
        _activities[idx] = _activities[idx].copyWith(pinned: false);
      _pinnedIds.remove(id);
      _savePinnedIds();
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
                              done: _sumDoneMinutes,
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

// _RadialPainter removed — radial drawing provided by RadialBarWidget in widgets/
