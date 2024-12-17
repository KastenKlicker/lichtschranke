class TimeEntry implements Comparable<TimeEntry>{

  DateTime date; // Added field for date
  String name;
  String distance;
  int timeInMillis;

  TimeEntry({
    required this.date,
    required this.timeInMillis,
    this.name = '',
    this.distance = ''
  }); // Ensure usage of updated format

  Map<String, String> toMap() {
    return {
      'date': date.toIso8601String(),
      'name': name,
      'timeInMillis': timeInMillis.toString(),
      'distance' : distance,
    };
  }

  static TimeEntry fromMap(Map<String, String> map) {
    return TimeEntry(
      date: DateTime.parse(map['date']!),
      name: map['name'] ?? '',
      timeInMillis: int.parse(map['timeInMillis']!),
      distance: map['distance'] ?? '',
    );
  }

  String getTimeFormatted() {
    final hours = (timeInMillis ~/ (1000 * 60 * 60)) % 24; // Stunden
    final minutes = (timeInMillis ~/ (1000 * 60)) % 60; // Minuten
    final seconds = (timeInMillis ~/ 1000) % 60; // Sekunden
    final millis = timeInMillis % 1000; // Millisekunden

    // Formatierung mit führenden Nullen
    final formattedHours = hours.toString().padLeft(2, '0');
    final formattedMinutes = minutes.toString().padLeft(2, '0');
    final formattedSeconds = seconds.toString().padLeft(2, '0');
    final formattedMilliseconds = millis.toString().padLeft(3, '0');

    return '$formattedHours:$formattedMinutes:$formattedSeconds.$formattedMilliseconds';
  }

  static int parseTimeToMilliseconds(String time) {
    // Splitte den String in Stunden, Minuten, Sekunden und Millisekunden
    final parts = time.split(RegExp(r'[:.]'));

    if (parts.length != 4) {
      throw FormatException('Das Zeitformat muss "HH:mm:ss.SSS" sein');
    }

    // Teile in Integer umwandeln
    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);
    final seconds = int.parse(parts[2]);
    final milliseconds = int.parse(parts[3]);

    // Umrechnung in Millisekunden
    int totalMilliseconds =
        (hours * 60 * 60 * 1000) + // Stunden -> Millisekunden
            (minutes * 60 * 1000) +   // Minuten -> Millisekunden
            (seconds * 1000) +        // Sekunden -> Millisekunden
            milliseconds;             // Millisekunden direkt

    return totalMilliseconds;
  }

  @override
  int compareTo(TimeEntry other) {
    // Invertiere den Vergleich nach Datum
    final int dateComparison = other.date.compareTo(this.date);
    if (dateComparison != 0) {
      return dateComparison;
    }

    // Invertiere den Vergleich nach Zeit in Millisekunden
    final int timeComparison = other.timeInMillis.compareTo(this.timeInMillis);
    if (timeComparison != 0) {
      return timeComparison;
    }

    // Zuletzt den Vergleich nach Name (alphabetisch absteigend)
    return this.name.compareTo(other.name);
  }
}