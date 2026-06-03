class Rider {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;

  Rider({required this.id, required this.name, required this.email, required this.phone, required this.role});

  factory Rider.fromJson(Map<String, dynamic> json) => Rider(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    email: json['email']?.toString() ?? '',
    phone: json['phone']?.toString() ?? '',
    role: json['role']?.toString() ?? '',
  );
}

class OrderItem {
  final String itemId;
  final String productId;
  final String name;
  int quantity;
  double price;
  final String category;

  OrderItem({
    required this.itemId,
    required this.productId,
    required this.name,
    required this.quantity,
    required this.price,
    this.category = '',
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    itemId: json['itemId']?.toString() ?? json['id']?.toString() ?? json['productId']?.toString() ?? '',
    productId: json['productId']?.toString() ?? json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? json['productName']?.toString() ?? '',
    quantity: (json['quantity'] ?? 1).toInt(),
    price: (json['price'] ?? 0).toDouble(),
    category: json['category']?.toString() ?? '',
  );

  Map<String, dynamic> toJson() => {
    'itemId': itemId,
    'productId': productId,
    'name': name,
    'quantity': quantity,
    'price': price,
    'category': category,
  };
}

class Order {
  final String id;
  final String riderId;
  final Map<String, dynamic>? originalOrder;

  Order({required this.id, this.riderId = '', this.originalOrder});

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id']?.toString() ?? '',
      riderId: json['riderId']?.toString() ?? '',
      originalOrder: json['originalOrder'] as Map<String, dynamic>?,
    );
  }

  String get orderNumber {
    final o = originalOrder ?? {};
    return o['orderNumber']?.toString() ?? o['receiptNumber']?.toString() ?? o['invoiceNumber']?.toString() ?? (id.length > 8 ? id.substring(0, 8) : id);
  }

  String get customerName => originalOrder?['customerName']?.toString() ?? 'Customer';
  String get address => originalOrder?['address']?.toString() ?? originalOrder?['deliveryAddress']?.toString() ?? '';
  String get phone => originalOrder?['phone']?.toString() ?? originalOrder?['customerPhone']?.toString() ?? '';
  String get serviceType => originalOrder?['serviceType']?.toString() ?? '';
  String get deliveryAgent => originalOrder?['deliveryAgent']?.toString() ?? '';
  double get deliveryFee => (originalOrder?['deliveryCharge'] ?? originalOrder?['deliveryFee'] ?? originalOrder?['serviceCharge'] ?? 0).toDouble();
  double get total => (originalOrder?['total'] ?? 0).toDouble();
  double get subtotal => (originalOrder?['subtotal'] ?? 0).toDouble();
  List<OrderItem> get items => (originalOrder?['items'] as List?)?.map((i) => OrderItem.fromJson(i)).toList() ?? [];

  bool get isPaid {
    final status = originalOrder?['status']?.toString().toLowerCase() ?? '';
    return status == 'payment collected' || status == 'completed';
  }
}

class Product {
  final String id;
  final String name;
  final double price;
  final String category;

  Product({required this.id, required this.name, required this.price, this.category = ''});

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
    name: json['name']?.toString() ?? json['productName']?.toString() ?? '',
    price: (json['price'] ?? 0).toDouble(),
    category: json['category']?.toString() ?? json['categoryName']?.toString() ?? json['type']?.toString() ?? json['group']?.toString() ?? '',
  );
}

class HotelSettings {
  final String hotelName;
  final String currency;
  final String riderAppTitle;
  final String riderAppSubtitle;
  final String riderAppLoginNote;
  final String? logo;
  final String? riderAppLogo;
  final String? riderAppAvatar;
  final List<RiderShift> riderShifts;

  HotelSettings({
    this.hotelName = 'Usman Hotel',
    this.currency = 'PKR',
    this.riderAppTitle = 'Rider Portal',
    this.riderAppSubtitle = 'Fast delivery management for riders',
    this.riderAppLoginNote = 'Login to continue',
    this.logo,
    this.riderAppLogo,
    this.riderAppAvatar,
    this.riderShifts = const [],
  });

  factory HotelSettings.fromJson(Map<String, dynamic> json) {
    final rawShifts = json['riderShifts'] as List? ?? (json['riderShift'] != null ? [json['riderShift']] : []);
    return HotelSettings(
      hotelName: json['hotelName']?.toString() ?? 'Usman Hotel',
      currency: json['currency']?.toString() ?? 'PKR',
      riderAppTitle: json['riderAppTitle']?.toString() ?? 'Rider Portal',
      riderAppSubtitle: json['riderAppSubtitle']?.toString() ?? '',
      riderAppLoginNote: json['riderAppLoginNote']?.toString() ?? 'Login to continue',
      logo: json['logo']?.toString(),
      riderAppLogo: json['riderAppLogo']?.toString(),
      riderAppAvatar: json['riderAppAvatar']?.toString(),
      riderShifts: (rawShifts as List?)?.map((s) => RiderShift.fromJson(s)).toList() ?? [],
    );
  }
}

class RiderShift {
  final bool active;
  final String? riderId;
  final String? riderName;
  final String? riderUsername;
  final String? startedAt;

  RiderShift({this.active = false, this.riderId, this.riderName, this.riderUsername, this.startedAt});

  factory RiderShift.fromJson(Map<String, dynamic> json) => RiderShift(
    active: json['active'] == true,
    riderId: json['riderId']?.toString(),
    riderName: json['riderName']?.toString(),
    riderUsername: json['riderUsername']?.toString(),
    startedAt: json['startedAt']?.toString(),
  );
}
