import 'package:flutter/material.dart';
import 'package:lichtschranke/TimeListScreen.dart';
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
          IconButton(
            icon: Icon(Icons.list, color: Colors.orange,),
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const TimeListScreen()));
            },),
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