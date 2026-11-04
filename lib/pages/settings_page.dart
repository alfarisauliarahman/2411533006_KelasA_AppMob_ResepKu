import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:resepku/providers/theme_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: SwitchListTile(
        title: const Text('Mode gelap'),
        value: context.watch<ThemeProvider>().themeMode == ThemeMode.dark,
        onChanged: context.read<ThemeProvider>().setDarkMode,
      ),
    );
  }
}
