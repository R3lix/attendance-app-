import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/attendance_provider.dart';
import '../models/attendance_record.dart';

class StatsScreen extends StatefulWidget {
  @override
  _StatsScreenState createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  DateTime _viewDate = DateTime.now(); 

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final stats = provider.calculateStats();
    final bool isLow = stats['isLow'];

    final dayIndex = _viewDate.weekday - 1;
    final subjectsOnDay = provider.subjects.where((s) => s.dayIndex == dayIndex).toList();

    return Scaffold(
      appBar: AppBar(title: Text("Statistics & History")),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Stats Row
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  // Attendance Card
                  _buildStatCard("Attendance", "${stats['currentPct'].toStringAsFixed(1)}%", 
                    isLow ? Colors.red : Colors.green),
                  
                  SizedBox(width: 10),
                  
                  // Dynamic Card: Show "Bunks" if Safe, "Recover" if Low
                  if (isLow)
                    _buildStatCard("Attend Next", "${stats['recovery']} Classes", Colors.blue)
                  else
                    _buildStatCard("Bunks Left", "${stats['buffer']}", Colors.orange),
                ],
              ),
            ),
            Divider(),
            
            // Calendar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text("Tap a date to see history", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            CalendarDatePicker(
              initialDate: _viewDate,
              firstDate: DateTime(2024),
              lastDate: DateTime(2030),
              onDateChanged: (date) => setState(() => _viewDate = date),
            ),
            Divider(),

            // Daily History List
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("History for ${DateFormat('MMM d').format(_viewDate)}", style: TextStyle(color: Colors.grey)),
            ),
            
            if (subjectsOnDay.isEmpty)
              Padding(padding: EdgeInsets.all(20), child: Text("No classes scheduled."))
            else
              ...subjectsOnDay.map((subject) {
                final status = provider.getStatus(subject.id, _viewDate);
                Color color = Colors.grey[200]!;
                IconData icon = Icons.help_outline;
                String text = "Not Marked";
                bool isCancelled = false;

                if (status == AttendanceStatus.present) {
                  color = Colors.green[100]!;
                  icon = Icons.check_circle;
                  text = "Present";
                } else if (status == AttendanceStatus.absent) {
                  color = Colors.red[100]!;
                  icon = Icons.cancel;
                  text = "Absent";
                } else if (status == AttendanceStatus.cancelled) {
                  color = Colors.grey[300]!;
                  icon = Icons.block;
                  text = "Cancelled";
                  isCancelled = true;
                }

                return Card(
                  color: color,
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: Icon(icon, color: Colors.black54),
                    title: Text(
                      subject.name,
                      style: TextStyle(
                        // FIX: Force text to black so it's visible in Dark Mode
                        color: Colors.black87, 
                        fontWeight: FontWeight.bold,
                        decoration: isCancelled ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    trailing: Text(
                      text, 
                      style: TextStyle(
                        // FIX: Force text to black so it's visible in Dark Mode
                        color: Colors.black87,
                        fontWeight: FontWeight.bold
                      )
                    ),
                  ),
                );
              }).toList(),
             SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: TextStyle(color: Colors.grey)), // Title can stay grey, it adapts
          ],
        ),
      ),
    );
  }
}