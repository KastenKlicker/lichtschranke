
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TimeEntry {

  String time; // Reference modification to include milliseconds
  String date; // Added field for date
  String name;

  TimeEntry({required this.time, required this.date, this.name = ''}); // Ensure usage of updated format

  Map<String, String> toMap() { // Ensure time format includes milliseconds
    return {'time': time, 'date': date, 'name': name};
  }

  static TimeEntry fromMap(Map<String, String> map) {
    return TimeEntry(time: map['time']!, date: map['date']!, name: map['name'] ?? ''); // Ensure updated format

  }
}

void main() {
  runApp(const MyApp());
}

class EditNameDialog extends StatelessWidget {
  final String initialName;
  final ValueChanged<String> onNameChanged;

  const EditNameDialog({super.key, required this.initialName, required this.onNameChanged});

  @override
  Widget build(BuildContext context) {
    TextEditingController controller = TextEditingController(text: initialName);

    return AlertDialog(
      title: const Text('Edit Name'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(hintText: 'Enter name'),
      ),
      actions: [
        ElevatedButton(
          child: const Text('Save'),
          onPressed: () {
            onNameChanged(controller.text);
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Time List App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: TimeListScreen(),
    );
  }
}

class TimeListScreen extends StatefulWidget {
  const TimeListScreen({super.key});

  @override
  _TimeListScreenState createState() => _TimeListScreenState();
}

class _TimeListScreenState extends State<TimeListScreen> {
  List<TimeEntry> _times = [];
  List<TimeEntry> _filteredTimes = [];
  String _currentSearchQuery = '';
  // Dummy method to simulate receiving times over Bluetooth

void _editName(int index) {
  showDialog(
    context: context,
    builder: (context) => EditNameDialog(
      initialName: _filteredTimes[index].name,
      onNameChanged: (newName) {
        setState(() {
          _filteredTimes[index].name = newName;
          int originalIndex = _times.indexWhere((entry) =>
              entry.time == _filteredTimes[index].time &&
              entry.date == _filteredTimes[index].date);
          if (originalIndex != -1) {
            _times[originalIndex].name = newName;
          }
        });
        _saveTimes();
     },
   ),
 );
}

  @override
  void initState() {
    super.initState();
    _addTestData();
    _filteredTimes = List.from(_times)..sort((a, b) => b.time.compareTo(a.time));

  }

  void _addTestData() {
    List<String> names = [ 
      'Big Chungus',
      'Big Chungus',
      'Quick Chungus',
      'Quick Chungus',
      'Quick Chungus',
      'Sick Chungus'
    ];
    names.shuffle();
    for (var name in names) {
      _times.add(TimeEntry(time: DateFormat('HH:mm:ss.SSS').format(DateTime.now()), date: DateFormat('dd.MM.yyyy').format(DateTime.now()), name: name));
    }
  }

  // Load times from SharedPreferences
  _loadTimes() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? timeStringList = prefs.getStringList('times');
    if (timeStringList != null) {
      setState(() {
        _times = timeStringList
            .map((timeString) => TimeEntry.fromMap(Map<String, String>.from(json.decode(timeString)))) // Ensure updated format
            .toList();
      });
    }
  }

  // Save times to SharedPreferences
  _saveTimes() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'times', _times.map((entry) => json.encode(entry.toMap())).toList());
  }

  // Add a new time
  // Delete a time entry
  void _deleteTime(int index) async {
    setState(() {
      TimeEntry timeEntry = _filteredTimes[index];
      _filteredTimes.removeAt(index);

      // Entferne nur den klar identifizierten Eintrag aus `_times`
      _times.removeWhere((entry) =>
      entry.time == timeEntry.time &&
          entry.date == timeEntry.date &&
          entry.name == timeEntry.name);

      // Aktualisiere die gefilterte Liste erneut nach der Löschung:
      _filterTimes(_currentSearchQuery);
    });
    _saveTimes();
  }

  // Add a new time
  void _addTime() async {
    final newTimeEntry = TimeEntry(time: DateFormat('HH:mm:ss.SSS').format(DateTime.now()), date: DateFormat('dd.MM.yyyy').format(DateTime.now()));
    setState(() {
      _times.add(newTimeEntry);
    });
    _saveTimes();
  }

  void _filterTimes(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredTimes = List.from(_times);
      });
      return;
    }
    List<TimeEntry> filteredTimes = _times.where((entry) => entry.name.toLowerCase().contains(query.toLowerCase())).toList();
    setState(() {
      _filteredTimes = filteredTimes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search by name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(30.0)),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(Icons.search),
              filled: true,
            ),
            onChanged: (value) {
              setState(() {
                _currentSearchQuery = value;
              });
              _filterTimes(value);
            },
          ),
        ),


        // Remove this line
      ),
      body: ListView.builder(
        itemCount: _filteredTimes.length,
        itemBuilder: (context, index) {
          final entry = _filteredTimes[index];
          return ListTile(
            title: Text(entry.name.isEmpty ? ' ' : entry.name),

            subtitle: Text('${entry.time} ${entry.date}'), // Ensure updated format displays correctly
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    if (index >= 0 && index < _filteredTimes.length) _editName(index);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    if (index >= 0 && index < _filteredTimes.length) _deleteTime(index);
                  },
                )
              ],
            ),
          );
        },
      ),
    );
  }
}