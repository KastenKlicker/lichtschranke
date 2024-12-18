import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:lichtschranke/TimeEntry.dart';

class AppState extends ChangeNotifier {
  String connectionStatus = "Nicht verbunden.";
  SplayTreeSet<TimeEntry> timeEntries = SplayTreeSet();

  void updateConnectionStatus(String status) {
    connectionStatus = status;
    notifyListeners();
  }

  void addTimeEntry(TimeEntry entry) {
    timeEntries.add(entry);
    notifyListeners();
  }

  void removeTimeEntry(TimeEntry entry) {
    timeEntries.remove(entry);
    notifyListeners();
  }
}