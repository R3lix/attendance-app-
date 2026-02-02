import 'package:hive/hive.dart';

part 'subject.g.dart';

@HiveType(typeId: 1)
class Subject extends HiveObject {
  @HiveField(0)
  String id;
  
  @HiveField(1)
  String name;
  
  @HiveField(2)
  int dayIndex;
  
  @HiveField(3)
  int startHour;
  
  @HiveField(4)
  int startMinute;
  
  @HiveField(5)
  int endHour;
  
  @HiveField(6)
  int endMinute;

  @HiveField(7)
  String? description;

  Subject({
    required this.id,
    required this.name,
    required this.dayIndex,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    this.description,
  });
}