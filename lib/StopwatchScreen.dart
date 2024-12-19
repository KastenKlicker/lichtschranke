import 'package:flutter/material.dart';
import 'package:lichtschranke/TimeListScreen.dart';
import 'package:lichtschranke/base_scaffold.dart';
import 'package:provider/provider.dart';
import 'AppState.dart';

class StopwatchScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context); // Zugriff auf AppState

    return BaseScaffold(
      appBar: AppBar(
        title: Stack(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: Icon(Icons.list, color: Colors.orange,),
                onPressed: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => const TimeListScreen()));
                },),
            ),
            Align(
              child: Text("Stopwatch"),
              alignment: Alignment.center,
            )
          ],
        )
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