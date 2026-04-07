class PeakHourSummary {
  const PeakHourSummary({required this.hour, required this.sessionsCount});

  factory PeakHourSummary.fromMap(Map<String, dynamic> data) {
    return PeakHourSummary(
      hour: data['hour']?.toString() ?? 'unknown',
      sessionsCount: _asInt(data['sessionsCount']) ?? 0,
    );
  }

  final String hour;
  final int sessionsCount;
}

class OwnedGymDailySummary {
  const OwnedGymDailySummary({
    required this.gymId,
    required this.gymName,
    required this.totalSessions,
    required this.activeClients,
    required this.newClients,
    required this.revenue,
    required this.peakHours,
  });

  factory OwnedGymDailySummary.fromMap(Map<String, dynamic> data) {
    final rawPeakHours = _asList(data['peakHours']);

    return OwnedGymDailySummary(
      gymId: data['gymId']?.toString() ?? '',
      gymName: data['gymName']?.toString() ?? data['gymId']?.toString() ?? '',
      totalSessions: _asInt(data['totalSessions']) ?? 0,
      activeClients: _asInt(data['activeClients']) ?? 0,
      newClients: _asInt(data['newClients']) ?? 0,
      revenue: _asNum(data['revenue']) ?? 0,
      peakHours: rawPeakHours
          .whereType<Map>()
          .map(
            (item) => PeakHourSummary.fromMap(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList(growable: false),
    );
  }

  final String gymId;
  final String gymName;
  final int totalSessions;
  final int activeClients;
  final int newClients;
  final num revenue;
  final List<PeakHourSummary> peakHours;
}

class OwnerAnalyticsDay {
  const OwnerAnalyticsDay({
    required this.date,
    required this.totalSessions,
    required this.activeClients,
    required this.newClients,
    required this.revenue,
    required this.gyms,
  });

  factory OwnerAnalyticsDay.fromMap(Map<String, dynamic> data) {
    final rawGyms = _asList(data['gyms']);
    final summary = _asMap(data['summary']);

    return OwnerAnalyticsDay(
      date: data['date']?.toString() ?? '',
      totalSessions: _asInt(summary['totalSessions']) ?? 0,
      activeClients: _asInt(summary['activeClients']) ?? 0,
      newClients: _asInt(summary['newClients']) ?? 0,
      revenue: _asNum(summary['revenue']) ?? 0,
      gyms: rawGyms
          .whereType<Map>()
          .map(
            (item) => OwnedGymDailySummary.fromMap(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList(growable: false),
    );
  }

  final String date;
  final int totalSessions;
  final int activeClients;
  final int newClients;
  final num revenue;
  final List<OwnedGymDailySummary> gyms;
}

class OwnerAnalyticsSeries {
  const OwnerAnalyticsSeries({required this.days});

  final List<OwnerAnalyticsDay> days;

  OwnerAnalyticsDay? get latest => days.isEmpty ? null : days.last;
}

class GymDailyStatsSnapshot {
  const GymDailyStatsSnapshot({
    required this.id,
    required this.date,
    required this.totalSessions,
    required this.activeClients,
    required this.newClients,
    required this.revenue,
  });

  factory GymDailyStatsSnapshot.fromMap(Map<String, dynamic> data) {
    return GymDailyStatsSnapshot(
      id: data['id']?.toString() ?? data['date']?.toString() ?? '',
      date: data['date']?.toString() ?? '',
      totalSessions: _asInt(data['totalSessions']) ?? 0,
      activeClients: _asInt(data['activeClients']) ?? 0,
      newClients: _asInt(data['newClients']) ?? 0,
      revenue: _asNum(data['revenue']) ?? 0,
    );
  }

  final String id;
  final String date;
  final int totalSessions;
  final int activeClients;
  final int newClients;
  final num revenue;
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, entryValue) => MapEntry(key.toString(), entryValue));
  }

  return const <String, dynamic>{};
}

List<dynamic> _asList(Object? value) {
  if (value is List<dynamic>) {
    return value;
  }

  if (value is List) {
    return value.toList(growable: false);
  }

  return const <dynamic>[];
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '');
}

num? _asNum(Object? value) {
  if (value is num) {
    return value;
  }

  return num.tryParse(value?.toString() ?? '');
}
