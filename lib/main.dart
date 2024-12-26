import 'package:flutter/material.dart';
import 'package:lichtschranke/StopwatchScreen.dart';
import 'package:provider/provider.dart';
import 'package:lichtschranke/AppState.dart';


void main() {
  runApp(ChangeNotifierProvider(
    create: (context) => AppState(),
    child: MyApp(),
  ));
}

ThemeData appTheme = ThemeData(
  primarySwatch: Colors.orange,
  colorScheme: ColorScheme.light(
    primary: Colors.orange
  ),
  
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: Colors.orange,
  ),
  inputDecorationTheme: InputDecorationTheme(
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.orange, width: 1.5),
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.orange, width: 1.0),
    ),
    errorBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.red, width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.red, width: 2),
    ),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: Colors.orange,
    foregroundColor: Colors.white,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.all<Color>(Colors.orange),
      foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: ButtonStyle(
      foregroundColor: WidgetStateProperty.all<Color>(Colors.orange),
    ),
  ),
  datePickerTheme: DatePickerThemeData(
    backgroundColor: Colors.white,
    rangePickerBackgroundColor: Colors.white,
    rangePickerHeaderBackgroundColor: Colors.orange,
    rangePickerHeaderForegroundColor: Colors.white,
    rangeSelectionBackgroundColor: Colors.orange[100],
    rangePickerShadowColor: Colors.orange,
    dividerColor: Colors.red
  ),
  textTheme: TextTheme(
    bodyLarge: TextStyle(color: Colors.black),
    bodyMedium: TextStyle(color: Colors.black87),
  ),
  textSelectionTheme: TextSelectionThemeData(
    cursorColor: Colors.orange,
    selectionColor: Colors.orange[300],
    selectionHandleColor: Colors.orange,
  ),
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lichtschranke',
      theme: appTheme,
      home: StopwatchScreen(),
    );
  }
}