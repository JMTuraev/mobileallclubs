import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_clients.dart';
import '../../../models/auth_bootstrap_models.dart';
import '../../bootstrap/application/bootstrap_controller.dart';
import '../../clients/domain/client_detail_models.dart';
import '../domain/gym_transaction_summary.dart';

final currentGymTransactionsProvider =
    StreamProvider<List<GymTransactionSummary>>((ref) {
      final session = ref.watch(bootstrapControllerProvider).session;
      final gymId = session?.gymId;

      if (!_canReadTransactions(session)) {
        return Stream.value(const <GymTransactionSummary>[]);
      }

      final firestore = ref.watch(firebaseFirestoreProvider);
      final subscriptionsQuery = firestore
          .collection('gyms')
          .doc(gymId)
          .collection('subscriptions');
      final transactionsQuery = firestore
          .collection('gyms')
          .doc(gymId)
          .collection('transactions')
          .orderBy('createdAt', descending: true);
      final financeTransactionsQuery = firestore
          .collection('gyms')
          .doc(gymId)
          .collection('financeTransactions')
          .orderBy('createdAt', descending: true);

      late StreamController<List<GymTransactionSummary>> controller;
      StreamSubscription? subscriptionsSubscription;
      StreamSubscription? transactionsSubscription;
      StreamSubscription? financeTransactionsSubscription;

      var subscriptions = const <ClientSubscriptionSummary>[];
      var transactions = const <GymTransactionSummary>[];
      var financeTransactions = const <GymTransactionSummary>[];

      List<GymTransactionSummary> mergeTransactions() {
        final subscriptionsById = <String, ClientSubscriptionSummary>{};
        for (final subscription in subscriptions) {
          subscriptionsById[subscription.id] = subscription;
        }

        final merged = [...transactions, ...financeTransactions]
          ..sort((left, right) {
            final leftDate =
                left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final rightDate =
                right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return rightDate.compareTo(leftDate);
          });

        return merged
            .map((transaction) {
              if (transaction.subscriptionId == null ||
                  transaction.subscriptionStatus != null) {
                return transaction;
              }

              final subscription =
                  subscriptionsById[transaction.subscriptionId!];
              if (subscription == null) {
                return transaction;
              }

              return transaction.copyWith(
                subscriptionStatus: subscription.status,
              );
            })
            .toList(growable: false);
      }

      void emitMerged() {
        if (!controller.isClosed) {
          controller.add(mergeTransactions());
        }
      }

      controller = StreamController<List<GymTransactionSummary>>(
        onListen: () {
          subscriptionsSubscription = subscriptionsQuery.snapshots().listen((
            snapshot,
          ) {
            subscriptions = snapshot.docs
                .map(ClientSubscriptionSummary.fromSnapshot)
                .toList(growable: false);
            emitMerged();
          }, onError: controller.addError);
          transactionsSubscription = transactionsQuery.snapshots().listen((
            snapshot,
          ) {
            transactions = snapshot.docs
                .map(GymTransactionSummary.fromSnapshot)
                .toList(growable: false);
            emitMerged();
          }, onError: controller.addError);
          financeTransactionsSubscription = financeTransactionsQuery
              .snapshots()
              .listen((snapshot) {
                financeTransactions = snapshot.docs
                    .map(GymTransactionSummary.fromSnapshot)
                    .toList(growable: false);
                emitMerged();
              }, onError: controller.addError);
        },
        onCancel: () async {
          await subscriptionsSubscription?.cancel();
          await transactionsSubscription?.cancel();
          await financeTransactionsSubscription?.cancel();
        },
      );

      ref.onDispose(() async {
        await controller.close();
      });

      return controller.stream;
    });

final currentGymClientTransactionsProvider =
    Provider.family<AsyncValue<List<GymTransactionSummary>>, String>(((
      ref,
      clientId,
    ) {
      if (!_canReadClientTransactions(
        ref.watch(bootstrapControllerProvider).session,
        clientId,
      )) {
        return const AsyncValue.data(<GymTransactionSummary>[]);
      }

      return ref
          .watch(currentGymTransactionsProvider)
          .whenData(
            (transactions) => transactions
                .where((transaction) => transaction.clientId == clientId)
                .toList(growable: false),
          );
    }));

bool _canReadTransactions(ResolvedAuthSession? session) {
  final gymId = session?.gymId;
  final role = session?.role ?? AllClubsRole.unknown;

  return gymId != null &&
      gymId.isNotEmpty &&
      (role == AllClubsRole.owner || role == AllClubsRole.staff);
}

bool _canReadClientTransactions(ResolvedAuthSession? session, String clientId) {
  return clientId.trim().isNotEmpty && _canReadTransactions(session);
}
