import 'package:flutter/material.dart';
import 'package:haseeb/models/count_activity.dart';
import 'package:haseeb/models/duration_activity.dart';
import 'package:haseeb/services/activity_service.dart';
import 'package:haseeb/widgets/activity_card_widget.dart';
import 'package:haseeb/widgets/radial_bar_widget.dart';

//This screen will display the data for today.

/*
The upper widget will be a radial bar showing the time utilization/tracked for today.

below will be a list of activities for today with their progress bars. for showing activities currently being worked on.

Below this list will be another list of completed activities for today.
 */

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late ActivityService _activityService;
  List<CountActivity> _ongoingCountActivities = [];
  List<DurationActivity> _ongoingDurationActivities = [];
  List<CountActivity> _completedCountActivities = [];
  List<DurationActivity> _completedDurationActivities = [];
  bool _isLoading = true;
  int _totalTrackedMinutes = 0;

  @override
  void initState() {
    super.initState();
    _initService();
  }

  Future<void> _initService() async {
    _activityService = ActivityService();
    await _activityService.init();
    await _loadActivities();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _clearDatabase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Database'),
        content: const Text('Are you sure you want to clear all activities? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      // Clear all activities
      final activities = _activityService.getAllActivities();
      for (final activity in activities) {
        await _activityService.deleteActivity(activity.id);
      }

      // Clear all custom lists
      final customLists = _activityService.getAllCustomLists();
      for (final customList in customLists) {
        await _activityService.deleteCustomList(customList.title);
      }

      await _loadActivities();
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Database cleared successfully')),
        );
      }
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });
    await _loadActivities();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadActivities() async {
    final activities = _activityService.getAllActivities();
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    // Filter activities for today only
    final todayActivities = activities.where((activity) {
      final activityDate = DateTime(
        activity.timestamp.year,
        activity.timestamp.month,
        activity.timestamp.day,
      );
      return activityDate.isAtSameMomentAs(todayStart);
    }).toList();

    setState(() {
      _ongoingCountActivities = todayActivities
          .whereType<CountActivity>()
          .where((a) => a.doneCount < a.totalCount)
          .toList();
      _ongoingDurationActivities = todayActivities
          .whereType<DurationActivity>()
          .where((a) => a.doneDuration < a.totalDuration)
          .toList();
      _completedCountActivities = todayActivities
          .whereType<CountActivity>()
          .where((a) => a.doneCount >= a.totalCount)
          .toList();
      _completedDurationActivities = todayActivities
          .whereType<DurationActivity>()
          .where((a) => a.doneDuration >= a.totalDuration)
          .toList();

      // Calculate total tracked minutes for radial bar
      _totalTrackedMinutes = 0;
      for (final activity in todayActivities) {
        if (activity is DurationActivity) {
          _totalTrackedMinutes += activity.doneDuration;
        } else if (activity is CountActivity) {
          // Estimate time based on count (this could be improved with actual time tracking)
          _totalTrackedMinutes +=
              (activity.doneCount * 2); // 2 minutes per rep as estimate
        }
      }
    });
  }

  Future<void> _addSampleActivity() async {
    final newActivity = CountActivity(
      id: 'sample_${DateTime.now().millisecondsSinceEpoch}',
      title: 'New Activity',
      timestamp: DateTime.now(),
      totalCount: 50,
      doneCount: 0,
    );

    await _activityService.addActivity(newActivity);
    await _refreshData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Tracker'),
        actions: [
          IconButton(
            onPressed: _clearDatabase,
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear Database',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          child: SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                // Radial bar widget for today's progress
                RadialBarWidget(
                  total: 1440, // 24 hours in minutes
                  done: _totalTrackedMinutes,
                  title: "Today's Tracked Time",
                ),

                // ListView of ongoing activities
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Ongoing Activities',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (_ongoingCountActivities.isEmpty &&
                    _ongoingDurationActivities.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No ongoing activities for today'),
                  )
                else
                  ..._ongoingCountActivities.map(
                    (activity) => ActivityCardWidget(
                      title: activity.title,
                      total: activity.totalCount,
                      done: activity.doneCount,
                      timestamp: activity.timestamp,
                      type: 'COUNT',
                    ),
                  ),
                ..._ongoingDurationActivities.map(
                  (activity) => ActivityCardWidget(
                    title: activity.title,
                    total: activity.totalDuration,
                    done: activity.doneDuration,
                    timestamp: activity.timestamp,
                    type: 'DURATION',
                  ),
                ),

                // ListView of completed activities
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Completed Activities',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                if (_completedCountActivities.isEmpty &&
                    _completedDurationActivities.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No completed activities for today'),
                  )
                else
                  Column(
                    children: [
                      ..._completedCountActivities.map(
                        (activity) => ActivityCardWidget(
                          title: activity.title,
                          total: activity.totalCount,
                          done: activity.doneCount,
                          timestamp: activity.timestamp,
                          type: 'COUNT',
                        ),
                      ),
                      ..._completedDurationActivities.map(
                        (activity) => ActivityCardWidget(
                          title: activity.title,
                          total: activity.totalDuration,
                          done: activity.doneDuration,
                          timestamp: activity.timestamp,
                          type: 'DURATION',
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSampleActivity,
        tooltip: 'Add Sample Activity',
        child: const Icon(Icons.add),
      ),
    );
  }
}
