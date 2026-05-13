import 'package:flutter_test/flutter_test.dart';
import 'package:mobileallclubs/features/clients/domain/client_detail_models.dart';
import 'package:mobileallclubs/features/clients/domain/client_summary.dart';
import 'package:mobileallclubs/features/finance/domain/finance_page_snapshot.dart';
import 'package:mobileallclubs/features/finance/domain/gym_transaction_summary.dart';

void main() {
  group('buildFinancePageSnapshot', () {
    test(
      'matches web overview debt logic and skips replaced subscriptions',
      () {
        final snapshot = buildFinancePageSnapshot(
          transactions: [
            GymTransactionSummary(
              id: 'tx_cash',
              clientId: 'client_1',
              amount: 100,
              paymentMethod: 'cash',
              createdAt: DateTime(2026, 4, 14, 10),
            ),
            GymTransactionSummary(
              id: 'tx_debt',
              clientId: 'client_1',
              amount: 50,
              paymentMethod: 'debt',
              createdAt: DateTime(2026, 4, 14, 11),
            ),
            GymTransactionSummary(
              id: 'tx_replaced',
              clientId: 'client_1',
              amount: 200,
              paymentMethod: 'cash',
              subscriptionStatus: 'replaced',
              createdAt: DateTime(2026, 4, 14, 12),
            ),
          ],
          subscriptions: const [],
          clientsById: const {
            'client_1': GymClientSummary(
              id: 'client_1',
              firstName: 'Ali',
              lastName: 'Valiyev',
            ),
          },
          from: DateTime(2026, 4, 14),
          to: DateTime(2026, 4, 14),
        );

        expect(snapshot.dateFilteredTransactions, hasLength(2));
        expect(snapshot.overviews, hasLength(1));
        expect(snapshot.overviews.single.clientName, 'Ali Valiyev');
        expect(snapshot.overviews.single.totalRevenue, 150);
        expect(snapshot.overviews.single.debt, 50);
        expect(snapshot.totalRevenue, 150);
        expect(snapshot.totalDebt, 50);
        expect(snapshot.filteredTotal, 150);
      },
    );

    test(
      'matches web transaction table filters for package and cancelled rows',
      () {
        final snapshot = buildFinancePageSnapshot(
          transactions: [
            GymTransactionSummary(
              id: 'tx_active_package',
              clientId: 'client_1',
              subscriptionId: 'sub_active',
              type: 'payment',
              category: 'package',
              amount: 100,
              createdAt: DateTime(2026, 4, 14, 9),
            ),
            GymTransactionSummary(
              id: 'tx_expired_package',
              clientId: 'client_1',
              subscriptionId: 'sub_expired',
              type: 'payment',
              category: 'package',
              amount: 200,
              createdAt: DateTime(2026, 4, 14, 10),
            ),
            GymTransactionSummary(
              id: 'tx_missing_package',
              clientId: 'client_1',
              subscriptionId: 'sub_missing',
              type: 'payment',
              category: 'package',
              amount: 300,
              createdAt: DateTime(2026, 4, 14, 11),
            ),
            GymTransactionSummary(
              id: 'tx_cancelled_bar',
              clientId: 'client_1',
              type: 'bar',
              status: 'cancelled',
              amount: 25,
              createdAt: DateTime(2026, 4, 14, 12),
            ),
            GymTransactionSummary(
              id: 'tx_service',
              clientId: 'client_1',
              type: 'service',
              amount: 40,
              createdAt: DateTime(2026, 4, 14, 13),
            ),
            GymTransactionSummary(
              id: 'tx_other_client',
              clientId: 'client_2',
              type: 'bar',
              amount: 60,
              createdAt: DateTime(2026, 4, 14, 14),
            ),
          ],
          subscriptions: const [
            ClientSubscriptionSummary(
              id: 'sub_active',
              clientId: 'client_1',
              clientName: 'Ali Valiyev',
              status: 'active',
            ),
            ClientSubscriptionSummary(
              id: 'sub_expired',
              clientId: 'client_1',
              clientName: 'Ali Valiyev',
              status: 'expired',
            ),
          ],
          clientsById: const {
            'client_1': GymClientSummary(
              id: 'client_1',
              firstName: 'Ali',
              lastName: 'Valiyev',
            ),
            'client_2': GymClientSummary(
              id: 'client_2',
              firstName: 'Sara',
              lastName: 'Karimova',
            ),
          },
          from: null,
          to: null,
          selectedClientId: 'client_1',
        );

        expect(
          snapshot.transactions.map((transaction) => transaction.id).toList(),
          ['tx_active_package', 'tx_service'],
        );
        expect(snapshot.selectedClientId, 'client_1');
        expect(snapshot.selectedClientName, 'Ali Valiyev');
        expect(snapshot.filteredTotal, 140);
        expect(snapshot.dateFilteredTransactions, hasLength(6));
      },
    );
  });
}
