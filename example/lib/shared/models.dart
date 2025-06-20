import 'dart:math';

class User {
  final String name;
  final String email;
  final String? avatarUrl;

  const User({required this.name, required this.email, this.avatarUrl});

  static User example() =>
      const User(name: 'John Doe', email: 'john@example.com', avatarUrl: null);
}

class Product {
  final String id;
  final String name;
  final double price;
  final int stock;
  final String category;

  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    required this.category,
  });

  static List<Product> examples() => [
    for (int i = 0; i < 30; i++)
      Product(
        id: 'prod_$i',
        name: 'Product $i',
        price: (10 + i * 2.5),
        stock: Random().nextInt(20),
        category: [
          'Electronics',
          'Kitchen',
          'Education',
          'Clothing',
          'Sports',
          'Books',
          'Toys',
          'Health',
          'Beauty',
        ][Random().nextInt(3)],
      ),
  ];
}
