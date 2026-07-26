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

Validator $CatalogQueryDtoSchema = l.withName('CatalogQueryDto').schema({
  CatalogQueryDtoSchemaKeys.category: l.string().min(1).required(),
  CatalogQueryDtoSchemaKeys.page: l.int().min(1).required(),
  CatalogQueryDtoSchemaKeys.limit: l.int().max(100).min(1).required(),
});

SchemaValidationResult<CatalogQueryDto> $CatalogQueryDtoValidate(
  Map<String, dynamic> json,
) => $CatalogQueryDtoSchema.validateSchema(
  json,
  fromJson: CatalogQueryDto.fromJson,
);

extension CatalogQueryDtoValidationExtension on CatalogQueryDto {
  SchemaValidationResult<CatalogQueryDto> validateSelf() =>
      $CatalogQueryDtoValidate(toJson());
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

Validator $CheckoutInputDtoSchema = l.withName('CheckoutInputDto').schema({
  CheckoutInputDtoSchemaKeys.customer: $CheckoutCustomerDtoSchema.required(),
  CheckoutInputDtoSchemaKeys.currency: l.string().min(1).required(),
  CheckoutInputDtoSchemaKeys.items: l
      .list(validators: [$CheckoutItemDtoSchema.required()])
      .required(),
  CheckoutInputDtoSchemaKeys.coupon: l.string(),
  CheckoutInputDtoSchemaKeys.shippingAddress: l
      .map(keyValidator: l.string().required(), valueValidator: l.any())
      .required(),
});

SchemaValidationResult<CheckoutInputDto> $CheckoutInputDtoValidate(
  Map<String, dynamic> json,
) => $CheckoutInputDtoSchema.validateSchema(
  json,
  fromJson: CheckoutInputDto.fromJson,
);

extension CheckoutInputDtoValidationExtension on CheckoutInputDto {
  SchemaValidationResult<CheckoutInputDto> validateSelf() =>
      $CheckoutInputDtoValidate(toJson());
}

// ignore: constant_identifier_names
const CheckoutInputDtoErrorKeys = (
  customer: (id: "customer.id"),
  currency: "currency",
  items: "items",
  coupon: "coupon",
  shippingAddress: "shippingAddress",
);

// ignore: constant_identifier_names
const CheckoutCustomerDtoSchemaKeys = (id: "id");

Validator $CheckoutCustomerDtoSchema = l.withName('CheckoutCustomerDto').schema(
  {CheckoutCustomerDtoSchemaKeys.id: l.string().min(1).required()},
);

SchemaValidationResult<CheckoutCustomerDto> $CheckoutCustomerDtoValidate(
  Map<String, dynamic> json,
) => $CheckoutCustomerDtoSchema.validateSchema(
  json,
  fromJson: CheckoutCustomerDto.fromJson,
);

extension CheckoutCustomerDtoValidationExtension on CheckoutCustomerDto {
  SchemaValidationResult<CheckoutCustomerDto> validateSelf() =>
      $CheckoutCustomerDtoValidate(toJson());
}

// ignore: constant_identifier_names
const CheckoutCustomerDtoErrorKeys = (id: "id");

// ignore: constant_identifier_names
const CheckoutItemDtoSchemaKeys = (
  sku: "sku",
  quantity: "quantity",
  unitPriceCents: "unitPriceCents",
);

Validator $CheckoutItemDtoSchema = l.withName('CheckoutItemDto').schema({
  CheckoutItemDtoSchemaKeys.sku: l.string().min(1).required(),
  CheckoutItemDtoSchemaKeys.quantity: l.int().min(1).required(),
  CheckoutItemDtoSchemaKeys.unitPriceCents: l.int().min(1).required(),
});

SchemaValidationResult<CheckoutItemDto> $CheckoutItemDtoValidate(
  Map<String, dynamic> json,
) => $CheckoutItemDtoSchema.validateSchema(
  json,
  fromJson: CheckoutItemDto.fromJson,
);

extension CheckoutItemDtoValidationExtension on CheckoutItemDto {
  SchemaValidationResult<CheckoutItemDto> validateSelf() =>
      $CheckoutItemDtoValidate(toJson());
}

// ignore: constant_identifier_names
const CheckoutItemDtoErrorKeys = (
  sku: "sku",
  quantity: "quantity",
  unitPriceCents: "unitPriceCents",
);

// ignore: constant_identifier_names
const EchoInputDtoSchemaKeys = (message: "message");

Validator $EchoInputDtoSchema = l.withName('EchoInputDto').schema({
  EchoInputDtoSchemaKeys.message: l.string().min(1).required(),
});

SchemaValidationResult<EchoInputDto> $EchoInputDtoValidate(
  Map<String, dynamic> json,
) => $EchoInputDtoSchema.validateSchema(json, fromJson: EchoInputDto.fromJson);

extension EchoInputDtoValidationExtension on EchoInputDto {
  SchemaValidationResult<EchoInputDto> validateSelf() =>
      $EchoInputDtoValidate(toJson());
}

// ignore: constant_identifier_names
const EchoInputDtoErrorKeys = (message: "message");
