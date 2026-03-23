import 'dart:async';
import 'dart:math';

import 'models.dart';

class MockApiService {
  static final _random = Random();

  static Future<User> fetchUser({bool shouldFail = false}) async {
    await Future.delayed(Duration(milliseconds: 800 + _random.nextInt(1200)));

    if (shouldFail || _random.nextDouble() < 0.2) {
      throw Exception('Failed to load user data');
    }

    return User.example();
  }

  /// Simulates an API response that includes both data and message fields
  static Future<Map<String, dynamic>> fetchUserWithMessage({
    bool shouldFail = false,
  }) async {
    await Future.delayed(Duration(milliseconds: 800 + _random.nextInt(1200)));

    if (shouldFail || _random.nextDouble() < 0.2) {
      throw Exception('Failed to load user data');
    }

    final user = User.example();
    return {
      'data': {
        'name': user.name,
        'email': user.email,
        'avatarUrl': user.avatarUrl,
      },
      'message':
          'Welcome back, ${user.name}! Your profile has been loaded successfully.',
    };
  }

  static Future<List<Product>> fetchProducts({bool shouldFail = false}) async {
    await Future.delayed(Duration(milliseconds: 1000 + _random.nextInt(1000)));

    if (shouldFail || _random.nextDouble() < 0.15) {
      throw Exception('Failed to load products');
    }

    return Product.examples();
  }

  static Future<List<Product>> searchProducts(
    String query, {
    bool shouldFail = false,
  }) async {
    await Future.delayed(Duration(milliseconds: 600 + _random.nextInt(800)));

    if (shouldFail || _random.nextDouble() < 0.1) {
      throw Exception('Search failed - network error');
    }

    if (query.isEmpty) {
      return [];
    }

    final allProducts = Product.examples();
    return [
      for (final product in allProducts)
        if (product.name.toLowerCase().contains(query.toLowerCase()) ||
            product.category.toLowerCase().contains(query.toLowerCase()))
          product,
    ];
  }

  static Future<void> deleteItem(String id) async {
    await Future.delayed(Duration(milliseconds: 500 + _random.nextInt(500)));
    if (_random.nextDouble() < 0.15) {
      throw Exception('Failed to delete item');
    }
  }

  static Future<void> submitFeedback(String feedback) async {
    await Future.delayed(Duration(milliseconds: 400 + _random.nextInt(600)));
    if (_random.nextDouble() < 0.1) {
      throw Exception('Failed to submit feedback');
    }
  }
}

class MockStreamService {
  static Stream<int> counter() async* {
    int count = 0;
    while (true) {
      await Future.delayed(const Duration(seconds: 1));
      yield count++;
    }
  }
}
