class PersonalInfo {
  final String flightType;
  final String flightClass;
  final String accommodationType;

  const PersonalInfo({
    this.flightType = 'round_trip',
    this.flightClass = 'economy',
    this.accommodationType = 'hotel',
  });

  factory PersonalInfo.fromMap(Map<String, dynamic> map) => PersonalInfo(
        flightType: map['flight_type'] as String? ?? 'round_trip',
        flightClass: map['flight_class'] as String? ?? 'economy',
        accommodationType:
            map['accommodation_type'] as String? ?? 'hotel',
      );

  Map<String, dynamic> toMap() => {
        'flight_type': flightType,
        'flight_class': flightClass,
        'accommodation_type': accommodationType,
      };
}
