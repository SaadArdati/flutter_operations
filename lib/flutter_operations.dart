/// Type-safe async & stream state management for Flutter powered by **sealed
/// classes**, **exhaustive pattern matching**, and **cached data**. No more
/// juggling `isLoading`, `error`, and `data` fields.
///
/// Exported mixins
/// * [AsyncOperationMixin]: For one-shot operations.
/// * [StreamOperationMixin]: For continuous streams.
///
/// Both mixins expose the same runtime states via [OperationState]:
/// `IdleOperation`, `LoadingOperation`, `SuccessOperation`
/// (`ValueSuccessOperation` / `VoidSuccessOperation`), and `ErrorOperation`.
library;

export 'src/async_operation_mixin.dart';
export 'src/operation_state.dart';
export 'src/stream_operation_mixin.dart';
