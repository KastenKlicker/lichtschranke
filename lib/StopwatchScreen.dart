import 'package:flutter/material.dart';
import 'package:lichtschranke/TimeEntry.dart';
import 'package:lichtschranke/TimeListScreen.dart';
import 'package:lichtschranke/base_scaffold.dart';
import 'package:provider/provider.dart';
import 'AppState.dart';

class StopwatchScreen extends StatefulWidget {
  @override
  _StopwatchScreenState createState() => _StopwatchScreenState();
}

class _StopwatchScreenState extends State<StopwatchScreen> {

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
                        timeInMillis:
                        appState.elapsedTime.inMilliseconds));
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.stop_circle,
                    color: Colors.orange,
                    size: 60,
                  ),
                  onPressed: () {
                    appState.stop(); // Stoppuhr stoppen
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
                appState.start(); // Timer starten
              },
            ),
          )
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