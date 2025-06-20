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
