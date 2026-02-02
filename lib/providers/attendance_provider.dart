import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/subject.dart';
import '../models/attendance_record.dart';

class AttendanceProvider with ChangeNotifier {
  late Box<Subject> _subjectBox;
  late Box<AttendanceRecord> _recordBox;
  late Box _settingsBox;

  DateTime _selectedDate = DateTime.now();
  DateTime get selectedDate => _selectedDate;

  AttendanceProvider() {
    _subjectBox = Hive.box<Subject>('subjects');
    _recordBox = Hive.box<AttendanceRecord>('records');
    _settingsBox = Hive.box('settings');
  }

  // --- SETTINGS: DARK MODE ---
  bool get isDarkMode => _settingsBox.get('darkMode', defaultValue: false);
  void toggleTheme(bool value) {
    _settingsBox.put('darkMode', value);
    notifyListeners();
  }

  // --- SETTINGS: SECRET PINK MODE ---
  bool get isPinkMode => _settingsBox.get('pinkMode', defaultValue: false);
  void togglePinkMode() {
    bool current = isPinkMode;
    _settingsBox.put('pinkMode', !current);
    notifyListeners();
  }

  // --- SETTINGS: TARGET PERCENTAGE ---
  double get targetPercentage => _settingsBox.get('target', defaultValue: 75.0);
  void setTargetPercentage(double value) {
    _settingsBox.put('target', value);
    notifyListeners();
  }

  // --- SETTINGS: WALLPAPER ---
  String? get wallpaperUrl => _settingsBox.get('wallpaper', defaultValue: null);
  void setWallpaper(String? url) {
    if (url != null && url.isEmpty) {
      _settingsBox.delete('wallpaper');
    } else {
      _settingsBox.put('wallpaper', url);
    }
    notifyListeners();
  }

  // --- SEMESTER END DATE ---
  DateTime get semesterEnd => _settingsBox.get('endDate', defaultValue: DateTime.now().add(Duration(days: 90)));

  // --- DATE SELECTION ---
  void changeDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  // --- SUBJECT MANAGEMENT ---
  List<Subject> get subjects => _subjectBox.values.toList();
  
  void addSubject(Subject s) { 
    _subjectBox.add(s); 
    notifyListeners(); 
  }
  
  void deleteSubject(Subject s) { 
    s.delete(); 
    notifyListeners(); 
  }

  // --- ATTENDANCE ACTIONS ---
  void markAttendance(String subjectId, DateTime date, AttendanceStatus status) {
    final key = "${subjectId}_${date.year}${date.month}${date.day}";
    final record = AttendanceRecord(subjectId: subjectId, date: date, status: status);
    _recordBox.put(key, record);
    notifyListeners();
  }

  AttendanceStatus getStatus(String subjectId, DateTime date) {
    final key = "${subjectId}_${date.year}${date.month}${date.day}";
    return _recordBox.get(key)?.status ?? AttendanceStatus.none;
  }

  List<AttendanceRecord> getAllRecordsForSubject(String id) {
    return _recordBox.values.where((r) => 
      r.subjectId == id && 
      r.status != AttendanceStatus.none && 
      r.status != AttendanceStatus.cancelled
    ).toList();
  }

  void updateSubjectDescription(Subject s, String newDesc) {
    s.description = newDesc;
    s.save();
    notifyListeners();
  }

  void refresh() { notifyListeners(); }

  Future<void> resetAllData() async {
    await _recordBox.clear();
    await _subjectBox.clear();
    notifyListeners();
  }

  // --- STATS CALCULATION ---
  Map<String, dynamic> calculateStats() {
    final allRecords = _recordBox.values.cast<AttendanceRecord>().toList();
    
    final validRecords = allRecords.where((r) => 
      r.status != AttendanceStatus.none && 
      r.status != AttendanceStatus.cancelled
    ).toList();
    
    int present = validRecords.where((r) => r.status == AttendanceStatus.present).length;
    int totalHeld = validRecords.length;
    
    double currentPct = totalHeld == 0 ? 100.0 : (present / totalHeld) * 100;

    int weeksLeft = (semesterEnd.difference(DateTime.now()).inDays / 7).ceil();
    if (weeksLeft < 0) weeksLeft = 0;
    
    int remainingClasses = weeksLeft * subjects.length;
    int totalPossible = totalHeld + remainingClasses;
    
    int maxAbsences = (totalPossible * (1 - (targetPercentage / 100))).floor();
    int currentAbsences = validRecords.where((r) => r.status == AttendanceStatus.absent).length;
    int bunksAvailable = maxAbsences - currentAbsences;

    int classesNeeded = 0;
    if (currentPct < targetPercentage) {
      double targetDecimal = targetPercentage / 100.0;
      if (targetDecimal >= 1.0) {
         classesNeeded = (totalHeld - present) > 0 ? 999 : 0; 
      } else {
         classesNeeded = ((targetDecimal * totalHeld - present) / (1 - targetDecimal)).ceil();
      }
      if (classesNeeded < 0) classesNeeded = 0;
    }

    return {
      'currentPct': currentPct,
      'present': present,
      'absent': currentAbsences,
      'buffer': bunksAvailable,       
      'recovery': classesNeeded,      
      'isLow': currentPct < targetPercentage, 
    };
  }
}