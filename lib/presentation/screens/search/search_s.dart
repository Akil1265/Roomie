import 'package:flutter/material.dart';
import 'package:roomie/data/models/search_filters.dart';
import 'package:roomie/presentation/controllers/search_controller.dart' as sc;
import 'package:roomie/presentation/screens/groups/available_group_detail_s.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final sc.GroupsSearchController _controller;
  final TextEditingController _searchCtrl = TextEditingController();
  List<String> _history = const [];

  @override
  void initState() {
    super.initState();
  _controller = sc.GroupsSearchController();
    _controller.addListener(_onChanged);
    _controller.init();
    _loadHistory();
  }

  void _onChanged() => setState(() {});

  Future<void> _loadHistory() async {
    final h = await _controller.getHistory();
    if (mounted) setState(() => _history = h);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 1,
        title: Text(
          'Search',
          style: theme.textTheme.headlineSmall?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.bold,
              ) ??
              TextStyle(
                color: cs.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => _controller.setQuery(v),
                    onSubmitted: (_) async {
                      await _controller.commitQueryToHistory();
                      await _loadHistory();
                    },
                    decoration: InputDecoration(
                      hintText: 'Search groups by name or location...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: cs.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cs.outlineVariant),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _openFilters,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Icon(Icons.tune, color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),

          // History row (with clear all)
          if (_history.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent searches', style: theme.textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
                  TextButton(
                    onPressed: () async {
                      await _controller.clearHistory();
                      await _loadHistory();
                    },
                    child: const Text('Clear all'),
                  ),
                ],
              ),
            ),

          if (_history.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final item = _history[index];
                  return InputChip(
                    label: Text(item),
                    onPressed: () {
                      _searchCtrl.text = item;
                      _controller.setQuery(item);
                    },
                    onDeleted: () async {
                      await _controller.removeHistoryAt(index);
                      await _loadHistory();
                    },
                  );
                },
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemCount: _history.length,
              ),
            ),

          // Results
          Expanded(
            child: _controller.loading
                ? const Center(child: CircularProgressIndicator())
                : _controller.results.isEmpty
                    ? Center(
                        child: Text('No results', style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        itemBuilder: (_, i) {
                          final g = _controller.results[i];
                          return _GroupTile(group: g);
                        },
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemCount: _controller.results.length,
                      ),
          ),
        ],
      ),
    );
  }

  void _openFilters() async {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    double? minRent = _controller.filters.minRent;
    double? maxRent = _controller.filters.maxRent;
    final roomTypeCtrl = TextEditingController(text: _controller.filters.roomType ?? '');
    final locationCtrl = TextEditingController(text: _controller.filters.location ?? '');
    final minRentCtrl = TextEditingController(text: minRent?.toStringAsFixed(0) ?? '');
    final maxRentCtrl = TextEditingController(text: maxRent?.toStringAsFixed(0) ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: StatefulBuilder(builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Filters', style: theme.textTheme.titleMedium?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w600)),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            minRent = null;
                            maxRent = null;
                            roomTypeCtrl.text = '';
                            locationCtrl.text = '';
                            minRentCtrl.text = '';
                            maxRentCtrl.text = '';
                          });
                        },
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Rent range
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Min rent'),
                          controller: minRentCtrl,
                          onChanged: (v) => setModalState(() => minRent = double.tryParse(v)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Max rent'),
                          controller: maxRentCtrl,
                          onChanged: (v) => setModalState(() => maxRent = double.tryParse(v)),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(labelText: 'Location'),
                    controller: locationCtrl,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(labelText: 'Room type (e.g., 1BHK, 2BHK, PG)'),
                    controller: roomTypeCtrl,
                  ),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check),
                      onPressed: () {
                        _controller.setFilters(SearchFilters(
                          minRent: minRent,
                          maxRent: maxRent,
                          location: locationCtrl.text.trim(),
                          roomType: roomTypeCtrl.text.trim(),
                        ));
                        Navigator.pop(context);
                      },
                      label: const Text('Apply filters'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          }),
        );
      },
    );
  }
}

class _GroupTile extends StatelessWidget {
  final Map<String, dynamic> group;
  const _GroupTile({required this.group});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = group['name']?.toString() ?? 'Group';
    final location = group['location']?.toString() ?? '';
    final roomType = group['roomType']?.toString();
    final rent = group['rentAmount'] is num ? (group['rentAmount'] as num).toDouble() : null;
    final currency = group['rentCurrency']?.toString() ?? '₹';

    return Card(
      color: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.primary,
          child: Icon(Icons.home_work_outlined, color: cs.onPrimary),
        ),
        title: Text(name, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.onSurface)),
        subtitle: Text(
          [if (location.isNotEmpty) location, if (roomType != null && roomType.isNotEmpty) roomType].join(' • '),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        trailing: rent == null
            ? null
            : Text('$currency${rent.toStringAsFixed(0)}', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w600)),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AvailableGroupDetailScreen(group: group),
            ),
          );
        },
      ),
    );
  }
}
