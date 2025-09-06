// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'count_activity.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CountActivityAdapter extends TypeAdapter<CountActivity> {
  @override
  final int typeId = 1;

  @override
  CountActivity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CountActivity(
      id: fields[0] as String,
      title: fields[1] as String,
      timestamp: fields[2] as DateTime,
      totalCount: fields[3] as int,
      doneCount: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, CountActivity obj) {
    writer
      ..writeByte(5)
      ..writeByte(3)
      ..write(obj.totalCount)
      ..writeByte(4)
      ..write(obj.doneCount)
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
      other is CountActivityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
