import 'package:hive/hive.dart';

part 'attendance_record.g.dart';

@HiveType(typeId: 2)
enum AttendanceStatus { 
  @HiveField(0) present, 
  @HiveField(1) absent, 
  @HiveField(2) leave, 
  @HiveField(3) none,
  @HiveField(4) cancelled // <--- NEW OPTION
}

@HiveType(typeId: 3)
class AttendanceRecord extends HiveObject {
  @HiveField(0)
  final String subjectId;
  @HiveField(1)
  final DateTime date;
  @HiveField(2)
  AttendanceStatus status;

  AttendanceRecord({
    required this.subjectId,
    required this.date,
    this.status = AttendanceStatus.none,
  });
}