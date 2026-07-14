import 'package:flutter_operations/src/message_zone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('messageKey is a unique object, not a canonicalized const', () {
    // Dart canonicalizes const instances, so every `const Object()` in the
    // program is the same instance — a forgeable, collidable zone key.
    // messageKey must be a fresh `final Object()`, distinct from any other.
    expect(identical(messageKey, const Object()), isFalse);
  });
}
