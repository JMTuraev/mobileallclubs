import 'package:flutter_test/flutter_test.dart';
import 'package:mobileallclubs/features/clients/domain/client_summary.dart';

void main() {
  group('GymClientSummary.matchesSearch', () {
    const client = GymClientSummary(
      id: 'client-1',
      firstName: 'Ali',
      lastName: 'Valiyev',
      phone: '+998 (90) 123-45-67',
      email: 'ali@example.com',
    );

    test('matches phone digits even when phone is formatted', () {
      expect(client.matchesSearch('90123'), isTrue);
      expect(client.matchesSearch('998901234567'), isTrue);
    });

    test('does not match by name or email anymore', () {
      expect(client.matchesSearch('Ali'), isFalse);
      expect(client.matchesSearch('ali@example.com'), isFalse);
    });

    test('returns true only for an empty query', () {
      expect(client.matchesSearch(''), isTrue);
      expect(client.matchesSearch('   '), isTrue);
      expect(client.matchesSearch('+()'), isFalse);
    });
  });
}
