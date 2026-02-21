import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static final ThemeProvider _instance = ThemeProvider._internal();
  static ThemeProvider get instance => _instance;

  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  // main.dart içerisinde temanın Material tarafında algılanmasını sağlar
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  // Constructor'ı boş bıraktık çünkü başlatmayı artık main.dart'tan yapacağız
  ThemeProvider._internal();

  // 🔥 YENİ: main.dart içinden çağıracağımız ve uygulamanın açılmadan önce 
  // karanlık modu bilmesini sağlayan fonksiyon
  Future<void> initializeTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    notifyListeners();
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    _saveTheme(_isDarkMode);
    notifyListeners();
  }

  void setTheme(bool isDark) {
    if (_isDarkMode != isDark) {
      _isDarkMode = isDark;
      _saveTheme(isDark);
      notifyListeners();
    }
  }

  Future<void> _saveTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
  }
}