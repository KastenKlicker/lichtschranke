import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:bluetooth_classic/bluetooth_classic.dart';
import 'package:bluetooth_classic/models/device.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'package:lichtschranke/TimeEntry.dart';

class AppState extends ChangeNotifier {
  
  String _connectionStatus = "Nicht verbunden.";
  String _distance = "";
  bool _isRunning = false;
  Duration _elapsedTime = Duration.zero;
  DateTime? _startTime;
  Timer? _timer;
  
  SplayTreeSet<TimeEntry> timeEntries = SplayTreeSet();
  List<TimeEntry> _filteredTimes = [];
  final BluetoothClassic _bluetoothClassicPlugin = BluetoothClassic();
  late Device lichtschranke;

  DateTimeRange initialDateRange = DateTimeRange(
      start: DateTime.now().subtract(Duration(days: DateTime.now().weekday -1)), // Get Week start
      end: DateTime.now());

  // Getter
  String get connectionStatus => _connectionStatus;
  bool get isRunning => _isRunning;
  Duration get elapsedTime => _elapsedTime;
  String get distance => _distance;
  UnmodifiableListView<TimeEntry> get filteredTimes =>
      UnmodifiableListView(_filteredTimes);


  set distance(String value) {
    _distance = value;
    // TODO ist notwendig? notifyListeners();
  }

  set isRunning(bool value) {
    _isRunning = value;
  }

  void start() {
    _isRunning = true;
    _startTime = _startTime ?? DateTime.now().subtract(_elapsedTime);

    // Aktualisiere _elapsedTime basierend auf Systemzeit
    _timer = Timer.periodic(const Duration(milliseconds: 1), (timer) {
      final now = DateTime.now();
      if (_startTime != null) {
        _elapsedTime = now.difference(_startTime!);
        notifyListeners();
      }
    });

    notifyListeners();
  }
  
  void startOverBluetooth() {
    _bluetoothClassicPlugin.write("start\n");
  }

  void stop() {
    _isRunning = false;
    _timer?.cancel();
    _timer = null;

    _startTime = null; // Startzeitpunkt zurücksetzen
    _elapsedTime = Duration.zero;

    notifyListeners();
  }

  void addTimeEntryToSet(TimeEntry timeEntry) {
    timeEntries.add(timeEntry);
    _filteredTimes = List.from(timeEntries);
    notifyListeners();
  }

  // Constructor
  AppState() {
    _loadTimes();
    _initializeBluetooth();
  }

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
      _connectionStatus = "Lichtschranke nicht gefunden.";
      notifyListeners();
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

  void connectToLichtschranke() async {
    await _bluetoothClassicPlugin.connect(lichtschranke.address, "00001101-0000-1000-8000-00805f9b34fb");
  }

  void _handleBluetoothStatus(int status) {
    if (status == Device.disconnected) {
      _connectionStatus = "Nicht verbunden.";
      notifyListeners();
    }
    else if (status == Device.connecting) {
      _connectionStatus = "Verbinde mit Lichtschranke...";
      notifyListeners();
    }
    else {
      _connectionStatus = "Verbunden mit Lichtschranke";
      notifyListeners();
    }
  }

  bool _isLessThan500ms(TimeEntry newEntry) {
    return timeEntries.any((entry) {
      if (entry.compareTo(newEntry) == 0) return false;
      int difference = newEntry.timeInMillis - entry.timeInMillis;
      return difference.abs() < 500;
    });
  }

  void _handleData(Uint8List event) async {    
    String timeInMillisStr = String.fromCharCodes(event);
    
    timeInMillisStr = timeInMillisStr.split("\n")[0];
    timeInMillisStr.replaceAll(new RegExp(r"\D"), "");
    
    if (timeInMillisStr.contains("Reset") || timeInMillisStr.isEmpty) {
      return;
    }
    
    int timeInMillis = int.parse(timeInMillisStr);

    if (timeInMillis == 0) {
      return;
    } else if (timeInMillis == 1) {
      isRunning = true;
      start();
      return;
    }
    
    if (!_isRunning) {
      start();
    }

    // setzen und Timer hochpräzise neu starten, ab neuem Wert weiterzählen
    _elapsedTime = Duration(milliseconds: timeInMillis);
    _startTime = DateTime.now().subtract(_elapsedTime); // Reset Startzeit

    // Timer neu starten
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 1), (timer) {
      final now = DateTime.now();
      if (_startTime != null) {
        _elapsedTime = now.difference(_startTime!);
        notifyListeners();
      }
    });

    TimeEntry newEntry = TimeEntry(
        timeInMillis: timeInMillis,
        date: DateTime.now(),
        distance: _distance);

    if (_isLessThan500ms(newEntry))
      return;

      // Fügen Sie den empfangenen Zeitstempel zur Liste hinzu
    timeEntries.add(newEntry);
    _filteredTimes = List.from(timeEntries);
    notifyListeners();
    
    // Zum Speichern der neuen Einträge aufrufen
    _saveTimes(); // TODO Useless?
  }

  void resetLichtschranke(BuildContext context) {
    stop();
    if (_connectionStatus != "Verbunden mit Lichtschranke") return;

    _bluetoothClassicPlugin.write("reset\n");

    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: const Text('Lichtschranke wurde zurückgesetzt'),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> selectDateRange(BuildContext context) async {
    // Öffne den Datumsbereich-Picker
    DateTimeRange? selectedDateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020), // frühester auswählbarer Zeitpunkt
      lastDate: DateTime(2100), // spätester auswählbarer Zeitpunkt
      initialDateRange: initialDateRange, // standardmäßig eingestellter Bereich
    );

    // Wenn ein Datum ausgewählt wurde, filtere die Einträge entsprechend
    if (selectedDateRange != null) {
      filterByDateRange(selectedDateRange);
      initialDateRange = selectedDateRange;
    }
  }

  void filterByDateRange(DateTimeRange dateTimeRange) {
    _filteredTimes = timeEntries
        .where((entry) =>
    entry.date.isAfter(dateTimeRange.start) &&
        entry.date.isBefore(dateTimeRange.end.add(const Duration(days: 1))))
        .toList();
    notifyListeners();
  }

  Future<void> _loadTimes() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? timeStringList = prefs.getStringList('times');
    if (timeStringList != null) {
      timeEntries = SplayTreeSet.from(timeStringList
          .map((timeString) =>
          TimeEntry.fromMap(Map<String, String>.from(json.decode(timeString))))
          .toSet());
      _filteredTimes = List.from(timeEntries);
      notifyListeners();
    }
  }

  Future<void> _saveTimes() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Nur Zeiten mit Namen speichern
    List<TimeEntry> timesWithName = timeEntries.where((entry) => entry.name.trim().isNotEmpty).toList();

    // Zeiten serialisieren und speichern
    List<String> encodedTimes = timesWithName.map((entry) => json.encode(entry.toMap())).toList();

    await prefs.setStringList('times', encodedTimes);
  }

  /// Zeit-Einträge manipulieren
  void filterTimes(String query) {
    _filteredTimes = timeEntries
        .where((entry) => entry.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
    notifyListeners();
  }

  void deleteTime(int index) {
    TimeEntry timeEntry = _filteredTimes[index];
    _filteredTimes.removeAt(index);
    timeEntries.removeWhere((entry) =>
    entry.timeInMillis == timeEntry.timeInMillis &&
        entry.date == timeEntry.date &&
        entry.name == timeEntry.name);
    notifyListeners();
    _saveTimes();
  }

  void showEntryDialog(BuildContext context, TimeEntry timeEntry,
      {int index = -100}) {
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
        TextEditingController distanceController = TextEditingController(
            text: timeEntry.distance
        );

        bool isTimeValid = true;
        bool isDateValid = true;

        return StatefulBuilder(builder: (context, setInnerState) {
          final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

          return AlertDialog(
            backgroundColor: Colors.white,
            title: const Text('Zeiteintrag'),
            content: SingleChildScrollView(
              child: isLandscape
                  ? Row(
                children: [
                  Expanded( // Zeit- und Datum-Textfelder nebeneinander
                    child: Column(
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
                          onChanged: (value) {
                              try {
                                DateFormat('HH:mm:ss.SSS').parseStrict(value);
                                isTimeValid = true;
                              } catch (e) {
                                isTimeValid = false;
                              }
                              notifyListeners();
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
                          onChanged: (value) {
                            try {
                              DateFormat('dd.MM.yyyy HH:mm').parseStrict(value);
                              isDateValid = true;
                            } catch (e) {
                              isDateValid = false;
                            }
                            notifyListeners();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10), // Abstand zwischen Spalten
                  Expanded( // Name und Distanz
                    child: Column(
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(hintText: 'Name'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: distanceController,
                          decoration: const InputDecoration(hintText: "Distanz"),
                        ),
                      ],
                    ),
                  ),
                ],
              )
                  : Column( // Hochformat-Layout (wie gewohnt)
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
                    onChanged: (value) {
                      try {
                        DateFormat('HH:mm:ss.SSS').parseStrict(value);
                        isTimeValid = true;
                      } catch (e) {
                        isTimeValid = false;
                      }
                      notifyListeners();
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
                    onChanged: (value) {
                      try {
                        DateFormat('dd.MM.yyyy HH:mm').parseStrict(value);
                        isDateValid = true;
                      } catch (e) {
                        isDateValid = false;
                      }
                      notifyListeners();
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(hintText: 'Name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: distanceController,
                    decoration: const InputDecoration(hintText: "Distanz"),
                  ),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                child: const Text('Speichern', style: TextStyle(color: Colors.white)),
                onPressed: () {
                  if (isTimeValid && isDateValid) {
                    String time = timeController.text.trim();
                    String date = dateController.text.trim();
                    String name = nameController.text.trim();
                    String distance = distanceController.text.trim();

                    try {
                      TimeEntry newEntry = TimeEntry(
                          date: DateFormat('dd.MM.yyyy HH:mm').parseStrict(date),
                          name: name,
                          timeInMillis: TimeEntry.parseTimeToMilliseconds(time),
                          distance: distance);

                      // Falls Bearbeitung eines Eintrags, wird der alte gelöscht
                      if (index != -100) deleteTime(index);

                      timeEntries.add(newEntry);
                      _filteredTimes = List.from(timeEntries);
                      notifyListeners();

                      _saveTimes();
                      Navigator.of(context).pop();
                    } catch (e) {
                      // Fehler wird automatisch durch die Tastatur angezeigt
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
      },
    );
  }

  void _showMenuDialog(BuildContext context, String option) {
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

  Future<void> exportFilteredTimesToCSV(BuildContext context) async {
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
      _showMenuDialog(context, 'Datei wurde unter: ${file.path} gespeichert.');
    } catch (e) {
      // Fehlerbehandlung
      _showMenuDialog(context, 'Export fehlgeschlagen: $e');
    }
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

  String _createCSVFile() {

    List<List<String>> rows = [
      ["Name", "Datum", "Zeit", "Distanz"] // Kopfzeile
    ];

    for (var entry in _filteredTimes) {
      rows.add([entry.name, entry.date.toIso8601String(), entry.timeInMillis.toString(), entry.distance]);
    }

    // Konvertiere die Liste in CSV-Format
    String csv = const ListToCsvConverter().convert(rows);

    return csv;
  }

  Future<String?> selectExportDirectory() async {
    Directory downloadsDirectory = Directory('~/Downloads');
    String initialDirectoryPath = downloadsDirectory.path;

    String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Wähle einen Ordner für den Export',
      initialDirectory: initialDirectoryPath,
    );

    return selectedDirectory;
  }

  Future<void> shareFilteredTimes() async {
    String csv = _createCSVFile();
    Share.shareXFiles([XFile.fromData(utf8.encode(csv), mimeType: "text/csv")], fileNameOverrides: ["LichtschrankeExport.csv"]);
  }

  Future<void> importCSV(BuildContext context) async {
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
            importedTimes.add(
                TimeEntry(
                    name: row[0].toString(),
                    date: DateTime.parse(row[1].toString()),
                    timeInMillis: row[2],
                    distance: row[3]
                )
            );
          }
        }

        timeEntries.addAll(importedTimes);
        _filteredTimes = List.from(timeEntries);
        notifyListeners();

        _saveTimes();
        _showMenuDialog(context, 'CSV-Import erfolgreich abgeschlossen.');
      } else {
        _showMenuDialog(context, 'Kein Datei ausgewählt.');
      }
    } catch (e) {
      _showMenuDialog(context, 'Import fehlgeschlagen: $e');
    }
  }

  void updateConnectionStatus(String status) {
    _connectionStatus = status;
    notifyListeners();
  }
}