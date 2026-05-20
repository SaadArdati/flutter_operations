/// Internal storage for the optional success message attached during a
/// single fetch / listen call. The mixin creates one cell per call and
/// installs it in a Zone; user code calls `attachMessage` to write to it.
class MessageCell {
  String? value;
}

/// Zone key used to look up the active [MessageCell] from any code running
/// inside a fetch or stream body. Library-private: not exported.
const Object messageKey = Object();
