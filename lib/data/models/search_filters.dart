class SearchFilters {
  final double? minRent;
  final double? maxRent;
  final String? location;
  final String? roomType;
  final double? lat;
  final double? lng;
  final double? radiusKm; // when set with lat/lng, filter by distance

  const SearchFilters({this.minRent, this.maxRent, this.location, this.roomType, this.lat, this.lng, this.radiusKm});

  SearchFilters copyWith({double? minRent, double? maxRent, String? location, String? roomType, double? lat, double? lng, double? radiusKm}) {
    return SearchFilters(
      minRent: minRent ?? this.minRent,
      maxRent: maxRent ?? this.maxRent,
      location: location ?? this.location,
      roomType: roomType ?? this.roomType,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      radiusKm: radiusKm ?? this.radiusKm,
    );
  }

  bool get isEmpty =>
      minRent == null &&
      maxRent == null &&
      (location == null || location!.isEmpty) &&
      (roomType == null || roomType!.isEmpty) &&
      (lat == null || lng == null || radiusKm == null);

  bool get hasGeo => lat != null && lng != null && radiusKm != null;
}
