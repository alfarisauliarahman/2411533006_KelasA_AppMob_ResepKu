import 'package:resepku/providers/favorite_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:resepku/providers/settings_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus semua favorit?'),
        content: const Text('Semua favorit beserta catatannya akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (!context.mounted || confirmed != true) return;
    await context.read<FavoriteProvider>().clear();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Semua favorit telah dihapus.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('Mode gelap'),
            value: settings.isDark,
            onChanged: settings.setDark,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.grid_view),
            title: const Text('Tampilan grid'),
            subtitle: const Text('Daftar resep ditampilkan dalam dua kolom'),
            value: settings.isGrid,
            onChanged: settings.setGrid,
          ),
          const Divider(),
          Consumer<FavoriteProvider>(
            builder: (context, favorite, child) => ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Hapus semua favorit'),
              subtitle: Text('${favorite.count} favorit tersimpan'),
              enabled: favorite.count > 0,
              onTap: () => _confirmClear(context),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Pengaturan tersimpan di HP'),
            subtitle: Text('Pilihan tetap ada walaupun aplikasi ditutup.'),
          ),
        ],
      ),
    );
  }
}
