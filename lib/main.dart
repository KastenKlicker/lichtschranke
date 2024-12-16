
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

// TODO Start über Smartphone

class TimeEntry {
  
  DateTime date; // Added field for date
  String name;
  String distance;
  int timeInMillis;

  TimeEntry({
    required this.date,
    required this.timeInMillis,
    this.name = '',
    this.distance = ''
  }); // Ensure usage of updated format

  Map<String, String> toMap() {
    return {
      'date': date.toIso8601String(),
      'name': name,
      'timeInMillis': timeInMillis.toString(),
      'distance' : distance,
    };
  }

  static TimeEntry fromMap(Map<String, String> map) {
    return TimeEntry(
      date: DateTime.parse(map['date']!),
      name: map['name'] ?? '',
      timeInMillis: int.parse(map['timeInMillis']!),
      distance: map['distance'] ?? '',
    );
  }

  String getTimeFormatted() {
    final hours = (timeInMillis ~/ (1000 * 60 * 60)) % 24; // Stunden
    final minutes = (timeInMillis ~/ (1000 * 60)) % 60; // Minuten
    final seconds = (timeInMillis ~/ 1000) % 60; // Sekunden
    final millis = timeInMillis % 1000; // Millisekunden

    // Formatierung mit führenden Nullen
    final formattedHours = hours.toString().padLeft(2, '0');
    final formattedMinutes = minutes.toString().padLeft(2, '0');
    final formattedSeconds = seconds.toString().padLeft(2, '0');
    final formattedMilliseconds = millis.toString().padLeft(3, '0');

    return '$formattedHours:$formattedMinutes:$formattedSeconds.$formattedMilliseconds';
  }

  static int parseTimeToMilliseconds(String time) {
    // Splitte den String in Stunden, Minuten, Sekunden und Millisekunden
    final parts = time.split(RegExp(r'[:.]'));

    if (parts.length != 4) {
      throw FormatException('Das Zeitformat muss "HH:mm:ss.SSS" sein');
    }

    // Teile in Integer umwandeln
    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);
    final seconds = int.parse(parts[2]);
    final milliseconds = int.parse(parts[3]);

    // Umrechnung in Millisekunden
    int totalMilliseconds =
        (hours * 60 * 60 * 1000) + // Stunden -> Millisekunden
            (minutes * 60 * 1000) +   // Minuten -> Millisekunden
            (seconds * 1000) +        // Sekunden -> Millisekunden
            milliseconds;             // Millisekunden direkt

    return totalMilliseconds;
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
        entry.date == timeEntry.date &&
        entry.name == timeEntry.name &&
        entry.date == timeEntry.date);
  }
  List<TimeEntry> _filteredTimes = [];
  void _sortTimes() {
    _times.sort((a, b) {
      final dateComparison = b.date.compareTo(a.date);
      return dateComparison != 0 ? dateComparison : b.timeInMillis.compareTo(a.timeInMillis);
    });
    _filteredTimes = List.from(_times);
  }
  String _currentSearchQuery = '';
  final BluetoothClassic _bluetoothClassicPlugin = BluetoothClassic();

  /*void _editTimeEntry(int index) {
  
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
                    
                    _filteredTimes[index].date = date;
                    _filteredTimes[index].name = name;
                    _filteredTimes[index].timeInMillis =
                        DateFormat('HH:mm:ss.SSS')
                            .parse(time)
                            .millisecondsSinceEpoch;

                    _sortTimes();

                    int originalIndex = _times.indexWhere((entry) =>
                        entry.timeInMillis ==
                            _filteredTimes[index].timeInMillis &&
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
}*/

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
    
    // TODO Nicht nur am Anfang prüfen
    
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
    if (timeInMillisStr.contains("Reset")) {
        return;
    }
    int timeInMillis = int.parse(timeInMillisStr);
    
    if (timeInMillis == 0) {
      return;
    }
    
    TimeEntry newEntry = TimeEntry(
        timeInMillis: timeInMillis,
        date: DateTime.now());

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
        _filteredTimes = List.from(_times)..sort((a, b) => b.timeInMillis.compareTo(a.timeInMillis));
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
  void _showEntryDialog(TimeEntry timeEntry, {int index = -100}) {
    showDialog(
      context: context,
      builder: (context) {
        TextEditingController timeController = TextEditingController(
            text: timeEntry.getTimeFormatted()
        );
        TextEditingController dateController = TextEditingController(
            text: DateFormat('dd.MM.yyyy HH:mm').format(timeEntry.date));
        TextEditingController nameController = TextEditingController(
          text: timeEntry.name
        );

        bool isTimeValid = true;
        bool isDateValid = true;

  return AlertDialog(
    backgroundColor: Colors.white,
            title: const Text('Zeiteintrag'),
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

                      TimeEntry newEntry = TimeEntry(
                          date: DateFormat('dd.MM.yyyy HH:mm').parseStrict(date),
                          name: name,
                          timeInMillis: TimeEntry.parseTimeToMilliseconds(time));
                        if (index != -100)
                          _deleteTime(index);

                        if (_isDuplicate(newEntry))
                          return;

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
      // DateTime entryDate = DateFormat('dd.MM.yyyy HH:mm').parse('${entry.date} ${entry.time}'); TODO Idk was hier passiert, warum ist da ein ${entry.time}
      DateTime entryDate = DateFormat('dd.MM.yyyy HH:mm').parse('${entry.date}');
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
      entry.timeInMillis == timeEntry.timeInMillis &&
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
      rows.add([entry.name, entry.date.toIso8601String(), entry.timeInMillis.toString()]);
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
              date: DateTime.parse(row[1].toString()),
              timeInMillis: int.parse(row[2]),
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
        padding: const EdgeInsets.only(bottom: 55.0),
        child: FloatingActionButton(
          onPressed: () => _showEntryDialog(
            TimeEntry(date: DateTime.now(), timeInMillis: 0)
          ),
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
                  // Ensure updated format displays correctly
                  subtitle: Text('${entry.getTimeFormatted()} ${DateFormat('dd.MM.yyyy HH:mm').format(entry.date)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          if (index >= 0 && index < _filteredTimes.length) _showEntryDialog(_filteredTimes[index], index: index);
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
                IconButton(
                  onPressed: () {
                    if (_connectionStatus != "Verbunden mit Lichtschranke"
                        && _connectionStatus != "Verbinde mit Lichtschranke...")
                      _connectToLichtschranke();
                  },
                  icon: Icon(Icons.bluetooth,
                    color: (_connectionStatus == "Verbunden mit Lichtschranke")? Colors.green
                    : (_connectionStatus == "Verbinde mit Lichtschranke...")? Colors.orange
                    : Colors.red,)),
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
                      if (_connectionStatus == "Verbunden mit Lichtschranke") {
                        _bluetoothClassicPlugin.write("reset\n");
                      
                        MaterialBanner materialBanner= MaterialBanner(
                          content: Text('Lichtschranke wurde zurückgesetzt'), actions: [
                          TextButton(
                              onPressed: () => ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
                              child: const Text("Verstanden"))
                        ],
                        );
                        
                        ScaffoldMessenger.of(context).showMaterialBanner(materialBanner);
                      }
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