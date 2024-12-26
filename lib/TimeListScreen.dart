import 'package:flutter/material.dart';
import 'package:lichtschranke/base_scaffold.dart';
import 'package:provider/provider.dart';
import 'package:lichtschranke/AppState.dart';
import 'package:lichtschranke/TimeEntry.dart';
import 'package:intl/intl.dart';

class TimeListScreen extends StatelessWidget {
  const TimeListScreen({Key? key}) : super(key: key);

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
                    icon: 
                      Icon(Icons.arrow_back, color: Colors.orange,),
                    onPressed: () {
                      Navigator.pop(context);
                    }),
              ),
              Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.only(right: 46.0),
                  child: Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(30.0),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Nach Namen suchen',
                        border: OutlineInputBorder(
                          borderRadius:
                          BorderRadius.all(Radius.circular(30.0)), // Runde Ecken
                          borderSide: BorderSide.none, // Kein Rand
                        ),
                        prefixIcon: Icon(Icons.search, color: Colors.orange),
                        filled: true,
                        fillColor: Colors.white, // Weißer Hintergrund
                        contentPadding:
                        EdgeInsets.symmetric(vertical: 14.0),
                      ),
                      onChanged: (value) {
                        appState.filterTimes(value);
                      },
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 0),
                  child: PopupMenuButton<String>(
                    color: Colors.white,
                    icon: const Icon(Icons.more_vert,
                        color: Colors.orange), // Optionen
                    onSelected: (String value) {
                      if (value == 'Zeitraum') {
                        // Zeitraum festlegen
                        appState.selectDateRange(context);
                      } else if (value == 'Export') {
                        appState.exportFilteredTimesToCSV(context);
                      } else if (value == 'Import') {
                        appState.importCSV(context);
                      } else {
                        appState.shareFilteredTimes();
                      }
                    },
                    itemBuilder: (BuildContext context) {
                      return ['Zeitraum', 'Import', 'Export', 'Teilen']
                          .map((String choice) {
                        return PopupMenuItem<String>(
                          value: choice,
                          child: Text(choice),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ],
          )),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 55.0),
        child: FloatingActionButton(
          onPressed: () => appState.showEntryDialog(
              context, TimeEntry(date: DateTime.now(), timeInMillis: 0)),
          child: const Icon(Icons.add),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.white,
              child: ListView.builder(
                itemCount: appState.filteredTimes.length,
                itemBuilder: (context, index) {
                  final entry = appState.filteredTimes[index];
                  return ListTile(
                    title: Row(
                      children: [
                        Text(entry.name),
                        Expanded(
                          child: Text(
                            entry.distance,
                            textAlign: TextAlign.right,
                          ),
                        )
                      ],
                    ),
                    subtitle: Row(
                      children: [
                        Text(entry.getTimeFormatted()),
                        Expanded(
                          child: Text(
                            DateFormat('dd.MM.yyyy HH:mm')
                                .format(entry.date),
                            textAlign: TextAlign.right,
                          ),
                        )
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            appState.showEntryDialog(
                                context, entry,
                                index: index);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            appState.deleteTime(index);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}