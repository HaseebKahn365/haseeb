// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ActivityAdapter extends TypeAdapter<Activity> {
  @override
  final int typeId = 1;

  @override
  Activity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Activity(
      id: fields[0] as String,
      name: fields[1] as String,
      type: fields[2] as ActivityType,
    );
  }

  @override
  void write(BinaryWriter writer, Activity obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.type);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActivityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TimeActivityAdapter extends TypeAdapter<TimeActivity> {
  @override
  final int typeId = 2;

  @override
  TimeActivity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TimeActivity(
      parentId: fields[3] as String,
      recordId: fields[4] as String,
      start: fields[5] as DateTime,
      expectedEnd: fields[6] as DateTime,
      productiveMinutes: fields[7] as int,
      actualEnd: fields[8] as DateTime?,
      name: fields[1] as String,
    );
  }

  @override
  void write(BinaryWriter writer, TimeActivity obj) {
    writer
      ..writeByte(9)
      ..writeByte(3)
      ..write(obj.parentId)
      ..writeByte(4)
      ..write(obj.recordId)
      ..writeByte(5)
      ..write(obj.start)
      ..writeByte(6)
      ..write(obj.expectedEnd)
      ..writeByte(7)
      ..write(obj.productiveMinutes)
      ..writeByte(8)
      ..write(obj.actualEnd)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.type);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeActivityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CountActivityAdapter extends TypeAdapter<CountActivity> {
  @override
  final int typeId = 3;

  @override
  CountActivity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CountActivity(
      parentId: fields[3] as String,
      recordId: fields[4] as String,
      timestamp: fields[5] as DateTime,
      count: fields[6] as int,
      name: fields[1] as String,
    );
  }

  @override
  void write(BinaryWriter writer, CountActivity obj) {
    writer
      ..writeByte(7)
      ..writeByte(3)
      ..write(obj.parentId)
      ..writeByte(4)
      ..write(obj.recordId)
      ..writeByte(5)
      ..write(obj.timestamp)
      ..writeByte(6)
      ..write(obj.count)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.type);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CountActivityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ActivityTypeAdapter extends TypeAdapter<ActivityType> {
  @override
  final int typeId = 0;

  @override
  ActivityType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ActivityType.count;
      case 1:
        return ActivityType.time;
      default:
        return ActivityType.count;
    }
  }

  @override
  void write(BinaryWriter writer, ActivityType obj) {
    switch (obj) {
      case ActivityType.count:
        writer.writeByte(0);
        break;
      case ActivityType.time:
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
