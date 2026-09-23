import 'package:flutter_test/flutter_test.dart';
import 'package:omi/services/account_cutover/account_cutover_policy.dart';

void main() {
  group('AccountCutoverPolicy', () {
    test('preserves authenticated owner for the upstream Omi build', () {
      expect(
        AccountCutoverPolicy.ownerFor('owner-1', personalFirebaseEnabled: false),
        'owner-1',
      );
    });

    test('disables upstream cutover for a private Brainbase build', () {
      expect(
        AccountCutoverPolicy.ownerFor('owner-1', personalFirebaseEnabled: true),
        isNull,
      );
    });

    test('keeps absent and empty owners unbound', () {
      expect(AccountCutoverPolicy.ownerFor(null, personalFirebaseEnabled: false), isNull);
      expect(AccountCutoverPolicy.ownerFor('', personalFirebaseEnabled: false), isNull);
    });
  });
}
