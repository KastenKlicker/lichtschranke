import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lichtschranke/TimeListScreen.dart';
import 'package:lichtschranke/base_scaffold.dart';
import 'package:provider/provider.dart';
import 'AppState.dart';

class StopwatchScreen extends StatefulWidget {
  @override
  _StopwatchScreenState createState() => _StopwatchScreenState();
}

class _StopwatchScreenState extends State<StopwatchScreen> {
  Timer? _timer; // Optionaler Timer
  late DateTime _startTime; // Startzeitpunkt
  late Duration _elapsedTime; // Gespeicherte Dauer
  Duration _currentDuration = Duration.zero; // Aktuelle Dauer (inkl. ms)

  @override
  void initState() {
    super.initState();
    _elapsedTime = Duration.zero; // Initialisierte Dauer
    _startTimerIfNeeded();
  }

  void _startTimerIfNeeded() {
    final appState = Provider.of<AppState>(context, listen: false);

    if (appState.isRunning) {
      // Timer starten, wenn _isRunning true ist
      _startTime = DateTime.now().subtract(_elapsedTime); // Startzeit berechnen
      _timer ??= Timer.periodic(Duration(milliseconds: 10), (timer) {
        setState(() {
          // Differenz zwischen aktueller Zeit und Startzeit berechnen
          _currentDuration = DateTime.now().difference(_startTime);
        });
      });
    } else {
      // Timer stoppen, wenn _isRunning false ist
      _timer?.cancel();
      _timer = null;
      _elapsedTime = _currentDuration; // Elapsed Time speichern
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Überwacht Änderungen im AppState
    final appState = Provider.of<AppState>(context);
    appState.addListener(_startTimerIfNeeded);
  }

  @override
  void dispose() {
    // Cleanup: Timer und Listener entfernen
    _timer?.cancel();
    final appState = Provider.of<AppState>(context, listen: false);
    appState.removeListener(_startTimerIfNeeded);
    super.dispose();
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
          SizedBox(height: 20), // Platz für den Text
          Text(
            _formatElapsedTime(), // Formatiert die Zeit in hh:mm:ss:ms
            style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              // Toggle des _isRunning-Status im AppState
              if (appState.isRunning) {
                appState.stop();
              } else {
                appState.start();
              }
            },
            child: appState.isRunning ? Text("Stop") : Text("Start"),
          ),
        ],
      ),
    );
  }

  // Helfer-Funktion zur Formatierung der Zeit in hh:mm:ss:ms
  String _formatElapsedTime() {
    final hours = _currentDuration.inHours.toString().padLeft(2, '0');
    final minutes =
    _currentDuration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
    _currentDuration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final milliseconds =
    (_currentDuration.inMilliseconds.remainder(1000) ~/ 10)
        .toString()
        .padLeft(2, '0');
    return "$hours:$minutes:$seconds:$milliseconds";
  }
}