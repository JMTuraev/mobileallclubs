import 'package:cloud_firestore/cloud_firestore.dart';

class ClientInsightAlert {
  const ClientInsightAlert({
    required this.type,
    required this.title,
    required this.description,
    required this.severity,
  });

  factory ClientInsightAlert.fromMap(Map<String, dynamic> data) {
    return ClientInsightAlert(
      type: _asString(data['type']) ?? 'smart',
      title: _asString(data['title']) ?? 'Alert',
      description: _asString(data['description']) ?? 'No description',
      severity: _asString(data['severity']) ?? 'low',
    );
  }

  final String type;
  final String title;
  final String description;
  final String severity;
}

class ClientInsightsSummary {
  const ClientInsightsSummary({
    required this.id,
    required this.clientId,
    required this.attendanceDirection,
    required this.attendanceDelta,
    required this.last30Visits,
    required this.previous30Visits,
    required this.visitsPerWeek,
    required this.inactiveDays,
    required this.churnRisk,
    required this.lifetimeValue,
    required this.alerts,
    this.lastVisitAt,
  });

  factory ClientInsightsSummary.fromMap(String id, Map<String, dynamic> data) {
    final attendanceTrend = _asMap(data['attendanceTrend']);
    final visitFrequency = _asMap(data['visitFrequency']);
    final rawAlerts = _asList(data['alerts']);

    return ClientInsightsSummary(
      id: id,
      clientId: _asString(data['clientId']) ?? id,
      attendanceDirection: _asString(attendanceTrend['direction']) ?? 'flat',
      attendanceDelta: _asInt(attendanceTrend['delta']) ?? 0,
      last30Visits: _asInt(attendanceTrend['last30']) ?? 0,
      previous30Visits: _asInt(attendanceTrend['previous30']) ?? 0,
      visitsPerWeek: _asNum(visitFrequency['visitsPerWeek']) ?? 0,
      inactiveDays: _asInt(data['inactiveDays']),
      churnRisk: _asString(data['churnRisk']) ?? 'low',
      lifetimeValue: _asNum(data['lifetimeValue']) ?? 0,
      lastVisitAt: _asDateTime(data['lastVisitAt']),
      alerts: rawAlerts
          .whereType<Map>()
          .map(
            (item) => ClientInsightAlert.fromMap(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList(growable: false),
    );
  }

  final String id;
  final String clientId;
  final String attendanceDirection;
  final int attendanceDelta;
  final int last30Visits;
  final int previous30Visits;
  final num visitsPerWeek;
  final int? inactiveDays;
  final DateTime? lastVisitAt;
  final String churnRisk;
  final num lifetimeValue;
  final List<ClientInsightAlert> alerts;
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

String? _asString(Object? value) {
  final text = value?.toString();
  if (text == null || text.trim().isEmpty) {
    return null;
  }

  return text.trim();
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

DateTime? _asDateTime(Object? value) {
  if (value is Timestamp) {
    return value.toDate();
  }

  if (value is DateTime) {
    return value;
  }

  if (value is String) {
    return DateTime.tryParse(value);
  }

  if (value is Map) {
    final normalized = value.map(
      (key, entryValue) => MapEntry(key.toString(), entryValue),
    );
    final seconds = _asInt(normalized['_seconds'] ?? normalized['seconds']);
    final nanoseconds =
        _asInt(normalized['_nanoseconds'] ?? normalized['nanoseconds']) ?? 0;

    if (seconds != null) {
      final milliseconds = (seconds * 1000) + (nanoseconds ~/ 1000000);
      return DateTime.fromMillisecondsSinceEpoch(
        milliseconds,
        isUtc: true,
      ).toLocal();
    }
  }

  return null;
}
