import 'package:benchmark_workloads/benchmark_workloads.dart' as workloads;
import 'package:dart_orpc/dart_orpc.dart';

part 'benchmark_app.g.dart';

@Module(controllers: [BenchmarkController], providers: [BenchmarkService])
final class BenchmarkModule {
  const BenchmarkModule();
}

@Controller('benchmark')
final class BenchmarkController {
  const BenchmarkController(this.service);

  final BenchmarkService service;

  @RpcMethod(
    path: RestMapping.get('/catalog'),
    description: 'Return a filtered page of catalog items.',
    tags: ['benchmark'],
  )
  CatalogResponseDto catalog(@RpcInput() CatalogQueryDto input) {
    return service.catalog(input);
  }

  @RpcMethod(
    path: RestMapping.post('/checkout'),
    description: 'Validate and calculate a checkout.',
    tags: ['benchmark'],
  )
  CheckoutResponseDto checkout(@RpcInput() CheckoutInputDto input) {
    return service.checkout(input);
  }

  @RpcMethod()
  EchoResponseDto echo(@RpcInput() EchoInputDto input) {
    return EchoResponseDto(input.toJson());
  }
}

final class BenchmarkService {
  const BenchmarkService();

  CatalogResponseDto catalog(CatalogQueryDto input) {
    try {
      return CatalogResponseDto(
        workloads.buildCatalog(
          category: input.category,
          page: input.page,
          limit: input.limit,
        ),
      );
    } on FormatException catch (error) {
      throw RpcException.badRequest(error.message);
    }
  }

  CheckoutResponseDto checkout(CheckoutInputDto input) {
    try {
      return CheckoutResponseDto(
        workloads.calculateCheckout(
          customerId: input.customer.id,
          currency: input.currency,
          coupon: input.coupon,
          items: [
            for (final item in input.items)
              workloads.CheckoutLineInput(
                sku: item.sku,
                quantity: item.quantity,
                unitPriceCents: item.unitPriceCents,
              ),
          ],
        ),
      );
    } on FormatException catch (error) {
      throw RpcException.badRequest(error.message);
    }
  }
}

@luthor
final class CatalogQueryDto {
  const CatalogQueryDto({
    @HasMin(1) required this.category,
    @HasMin(1) required this.page,
    @HasMin(1) @HasMax(100) required this.limit,
  });

  factory CatalogQueryDto.fromJson(Map<String, dynamic> json) {
    return CatalogQueryDto(
      category: json['category'] as String,
      page: json['page'] as int,
      limit: json['limit'] as int,
    );
  }

  @FromQuery()
  final String category;

  @FromQuery()
  final int page;

  @FromQuery()
  final int limit;

  JsonObject toJson() => {'category': category, 'page': page, 'limit': limit};
}

@luthor
final class CheckoutInputDto {
  const CheckoutInputDto({
    required this.customer,
    @HasMin(1) required this.currency,
    @HasMin(1) required this.items,
    this.coupon,
    this.shippingAddress = const {},
  });

  factory CheckoutInputDto.fromJson(Map<String, dynamic> json) {
    return CheckoutInputDto(
      customer: CheckoutCustomerDto.fromJson(
        json['customer'] as Map<String, dynamic>,
      ),
      currency: json['currency'] as String,
      items: [
        for (final item in json['items'] as List)
          CheckoutItemDto.fromJson(item as Map<String, dynamic>),
      ],
      coupon: json['coupon'] as String?,
      shippingAddress:
          json['shippingAddress'] as Map<String, dynamic>? ?? const {},
    );
  }

  final CheckoutCustomerDto customer;

  final String currency;

  final List<CheckoutItemDto> items;

  final String? coupon;
  final Map<String, dynamic> shippingAddress;

  JsonObject toJson() => {
    'customer': customer.toJson(),
    'currency': currency,
    'items': [for (final item in items) item.toJson()],
    if (coupon != null) 'coupon': coupon,
    'shippingAddress': shippingAddress,
  };
}

@luthor
final class CheckoutCustomerDto {
  const CheckoutCustomerDto({@HasMin(1) required this.id});

  factory CheckoutCustomerDto.fromJson(Map<String, dynamic> json) {
    return CheckoutCustomerDto(id: json['id'] as String);
  }

  final String id;

  JsonObject toJson() => {'id': id};
}

@luthor
final class CheckoutItemDto {
  const CheckoutItemDto({
    @HasMin(1) required this.sku,
    @HasMin(1) required this.quantity,
    @HasMin(1) required this.unitPriceCents,
  });

  factory CheckoutItemDto.fromJson(Map<String, dynamic> json) {
    return CheckoutItemDto(
      sku: json['sku'] as String,
      quantity: json['quantity'] as int,
      unitPriceCents: json['unitPriceCents'] as int,
    );
  }

  final String sku;
  final int quantity;
  final int unitPriceCents;

  JsonObject toJson() => {
    'sku': sku,
    'quantity': quantity,
    'unitPriceCents': unitPriceCents,
  };
}

@luthor
final class EchoInputDto {
  const EchoInputDto({@HasMin(1) required this.message});

  factory EchoInputDto.fromJson(Map<String, dynamic> json) {
    return EchoInputDto(message: json['message'] as String);
  }

  final String message;

  JsonObject toJson() => {'message': message};
}

final class CatalogResponseDto extends _RawResponseDto {
  const CatalogResponseDto(super.value);

  factory CatalogResponseDto.fromJson(Map<String, dynamic> json) {
    return CatalogResponseDto(json);
  }
}

final class CheckoutResponseDto extends _RawResponseDto {
  const CheckoutResponseDto(super.value);

  factory CheckoutResponseDto.fromJson(Map<String, dynamic> json) {
    return CheckoutResponseDto(json);
  }
}

final class EchoResponseDto extends _RawResponseDto {
  const EchoResponseDto(super.value);

  factory EchoResponseDto.fromJson(Map<String, dynamic> json) {
    return EchoResponseDto(json);
  }
}

abstract base class _RawResponseDto {
  const _RawResponseDto(this.value);

  final JsonObject value;

  JsonObject toJson() => value;
}
