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

    // About App text
    final ThemeData theme = Theme.of(context);
    final TextStyle textStyle = theme.textTheme.bodyMedium!;
    final List<Widget> aboutBoxChildren = <Widget>[
      const SizedBox(height: 24),
      RichText(
        text: TextSpan(
          children: <TextSpan>[
            TextSpan(
                style: textStyle,
                text: "Lichtschranke is an app designed to measure "
                      'track & field running times.'
                      'Learn more about Lichtschranke at '),
            TextSpan(
                style: textStyle.copyWith(color: theme.colorScheme.primary),
                text: 'https://github.com/KastenKlicker/lichtschranke'),
            TextSpan(style: textStyle, text: '.'),
          ],
        ),
      ),
    ];

    return BaseScaffold(
      appBar: AppBar(
          title: Stack(
            children: [
              Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.only(right: 46.0),
                  child: Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(30.0),
                    child: TextFormField(
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
                      initialValue: appState.searchedName,
                      onChanged: (value) {
                        appState.searchedName = value;
                        appState.createFilteredTimes();
                      },
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 0),
                  child: IconButton(
                      icon:
                      Icon(Icons.arrow_forward, color: Colors.orange,),
                      onPressed: () {
                        Navigator.pop(context);
                      }),
                ),
              ),
            ],
          )
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
                decoration: BoxDecoration(
                  color: Colors.orange,
                ),
                child:
                Text("Lichtschranke",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                )),
            ListTile(
              leading: Icon(Icons.date_range_rounded),
              title: Text("Zeitraum"),
              onTap: () {
                appState.selectDateRange(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.drive_file_move_outlined),
              title: Text("Import"),
              onTap: () {
                appState.importCSV(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.drive_file_move_rtl_outlined),
              title: Text("Export"),
              onTap: () {
                appState.exportFilteredTimesToCSV(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.share),
              title: Text("Teilen"),
              onTap: () {
                appState.shareFilteredTimes();
              },
            ),
            AboutListTile(
              icon: Icon(Icons.info),
              applicationName: "Lichtschranke",
              applicationVersion: appState.appVersion, 
              applicationLegalese: "\u{a9} 2024 KastenKlicker",
              aboutBoxChildren: aboutBoxChildren,
              applicationIcon: Icon(Icons.watch_later_outlined, size: 50,),
            )
          ],
        ),
      ),
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