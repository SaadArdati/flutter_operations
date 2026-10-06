/// Type-safe async & stream state management for Flutter powered by sealed
/// classes, exhaustive pattern matching, and cached data. No more
/// juggling `isLoading`, `error`, and `data` fields.
///
/// Execution and lifecycle adapters:
/// * [Operation]: Shared state publication and reactive hooks.
/// * [AsyncOperation]: Host-owned execution and reactive integration hooks.
/// * [AsyncOperationMixin]: One operation on an external host.
/// * [AsyncOperationStateMixin]: Widget-owned Future work.
/// * [StreamOperation]: Host-owned subscriptions and awaitable cleanup.
/// * [StreamOperationMixin]: One subscription on an external host.
/// * [StreamOperationStateMixin]: Widget-owned continuous streams.
///
/// All expose [OperationState] snapshots: idle, loading, success, and error.
library;

export 'src/async_operation.dart';
export 'src/async_operation_mixin.dart';
export 'src/operation.dart';
export 'src/operation_state.dart';
export 'src/stream_operation.dart';
export 'src/stream_operation_mixin.dart';
