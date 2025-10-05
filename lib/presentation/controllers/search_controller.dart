import 'package:flutter/foundation.dart';
import 'package:roomie/data/datasources/groups_service.dart';
import 'package:roomie/data/datasources/search_history_service.dart';
import 'package:roomie/data/models/search_filters.dart';

class GroupsSearchController extends ChangeNotifier {
  final GroupsService _groupsService;
  final SearchHistoryService _historyService;

  String _query = '';
  SearchFilters _filters = const SearchFilters();
  bool _loading = false;
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _results = [];

  GroupsSearchController({GroupsService? groupsService, SearchHistoryService? historyService})
      : _groupsService = groupsService ?? GroupsService(),
        _historyService = historyService ?? SearchHistoryService();

  String get query => _query;
  SearchFilters get filters => _filters;
  bool get loading => _loading;
  List<Map<String, dynamic>> get results => _results;

  Future<void> init() async {
    await refreshBase();
  }

  Future<void> refreshBase() async {
    _loading = true;
    notifyListeners();
    try {
      _all = await _groupsService.getAllGroups();
      _apply();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setQuery(String q) {
    _query = q;
    _apply();
    notifyListeners();
  }

  void setFilters(SearchFilters f) {
    _filters = f;
    _apply();
    notifyListeners();
  }

  Future<void> commitQueryToHistory() async {
    if (_query.trim().isEmpty) return;
    await _historyService.addQuery(_query.trim());
  }

  Future<List<String>> getHistory() => _historyService.getHistory();
  Future<void> removeHistoryAt(int index) => _historyService.removeAt(index);
  Future<void> clearHistory() => _historyService.clear();

  void _apply() {
    final q = _query.trim().toLowerCase();
    _results = _all.where((g) {
      // Apply query on group name and location
      final name = (g['name']?.toString() ?? '').toLowerCase();
      final location = (g['location']?.toString() ?? '').toLowerCase();
      final matchesQuery = q.isEmpty || name.contains(q) || location.contains(q);

      // Filters: rent range
      final rentAmount = (g['rentAmount'] is num) ? (g['rentAmount'] as num).toDouble() : null;
      final rentOk = (_filters.minRent == null || (rentAmount != null && rentAmount >= _filters.minRent!)) &&
          (_filters.maxRent == null || (rentAmount != null && rentAmount <= _filters.maxRent!));

      // Filters: location exact/substring
      final locOk = _filters.location == null || _filters.location!.isEmpty ||
          location.contains(_filters.location!.toLowerCase());

      // Filters: room type exact match
      final roomType = (g['roomType']?.toString() ?? '').toLowerCase();
      final roomOk = _filters.roomType == null || _filters.roomType!.isEmpty ||
          roomType == _filters.roomType!.toLowerCase();

      return matchesQuery && rentOk && locOk && roomOk;
    }).toList();
  }
}
