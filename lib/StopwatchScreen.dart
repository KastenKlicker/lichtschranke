import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'AppState.dart';

class StopwatchScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context); // Zugriff auf AppState

    return Scaffold(
      appBar: AppBar(
        title: const Text("Stopwatch"),
      ),
      body: Column(
        children: [
          Text("Verbindungsstatus: ${appState.connectionStatus}"),
          ElevatedButton(
            onPressed: () {
              appState.updateConnectionStatus("Verbunden mit Lichtschranke");
            },
            child: const Text("Verbinden"),
          ),
        ],
      ),
    );
  }
}