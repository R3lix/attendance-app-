import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../providers/attendance_provider.dart';
import '../models/subject.dart';

class TimetableScreen extends StatelessWidget {
  // ⚠️ PASTE YOUR API KEY HERE AGAIN
  final String apiKey = 'AIzaSyBKaON_mbpzKY920GfbzlaqiRAiLlUZ9Os';

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
    
    return Scaffold(
      appBar: AppBar(
        title: Text("Weekly Timetable"),
        actions: [
          // NEW IMPORT BUTTON
          IconButton(
            icon: Icon(Icons.upload_file),
            tooltip: "Import CSV",
            onPressed: () => _showCSVImportDialog(context, provider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () => _showSubjectDialog(context, null),
      ),
      body: ListView.builder(
        itemCount: 7,
        itemBuilder: (context, dayIndex) {
          final daySubjects = provider.subjects.where((s) => s.dayIndex == dayIndex).toList();
          daySubjects.sort((a, b) => (a.startHour).compareTo(b.startHour));

          if (daySubjects.isEmpty) return SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(days[dayIndex], style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
              ),
              ...daySubjects.map((subject) => Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  title: Text(subject.name),
                  subtitle: Text("${subject.startHour}:${subject.startMinute.toString().padLeft(2,'0')} - ${subject.endHour}:${subject.endMinute.toString().padLeft(2,'0')}"),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red[300]),
                    onPressed: () => provider.deleteSubject(subject),
                  ),
                  onTap: () => _showSubjectDialog(context, subject),
                ),
              )).toList(),
            ],
          );
        },
      ),
    );
  }

  // --- NEW: CSV IMPORT DIALOG ---
  void _showCSVImportDialog(BuildContext context, AttendanceProvider provider) {
    final controller = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text("Import Timetable (AI)"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Paste your CSV or text timetable below. Gemini will try to understand it.", style: TextStyle(fontSize: 12, color: Colors.grey[700])),
              SizedBox(height: 10),
              TextField(
                controller: controller,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: "Example:\nMaths, Mon, 9:00, 10:00\nPhysics, Tue, 11:30, 12:30...",
                  border: OutlineInputBorder(),
                ),
              ),
              if (isLoading) Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator()),
            ],
          ),
          actions: [
            TextButton(child: Text("Cancel"), onPressed: () => Navigator.pop(context)),
            ElevatedButton.icon(
              icon: Icon(Icons.auto_awesome),
              label: Text("Generate"),
              onPressed: isLoading ? null : () async {
                setState(() => isLoading = true);
                try {
                  await _processCSVWithGemini(context, provider, controller.text);
                  Navigator.pop(context); // Close dialog on success
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                } finally {
                  if (context.mounted) setState(() => isLoading = false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- NEW: GEMINI LOGIC ---
  Future<void> _processCSVWithGemini(BuildContext context, AttendanceProvider provider, String csvText) async {
  
    final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
    
    final prompt = """
    I have this timetable text:
    "$csvText"

    Task: Convert this into a JSON array of objects.
    Rules:
    1. Each object must have: "name" (string), "day_index" (int 0-6, where 0=Mon, 6=Sun), "start_time" (string HH:MM 24hr), "end_time" (string HH:MM 24hr).
    2. If the text has no clear day/time, ignore that line.
    3. Return ONLY the JSON string. No markdown, no '```json'.
    
    Example Output:
    [{"name": "Math", "day_index": 0, "start_time": "09:00", "end_time": "10:00"}]
    """;

    final response = await model.generateContent([Content.text(prompt)]);
    String? cleanJson = response.text?.replaceAll('```json', '').replaceAll('```', '').trim();
    
    if (cleanJson == null || cleanJson.isEmpty) throw "AI returned empty response";

    try {
      final List<dynamic> data = jsonDecode(cleanJson);
      int count = 0;
      
      for (var item in data) {
        // Parse Time Strings (09:30) into Hours/Minutes
        final startParts = item['start_time'].toString().split(':');
        final endParts = item['end_time'].toString().split(':');
        
        final newSubject = Subject(
          id: Uuid().v4(),
          name: item['name'],
          dayIndex: item['day_index'],
          startHour: int.parse(startParts[0]),
          startMinute: int.parse(startParts[1]),
          endHour: int.parse(endParts[0]),
          endMinute: int.parse(endParts[1]),
        );
        provider.addSubject(newSubject);
        count++;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Imported $count subjects!")));
    } catch (e) {
      throw "Failed to parse AI response. Try clearer text.";
    }
  }

  // --- EXISTING MANUAL DIALOG ---
  void _showSubjectDialog(BuildContext context, Subject? subjectToEdit) {
    final isEditing = subjectToEdit != null;
    final nameController = TextEditingController(text: subjectToEdit?.name ?? "");
    int selectedDay = subjectToEdit?.dayIndex ?? 0;
    TimeOfDay start = subjectToEdit != null ? TimeOfDay(hour: subjectToEdit.startHour, minute: subjectToEdit.startMinute) : TimeOfDay(hour: 9, minute: 0);
    TimeOfDay end = subjectToEdit != null ? TimeOfDay(hour: subjectToEdit.endHour, minute: subjectToEdit.endMinute) : TimeOfDay(hour: 10, minute: 0);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isEditing ? "Edit Class" : "Add Class"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: InputDecoration(labelText: "Subject Name")),
                SizedBox(height: 10),
                DropdownButton<int>(
                  value: selectedDay,
                  isExpanded: true,
                  items: List.generate(7, (i) => DropdownMenuItem(value: i, child: Text(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][i]))),
                  onChanged: (val) => setState(() => selectedDay = val!),
                ),
                ListTile(title: Text("Start: ${start.format(context)}"), onTap: () async { final t = await showTimePicker(context: context, initialTime: start); if(t!=null) setState(()=>start=t); }),
                ListTile(title: Text("End: ${end.format(context)}"), onTap: () async { final t = await showTimePicker(context: context, initialTime: end); if(t!=null) setState(()=>end=t); }),
              ],
            ),
          ),
          actions: [
            if (isEditing) TextButton(
              child: Text("Duplicate"),
              onPressed: () {
                final newSub = Subject(id: Uuid().v4(), name: nameController.text, dayIndex: selectedDay, startHour: start.hour, startMinute: start.minute, endHour: end.hour, endMinute: end.minute);
                Provider.of<AttendanceProvider>(context, listen: false).addSubject(newSub);
                Navigator.pop(context);
              },
            ),
            ElevatedButton(
              child: Text("Save"),
              onPressed: () {
                final provider = Provider.of<AttendanceProvider>(context, listen: false);
                if (isEditing) {
                  subjectToEdit!.name = nameController.text;
                  subjectToEdit.dayIndex = selectedDay;
                  subjectToEdit.startHour = start.hour;
                  subjectToEdit.startMinute = start.minute;
                  subjectToEdit.endHour = end.hour;
                  subjectToEdit.endMinute = end.minute;
                  subjectToEdit.save();
                  provider.refresh();
                } else {
                  final newSub = Subject(id: Uuid().v4(), name: nameController.text, dayIndex: selectedDay, startHour: start.hour, startMinute: start.minute, endHour: end.hour, endMinute: end.minute);
                  provider.addSubject(newSub);
                }
                Navigator.pop(context);
              },
            )
          ],
        ),
      ),
    );
  }
}