import 'package:flutter/material.dart';

import 'screens/room_management_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RentalRoomApp());
}

class RentalRoomApp extends StatelessWidget {
  const RentalRoomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rental Room Management',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
        ),
      ),
      home: const RoomManagementScreen(),
    );
  }
}