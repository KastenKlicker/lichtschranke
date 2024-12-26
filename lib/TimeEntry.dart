class TimeEntry implements Comparable<TimeEntry>{

  DateTime date;
  String name;
  String distance;
  int timeInMillis;

  TimeEntry({
    required this.date,
    required this.timeInMillis,
    this.name = '',
    this.distance = ''
  });

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
    final hours = (timeInMillis ~/ (1000 * 60 * 60)) % 24;
    final minutes = (timeInMillis ~/ (1000 * 60)) % 60;
    final seconds = (timeInMillis ~/ 1000) % 60;
    final millis = timeInMillis % 1000;

    // Formatierung mit führenden Nullen
    final formattedHours = hours.toString().padLeft(2, '0');
    final formattedMinutes = minutes.toString().padLeft(2, '0');
    final formattedSeconds = seconds.toString().padLeft(2, '0');
    final formattedMilliseconds = millis.toString().padLeft(3, '0');

    return '$formattedHours:$formattedMinutes:$formattedSeconds.$formattedMilliseconds';
  }

  static int parseTimeToMilliseconds(String time) {
    // Split the String in the different time units
    final parts = time.split(RegExp(r'[:.]'));

    if (parts.length != 4) {
      throw FormatException('Das Zeitformat muss "HH:mm:ss.SSS" sein');
    }

    // Parse time units to numbers
    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);
    final seconds = int.parse(parts[2]);
    final milliseconds = int.parse(parts[3]);

    // Calculate time in milliseconds
    int totalMilliseconds =
        (hours * 60 * 60 * 1000) + // hours -> milliseconds
            (minutes * 60 * 1000) +   // minutes -> milliseconds
            (seconds * 1000) +        // seconds -> milliseconds
            milliseconds;             // milliseconds stay milliseconds

    return totalMilliseconds;
  }

  @override
  int compareTo(TimeEntry other) {
    // Compare date
    final int dateComparison = other.date.compareTo(this.date);
    if (dateComparison != 0) {
      return dateComparison;
    }

    // Compare time
    final int timeComparison = other.timeInMillis.compareTo(this.timeInMillis);
    if (timeComparison != 0) {
      return timeComparison;
    }

    // Compare name
    return this.name.compareTo(other.name);
  }
}