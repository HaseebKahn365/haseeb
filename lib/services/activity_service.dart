import 'package:haseeb/models/activity.dart';
import 'package:haseeb/models/activity_type.dart';
import 'package:haseeb/models/count_activity.dart';
import 'package:haseeb/models/custom_list.dart';
import 'package:haseeb/models/duration_activity.dart';
import 'package:haseeb/models/planned_activity.dart';
import 'package:hive/hive.dart';

class ActivityService {
  static const String activitiesBoxName = 'activities';
  static const String customListsBoxName = 'customLists';

  late Box<Activity> _activitiesBox;
  late Box<CustomList> _customListsBox;

  Future<void> init() async {
    _activitiesBox = await Hive.openBox<Activity>(activitiesBoxName);
    _customListsBox = await Hive.openBox<CustomList>(customListsBoxName);
  }

  // CRUD for Activities
  Future<void> addActivity(Activity activity) async {
    await _activitiesBox.put(activity.id, activity);
  }

  Activity? getActivity(String id) {
    return _activitiesBox.get(id);
  }

  Future<void> updateActivity(Activity activity) async {
    await activity.save();
  }

  Future<void> deleteActivity(String id) async {
    await _activitiesBox.delete(id);
  }

  List<Activity> getAllActivities() {
    return _activitiesBox.values.toList();
  }

  // Advanced filtering methods for agent
  List<Activity> getActivitiesByFilters(Map<String, dynamic> filters) {
    List<Activity> activities = _activitiesBox.values.toList();

    if (filters.containsKey('type')) {
      String type = filters['type'];
      if (type == 'COUNT') {
        activities = activities.whereType<CountActivity>().toList();
      } else if (type == 'DURATION') {
        activities = activities.whereType<DurationActivity>().toList();
      } else if (type == 'PLANNED') {
        activities = activities.whereType<PlannedActivity>().toList();
      }
    }

    if (filters.containsKey('date_from')) {
      DateTime fromDate = DateTime.parse(filters['date_from']);
      activities = activities
          .where(
            (activity) =>
                activity.timestamp.isAfter(fromDate) ||
                activity.timestamp.isAtSameMomentAs(fromDate),
          )
          .toList();
    }

    if (filters.containsKey('date_to')) {
      DateTime toDate = DateTime.parse(filters['date_to']);
      activities = activities
          .where(
            (activity) =>
                activity.timestamp.isBefore(toDate) ||
                activity.timestamp.isAtSameMomentAs(toDate),
          )
          .toList();
    }

    if (filters.containsKey('completion_status')) {
      String status = filters['completion_status'];
      if (status == 'completed') {
        activities = activities.where((activity) {
          if (activity is CountActivity) {
            return activity.doneCount >= activity.totalCount;
          } else if (activity is DurationActivity) {
            return activity.doneDuration >= activity.totalDuration;
          }
          return false;
        }).toList();
      } else if (status == 'ongoing') {
        activities = activities.where((activity) {
          if (activity is CountActivity) {
            return activity.doneCount < activity.totalCount;
          } else if (activity is DurationActivity) {
            return activity.doneDuration < activity.totalDuration;
          }
          return false;
        }).toList();
      }
    }

    if (filters.containsKey('title_contains')) {
      String rawSearch = filters['title_contains'] as String;
      String normalize(String s) =>
          s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final searchTerm = normalize(rawSearch);
      activities = activities
          .where((activity) => normalize(activity.title).contains(searchTerm))
          .toList();
    }

    return activities;
  }

  // Method to create activities for agent
  Future<String> createNewActivity(
    String type,
    String title,
    int totalValue, {
    String? description,
    String? plannedType,
  }) async {
    // Validate inputs
    if (type.isEmpty || title.isEmpty || totalValue <= 0) {
      throw ArgumentError(
        'Invalid parameters: type, title, and totalValue must be provided and valid',
      );
    }

    String id =
        '${type.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}';

    Activity activity;
    if (type == 'COUNT') {
      activity = CountActivity(
        id: id,
        title: title,
        timestamp: DateTime.now(),
        totalCount: totalValue,
        doneCount: 0,
      );
      print(
        '🔧 Agent: Created COUNT activity "$title" with target $totalValue',
      );
    } else if (type == 'DURATION') {
      activity = DurationActivity(
        id: id,
        title: title,
        timestamp: DateTime.now(),
        totalDuration: totalValue,
        doneDuration: 0,
      );
      print(
        '🔧 Agent: Created DURATION activity "$title" with target ${totalValue}min',
      );
    } else if (type == 'PLANNED') {
      // Determine the intended activity type for the planned activity
      ActivityType activityType = ActivityType.DURATION; // Default to DURATION
      if (plannedType == 'COUNT') {
        activityType = ActivityType.COUNT;
      } else if (plannedType == 'DURATION') {
        activityType = ActivityType.DURATION;
      }

      activity = PlannedActivity(
        id: id,
        title: title,
        timestamp: DateTime.now(),
        description: description ?? '',
        type: activityType,
        estimatedCompletionDuration: totalValue,
      );
      print(
        '🔧 Agent: Created PLANNED activity "$title" with estimated ${totalValue}min (type: ${activityType.toString().split('.').last})',
      );
    } else {
      throw ArgumentError(
        'Invalid activity type: $type. Supported: COUNT, DURATION, PLANNED',
      );
    }

    await addActivity(activity);
    print('✅ Agent: Activity "$title" saved to database with ID: $id');
    return id;
  }

  // Method to modify activity attributes for agent
  Future<bool> modifyActivityAttribute(
    String id,
    String attribute,
    dynamic value,
  ) async {
    print(
      '🔧 Agent: Attempting to modify activity $id attribute $attribute to $value',
    );

    Activity? activity = getActivity(id);
    if (activity == null) {
      print('❌ Agent: Activity with ID $id not found');
      return false;
    }

    try {
      switch (attribute) {
        case 'title':
          activity.title = value as String;
          print('✅ Agent: Updated title to "$value"');
          break;
        case 'done_count':
          if (activity is CountActivity) {
            activity.doneCount = value as int;
            print('✅ Agent: Updated done_count to $value');
          } else {
            print('❌ Agent: Cannot modify done_count on non-CountActivity');
            return false;
          }
          break;
        case 'done_duration':
          if (activity is DurationActivity) {
            activity.doneDuration = value as int;
            print('✅ Agent: Updated done_duration to ${value}min');
          } else {
            print(
              '❌ Agent: Cannot modify done_duration on non-DurationActivity',
            );
            return false;
          }
          break;
        case 'total_count':
          if (activity is CountActivity) {
            activity.totalCount = value as int;
            print('✅ Agent: Updated total_count to $value');
          } else {
            print('❌ Agent: Cannot modify total_count on non-CountActivity');
            return false;
          }
          break;
        case 'total_duration':
          if (activity is DurationActivity) {
            activity.totalDuration = value as int;
            print('✅ Agent: Updated total_duration to ${value}min');
          } else {
            print(
              '❌ Agent: Cannot modify total_duration on non-DurationActivity',
            );
            return false;
          }
          break;
        case 'description':
          if (activity is PlannedActivity) {
            activity.description = value as String;
            print('✅ Agent: Updated description to "$value"');
          } else {
            print('❌ Agent: Cannot modify description on non-PlannedActivity');
            return false;
          }
          break;
        default:
          print('❌ Agent: Unknown attribute "$attribute"');
          return false;
      }

      await updateActivity(activity);
      print('✅ Agent: Activity $id updated successfully');
      return true;
    } catch (e) {
      print('❌ Agent: Error modifying activity: $e');
      return false;
    }
  }

  // CRUD for CustomLists
  Future<void> addCustomList(CustomList customList) async {
    await _customListsBox.put(customList.title, customList);
  }

  CustomList? getCustomList(String title) {
    return _customListsBox.get(title);
  }

  Future<void> updateCustomList(CustomList customList) async {
    await customList.save();
  }

  Future<void> deleteCustomList(String title) async {
    await _customListsBox.delete(title);
  }

  List<CustomList> getAllCustomLists() {
    return _customListsBox.values.toList();
  }

  Future<void> close() async {
    await _activitiesBox.close();
    await _customListsBox.close();
  }
}
