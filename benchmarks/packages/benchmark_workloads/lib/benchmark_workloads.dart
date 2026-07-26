typedef JsonObject = Map<String, Object?>;

final class CheckoutLineInput {
  const CheckoutLineInput({
    required this.sku,
    required this.quantity,
    required this.unitPriceCents,
  });

  final String sku;
  final int quantity;
  final int unitPriceCents;
}

JsonObject buildCatalog({
  required String category,
  required int page,
  required int limit,
}) {
  if (category.isEmpty || page < 1 || limit < 1 || limit > 100) {
    throw const FormatException('Invalid catalog query.');
  }

  final offset = (page - 1) * limit;
  return {
    'items': [
      for (var index = 0; index < limit; index++)
        _catalogItem(category, offset + index + 1),
    ],
    'pagination': {
      'page': page,
      'limit': limit,
      'total': 10000,
      'hasNext': offset + limit < 10000,
    },
    'filters': {'category': category, 'inStock': true},
  };
}

JsonObject processCheckout(Object? input) {
  final body = _object(input, 'checkout');
  final customer = _object(body['customer'], 'customer');
  final customerId = _string(customer['id'], 'customer.id');
  final currency = _string(body['currency'], 'currency');
  final coupon = body['coupon'];
  if (coupon != null && coupon is! String) {
    throw const FormatException('coupon must be a string.');
  }

  final rawItems = body['items'];
  if (rawItems is! List || rawItems.isEmpty) {
    throw const FormatException('items must be a non-empty list.');
  }

  final lines = <CheckoutLineInput>[];
  for (var index = 0; index < rawItems.length; index++) {
    final item = _object(rawItems[index], 'items[$index]');
    lines.add(
      CheckoutLineInput(
        sku: _string(item['sku'], 'items[$index].sku'),
        quantity: _positiveInt(item['quantity'], 'items[$index].quantity'),
        unitPriceCents: _positiveInt(
          item['unitPriceCents'],
          'items[$index].unitPriceCents',
        ),
      ),
    );
  }

  return calculateCheckout(
    customerId: customerId,
    currency: currency,
    coupon: coupon as String?,
    items: lines,
  );
}

JsonObject calculateCheckout({
  required String customerId,
  required String currency,
  required String? coupon,
  required List<CheckoutLineInput> items,
}) {
  if (customerId.isEmpty || currency.isEmpty || items.isEmpty) {
    throw const FormatException('Invalid checkout input.');
  }

  var subtotalCents = 0;
  var itemCount = 0;
  final outputItems = <JsonObject>[];
  for (final item in items) {
    if (item.sku.isEmpty || item.quantity < 1 || item.unitPriceCents < 1) {
      throw const FormatException('Invalid checkout item.');
    }
    final lineTotalCents = item.quantity * item.unitPriceCents;
    subtotalCents += lineTotalCents;
    itemCount += item.quantity;
    outputItems.add({
      'sku': item.sku,
      'quantity': item.quantity,
      'lineTotalCents': lineTotalCents,
    });
  }

  final discountCents = coupon == 'SAVE10' ? subtotalCents ~/ 10 : 0;
  final taxableCents = subtotalCents - discountCents;
  final taxCents = (taxableCents * 7 + 50) ~/ 100;
  final shippingCents = subtotalCents >= 10000 ? 0 : 799;

  return {
    'orderId': 'bench-$customerId',
    'status': 'confirmed',
    'currency': currency,
    'itemCount': itemCount,
    'subtotalCents': subtotalCents,
    'discountCents': discountCents,
    'taxCents': taxCents,
    'shippingCents': shippingCents,
    'totalCents': taxableCents + taxCents + shippingCents,
    'items': outputItems,
  };
}

JsonObject _catalogItem(String category, int id) {
  final priceCents = 1299 + (id % 17) * 125;
  return {
    'id': id,
    'sku': '${category.toUpperCase()}-${id.toString().padLeft(6, '0')}',
    'name': 'Benchmark $category item $id',
    'priceCents': priceCents,
    'currency': 'USD',
    'inStock': id % 7 != 0,
    'rating': 3.5 + (id % 15) / 10,
    'tags': [category, 'benchmark', if (id.isEven) 'featured' else 'standard'],
    'dimensions': {
      'widthMm': 120 + id % 30,
      'heightMm': 180 + id % 40,
      'depthMm': 15 + id % 10,
      'weightGrams': 250 + id % 300,
    },
  };
}

JsonObject _object(Object? value, String field) {
  if (value is! Map) {
    throw FormatException('$field must be an object.');
  }
  return value.map((key, value) => MapEntry(key.toString(), value));
}

String _string(Object? value, String field) {
  if (value is! String || value.isEmpty) {
    throw FormatException('$field must be a non-empty string.');
  }
  return value;
}

int _positiveInt(Object? value, String field) {
  if (value is! int || value < 1) {
    throw FormatException('$field must be a positive integer.');
  }
  return value;
}
