// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'duration_activity.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DurationActivityAdapter extends TypeAdapter<DurationActivity> {
  @override
  final int typeId = 2;

  @override
  DurationActivity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DurationActivity(
      id: fields[0] as String,
      title: fields[1] as String,
      timestamp: fields[2] as DateTime,
      totalDuration: fields[3] as int,
      doneDuration: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, DurationActivity obj) {
    writer
      ..writeByte(5)
      ..writeByte(3)
      ..write(obj.totalDuration)
      ..writeByte(4)
      ..write(obj.doneDuration)
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
      other is DurationActivityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
