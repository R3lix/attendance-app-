import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/attendance_provider.dart';
import '../models/attendance_record.dart'; // Needed for enum check

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text("Settings")),
      body: ListView(
        children: [
          _buildSectionHeader("Appearance"),
          
          // SECRET TRIGGER TILE
          StatefulBuilder(
            builder: (context, setState) {
              int tapCount = 0;
              return ListTile(
                leading: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    tapCount++;
                    if (tapCount >= 3) {
                      provider.togglePinkMode();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(provider.isPinkMode ? "🌸 PINK MODE ACTIVATED!" : "Back to normal mode."),
                          backgroundColor: Colors.pink,
                        )
                      );
                      tapCount = 0;
                    }
                  },
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(
                      Icons.dark_mode, 
                      color: provider.isPinkMode ? Colors.pinkAccent : null
                    ),
                  ),
                ),
                title: Text("Dark Mode"),
                subtitle: Text("Tap the moon icon 3 times..."),
                trailing: Switch(
                  value: provider.isDarkMode,
                  activeColor: provider.isPinkMode ? Colors.pinkAccent : Colors.teal,
                  onChanged: (val) => provider.toggleTheme(val),
                ),
              );
            },
          ),

          Divider(),

          _buildSectionHeader("Academic Goals"),
          ListTile(
            leading: Icon(Icons.flag, color: provider.isPinkMode ? Colors.pink : Colors.teal),
            title: Text("Minimum Required Attendance"),
            subtitle: Text("Target: ${provider.targetPercentage.toInt()}%"),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text("60%"),
                Expanded(
                  child: Slider(
                    value: provider.targetPercentage,
                    min: 60,
                    max: 100,
                    divisions: 8,
                    label: "${provider.targetPercentage.toInt()}%",
                    activeColor: provider.isPinkMode ? Colors.pinkAccent : Colors.teal,
                    onChanged: (val) {
                      provider.setTargetPercentage(val);
                    },
                  ),
                ),
                Text("100%"),
              ],
            ),
          ),
          
          Divider(),

          _buildSectionHeader("Data Management"),
          
          // --- NEW EXPORT BUTTON ---
          ListTile(
            leading: Icon(Icons.copy_all, color: Colors.blue),
            title: Text("Export Data (Backup)"),
            subtitle: Text("Get a text code to move to another device"),
            onTap: () => _showExportDialog(context, provider),
          ),
          
          ListTile(
            leading: Icon(Icons.delete_forever, color: Colors.red),
            title: Text("Reset All Data", style: TextStyle(color: Colors.red)),
            onTap: () async {
               bool confirm = await showDialog(
                 context: context, 
                 builder: (ctx) => AlertDialog(
                   title: Text("Are you sure?"),
                   content: Text("This will delete all subjects and attendance records."),
                   actions: [
                     TextButton(child: Text("Cancel"), onPressed: () => Navigator.pop(ctx, false)),
                     TextButton(child: Text("Delete", style: TextStyle(color: Colors.red)), onPressed: () => Navigator.pop(ctx, true)),
                   ],
                 )
               ) ?? false;

               if (confirm) {
                 await provider.resetAllData();
                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("App Reset Successfully")));
               }
            },
          ),
          
          Divider(),
          SizedBox(height: 30),
          Center(
            child: Text(
              "A Razil Production",
              style: TextStyle(color: Colors.grey, fontSize: 14, fontStyle: FontStyle.italic),
            ),
          ),
          SizedBox(height: 50),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context, AttendanceProvider provider) {
    // 1. GENERATE CSV STRING
    // Format: "SubjectName, YYYY-MM-DD, Status"
    StringBuffer buffer = StringBuffer();
    buffer.writeln("Attendance Backup Data (Do not edit):");
    
    // We need to iterate all records and match them to subject names
    // Accessing private boxes via provider helpers if available, or just iterating subjects
    
    // Since we don't have a direct "getAllRecords" exposed, we will use Hive directly or add a getter.
    // Ideally, we add 'getAllRecords' to provider. I will assume we can access records via a new getter or just logic here.
    // For now, let's use the subjects to find records.
    
    int count = 0;
    for(var subject in provider.subjects) {
      final records = provider.getAllRecordsForSubject(subject.id);
      for(var record in records) {
        String statusStr = record.status == AttendanceStatus.present ? "Present" :
                           record.status == AttendanceStatus.absent ? "Absent" : "Cancelled";
        String dateStr = DateFormat('yyyy-MM-dd').format(record.date);
        
        // This is the line Gemini will read
        buffer.writeln("Record: ${subject.name}, $dateStr, $statusStr");
        count++;
      }
    }

    final exportString = buffer.toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Export Data"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Copy this text and paste it into the AI Chat on your new device to restore your data."),
            SizedBox(height: 10),
            Container(
              height: 150,
              padding: EdgeInsets.all(8),
              color: Colors.grey[200],
              child: SingleChildScrollView(
                child: Text(exportString, style: TextStyle(fontSize: 10, fontFamily: "monospace")),
              ),
            ),
            SizedBox(height: 10),
            Text("$count records found.", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            icon: Icon(Icons.copy),
            label: Text("Copy to Clipboard"),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: exportString));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Copied! Now paste it in Gemini on the other phone.")));
              Navigator.pop(ctx);
            },
          )
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title, 
        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 14)
      ),
    );
  }
}