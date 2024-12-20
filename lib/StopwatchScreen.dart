import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:lichtschranke/TimeEntry.dart';
import 'package:lichtschranke/TimeListScreen.dart';
import 'package:lichtschranke/base_scaffold.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'AppState.dart';

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
                top: -10, // Text schwebt über der Linie
                left: 20, // Positionierung des Textes
                child: Container(
                  color: Colors.white, // Hintergrundfarbe des Textes, damit er die Linie "unterbricht"
                  padding: EdgeInsets.symmetric(horizontal: 5),
                  child: Text(
                    "Letzte Zeit", // Dein Beschriftungstext
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