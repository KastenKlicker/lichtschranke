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
import 'package:package_info_plus/package_info_plus.dart';
import 'package:usb_serial/transaction.dart';
import 'package:usb_serial/usb_serial.dart';
import 'package:http/http.dart' as http;

class AppState extends ChangeNotifier {
  
  String _connectionStatus = "Nicht verbunden.";
  String _distance = "";
  bool _isRunning = false;
  bool _isReset = false;
  Duration _elapsedTime = Duration.zero;
  DateTime? _startTime;
  Timer? _timer;
  String _appVersion = "Unknown Version";
  String _newVersionURI = "notInitialized";
  
  SplayTreeSet<TimeEntry> timeEntries = SplayTreeSet();
  List<TimeEntry> _filteredTimes = [];
  final BluetoothClassic _bluetoothClassicPlugin = BluetoothClassic();

  DateTimeRange initialDateRange = DateTimeRange(
      start: DateTime.utc(2000),
      end: DateTime.now());
  
  String _searchedName = "";

  // Getter
  String get connectionStatus => _connectionStatus;
  bool get isRunning => _isRunning;
  Duration get elapsedTime => _elapsedTime;
  String get distance => _distance;
  String get searchedName => _searchedName;
  String get appVersion => _appVersion;
  String get newVersionURI => _newVersionURI;
  UnmodifiableListView<TimeEntry> get filteredTimes =>
      UnmodifiableListView(_filteredTimes);


  set distance(String value) {
    _distance = value;
    notifyListeners();
  }

  set isRunning(bool value) {
    _isRunning = value;
  }


  set searchedName(String value) {
    _searchedName = value;
  } 
  
  // Constructor
  AppState() {
    _loadTimes();
    _initializeSerial();
    _initializeBluetooth();
    _getAppVersion();
    _checkForNewVersion();
  }

  void start() {
    _isRunning = true;
    _startTime = _startTime ?? DateTime.now().subtract(_elapsedTime); // If startTime is null, calculate startTime

    // Update timer based on system time every millisecond
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
    if (_connectionStatus == "Verbunden mit Lichtschranke")
      _bluetoothClassicPlugin.write("start\n");
    else
      start();
  }

  void stop(BuildContext context) {
    _isRunning = false;
    _timer?.cancel();
    _timer = null;

    _startTime = null; // Startzeitpunkt zurücksetzen
    _elapsedTime = Duration.zero;

    if  (_connectionStatus == "Verbunden mit Lichtschranke") {
      resetLichtschranke(context);
    }

    notifyListeners();
  }

  void addTimeEntryToSet(TimeEntry timeEntry) {
    timeEntries.add(timeEntry);
    createFilteredTimes();
  }

  void _getAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    _appVersion = packageInfo.version;
  }
  
  void _checkForNewVersion() async {
    
     http.Response response = await http.get(
        Uri.parse('https://api.github.com/repos/KastenKlicker/lichtschranke/releases/latest'),
      headers: {
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
      }
    );
     
     // Check if http get request was completed successfully
     if (response.statusCode != 200) {
       print("Latest Version GET Request returned ${response.statusCode}!");
       print(response.body);
       _newVersionURI = "";
       return;
     }
     
     Map<String, dynamic> responseBodyMap = jsonDecode(response.body);
     
     // Check if a new version is available
     if (responseBodyMap["tag_name"] == _appVersion) {
       _newVersionURI = "";
       return;
     }
     List<dynamic> assets = responseBodyMap['assets'];
     if (assets.isNotEmpty && assets[0] is Map<String, dynamic>) {
       _newVersionURI = assets[0]["browser_download_url"] ?? "";
       return;
     }

     _newVersionURI = "";
  }
  
  Future<void> _initializeSerial() async {
    
    print("Init Serial");

    UsbPort? port;
    
    UsbSerial.usbEventStream?.listen((UsbEvent event) async {
      if (event.event == UsbEvent.ACTION_USB_ATTACHED) {
        port = await openSerial();
      } else if (event.event == UsbEvent.ACTION_USB_DETACHED) {
        port?.close();
      }
    });
  }
  
  Future<UsbPort> openSerial() async {
    print("Open Serial port");

    UsbPort port = (await UsbSerial.create(6790, 29986, UsbSerial.CH34x))!;
    print("Created port.");

    bool openResult = await port.open();
    if ( !openResult ) {
      print("Failed to open port.");
      return port;
    }
    print("Opened port.");

    await port.setDTR(true);
    await port.setRTS(true);
    print("Set up DTR AND RTS");

    port.setPortParameters(115200, UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);
    print("Set up Port Parameters");

    Transaction<String> transaction = Transaction.stringTerminated(
      port.inputStream!,
      Uint8List.fromList([13,10]), // New line
    );
    print("Created transaction");

    // listen
    transaction.stream.listen( (String data) {
      _handleData(data);
    });
    
    return port;
  }

  Future<void> _initializeBluetooth() async {
    
    await _bluetoothClassicPlugin.initPermissions();
    
    connectToLichtschranke();

    _bluetoothClassicPlugin.onDeviceStatusChanged().listen((status) {
      _handleBluetoothStatus(status);
    });

    _bluetoothClassicPlugin.onDeviceDataReceived().listen((event) {
      _handleDataBluetooth(event);
    });
  }

  void connectToLichtschranke() async {

    List<Device> deviceList = await _bluetoothClassicPlugin.getPairedDevices();

    List<String> deviceNames = <String>[];

    for (Device device in deviceList) {
      deviceNames.add(device.name!);
    }

    // Check if Lichtschranke is connected with the device
    if (!deviceNames.contains("Lichtschranke")) {
      _connectionStatus = "Lichtschranke nicht gefunden.";
      notifyListeners();
      return;
    }

    Device lichtschranke = deviceList.where((device) => device.name == "Lichtschranke").first;
    
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

  /// Checks if the latest TimeEntry is younger than 500ms
  bool _isLessThan500ms(TimeEntry newEntry) {
    return timeEntries.any((entry) {
      if (entry.compareTo(newEntry) == 0) return false;
      int difference = newEntry.timeInMillis - entry.timeInMillis;
      return difference.abs() < 500;
    });
  }
  
  void _handleDataBluetooth(Uint8List event) {
    
    _handleData(String.fromCharCodes(event));
  }

  /// Handles Data incoming over Bluetooth
  void _handleData(String timeInMillisStr) async {  
    // Get the numbers out of the incoming chars
    
    timeInMillisStr = timeInMillisStr.split("\n")[0];
    timeInMillisStr.replaceAll(new RegExp(r"\D"), "");
    
    int timeInMillis = int.parse(timeInMillisStr);

    // 0 == ack of reset, 1 == ack of start
    if (timeInMillis == 0) {
      _isReset = true;
      notifyListeners();
      return;
    } else if (timeInMillis == 1) {
      isRunning = true;
      start();
      return;
    }
    
    // Start the timer if a new time was received, but the timer wasn't running
    if (!_isRunning) {
      start();
    }

    // To display the most precise time, set the time the same as the received 
    _elapsedTime = Duration(milliseconds: timeInMillis);
    _startTime = DateTime.now().subtract(_elapsedTime);

    TimeEntry newEntry = TimeEntry(
        timeInMillis: timeInMillis,
        date: DateTime.now(),
        distance: _distance);

    if (_isLessThan500ms(newEntry))
      return;

      // Add timeEntry, to Set
    timeEntries.add(newEntry);
    createFilteredTimes();
    
    _saveTimes();
  }

  Future<void> resetLichtschranke(BuildContext context) async {
    if (_connectionStatus != "Verbunden mit Lichtschranke") return;

    _bluetoothClassicPlugin.write("reset\n");

    // Wait for reset ack
    while (!_isReset)
      await Future.delayed(Duration(milliseconds: 100));
    
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content:
          _isReset ? const Text('Lichtschranke wurde zurückgesetzt.') :
          const Text('Fehler beim zurücksetzen der Lichtschranke!'),
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
    
    _isReset = false;
  }

  /// Filters the TimeEntries by recorded Date
  Future<void> selectDateRange(BuildContext context) async {    
    DateTime startDate = (initialDateRange.start == DateTime.utc(2000)
        ? DateTime.now().subtract(Duration(days: DateTime.now().weekday -1))
        : initialDateRange.start);
    
    DateTime endDate = (startDate.isAfter(initialDateRange.end))
        ? startDate.add(const Duration(days: 1))
        : initialDateRange.end;
    
    DateTimeRange dateTimeRange = DateTimeRange(start: startDate, end: endDate);
    
    DateTimeRange? selectedDateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: dateTimeRange,
    );
    
    if (selectedDateRange != null) {
      initialDateRange = selectedDateRange;
      createFilteredTimes();
    }
  }

  /// Loads time from internal storage
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

  /// Save times to storage
  Future<void> _saveTimes() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Just save times to storage with name - deactivate the next statement if wanted
    //List<TimeEntry> timesWithName = timeEntries.where((entry) => entry.name.trim().isNotEmpty).toList();
    
    // Save all times
    List<TimeEntry> timesWithName = timeEntries.toList();

    // Encode TimeEntries
    List<String> encodedTimes = timesWithName.map((entry) => json.encode(entry.toMap())).toList();

    // Save times
    await prefs.setStringList('times', encodedTimes);
  }
  
  void createFilteredTimes() {
    _filteredTimes = List.from(timeEntries);
    
    // Filter by name
    _filteredTimes = timeEntries
        .where((entry) => entry.name.toLowerCase().contains(_searchedName.toLowerCase()))
        .toList();

    // Filter by date
    _filteredTimes = _filteredTimes
        .where((entry) =>
          entry.date.isAfter(initialDateRange.start) &&
          entry.date.isBefore(initialDateRange.end.add(const Duration(days: 1))))
        .toList();
    notifyListeners();
  }

  /// Delete Time by filteredTimes index
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

  /// Show the Editing Dialog for the chosen TimeEntry or if index = -100, a new one
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
                  Expanded(
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
                  const SizedBox(width: 10),
                  Expanded(
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
                  : Column( // Portrait mode
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

                      // If the edited TimeEntry is an existing one, then delete the old one
                      if (index != -100) deleteTime(index);

                      // Create the new TimeEntry
                      timeEntries.add(newEntry);
                      createFilteredTimes();

                      _saveTimes();
                      Navigator.of(context).pop();
                    } catch (e) {
                      // Some type of Error ig
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
      
      String? selectedDirectory = await _selectExportDirectory();
      if (selectedDirectory == null) return; // Return if user doesn't choose a directory

      String csv = _createCSVFile();

      // Save the file
      String fileName = fileNameController.text.trim();
      if (fileName.isEmpty) fileName = 'lichtschranke_export.csv';
      final file = File('$selectedDirectory/$fileName');
      await file.writeAsString(csv);

      // Success dialog
      _showMenuDialog(context, 'Datei wurde unter: ${file.path} gespeichert.');
    } catch (e) {
      // Error Dialog
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
      ["Name", "Datum", "Zeit", "Distanz"] // Header
    ];

    // Add entries from filtered Times to CSV Data structure
    for (var entry in _filteredTimes) {
      rows.add([entry.name, entry.date.toIso8601String(), entry.timeInMillis.toString(), entry.distance]);
    }

    // Convert list to CSV
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
    
    // Create a temporary file from the CSV for the share Dialog
    Share.shareXFiles([XFile.fromData(utf8.encode(csv), mimeType: "text/csv")], fileNameOverrides: ["LichtschrankeExport.csv"]);
  }

  Future<void> importCSV(BuildContext context) async {
    
    // Let the user pick a CSV file
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      // If a file is selected, parse file into TimeEntry list
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

        // Save times
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
}