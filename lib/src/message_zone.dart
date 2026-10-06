/// Internal storage for the optional success message attached during a
/// single run / listen call. The engine creates one cell per call and
/// installs it in a Zone; user code calls `attachMessage` to write to it.
class MessageCell {
  /// Creates message storage scoped to [owner].
  MessageCell({this.owner});

  /// Identity of the operation allowed to attach messages.
  final Object? owner;

  /// Pending message, consumed by the owning operation.
  String? value;
}

/// Zone key used to look up the active [MessageCell] from any code running
/// inside a fetch or stream body. Library-private: not exported.
///
/// Must be a lazily-initialized `final`, never `const`: Dart canonicalizes
/// const instances, so `const Object()` would be identical to every other
/// `const Object()` in the program, making this key forgeable and prone to
/// colliding with unrelated zone values. A fresh `Object()` guarantees a
/// unique, unforgeable identity.
final Object messageKey = Object();
