import 'package:flutter/material.dart';
import 'package:lichtschranke/ConnectionStatus.dart';
import 'package:provider/provider.dart';
import 'package:lichtschranke/AppState.dart';

class BaseScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final Drawer? drawer;

  const BaseScaffold({
    Key? key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.drawer,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      appBar: appBar, // AppBar, is set by the current screen
      drawer: drawer, // Drawer, is set by the current screen
      floatingActionButton: floatingActionButton,
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          // Body, is set by the current screen
          Expanded(child: body),

          // Bluetooth Connection status at the bottom of the screen
          Container(
            color: appState.connectionStatus.isConnected()
                ? Colors.green[200]
                : appState.connectionStatus.isConnecting()
                ? Colors.orange[200]
                : Colors.red[200],
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () {
                    if (!appState.connectionStatus.isBluetooth()) {
                      appState.connectToLichtschranke();
                    }
                  },
                  icon: Icon(
                    appState.connectionStatus.isSerial()
                        ? Icons.cable
                        : Icons.bluetooth,
                    color: appState.connectionStatus.isConnected()
                        ? Colors.green
                        : appState.connectionStatus.isConnecting()
                        ? Colors.orange
                        : Colors.red,
                  ),
                ),
                Expanded(
                  child: Text(
                    appState.connectionStatus.message,
                    style: TextStyle(
                      color: appState.connectionStatus.isConnected()
                          ? Colors.green[900]
                          : appState.connectionStatus.isConnecting()
                          ? Colors.orange[900]
                          : Colors.red[900],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    appState.stop(context);
                  },
                  icon: Icon(
                      Icons.refresh,
                      color: appState.connectionStatus.isConnected()
                          ? Colors.green
                          : appState.connectionStatus.isConnecting()
                          ? Colors.orange
                          : Colors.red,),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}