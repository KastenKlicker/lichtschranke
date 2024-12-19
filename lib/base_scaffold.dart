import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lichtschranke/AppState.dart';

class BaseScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;

  const BaseScaffold({
    Key? key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      appBar: appBar, // AppBar kann vom Screen definiert werden
      floatingActionButton: floatingActionButton,
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Hauptbereich, in den spezifische Inhalte eingefügt werden
          Expanded(child: body),

          // Gemeinsame Verbindungsanzeige am unteren Rand
          Container(
            color: appState.connectionStatus == "Verbunden mit Lichtschranke"
                ? Colors.green[200]
                : appState.connectionStatus == "Verbinde mit Lichtschranke..."
                ? Colors.orange[200]
                : Colors.red[200],
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () {
                    if (appState.connectionStatus !=
                        "Verbunden mit Lichtschranke" &&
                        appState.connectionStatus !=
                            "Verbinde mit Lichtschranke...") {
                      appState.connectToLichtschranke();
                    }
                  },
                  icon: Icon(
                    Icons.bluetooth,
                    color: appState.connectionStatus ==
                        "Verbunden mit Lichtschranke"
                        ? Colors.green
                        : appState.connectionStatus ==
                        "Verbinde mit Lichtschranke..."
                        ? Colors.orange
                        : Colors.red,
                  ),
                ),
                Expanded(
                  child: Text(
                    appState.connectionStatus,
                    style: TextStyle(
                      color: appState.connectionStatus ==
                          "Verbunden mit Lichtschranke"
                          ? Colors.green[900]
                          : appState.connectionStatus ==
                          "Verbinde mit Lichtschranke..."
                          ? Colors.orange[900]
                          : Colors.red[900],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    if (appState.connectionStatus ==
                        "Verbunden mit Lichtschranke") {
                      appState.resetLichtschranke(context);
                    }
                  },
                  icon: const Icon(Icons.refresh, color: Colors.black),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}