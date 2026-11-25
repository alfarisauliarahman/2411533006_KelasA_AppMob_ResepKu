import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FavoriteSort { newest, name }

/// Pengaturan aplikasi yang disimpan di HP dengan SharedPreferencesAsync.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  static const keyGrid = 'is_grid';
  static const keyDark = 'is_dark';
  static const keyFavoriteSort = 'favorite_sort';
  FavoriteSort _favoriteSort = FavoriteSort.newest;
  FavoriteSort get favoriteSort => _favoriteSort;

  Future<void> setFavoriteSort(FavoriteSort value) async {
    _favoriteSort = value;
    notifyListeners();
    await _prefs.setString(keyFavoriteSort, value.name);
  }

  final SharedPreferencesAsync _prefs;

  // Nilai saat ini disimpan di field agar build() dapat membacanya tanpa await
  bool _isGrid = false;
  bool _isDark = false;

  bool get isGrid => _isGrid;
  bool get isDark => _isDark;
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  /// Dipanggil sekali di main, sebelum runApp.
  Future<void> load() async {
    // null berarti key belum pernah disimpan (pembukaan pertama)
    _favoriteSort =
        FavoriteSort.values.asNameMap()[await _prefs.getString(
          keyFavoriteSort,
        )] ??
        FavoriteSort.newest;
    _isGrid = await _prefs.getBool(keyGrid) ?? false;
    _isDark = await _prefs.getBool(keyDark) ?? false;
    notifyListeners();
  }

  Future<void> setGrid(bool value) async {
    _isGrid = value;
    notifyListeners(); // tampilan berubah lebih dulu
    await _prefs.setBool(keyGrid, value); // lalu disimpan
  }

  Future<void> setDark(bool value) async {
    _isDark = value;
    notifyListeners();
    await _prefs.setBool(keyDark, value);
  }
}
