
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
      title: const Text('Namen ändern'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(hintText: 'Name'),
      ),
      actions: [
        ElevatedButton(
child: const Text('Speichern', style: TextStyle(color: Colors.white)),
          onPressed: () {
            onNameChanged(controller.text);
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

ThemeData appTheme = ThemeData(
  primarySwatch: Colors.orange,
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: Colors.white,
  ),
  inputDecorationTheme: InputDecorationTheme(
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.orange, width: 1.5),
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.orange, width: 1.0),
    ),
    errorBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.red, width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.red, width: 2),
    ),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: Colors.orange,
    foregroundColor: Colors.white,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.all<Color>(Colors.orange),
      foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: ButtonStyle(
      foregroundColor: WidgetStateProperty.all<Color>(Colors.orange),
    ),
  ),
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Time List App',
      theme: appTheme,
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
  void _showAddTimeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        TextEditingController timeController = TextEditingController();
        TextEditingController dateController = TextEditingController(
            text: DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now()));
        TextEditingController nameController = TextEditingController();

        bool isTimeValid = true;
        bool isDateValid = true;

        return AlertDialog(
          title: const Text('Neue Zeit'),
          content: StatefulBuilder(builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: timeController,
                  decoration: InputDecoration(
                    hintText: 'HH:mm:ss.SSS',
                    errorText: isTimeValid ? null : 'Invalid time format',
                    border: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: isTimeValid ? Colors.grey : Colors.red),
                    ),
                  ),
                  keyboardType: TextInputType.datetime,
                  onChanged: (value) {
                    setState(() {
                      try {
                        DateFormat('HH:mm:ss.SSS').parseStrict(value);
                        isTimeValid = true;
                      } catch (e) {
                        isTimeValid = false;
                      }
                    });
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: dateController,
                  decoration: InputDecoration(
                    hintText: 'dd.MM.yyyy HH:mm',
                    errorText: isDateValid ? null : 'Invalid date format',
                    border: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: isDateValid ? Colors.grey : Colors.red),
                    ),
                  ),
                  keyboardType: TextInputType.datetime,
                  onChanged: (value) {
                    setState(() {
                      try {
                        DateFormat('dd.MM.yyyy HH:mm').parseStrict(value);
                        isDateValid = true;
                      } catch (e) {
                        isDateValid = false;
                      }
                    });
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(hintText: 'Name'),
                ),
              ],
            );
          }),
          actions: [
            ElevatedButton(
child: const Text('Hinzufügen', style: TextStyle(color: Colors.white)),
              onPressed: () {
                if (isTimeValid && isDateValid) {
                  String time = timeController.text.trim();
                  String date = dateController.text.trim();
                  String name = nameController.text.trim();

                  try {
                    DateFormat('HH:mm:ss.SSS').parseStrict(time);
                    DateFormat('dd.MM.yyyy HH:mm').parseStrict(date);

                    int timeInMillis = DateFormat('HH:mm:ss.SSS')
                        .parse(time)
                        .millisecondsSinceEpoch;

                    TimeEntry newEntry = TimeEntry(
                        time: time,
                        date: date,
                        name: name,
                        timeInMillis: timeInMillis);

                    if (_isDuplicate(newEntry)) {
                      return;
                    }

                    setState(() {
                      _times.add(newEntry);
                      _sortTimes();
                      _filteredTimes = List.from(_times);
                    });

                    _saveTimes();
                    Navigator.of(context).pop();
                  } catch (e) {
                    // Fehler wird automatisch durch die Ränder des Textfelds angezeigt
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(30.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Nach Namen suchen',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(30.0)), // Runde Ecken
                  borderSide: BorderSide.none, // Kein Rand
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(30.0)),
                  borderSide: BorderSide.none, // Kein Rand bei Fokus
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(30.0)),
                  borderSide: BorderSide.none, // Kein Rand wenn aktiviert
                ),
                prefixIcon: Icon(Icons.search, color: Colors.orange),
                filled: true,
                fillColor: Colors.white, // Weißer Hintergrund
                contentPadding: EdgeInsets.symmetric(vertical: 14.0),
              ),
              onChanged: (value) {
              setState(() {
                _currentSearchQuery = value;
              });
              _filterTimes(value);
            },
          ),
        ),


      )
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTimeDialog,
        child: const Icon(Icons.add),
      ),
      body: Container(
        color: Colors.white,
        child: ListView.builder(
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
      ),
    );
  }
}