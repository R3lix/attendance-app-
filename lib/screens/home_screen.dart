import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import '../providers/attendance_provider.dart';
import '../models/attendance_record.dart';
import 'subject_detail_screen.dart';
import '../secrets.dart'; 

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final date = provider.selectedDate;
    final dayIndex = date.weekday - 1; 
    
    final daysClasses = provider.subjects.where((s) => s.dayIndex == dayIndex).toList();
    daysClasses.sort((a, b) => (a.startHour * 60 + a.startMinute).compareTo(b.startHour * 60 + b.startMinute));

    // BACKGROUND LOGIC
    BoxDecoration bgDecoration;
    Color textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    Color subTextColor = Colors.grey;

    if (provider.wallpaperUrl != null && provider.wallpaperUrl!.isNotEmpty) {
      bgDecoration = BoxDecoration(image: DecorationImage(image: NetworkImage(provider.wallpaperUrl!), fit: BoxFit.cover));
      textColor = Colors.white; // Wallpaper = White text with shadow
      subTextColor = Colors.white70;
    } else if (provider.isPinkMode) {
      bgDecoration = BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF9A9E), Color(0xFFFECFEF)], 
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        )
      );
      // FORCE BLACK TEXT IN PINK MODE
      textColor = Colors.black; 
      subTextColor = Colors.black54;
    } else {
      bgDecoration = BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor);
    }

    // Helper for Shadows (only needed if Wallpaper is on)
    List<Shadow>? textShadows = (provider.wallpaperUrl != null && provider.wallpaperUrl!.isNotEmpty) 
        ? [Shadow(color: Colors.black, blurRadius: 10)] 
        : null;

    return Scaffold(
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Attendance", style: TextStyle(
              fontSize: 16, 
              color: textColor,
              fontWeight: FontWeight.bold,
              shadows: textShadows
            )),
            Text(DateFormat('EEEE, MMM d').format(date), style: TextStyle(
              fontSize: 12, 
              color: subTextColor,
              shadows: textShadows
            )),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today, color: provider.isPinkMode ? Colors.black : Colors.teal),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context, initialDate: date, firstDate: DateTime(2024), lastDate: DateTime(2030),
              );
              if (picked != null) provider.changeDate(picked);
            },
          ),
          IconButton(
            icon: Icon(Icons.auto_awesome, color: provider.isPinkMode ? Colors.deepPurple : Colors.purpleAccent),
            onPressed: () => _showGeminiDialog(context, provider),
          )
        ],
      ),
      body: Stack(
        children: [
          // BACKGROUND CONTAINER
          Container(decoration: bgDecoration),
          
          // CLASS LIST
          SafeArea(
            child: daysClasses.isEmpty 
              ? Center(child: Text("No classes today.", style: TextStyle(color: textColor)))
              : ListView.builder(
                  itemCount: daysClasses.length,
                  itemBuilder: (context, index) {
                    final subject = daysClasses[index];
                    final status = provider.getStatus(subject.id, date);
                    final startTime = TimeOfDay(hour: subject.startHour, minute: subject.startMinute);
                    final endTime = TimeOfDay(hour: subject.endHour, minute: subject.endMinute);

                    return Card(
                      // Pink Mode = White Cards (Clean). Dark Mode = Standard.
                      color: provider.isPinkMode 
                          ? Colors.white.withOpacity(0.9) 
                          : (status == AttendanceStatus.cancelled ? Theme.of(context).cardColor.withOpacity(0.5) : null),
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        onTap: () {
                           Navigator.push(
                             context, 
                             MaterialPageRoute(builder: (_) => SubjectDetailScreen(subject: subject)),
                           );
                        },
                        title: Text(subject.name, style: TextStyle(fontWeight: FontWeight.bold, decoration: status == AttendanceStatus.cancelled ? TextDecoration.lineThrough : null)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("${startTime.format(context)} - ${endTime.format(context)}"),
                            if (subject.description != null && subject.description!.isNotEmpty)
                              Text("Teacher: ${subject.description}", style: TextStyle(color: Colors.pink, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _statusButton(provider, subject.id, date, AttendanceStatus.present, Colors.green, status),
                            _statusButton(provider, subject.id, date, AttendanceStatus.absent, Colors.red, status),
                            _statusButton(provider, subject.id, date, AttendanceStatus.cancelled, Colors.grey, status),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _statusButton(AttendanceProvider p, String id, DateTime date, AttendanceStatus type, Color color, AttendanceStatus current) {
    IconData icon = type == AttendanceStatus.present ? Icons.check_circle : type == AttendanceStatus.absent ? Icons.cancel : Icons.block;
    return IconButton(
      icon: Icon(icon),
      color: current == type ? color : Colors.grey[300],
      onPressed: () => p.markAttendance(id, date, type),
    );
  }

  void _showGeminiDialog(BuildContext context, AttendanceProvider provider) {
    final controller = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text("AI Assistant"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Tell me what happened ('I attended all classes') OR paste your Backup Data here."),
              SizedBox(height: 10),
              TextField(
                controller: controller, 
                maxLines: 4, 
                decoration: InputDecoration(
                  hintText: "Paste text here...",
                  border: OutlineInputBorder()
                )
              ),
              if (isLoading) LinearProgressIndicator(),
            ],
          ),
          actions: [
            TextButton(
              child: Text("Process"),
              onPressed: () async {
                setState(() => isLoading = true);
                const apiKey = googleApiKey; 

                try {
                   final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
                   
                   final scheduleMap = provider.subjects.map((s) => "${s.name} (ID: ${s.id})").join(", ");
                   
                   final prompt = """
                   User Schedule: $scheduleMap
                   
                   User Input: "${controller.text}"
                   
                   TASK:
                   1. Check if the user input contains a Backup List (Subject, Date, Status). If yes, extract ALL of them.
                   2. Check if the user is just talking naturally (e.g., "I was absent today").
                   
                   OUTPUT:
                   Return a JSON LIST of updates.
                   Format: [{"id": "subject_id_here", "status": "present", "date_offset": 0}]
                   
                   IMPORTANT:
                   - If user pastes a date like '2024-12-05', calculate the 'date_offset' from Today (${DateTime.now()}).
                   - If the date is 5 days ago, date_offset = -5.
                   - STRICT JSON ONLY. NO MARKDOWN.
                   """;

                   final response = await model.generateContent([Content.text(prompt)]);
                   final cleanJson = response.text!.replaceAll('```json', '').replaceAll('```', '').trim();
                   final List<dynamic> updates = jsonDecode(cleanJson);

                   int count = 0;
                   for (var item in updates) {
                     final date = DateTime.now().add(Duration(days: item['date_offset']));
                     final status = item['status'] == 'present' ? AttendanceStatus.present 
                                  : item['status'] == 'absent' ? AttendanceStatus.absent 
                                  : AttendanceStatus.cancelled;
                     
                     provider.markAttendance(item['id'], date, status);
                     count++;
                   }
                   
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Processed $count records!")));
                   Navigator.pop(context);

                } catch (e) {
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                } finally {
                   if(context.mounted) setState(() => isLoading = false);
                }
              },
            )
          ],
        ),
      ),
    );
  }
}