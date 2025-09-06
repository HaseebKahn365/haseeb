// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_type.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ActivityTypeAdapter extends TypeAdapter<ActivityType> {
  @override
  final int typeId = 4;

  @override
  ActivityType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ActivityType.COUNT;
      case 1:
        return ActivityType.DURATION;
      default:
        return ActivityType.COUNT;
    }
  }

  @override
  void write(BinaryWriter writer, ActivityType obj) {
    switch (obj) {
      case ActivityType.COUNT:
        writer.writeByte(0);
        break;
      case ActivityType.DURATION:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActivityTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
