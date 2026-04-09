// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ExpenseAdapter extends TypeAdapter<Expense> {
  @override
  final int typeId = 0;

  @override
  Expense read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Expense(
      id: fields[0] as String,
      merchant: fields[1] as String,
      amount: fields[2] as double,
      category: fields[3] as String,
      date: fields[4] as DateTime,
      imagePath: fields[5] as String,
      firebaseUrl: fields[6] as String,
      highValueAlertSent: fields[14] as bool,
      gstBreakdown: (fields[11] as Map?)?.cast<String, double>(),
      items: (fields[13] as List?)
          ?.map((dynamic e) => (e as Map).cast<String, dynamic>())
          .toList(),
      fraudScore: fields[12] as double,
      paymentMethod: fields[7] as String,
      isDuplicate: fields[8] as bool,
      vendorType: fields[9] as String,
      month: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Expense obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.merchant)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.date)
      ..writeByte(5)
      ..write(obj.imagePath)
      ..writeByte(6)
      ..write(obj.firebaseUrl)
      ..writeByte(7)
      ..write(obj.paymentMethod)
      ..writeByte(8)
      ..write(obj.isDuplicate)
      ..writeByte(9)
      ..write(obj.vendorType)
      ..writeByte(10)
      ..write(obj.month)
      ..writeByte(11)
      ..write(obj.gstBreakdown)
      ..writeByte(12)
      ..write(obj.fraudScore)
      ..writeByte(13)
      ..write(obj.items)
      ..writeByte(14)
      ..write(obj.highValueAlertSent);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
