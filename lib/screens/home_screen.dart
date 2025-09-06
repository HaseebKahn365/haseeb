import 'package:flutter/material.dart';
import 'package:haseeb/widgets/activity_card_widget.dart';
import 'package:haseeb/widgets/radial_bar_widget.dart';

//This screen will display the data for today.

/*
The upper widget will be a radial bar showing the time utilization/tracked for today.

below will be a list of activities for today with their progress bars. for showing activities currently being worked on.

Below this list will be another list of completed activities for today.
 */

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              // Radial bar widget for today's progress
              //           class RadialBarWidget extends StatelessWidget {
              // final int total;
              // final int done;
              // final String title;
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
              ...[
                ActivityCardWidget(
                  title: 'Pushups',
                  total: 100,
                  done: 75,
                  timestamp: DateTime.now(),
                  type: 'COUNT',
                ),
                ActivityCardWidget(
                  title: 'Running',
                  total: 120,
                  done: 120,
                  timestamp: DateTime.now(),
                  type: 'DURATION',
                ),
              ],
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
            ],
          ),
        ),
      ),
    );
  }
}
