import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryService {
  static const _key = 'search_history_v1';
  static const _maxItems = 10;

  Future<List<String>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? <String>[];
  }

  Future<void> addQuery(String query) async {
    if (query.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_key) ?? <String>[];
    // Move to top if exists, keep unique, cap size
    history.removeWhere((q) => q.toLowerCase() == query.toLowerCase());
    history.insert(0, query.trim());
    if (history.length > _maxItems) {
      history.removeRange(_maxItems, history.length);
    }
    await prefs.setStringList(_key, history);
  }

  Future<void> removeAt(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_key) ?? <String>[];
    if (index < 0 || index >= history.length) return;
    history.removeAt(index);
    await prefs.setStringList(_key, history);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
