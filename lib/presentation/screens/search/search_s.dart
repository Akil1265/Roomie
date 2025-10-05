import 'package:flutter/material.dart';
import 'package:roomie/data/models/search_filters.dart';
import 'package:roomie/presentation/controllers/search_controller.dart' as sc;
import 'package:roomie/presentation/screens/groups/available_group_detail_s.dart';
import 'package:roomie/presentation/screens/search/search_map_picker_s.dart';

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
          // Top Row: Messages-style search bar + one Filter button
          Container(
            color: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
            child: Row(
              children: [
                // Messages-like search bar
                Expanded(
                  flex: 1,
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: cs.outlineVariant,
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => _controller.setQuery(v),
                      onSubmitted: (_) async {
                        await _controller.commitQueryToHistory();
                        await _loadHistory();
                      },
                      decoration: InputDecoration(
                        hintText: 'Search here',
                        prefixIcon: Icon(
                          Icons.search,
                          color: cs.onSurfaceVariant,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: Colors.transparent,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Messages-style Filter button: filled pill with primary color
                ElevatedButton.icon(
                  onPressed: _openFilters,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  ),
                  icon: const Icon(Icons.tune, size: 20),
                  label: Text(
                    'Filters',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w600),
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
            child: Builder(
              builder: (_) {
                final filters = _controller.filters;
                final hasQuery = _searchCtrl.text.trim().isNotEmpty;
                final hasActiveFilters = (filters.minRent != null) ||
                    (filters.maxRent != null) ||
                    ((filters.roomType?.isNotEmpty ?? false)) ||
                    (filters.hasGeo);

                // Until user searches or applies a filter, show a friendly empty state
                if (!hasQuery && !hasActiveFilters) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search, size: 40, color: cs.onSurfaceVariant),
                        const SizedBox(height: 8),
                        Text(
                          'Find rooms',
                          style: theme.textTheme.titleMedium?.copyWith(color: cs.onSurface),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Search by room name, location, or rent',
                          style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  );
                }

                if (_controller.loading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (_controller.results.isEmpty) {
                  return Center(
                    child: Text('No rooms found', style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  itemBuilder: (_, i) {
                    final g = _controller.results[i];
                    return _GroupTile(group: g);
                  },
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemCount: _controller.results.length,
                );
              },
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
    double radiusKm = _controller.filters.radiusKm ?? 5.0;
    String? selectedRoomType = _controller.filters.roomType?.isNotEmpty == true
        ? _controller.filters.roomType
        : null; // null means "None"
    double sliderMin = 0;
    double sliderMax = 100000; // adjust as needed or derive from data
    RangeValues currentRange = RangeValues(
      (minRent ?? sliderMin).clamp(sliderMin, sliderMax),
      (maxRent ?? sliderMax).clamp(sliderMin, sliderMax),
    );
    final roomTypes = <String>['1BHK', '2BHK', '3BHK', 'PG', 'Studio'];

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
                            selectedRoomType = null;
                            radiusKm = 5.0;
                            currentRange = const RangeValues(0, 100000);
                          });
                          _controller.setFilters(const SearchFilters());
                        },
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Rent range (RangeSlider)
                  Text('Rent range', style: theme.textTheme.labelLarge?.copyWith(color: cs.onSurface)),
                  RangeSlider(
                    min: sliderMin,
                    max: sliderMax,
                    divisions: 100,
                    labels: RangeLabels(
                      currentRange.start.toStringAsFixed(0),
                      currentRange.end.toStringAsFixed(0),
                    ),
                    values: currentRange,
                    onChanged: (values) {
                      setModalState(() {
                        currentRange = values;
                        minRent = values.start == sliderMin ? null : values.start;
                        maxRent = values.end == sliderMax ? null : values.end;
                      });
                      _controller.setFilters(_controller.filters.copyWith(
                        minRent: minRent,
                        maxRent: maxRent,
                      ));
                    },
                  ),

                  const SizedBox(height: 12),

                  // Room types chips
                  Text('Room type', style: theme.textTheme.labelLarge?.copyWith(color: cs.onSurface)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('None'),
                        selected: selectedRoomType == null || selectedRoomType!.isEmpty,
                        onSelected: (sel) {
                          setModalState(() => selectedRoomType = null);
                          _controller.setFilters(_controller.filters.copyWith(roomType: ''));
                        },
                      ),
                      for (final rt in roomTypes)
                        ChoiceChip(
                          label: Text(rt),
                          selected: selectedRoomType == rt,
                          onSelected: (sel) {
                            setModalState(() => selectedRoomType = sel ? rt : null);
                            _controller.setFilters(_controller.filters.copyWith(roomType: sel ? rt : ''));
                          },
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Location & Radius - Single button to open map
                  Text('Location & Radius', style: theme.textTheme.labelLarge?.copyWith(color: cs.onSurface)),
                  const SizedBox(height: 8),
                  
                  // Selected location display
                  if (_controller.filters.hasGeo)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: cs.primary.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, color: cs.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Location set',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Radius: ${_controller.filters.radiusKm?.toStringAsFixed(1)} km',
                                  style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.clear),
                            color: cs.error,
                            iconSize: 20,
                            onPressed: () {
                              _controller.setFilters(_controller.filters.copyWith(
                                lat: null,
                                lng: null,
                                radiusKm: null,
                              ));
                              setModalState(() {});
                            },
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_off, color: cs.onSurfaceVariant, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No location filter set',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 12),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.map),
                      label: const Text('Select Location on Map'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () async {
                        await _pickLocationOnMap(setModalState, radiusKm);
                      },
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

  Future<void> _pickLocationOnMap(StateSetter setModalState, double radiusKm) async {
    final result = await Navigator.push<Map<String, double>>(
      context,
      MaterialPageRoute(
        builder: (context) => SearchMapPickerScreen(
          initialLat: _controller.filters.lat,
          initialLng: _controller.filters.lng,
          radiusKm: radiusKm,
        ),
      ),
    );
    
    if (result != null && result['lat'] != null && result['lng'] != null) {
      final selectedRadius = result['radius'] ?? radiusKm;
      _controller.setGeo(result['lat']!, result['lng']!, selectedRadius);
      
      // Force full widget rebuild to show updated location
      setState(() {});
      setModalState(() {}); // Update modal state
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location set! Radius: ${selectedRadius.toStringAsFixed(1)} km'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      // User cancelled selection; do nothing (keep existing filters)
    }
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
