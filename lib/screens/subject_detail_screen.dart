import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/attendance_provider.dart';
import '../models/subject.dart';
import '../models/attendance_record.dart';

class SubjectDetailScreen extends StatelessWidget {
  final Subject subject;

  SubjectDetailScreen({required this.subject});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    
    // Get records for THIS subject
    final allRecords = provider.getAllRecordsForSubject(subject.id);
    final total = allRecords.length;
    final present = allRecords.where((r) => r.status == AttendanceStatus.present).length;
    final percent = total == 0 ? 100.0 : (present / total) * 100;
    
    // Sort newest first
    allRecords.sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        title: Text(subject.name),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () => _showEditDialog(context, provider),
          )
        ],
      ),
      body: Column(
        children: [
          // HEADER
          Container(
            width: double.infinity,
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: percent >= 75 
                    ? [Colors.green.shade400, Colors.green.shade700] 
                    : [Colors.red.shade400, Colors.red.shade700],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text("${percent.toStringAsFixed(1)}%", 
                  style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white)),
                Text("Attendance", style: TextStyle(color: Colors.white70)),
                SizedBox(height: 10),
                Divider(color: Colors.white30),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person, color: Colors.white, size: 18),
                    SizedBox(width: 5),
                    Text(
                      subject.description ?? "Tap edit to add Teacher",
                      style: TextStyle(color: Colors.white, fontSize: 16, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // HISTORY LIST
          Expanded(
            child: ListView.builder(
              itemCount: allRecords.length,
              itemBuilder: (ctx, index) {
                final record = allRecords[index];
                return ListTile(
                  leading: Icon(
                    record.status == AttendanceStatus.present ? Icons.check_circle : 
                    record.status == AttendanceStatus.absent ? Icons.cancel : Icons.block,
                    color: record.status == AttendanceStatus.present ? Colors.green : 
                           record.status == AttendanceStatus.absent ? Colors.red : Colors.grey,
                  ),
                  title: Text(DateFormat('EEEE, MMM d').format(record.date)),
                  trailing: Text(
                    record.status == AttendanceStatus.present ? "Present" : 
                    record.status == AttendanceStatus.absent ? "Absent" : "Cancelled",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, AttendanceProvider provider) {
    TextEditingController controller = TextEditingController(text: subject.description);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Edit Details"),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: "Teacher Name / Description"),
        ),
        actions: [
          TextButton(child: Text("Cancel"), onPressed: () => Navigator.pop(ctx)),
          ElevatedButton(
            child: Text("Save"),
            onPressed: () {
              provider.updateSubjectDescription(subject, controller.text);
              Navigator.pop(ctx);
            },
          )
        ],
      ),
    );
  }
}