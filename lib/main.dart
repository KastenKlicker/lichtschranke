
import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bluetooth_classic/bluetooth_classic.dart';
import 'package:bluetooth_classic/models/device.dart';

class TimeEntry {

  String time; // Reference modification to include milliseconds
  String date; // Added field for date
  String name;
  int timeInMillis;

  TimeEntry({required this.time, required this.date, required this.timeInMillis, this.name = ''}); // Ensure usage of updated format

  Map<String, String> toMap() {
    return {
      'time': time,
      'date': date,
      'name': name,
      'timeInMillis': timeInMillis.toString(), // Sicherstellen, dass this auch bei Speicherung bleibt
    };
  }

  static TimeEntry fromMap(Map<String, String> map) {
    return TimeEntry(
      time: map['time']!,
      date: map['date']!,
      name: map['name'] ?? '',
      timeInMillis: int.parse(map['timeInMillis']!), // timeInMillis hinzugefügt und von String konvertiert
    );
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
  bool _isDuplicate(TimeEntry timeEntry) {
    return _times.any((entry) =>
        entry.time == timeEntry.time &&
        entry.date == timeEntry.date &&
        entry.name == timeEntry.name);
  }
  List<TimeEntry> _filteredTimes = [];
  void _sortTimes() {
    _times.sort((a, b) {
      final dateComparison = b.date.compareTo(a.date);
      return dateComparison != 0 ? dateComparison : b.time.compareTo(a.time);
    });
    _filteredTimes = List.from(_times);
  }
  String _currentSearchQuery = '';
  final BluetoothClassic _bluetoothClassicPlugin = BluetoothClassic();

void _editName(int index) {
  showDialog(
    context: context,
    builder: (context) => EditNameDialog(
      initialName: _filteredTimes[index].name,
      onNameChanged: (newName) {
        setState(() {
          _filteredTimes[index].name = newName;
          _sortTimes();
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
    _loadTimes();
    _sortTimes();
    _initializeBluetooth();
  }

  Future<void> _initializeBluetooth() async {
    // Zugriff auf Bluetooth-Erlaubnis
    await _bluetoothClassicPlugin.initPermissions();
    // Verbindung mit dem Bluetooth-Gerät herstellen
    
    // Lichtschranke mit Name finden
    List<Device> deviceList = await _bluetoothClassicPlugin.getPairedDevices();
    
    Device lichtschranke = await deviceList.where((device) => device.name == "Lichtschranke").first;
    
    print("Adresse Lichtschranke: " + lichtschranke.address);
    
    await _bluetoothClassicPlugin.connect(lichtschranke.address, "00001101-0000-1000-8000-00805f9b34fb");

    // Daten-Event abonnieren
    _bluetoothClassicPlugin.onDeviceDataReceived().listen((event) {
      _handleData(event);
    });
  }

  bool _isLessThan500ms(TimeEntry newEntry) {
    return _times.any((entry) {
      if (entry.date != newEntry.date) return false;
      int difference = newEntry.timeInMillis - entry.timeInMillis;
      return difference < 500;
    });
  }

  void _handleData(Uint8List event) {
    setState(() {
      String timeInMillisStr = String.fromCharCodes(event).trim();
      int timeInMillis = int.parse(timeInMillisStr);
      DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(timeInMillis, isUtc: true);

      String formattedTime = DateFormat('HH:mm:ss.SSS').format(dateTime);
      TimeEntry newEntry = TimeEntry(
          time: formattedTime,
          timeInMillis: timeInMillis,
          date: DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now()));
      
      if (_isDuplicate(newEntry) || _isLessThan500ms(newEntry)) return;

      // Fügen Sie den empfangenen Zeitstempel zur Liste hinzu
      _times.add(newEntry);
      
      _sortTimes();

      _filteredTimes = List.from(_times);
    });

    // Zum Speichern der neuen Einträge aufrufen
    _saveTimes();
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
        _sortTimes();
        _filteredTimes = List.from(_times)..sort((a, b) => b.time.compareTo(a.time));
      });
    }
  }

  // Save times to SharedPreferences
  _saveTimes() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Nur Zeiten mit Namen speichern
    List<TimeEntry> timesWithName = _times.where((entry) => entry.name.trim().isNotEmpty).toList();

    // Zeiten serialisieren und speichern
    List<String> encodedTimes = timesWithName.map((entry) => json.encode(entry.toMap())).toList();

    await prefs.setStringList('times', encodedTimes);
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

  void _filterTimes(String query) {
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