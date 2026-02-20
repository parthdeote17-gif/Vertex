import 'package:flutter/material.dart';
import '../users/users_list_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ✨ Scaffold aur AppBar yahan se hata diya
    // Kyunki hum UsersListScreen mein custom design use kar rahe hain
    return const UsersListScreen();
  }
}