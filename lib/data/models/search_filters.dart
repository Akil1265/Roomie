class SearchFilters {
  final double? minRent;
  final double? maxRent;
  final String? location;
  final String? roomType;

  const SearchFilters({this.minRent, this.maxRent, this.location, this.roomType});

  SearchFilters copyWith({double? minRent, double? maxRent, String? location, String? roomType}) {
    return SearchFilters(
      minRent: minRent ?? this.minRent,
      maxRent: maxRent ?? this.maxRent,
      location: location ?? this.location,
      roomType: roomType ?? this.roomType,
    );
  }

  bool get isEmpty => minRent == null && maxRent == null && (location == null || location!.isEmpty) && (roomType == null || roomType!.isEmpty);
}
