/// Represents the result of an operation with optional data and success message.
///
/// Used with [fetchWithMessage] to return both data and an optional message
/// from a single operation.
///
/// Example:
/// ```dart
/// @override
/// Future<OperationResult<User>> fetchWithMessage() async {
///   // API returns a Map with 'data' and 'message' fields
///   final response = await http.get(Uri.parse('https://api.example.com/user'));
///   final json = jsonDecode(response.body);
///
///   // Decode the data
///   final user = User.fromJson(json['data']);
///
///   // Extract the message from server response
///   final message = json['message'] as String?;
///
///   return OperationResult(user, message: message);
/// }
/// ```
class OperationResult<T> {
  /// Creates an operation result with data and an optional message.
  const OperationResult(this.data, {this.message});

  /// The data associated with the operation result.
  final T data;

  /// An optional success message associated with the operation result.
  final String? message;
}
