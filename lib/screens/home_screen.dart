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

  @override
  void initState() {
    super.initState();
    _initService();
  }

  Future<void> _initService() async {
    _activityService = ActivityService();
    await _activityService.init();
    await _loadSampleData();
    await _loadActivities();
  }

  Future<void> _loadSampleData() async {
    // Add sample data if not exists
    if (_activityService.getAllActivities().isEmpty) {
      final pushups = CountActivity(
        id: 'pushups',
        title: 'Pushups',
        timestamp: DateTime.now(),
        totalCount: 100,
        doneCount: 75,
      );
      final running = DurationActivity(
        id: 'running',
        title: 'Running',
        timestamp: DateTime.now(),
        totalDuration: 120,
        doneDuration: 120,
      );
      final yoga = DurationActivity(
        id: 'yoga',
        title: 'Yoga',
        timestamp: DateTime.now(),
        totalDuration: 60,
        doneDuration: 60,
      );
      final meditation = DurationActivity(
        id: 'meditation',
        title: 'Meditation',
        timestamp: DateTime.now(),
        totalDuration: 30,
        doneDuration: 30,
      );

      await _activityService.addActivity(pushups);
      await _activityService.addActivity(running);
      await _activityService.addActivity(yoga);
      await _activityService.addActivity(meditation);
    }
  }

  Future<void> _loadActivities() async {
    final activities = _activityService.getAllActivities();
    setState(() {
      _ongoingCountActivities = activities
          .whereType<CountActivity>()
          .where((a) => a.doneCount < a.totalCount)
          .toList();
      _ongoingDurationActivities = activities
          .whereType<DurationActivity>()
          .where((a) => a.doneDuration < a.totalDuration)
          .toList();
      _completedCountActivities = activities
          .whereType<CountActivity>()
          .where((a) => a.doneCount >= a.totalCount)
          .toList();
      _completedDurationActivities = activities
          .whereType<DurationActivity>()
          .where((a) => a.doneDuration >= a.totalDuration)
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              // Radial bar widget for today's progress
              RadialBarWidget(
                total: 1440,
                done: 800,
                title: "Today's Tracked Time",
              ),

              // ListView of ongoing activities
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Ongoing Activities',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
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
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),

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
    );
  }
}
