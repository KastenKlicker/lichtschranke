
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TimeEntry {

  String time; // Reference modification to include milliseconds
  String name;

  TimeEntry({required this.time, this.name = ''}); // Ensure usage of updated format

  Map<String, String> toMap() { // Ensure time format includes milliseconds
    return {'time': time, 'name': name};
  }

  static TimeEntry fromMap(Map<String, String> map) {
    return TimeEntry(time: map['time']!, name: map['name'] ?? ''); // Ensure updated format

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
  // Dummy method to simulate receiving times over Bluetooth
  void _simulateBluetoothTimeEntry() {
    // Simulate receiving a new time entry
    final receivedTimeEntry = TimeEntry(time: DateFormat('HH:mm:ss.SSS').format(DateTime.now()), name: 'Received via Bluetooth');
    setState(() {
      _times.add(receivedTimeEntry);
    });
    _saveTimes();
  }

  void _editName(int index) {
    showDialog(
      context: context,
      builder: (context) => EditNameDialog(
        initialName: _times[index].name,
        onNameChanged: (newName) {
          setState(() {
            _times[index].name = newName;
          });
          _saveTimes();
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadTimes();
    _simulateBluetoothTimeEntry();
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
      _times.removeAt(index);
    });
    _saveTimes();
  }

  // Add a new time
  void _addTime() async {
    final newTimeEntry = TimeEntry(time: DateFormat('HH:mm:ss.SSS').format(DateTime.now()));
    setState(() {
      _times.add(newTimeEntry);
    });
    _saveTimes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Time List App'),
      ),
      body: ListView.builder(
        itemCount: _times.length,
        itemBuilder: (context, index) {
          final entry = _times[index];
          return ListTile(
            title: Text(entry.name.isEmpty ? ' ' : entry.name),

            subtitle: Text(entry.time), // Ensure updated format displays correctly
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editName(index),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _deleteTime(index),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}