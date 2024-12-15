
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bluetooth_classic/bluetooth_classic.dart';
import 'package:bluetooth_classic/models/device.dart';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

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

ThemeData appTheme = ThemeData(
  primarySwatch: Colors.orange,
  colorScheme: ColorScheme.light(
    primary: Colors.orange
  ),
  
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: Colors.orange,
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
  datePickerTheme: DatePickerThemeData(
    backgroundColor: Colors.white,
    rangePickerBackgroundColor: Colors.white,
    rangePickerHeaderBackgroundColor: Colors.orange,
    rangePickerHeaderForegroundColor: Colors.white,
    rangeSelectionBackgroundColor: Colors.orange[100],
    rangePickerShadowColor: Colors.orange,
    dividerColor: Colors.red
  ),
  textTheme: TextTheme(
    bodyLarge: TextStyle(color: Colors.black), // Standard Texte auf Schwarz für Lesbarkeit
    bodyMedium: TextStyle(color: Colors.black87), // Abgeschwächter Standardtext
  ),
  textSelectionTheme: TextSelectionThemeData(
    cursorColor: Colors.orange,
    selectionColor: Colors.orange[300], // Markierungsfarbe für ausgewählten Text
    selectionHandleColor: Colors.orange,
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
  
void _editTimeEntry(int index) {
  
  // TODO Bei ändern von dem Date wird der Eintragt nicht an die richtige Stelle eingetragen, SortedList?
  showDialog(
    context: context,
    builder: (context) {
      TextEditingController timeController = TextEditingController(text: _filteredTimes[index].time);
      TextEditingController dateController = TextEditingController(text: _filteredTimes[index].date);
      TextEditingController nameController = TextEditingController(text: _filteredTimes[index].name);

      bool isTimeValid = true;
      bool isDateValid = true;

      return AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Eintrag bearbeiten'),
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
            child: const Text('Speichern', style: TextStyle(color: Colors.white)),
            onPressed: () {
              if (isTimeValid && isDateValid) {
                String time = timeController.text.trim();
                String date = dateController.text.trim();
                String name = nameController.text.trim();

                try {
                  DateFormat('HH:mm:ss.SSS').parseStrict(time);
                  DateFormat('dd.MM.yyyy HH:mm').parseStrict(date);

                  setState(() {
                    
                    _filteredTimes[index].time = time;
                    _filteredTimes[index].date = date;
                    _filteredTimes[index].name = name;
                    _filteredTimes[index].timeInMillis =
                        DateFormat('HH:mm:ss.SSS')
                            .parse(time)
                            .millisecondsSinceEpoch;

                    _sortTimes();

                    int originalIndex = _times.indexWhere((entry) =>
                        entry.time ==
                            _filteredTimes[index].time &&
                        entry.date ==
                            _filteredTimes[index].date);
                    if (originalIndex != -1) {
                      _times[originalIndex] = _filteredTimes[index];
                    }
                  });
                  _saveTimes();
                  Navigator.of(context).pop();
                } catch (e) {
                  // Handle validation errors
                }
              }
            },
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Abbrechen'),
          ),
        ],
      );
    });
}

  @override
  void initState() {
    super.initState();
    _loadTimes();
    _sortTimes();
    
    _initializeBluetooth();
  }

  String _connectionStatus = "Nicht verbunden.";
  late Device lichtschranke;

  Future<void> _initializeBluetooth() async {
    
    // Zugriff auf Bluetooth-Erlaubnis
    await _bluetoothClassicPlugin.initPermissions();
    // Verbindung mit dem Bluetooth-Gerät herstellen
    
    // Lichtschranke mit Name finden
    List<Device> deviceList = await _bluetoothClassicPlugin.getPairedDevices();
    
    List<String> deviceNames = <String>[];
    
    for (Device device in deviceList) {
      deviceNames.add(device.name!);
    }
    
    if (!deviceNames.contains("Lichtschranke")) {
      setState(() {
        _connectionStatus = "Lichtschranke nicht gefunden.";
      });
      return;
    }

    lichtschranke = deviceList.where((device) => device.name == "Lichtschranke").first;

    _bluetoothClassicPlugin.onDeviceStatusChanged().listen((status) {
      _handleBluetoothStatus(status);
    });

    _bluetoothClassicPlugin.onDeviceDataReceived().listen((event) {
      _handleData(event);
    });
  }
  
  void _connectToLichtschranke() async {
    await _bluetoothClassicPlugin.connect(lichtschranke.address, "00001101-0000-1000-8000-00805f9b34fb");
  }
  
  void _handleBluetoothStatus(int status) {
    if (status == Device.disconnected) {
      setState(() {
        _connectionStatus = "Nicht verbunden.";
      });
    }
    else if (status == Device.connecting) {
      setState(() {
        _connectionStatus = "Verbinde mit Lichtschranke...";
      });
    }
    else {
      setState(() {
        _connectionStatus = "Verbunden mit Lichtschranke";
      });
    }
  }

  bool _isLessThan500ms(TimeEntry newEntry) {
    return _times.any((entry) {
      if (entry.date != newEntry.date) return false;
      int difference = newEntry.timeInMillis - entry.timeInMillis;
      return difference < 500;
    });
  }

  void _handleData(Uint8List event) {

    String timeInMillisStr = String.fromCharCodes(event).trim();
    int timeInMillis = int.parse(timeInMillisStr);
    DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(timeInMillis, isUtc: true);

    String formattedTime = DateFormat('HH:mm:ss.SSS').format(dateTime);
    TimeEntry newEntry = TimeEntry(
        time: formattedTime,
        timeInMillis: timeInMillis,
        date: DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now()));

    if (_isDuplicate(newEntry) || _isLessThan500ms(newEntry)) return;
    
    setState(() {

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
  backgroundColor: Colors.white,
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
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Abbrechen'),
            ),
          ],
        );
      },
    );
  }

  void _filterByDateRange(DateTimeRange dateRange) {
    List<TimeEntry> filteredTimes = _times.where((entry) {
      DateTime entryDate = DateFormat('dd.MM.yyyy HH:mm').parse('${entry.date} ${entry.time}');
      return entryDate.isAfter(dateRange.start) && entryDate.isBefore(dateRange.end.add(Duration(days: 1)));
    }).toList();
    setState(() {
      _filteredTimes = filteredTimes;
    });
  }

  // Show a dialog to filter based on date range
  Future<void> _selectDateRange() async {
  
  DateTime today = DateTime.now();

    DateTimeRange? dateTimeRange = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2024), 
        lastDate: DateTime(2100),
        initialDateRange: DateTimeRange(
            start: today.subtract(Duration(days: today.weekday -1)), // Get Week start
            end: today),
    );
    
    _filterByDateRange(dateTimeRange!);
    
  }
  // Show a dialog for menu options
  void _showMenuDialog(String option) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white, // Updated background to white
          title: Text(option, style: TextStyle(fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
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

  Future<void> _exportFilteredTimesToCSV() async {
  try {
    TextEditingController fileNameController = TextEditingController(text: 'lichtschranke_export.csv');
    
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Dateiname auswählen'),
          content: TextField(
            controller: fileNameController,
            decoration: const InputDecoration(
              hintText: 'Gib den Dateinamen ein',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              child: const Text('Speichern', style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
    
      // Erstelle den CSV-Inhalt aus den gefilterten Zeiten (_filteredTimes)
      String? selectedDirectory = await _selectExportDirectory();
      if (selectedDirectory == null) return; // Abbruch, falls Benutzer nichts auswählt

      String csv = _createCSVFile();

      // Speichere die Datei im Downloads-Ordner
      String fileName = fileNameController.text.trim();
      if (fileName.isEmpty) fileName = 'lichtschranke_export.csv';
      final file = File('$selectedDirectory/$fileName');
      await file.writeAsString(csv);

      // Erfolgsmeldung anzeigen
      _showMenuDialog('Datei wurde unter: ${file.path} gespeichert.');
    } catch (e) {
      // Fehlerbehandlung
      _showMenuDialog('Export fehlgeschlagen: $e');
    }
  }
  
  String _createCSVFile() {

    List<List<String>> rows = [
      ["Name", "Datum", "Uhrzeit"] // Kopfzeile
    ];
    
    for (var entry in _filteredTimes) {
      rows.add([entry.name, entry.date, entry.time]);
    }

    // Konvertiere die Liste in CSV-Format
    String csv = const ListToCsvConverter().convert(rows);
    
    return csv;
  }

  Future<String?> _selectExportDirectory() async {
    Directory downloadsDirectory = Directory('~/Downloads');
    String initialDirectoryPath = downloadsDirectory.path;

    String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Wähle einen Ordner für den Export',
      initialDirectory: initialDirectoryPath,
    );

    return selectedDirectory;
  }
  
  Future<void> _shareFilteredTimes() async {
    String csv = _createCSVFile();
    Share.shareXFiles([XFile.fromData(utf8.encode(csv), mimeType: "text/csv")], fileNameOverrides: ["LichtschrankeExport.csv"]);
  }
  
  Future<void> _importCSV() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (result != null && result.files.single.path != null) {
        String filePath = result.files.single.path!;
        final file = File(filePath);
        String csvContent = await file.readAsString();
        List<List<dynamic>> csvRows = const CsvToListConverter().convert(csvContent);

        List<TimeEntry> importedTimes = [];
        for (var row in csvRows.skip(1)) { // Skip header row
          if (row.length >= 3) {
            TimeEntry mightBeAdded = TimeEntry(
              name: row[0].toString(),
              date: row[1].toString(),
              time: row[2].toString(),
              timeInMillis: DateFormat('HH:mm:ss.SSS').parse(row[2]).millisecondsSinceEpoch,
            );
            if(!_isDuplicate(mightBeAdded))
              importedTimes.add(mightBeAdded);
          }
        }

        setState(() {
          _times.addAll(importedTimes);
          _sortTimes();
          _filteredTimes = List.from(_times);
        });

        _saveTimes();
        _showMenuDialog('CSV-Import erfolgreich abgeschlossen.');
      } else {
        _showMenuDialog('Kein Datei ausgewählt.');
      }
    } catch (e) {
      _showMenuDialog('Import fehlgeschlagen: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.only(right: 46.0),
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
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 0),
                child: PopupMenuButton<String>(
                  color: Colors.white,
                  icon: Icon(Icons.more_vert, color: Colors.orange), // Changed to three vertical points icon in orange
                  onSelected: (String value) {
                    if (value == 'Zeitraum') {
                      _selectDateRange();
                    } else if (value == 'Export') {
                      _exportFilteredTimesToCSV();
                    } else if (value == 'Import') {
                      _importCSV();
                    } else {
                      _shareFilteredTimes();
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    return ['Zeitraum', 'Import', 'Export', 'Teilen'].map((String choice) {
                      return PopupMenuItem<String>(
                        value: choice,
                        child: Text(choice),
                        // TODO Teilen button
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ],
        )
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 50.0),
        child: FloatingActionButton(
          onPressed: _showAddTimeDialog,
          child: const Icon(Icons.add),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
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
                          if (index >= 0 && index < _filteredTimes.length) _editTimeEntry(index);
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
          ),
          Container(
            color:  (_connectionStatus == "Verbunden mit Lichtschranke")? Colors.green[200]
                : (_connectionStatus == "Verbinde mit Lichtschranke...")? Colors.orange[200]
                : Colors.red[200],
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(Icons.bluetooth, color: (_connectionStatus == "Verbunden mit Lichtschranke")? Colors.green
                    : (_connectionStatus == "Verbinde mit Lichtschranke...")? Colors.orange
                    : Colors.red,
                  size: 40.0,),
                Expanded(
                  child: Text(
                    _connectionStatus,
                    style: (_connectionStatus == "Verbunden mit Lichtschranke")? TextStyle(color: Colors.green[900]) 
                          : (_connectionStatus == "Verbinde mit Lichtschranke...")? TextStyle(color: Colors.orange[900])
                          : TextStyle(color: Colors.red[900]),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                    onPressed: () {
                      if (_connectionStatus != "Verbunden mit Lichtschranke"
                          && _connectionStatus != "Verbinde mit Lichtschranke...")
                        _connectToLichtschranke();
                    },
                    icon: Icon(Icons.refresh, color: Colors.black)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}