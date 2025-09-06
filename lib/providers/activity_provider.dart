import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haseeb/services/activity_service.dart';

final activityServiceProvider = Provider<ActivityService>((ref) {
  final service = ActivityService();
  service.init();
  return service;
});
