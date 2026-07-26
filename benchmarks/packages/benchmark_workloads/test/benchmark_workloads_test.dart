import 'package:benchmark_workloads/benchmark_workloads.dart';
import 'package:test/test.dart';

void main() {
  test('catalog builds deterministic pagination and nested items', () {
    final catalog = buildCatalog(category: 'books', page: 2, limit: 10);
    final items = catalog['items']! as List<Object?>;

    expect(items, hasLength(10));
    expect(items.first, containsPair('id', 11));
    expect(items.last, containsPair('id', 20));
    expect(catalog['pagination'], {
      'page': 2,
      'limit': 10,
      'total': 10000,
      'hasNext': true,
    });
  });

  test('checkout validates items and calculates integer money totals', () {
    final checkout = processCheckout({
      'customer': {'id': 'customer-42'},
      'currency': 'USD',
      'coupon': 'SAVE10',
      'items': [
        {'sku': 'BOOK-000042', 'quantity': 2, 'unitPriceCents': 2499},
        {'sku': 'BOOK-000108', 'quantity': 1, 'unitPriceCents': 3599},
        {'sku': 'MEDIA-000007', 'quantity': 3, 'unitPriceCents': 1299},
        {'sku': 'OFFICE-000013', 'quantity': 1, 'unitPriceCents': 1899},
      ],
    });

    expect(checkout, containsPair('itemCount', 7));
    expect(checkout, containsPair('subtotalCents', 14393));
    expect(checkout, containsPair('discountCents', 1439));
    expect(checkout, containsPair('taxCents', 907));
    expect(checkout, containsPair('shippingCents', 0));
    expect(checkout, containsPair('totalCents', 13861));
  });

  test('typed checkout calculation matches the map boundary adapter', () {
    final typed = calculateCheckout(
      customerId: 'customer-42',
      currency: 'USD',
      coupon: 'SAVE10',
      items: const [
        CheckoutLineInput(
          sku: 'BOOK-000042',
          quantity: 2,
          unitPriceCents: 2499,
        ),
        CheckoutLineInput(
          sku: 'BOOK-000108',
          quantity: 1,
          unitPriceCents: 3599,
        ),
        CheckoutLineInput(
          sku: 'MEDIA-000007',
          quantity: 3,
          unitPriceCents: 1299,
        ),
        CheckoutLineInput(
          sku: 'OFFICE-000013',
          quantity: 1,
          unitPriceCents: 1899,
        ),
      ],
    );

    expect(typed, containsPair('itemCount', 7));
    expect(typed, containsPair('totalCents', 13861));
  });

  test('invalid catalog and checkout inputs are rejected', () {
    expect(
      () => buildCatalog(category: '', page: 0, limit: 101),
      throwsFormatException,
    );
    expect(
      () => processCheckout({
        'customer': {'id': 'customer-42'},
        'currency': 'USD',
        'items': const [],
      }),
      throwsFormatException,
    );
  });
}
