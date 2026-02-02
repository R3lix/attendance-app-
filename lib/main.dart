import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'models/subject.dart';
import 'models/attendance_record.dart';
import 'providers/attendance_provider.dart';
import 'screens/home_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/timetable_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  
  Hive.registerAdapter(SubjectAdapter());
  Hive.registerAdapter(AttendanceStatusAdapter());
  Hive.registerAdapter(AttendanceRecordAdapter());
  
  await Hive.openBox<Subject>('subjects');
  await Hive.openBox<AttendanceRecord>('records');
  await Hive.openBox('settings');

  runApp(
    ChangeNotifierProvider(
      create: (_) => AttendanceProvider(),
      child: AttendanceApp(),
    ),
  );
}

class AttendanceApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    
    // IF PINK MODE: Use Hot Pink. IF NORMAL: Use Teal.
    final seedColor = provider.isPinkMode ? Colors.pinkAccent : Colors.teal;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Attendance',
      themeMode: provider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      
      // LIGHT THEME
      theme: ThemeData(
        useMaterial3: true, 
        colorSchemeSeed: seedColor,
        brightness: Brightness.light,
      ),
      
      // DARK THEME
      darkTheme: ThemeData(
        useMaterial3: true, 
        colorSchemeSeed: seedColor,
        brightness: Brightness.dark,
        // If Pink Mode is on, force darker backgrounds to make pink pop
        scaffoldBackgroundColor: provider.isPinkMode ? Color(0xFF1A0510) : null, 
      ),
      
      home: MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  @override
  _MainNavigationState createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final _screens = [HomeScreen(), StatsScreen(), TimetableScreen(), SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        indicatorColor: provider.isPinkMode ? Colors.pinkAccent.withOpacity(0.5) : null,
        destinations: [
          NavigationDestination(icon: Icon(Icons.check_circle_outline), label: "Today"),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), label: "Stats"),
          NavigationDestination(icon: Icon(Icons.calendar_view_week), label: "Timetable"),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: "Settings"),
        ],
      ),
    );
  }
}