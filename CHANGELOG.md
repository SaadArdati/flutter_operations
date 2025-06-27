## 1.1.0

**BREAKING CHANGES:**

- Removed `idle` parameter from `LoadingOperation` 
- Added `IdleOperation<T>` class extending `LoadingOperation<T>`
- Changed `LoadingOperation` from `final` to `base` class
- Added convenience getters: `hasNoData`, `isLoading`, `isIdle`, `isSuccess`, `isError`, etc.
- Added `SuccessOperation.empty()` constructor and `empty` property
- Added `setIdle()` method to both mixins
- Removed `doesGlobalRefresh` parameter from internal methods

**Migration:**
- Replace `LoadingOperation.idle` checks with `operation.isIdle`
- Handle `IdleOperation` in pattern matching when `loadOnInit = false`
- Update equality checks due to `LoadingOperation` structure changes

## 1.0.1

- Update README.md

## 1.0.0

- Initial release.
