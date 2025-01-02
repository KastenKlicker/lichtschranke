import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:lichtschranke/TimeEntry.dart';
import 'package:lichtschranke/TimeListScreen.dart';
import 'package:lichtschranke/base_scaffold.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'AppState.dart';
import 'package:url_launcher/url_launcher.dart';

class StopwatchScreen extends StatefulWidget {
  @override
  _StopwatchScreenState createState() => _StopwatchScreenState();
}

const List<String> distanceList = <String>[
  "",
  "30m",
  "100m",
  "150m",
  "200m",
  "300m",
  "400m",
  "500m",
  "600m",
  "800m",
];

typedef DistanceEntry = DropdownMenuEntry<String>;

class _StopwatchScreenState extends State<StopwatchScreen> {

  static final List<DistanceEntry> distanceEntries = UnmodifiableListView<DistanceEntry>(
    distanceList.map<DistanceEntry>((String distance) => DistanceEntry(value: distance, label: distance))
  );

  String dropdownValue = distanceList.first;
  
  final TextEditingController distanceController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Check if a new version is available
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final appState = Provider.of<AppState>(context, listen: false);

      while (appState.newVersionURI == "notInitialized")
        await Future.delayed(Duration(milliseconds: 100));
      
      if (appState.newVersionURI.isNotEmpty) {
        _showUpdateDialog(context, appState);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return BaseScaffold(
      appBar: AppBar(
        title: Stack(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: Icon(Icons.list, color: Colors.orange),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TimeListScreen(),
                    ),
                  );
                },
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: Text("Stopwatch"),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Icon(Icons.watch_later_outlined, size: 200),
          SizedBox(height: 20),
          DropdownMenu(
            initialSelection: distanceList.first,
            dropdownMenuEntries: distanceEntries,
            label: const Text("Distanz"),
            width: 200,
            controller: distanceController,
            requestFocusOnTap: true,
            menuHeight: 300,
            onSelected: (String? distanceValue) {
              if (distanceController.text != dropdownValue) {
                dropdownValue = distanceController.text;
                appState.distance = dropdownValue;
              }
            },
          ),
          SizedBox(height: 20),
          // Anzeige der aktuellen Zeit
          Text(
            _formatElapsedTime(appState.elapsedTime),
            style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),
          // Start-/Stopp-Steuerelemente
          Center(
            child: appState.isRunning
                ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.add_circle,
                    color: Colors.orange,
                    size: 60,
                  ),
                  onPressed: () {
                    appState.addTimeEntryToSet(TimeEntry(
                        date: DateTime.now(),
                        timeInMillis: appState.elapsedTime.inMilliseconds,
                        distance: appState.distance));
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.refresh,
                    color: Colors.orange,
                    size: 60,
                  ),
                  onPressed: () {
                    appState.stop(context); // Stoppuhr stoppen
                  },
                ),
              ],
            )
                : IconButton(
              icon: Icon(
                Icons.play_circle,
                color: Colors.orange,
                size: 60,
              ),
              onPressed: () {
                appState.startOverBluetooth(); // Timer starten
              },
            ),
          ),
          SizedBox(height: 10,),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 250,
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.orange, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: (appState.filteredTimes.isNotEmpty)? Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(appState.filteredTimes.first.name,
                          textAlign: TextAlign.left,),
                        Text(appState.filteredTimes.first.distance,
                          textAlign: TextAlign.right,)
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(appState.filteredTimes.first.getTimeFormatted(),
                          textAlign: TextAlign.left,),
                        Text(DateFormat('dd.MM.yyyy HH:mm').format(appState.filteredTimes.first.date),
                          textAlign: TextAlign.right,)
                      ],
                    ),
                  ],
                ) : Text("Keine Zeit vorhanden"),
              ),
              Positioned(
                top: -10,
                left: 20,
                child: Container(
                  color: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 5),
                  child: Text(
                    "Letzte Zeit",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showUpdateDialog(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Neue Version verfügbar!"),
          content: Text("Jetzt auf Update klicken um die neuste Version zu installieren."),
          actions: [
            ElevatedButton(
              child: Text("Später"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text("Update", style: TextStyle(color: Colors.white)),
              onPressed: () async {
                Uri uri = Uri.parse(appState.newVersionURI);
                if (!await launchUrl(uri)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Fehler: Die URL konnte nicht geöffnet werden.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                Navigator.of(context).pop();
              },
            )
          ],
        );
      },
    );
  }

  String _formatElapsedTime(Duration elapsedTime) {
    final hours = elapsedTime.inHours.toString().padLeft(2, '0');
    final minutes =
    elapsedTime.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
    elapsedTime.inSeconds.remainder(60).toString().padLeft(2, '0');
    final milliseconds =
    (elapsedTime.inMilliseconds.remainder(1000) ~/ 10)
        .toString()
        .padLeft(2, '0');
    return "$hours:$minutes:$seconds:$milliseconds";
  }
}