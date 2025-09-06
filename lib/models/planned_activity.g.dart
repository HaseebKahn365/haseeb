// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'planned_activity.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PlannedActivityAdapter extends TypeAdapter<PlannedActivity> {
  @override
  final int typeId = 3;

  @override
  PlannedActivity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PlannedActivity(
      id: fields[0] as String,
      title: fields[1] as String,
      timestamp: fields[2] as DateTime,
      description: fields[3] as String,
      type: fields[4] as ActivityType,
      estimatedCompletionDuration: fields[5] as int,
    );
  }

  @override
  void write(BinaryWriter writer, PlannedActivity obj) {
    writer
      ..writeByte(6)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.type)
      ..writeByte(5)
      ..write(obj.estimatedCompletionDuration)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlannedActivityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
