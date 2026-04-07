import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_clients.dart';
import '../../../models/auth_bootstrap_models.dart';
import '../../bootstrap/application/bootstrap_controller.dart';
import '../domain/owner_analytics_models.dart';

final ownerAnalytics30DayProvider = FutureProvider<OwnerAnalyticsSeries?>((
  ref,
) async {
  final session = ref.watch(bootstrapControllerProvider).session;
  if (session == null || session.role != AllClubsRole.owner) {
    return null;
  }

  final functions = ref.watch(firebaseFunctionsProvider);
  final today = DateTime.now();
  final dates = <String>[];

  for (var i = 29; i >= 0; i -= 1) {
    final day = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: i));
    dates.add(_dateKey(day));
  }

  final results = await Future.wait(
    dates.map(
      (date) async =>
          functions.httpsCallable('getOwnerAnalytics').call({'date': date}),
    ),
  );

  return OwnerAnalyticsSeries(
    days: results
        .map((result) {
          final data = result.data;
          if (data is! Map) {
            throw Exception(
              'Unexpected getOwnerAnalytics response: ${data.runtimeType}',
            );
          }

          return OwnerAnalyticsDay.fromMap(
            data.map((key, value) => MapEntry(key.toString(), value)),
          );
        })
        .toList(growable: false),
  );
});

final currentGymDailyStatsProvider = FutureProvider<GymDailyStatsSnapshot?>((
  ref,
) async {
  final session = ref.watch(bootstrapControllerProvider).session;
  if (session == null) {
    return null;
  }

  final gymId = session.gymId;
  final role = session.role;
  if (gymId == null ||
      gymId.isEmpty ||
      (role != AllClubsRole.owner && role != AllClubsRole.staff)) {
    return null;
  }

  final functions = ref.watch(firebaseFunctionsProvider);
  final today = _dateKey(DateTime.now());
  final result = await functions
      .httpsCallable('getGymDailyStats')
      .call({'date': today});
  final data = result.data;

  if (data is! Map) {
    throw Exception(
      'Unexpected getGymDailyStats response: ${data.runtimeType}',
    );
  }

  return GymDailyStatsSnapshot.fromMap(
    data.map((key, value) => MapEntry(key.toString(), value)),
  );
});

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
