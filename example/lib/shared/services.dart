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
    // Pick a random subset of products to simulate search results
    final filteredProducts = [
      for (final product in allProducts)
        if (_random.nextBool()) product,
    ];

    return filteredProducts;
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
