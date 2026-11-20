import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class Product {
  final int? id;
  final String code;
  final String name;
  final double price;
  int qty; // Active cart quantity (not saved in DB)

  Product({
    this.id,
    required this.code,
    required this.name,
    required this.price,
    this.qty = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code.trim(),
      'name': name.trim(),
      'price': price,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      code: map['code'] as String,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
    );
  }
}

class DbHelper {
  static final DbHelper instance = DbHelper._internal();
  DbHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'pos_billing.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            price REAL NOT NULL
          )
        ''');

        // Starter sample items on first install
        await db.insert('products', {'code': '101', 'name': 'Fresh Milk 1L', 'price': 450.00});
        await db.insert('products', {'code': '102', 'name': 'White Bread', 'price': 180.00});
        await db.insert('products', {'code': '103', 'name': 'Ceylon Tea 100g', 'price': 350.00});
      },
    );
  }

  Future<List<Product>> getAllProducts() async {
    final db = await database;
    final maps = await db.query('products', orderBy: 'code ASC');
    return maps.map((m) => Product.fromMap(m)).toList();
  }

  Future<int> insertProduct(Product product) async {
    final db = await database;
    return await db.insert('products', product.toMap());
  }

  Future<int> updateProduct(Product product) async {
    final db = await database;
    return await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }
}