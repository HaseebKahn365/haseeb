import 'package:haseeb/models/activity.dart';
import 'package:haseeb/models/custom_list.dart';
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
