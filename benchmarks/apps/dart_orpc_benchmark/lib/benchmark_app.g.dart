// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'benchmark_app.dart';

// **************************************************************************
// RpcDtoFieldRefGenerator
// **************************************************************************

abstract final class CatalogQueryDtoFields {
  static const category = RpcInputField<CatalogQueryDto>('category');
  static const limit = RpcInputField<CatalogQueryDto>('limit');
  static const page = RpcInputField<CatalogQueryDto>('page');
}

abstract final class CheckoutInputDtoFields {
  static const coupon = RpcInputField<CheckoutInputDto>('coupon');
  static const currency = RpcInputField<CheckoutInputDto>('currency');
  static const customer = RpcInputField<CheckoutInputDto>('customer');
  static const items = RpcInputField<CheckoutInputDto>('items');
  static const shippingAddress = RpcInputField<CheckoutInputDto>(
    'shippingAddress',
  );
}

abstract final class CheckoutCustomerDtoFields {
  static const id = RpcInputField<CheckoutCustomerDto>('id');
}

abstract final class CheckoutItemDtoFields {
  static const quantity = RpcInputField<CheckoutItemDto>('quantity');
  static const sku = RpcInputField<CheckoutItemDto>('sku');
  static const unitPriceCents = RpcInputField<CheckoutItemDto>(
    'unitPriceCents',
  );
}

abstract final class EchoInputDtoFields {
  static const message = RpcInputField<EchoInputDto>('message');
}

// **************************************************************************
// LuthorGenerator
// **************************************************************************

// ignore: constant_identifier_names
const CatalogQueryDtoSchemaKeys = (
  category: "category",
  page: "page",
  limit: "limit",
);

final SchemaValidator $CatalogQueryDtoSchema = l
    .schema({
      CatalogQueryDtoSchemaKeys.category: l.string().min(1).required(),
      CatalogQueryDtoSchemaKeys.page: l.int().min(1).required(),
      CatalogQueryDtoSchemaKeys.limit: l.int().min(1).max(100).required(),
    })
    .withName("CatalogQueryDto");

ValidationResult<CatalogQueryDto> $CatalogQueryDtoValidate(Object? json) =>
    $CatalogQueryDtoSchema.validateSchema(
      json,
      fromJson: CatalogQueryDto.fromJson,
    );

extension CatalogQueryDtoValidationExtension on CatalogQueryDto {
  ValidationResult<CatalogQueryDto> validateSelf() =>
      $CatalogQueryDtoValidate(_$luthorJsonMap(toJson()));
}

// ignore: constant_identifier_names
const CatalogQueryDtoErrorKeys = (
  category: "category",
  page: "page",
  limit: "limit",
);

// ignore: constant_identifier_names
const CheckoutInputDtoSchemaKeys = (
  customer: "customer",
  currency: "currency",
  items: "items",
  coupon: "coupon",
  shippingAddress: "shippingAddress",
);

final SchemaValidator $CheckoutInputDtoSchema = l
    .schema({
      CheckoutInputDtoSchemaKeys.customer: forwardRef(
        () => $CheckoutCustomerDtoSchema.required(),
      ),
      CheckoutInputDtoSchemaKeys.currency: l.string().min(1).required(),
      CheckoutInputDtoSchemaKeys.items: l
          .list(forwardRef(() => $CheckoutItemDtoSchema.required()))
          .custom(_hasItems)
          .required(),
      CheckoutInputDtoSchemaKeys.coupon: l.string(),
      CheckoutInputDtoSchemaKeys.shippingAddress: l.map(
        keyValidator: l.string().required(),
        valueValidator: l.any(),
      ),
    })
    .withName("CheckoutInputDto");

ValidationResult<CheckoutInputDto> $CheckoutInputDtoValidate(Object? json) =>
    $CheckoutInputDtoSchema.validateSchema(
      json,
      fromJson: CheckoutInputDto.fromJson,
    );

extension CheckoutInputDtoValidationExtension on CheckoutInputDto {
  ValidationResult<CheckoutInputDto> validateSelf() =>
      $CheckoutInputDtoValidate(_$luthorJsonMap(toJson()));
}

// ignore: constant_identifier_names
const CheckoutInputDtoErrorKeys = (
  customer: ($key: "customer", id: "customer.id"),
  currency: "currency",
  items: "items",
  coupon: "coupon",
  shippingAddress: "shippingAddress",
);

// ignore: constant_identifier_names
const CheckoutCustomerDtoSchemaKeys = (id: "id");

final SchemaValidator $CheckoutCustomerDtoSchema = l
    .schema({CheckoutCustomerDtoSchemaKeys.id: l.string().min(1).required()})
    .withName("CheckoutCustomerDto");

ValidationResult<CheckoutCustomerDto> $CheckoutCustomerDtoValidate(
  Object? json,
) => $CheckoutCustomerDtoSchema.validateSchema(
  json,
  fromJson: CheckoutCustomerDto.fromJson,
);

extension CheckoutCustomerDtoValidationExtension on CheckoutCustomerDto {
  ValidationResult<CheckoutCustomerDto> validateSelf() =>
      $CheckoutCustomerDtoValidate(_$luthorJsonMap(toJson()));
}

// ignore: constant_identifier_names
const CheckoutCustomerDtoErrorKeys = (id: "id");

// ignore: constant_identifier_names
const CheckoutItemDtoSchemaKeys = (
  sku: "sku",
  quantity: "quantity",
  unitPriceCents: "unitPriceCents",
);

final SchemaValidator $CheckoutItemDtoSchema = l
    .schema({
      CheckoutItemDtoSchemaKeys.sku: l.string().min(1).required(),
      CheckoutItemDtoSchemaKeys.quantity: l.int().min(1).required(),
      CheckoutItemDtoSchemaKeys.unitPriceCents: l.int().min(1).required(),
    })
    .withName("CheckoutItemDto");

ValidationResult<CheckoutItemDto> $CheckoutItemDtoValidate(Object? json) =>
    $CheckoutItemDtoSchema.validateSchema(
      json,
      fromJson: CheckoutItemDto.fromJson,
    );

extension CheckoutItemDtoValidationExtension on CheckoutItemDto {
  ValidationResult<CheckoutItemDto> validateSelf() =>
      $CheckoutItemDtoValidate(_$luthorJsonMap(toJson()));
}

// ignore: constant_identifier_names
const CheckoutItemDtoErrorKeys = (
  sku: "sku",
  quantity: "quantity",
  unitPriceCents: "unitPriceCents",
);

// ignore: constant_identifier_names
const EchoInputDtoSchemaKeys = (message: "message");

final SchemaValidator $EchoInputDtoSchema = l
    .schema({EchoInputDtoSchemaKeys.message: l.string().min(1).required()})
    .withName("EchoInputDto");

ValidationResult<EchoInputDto> $EchoInputDtoValidate(Object? json) =>
    $EchoInputDtoSchema.validateSchema(json, fromJson: EchoInputDto.fromJson);

extension EchoInputDtoValidationExtension on EchoInputDto {
  ValidationResult<EchoInputDto> validateSelf() =>
      $EchoInputDtoValidate(_$luthorJsonMap(toJson()));
}

// ignore: constant_identifier_names
const EchoInputDtoErrorKeys = (message: "message");

Map<String, Object?> _$luthorJsonMap(Map<Object?, Object?> map) => {
  for (final entry in map.entries)
    entry.key.toString(): _$luthorJsonValue(entry.value),
};

Object? _$luthorJsonValue(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is Map) return _$luthorJsonMap(value);
  if (value is Iterable) {
    return [for (final item in value) _$luthorJsonValue(item)];
  }
  try {
    // ignore: avoid_dynamic_calls
    return _$luthorJsonValue((value as dynamic).toJson());
    // ignore: avoid_catching_errors
  } on NoSuchMethodError {
    return value;
  }
}
