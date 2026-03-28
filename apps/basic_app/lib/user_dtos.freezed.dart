// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_dtos.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GetUserDto {

@FromPath()@HasMin(1) String get id;@FromQuery()@JsonKey(includeIfNull: false) String? get include;
/// Create a copy of GetUserDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GetUserDtoCopyWith<GetUserDto> get copyWith => _$GetUserDtoCopyWithImpl<GetUserDto>(this as GetUserDto, _$identity);

  /// Serializes this GetUserDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GetUserDto&&(identical(other.id, id) || other.id == id)&&(identical(other.include, include) || other.include == include));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,include);

@override
String toString() {
  return 'GetUserDto(id: $id, include: $include)';
}


}

/// @nodoc
abstract mixin class $GetUserDtoCopyWith<$Res>  {
  factory $GetUserDtoCopyWith(GetUserDto value, $Res Function(GetUserDto) _then) = _$GetUserDtoCopyWithImpl;
@useResult
$Res call({
@FromPath()@HasMin(1) String id,@FromQuery()@JsonKey(includeIfNull: false) String? include
});




}
/// @nodoc
class _$GetUserDtoCopyWithImpl<$Res>
    implements $GetUserDtoCopyWith<$Res> {
  _$GetUserDtoCopyWithImpl(this._self, this._then);

  final GetUserDto _self;
  final $Res Function(GetUserDto) _then;

/// Create a copy of GetUserDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? include = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,include: freezed == include ? _self.include : include // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [GetUserDto].
extension GetUserDtoPatterns on GetUserDto {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GetUserDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GetUserDto() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GetUserDto value)  $default,){
final _that = this;
switch (_that) {
case _GetUserDto():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GetUserDto value)?  $default,){
final _that = this;
switch (_that) {
case _GetUserDto() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@FromPath()@HasMin(1)  String id, @FromQuery()@JsonKey(includeIfNull: false)  String? include)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GetUserDto() when $default != null:
return $default(_that.id,_that.include);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@FromPath()@HasMin(1)  String id, @FromQuery()@JsonKey(includeIfNull: false)  String? include)  $default,) {final _that = this;
switch (_that) {
case _GetUserDto():
return $default(_that.id,_that.include);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@FromPath()@HasMin(1)  String id, @FromQuery()@JsonKey(includeIfNull: false)  String? include)?  $default,) {final _that = this;
switch (_that) {
case _GetUserDto() when $default != null:
return $default(_that.id,_that.include);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GetUserDto implements GetUserDto {
  const _GetUserDto({@FromPath()@HasMin(1) required this.id, @FromQuery()@JsonKey(includeIfNull: false) this.include});
  factory _GetUserDto.fromJson(Map<String, dynamic> json) => _$GetUserDtoFromJson(json);

@override@FromPath()@HasMin(1) final  String id;
@override@FromQuery()@JsonKey(includeIfNull: false) final  String? include;

/// Create a copy of GetUserDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GetUserDtoCopyWith<_GetUserDto> get copyWith => __$GetUserDtoCopyWithImpl<_GetUserDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GetUserDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GetUserDto&&(identical(other.id, id) || other.id == id)&&(identical(other.include, include) || other.include == include));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,include);

@override
String toString() {
  return 'GetUserDto(id: $id, include: $include)';
}


}

/// @nodoc
abstract mixin class _$GetUserDtoCopyWith<$Res> implements $GetUserDtoCopyWith<$Res> {
  factory _$GetUserDtoCopyWith(_GetUserDto value, $Res Function(_GetUserDto) _then) = __$GetUserDtoCopyWithImpl;
@override @useResult
$Res call({
@FromPath()@HasMin(1) String id,@FromQuery()@JsonKey(includeIfNull: false) String? include
});




}
/// @nodoc
class __$GetUserDtoCopyWithImpl<$Res>
    implements _$GetUserDtoCopyWith<$Res> {
  __$GetUserDtoCopyWithImpl(this._self, this._then);

  final _GetUserDto _self;
  final $Res Function(_GetUserDto) _then;

/// Create a copy of GetUserDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? include = freezed,}) {
  return _then(_GetUserDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,include: freezed == include ? _self.include : include // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$UserResponseDto {

@HasMin(1) String get id;@HasMin(1) String get name;
/// Create a copy of UserResponseDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserResponseDtoCopyWith<UserResponseDto> get copyWith => _$UserResponseDtoCopyWithImpl<UserResponseDto>(this as UserResponseDto, _$identity);

  /// Serializes this UserResponseDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserResponseDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name);

@override
String toString() {
  return 'UserResponseDto(id: $id, name: $name)';
}


}

/// @nodoc
abstract mixin class $UserResponseDtoCopyWith<$Res>  {
  factory $UserResponseDtoCopyWith(UserResponseDto value, $Res Function(UserResponseDto) _then) = _$UserResponseDtoCopyWithImpl;
@useResult
$Res call({
@HasMin(1) String id,@HasMin(1) String name
});




}
/// @nodoc
class _$UserResponseDtoCopyWithImpl<$Res>
    implements $UserResponseDtoCopyWith<$Res> {
  _$UserResponseDtoCopyWithImpl(this._self, this._then);

  final UserResponseDto _self;
  final $Res Function(UserResponseDto) _then;

/// Create a copy of UserResponseDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [UserResponseDto].
extension UserResponseDtoPatterns on UserResponseDto {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserResponseDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserResponseDto() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserResponseDto value)  $default,){
final _that = this;
switch (_that) {
case _UserResponseDto():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserResponseDto value)?  $default,){
final _that = this;
switch (_that) {
case _UserResponseDto() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@HasMin(1)  String id, @HasMin(1)  String name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserResponseDto() when $default != null:
return $default(_that.id,_that.name);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@HasMin(1)  String id, @HasMin(1)  String name)  $default,) {final _that = this;
switch (_that) {
case _UserResponseDto():
return $default(_that.id,_that.name);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@HasMin(1)  String id, @HasMin(1)  String name)?  $default,) {final _that = this;
switch (_that) {
case _UserResponseDto() when $default != null:
return $default(_that.id,_that.name);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserResponseDto implements UserResponseDto {
  const _UserResponseDto({@HasMin(1) required this.id, @HasMin(1) required this.name});
  factory _UserResponseDto.fromJson(Map<String, dynamic> json) => _$UserResponseDtoFromJson(json);

@override@HasMin(1) final  String id;
@override@HasMin(1) final  String name;

/// Create a copy of UserResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserResponseDtoCopyWith<_UserResponseDto> get copyWith => __$UserResponseDtoCopyWithImpl<_UserResponseDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserResponseDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserResponseDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name);

@override
String toString() {
  return 'UserResponseDto(id: $id, name: $name)';
}


}

/// @nodoc
abstract mixin class _$UserResponseDtoCopyWith<$Res> implements $UserResponseDtoCopyWith<$Res> {
  factory _$UserResponseDtoCopyWith(_UserResponseDto value, $Res Function(_UserResponseDto) _then) = __$UserResponseDtoCopyWithImpl;
@override @useResult
$Res call({
@HasMin(1) String id,@HasMin(1) String name
});




}
/// @nodoc
class __$UserResponseDtoCopyWithImpl<$Res>
    implements _$UserResponseDtoCopyWith<$Res> {
  __$UserResponseDtoCopyWithImpl(this._self, this._then);

  final _UserResponseDto _self;
  final $Res Function(_UserResponseDto) _then;

/// Create a copy of UserResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,}) {
  return _then(_UserResponseDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$UserStatusDto {

@HasMin(1) String get status;
/// Create a copy of UserStatusDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserStatusDtoCopyWith<UserStatusDto> get copyWith => _$UserStatusDtoCopyWithImpl<UserStatusDto>(this as UserStatusDto, _$identity);

  /// Serializes this UserStatusDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserStatusDto&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status);

@override
String toString() {
  return 'UserStatusDto(status: $status)';
}


}

/// @nodoc
abstract mixin class $UserStatusDtoCopyWith<$Res>  {
  factory $UserStatusDtoCopyWith(UserStatusDto value, $Res Function(UserStatusDto) _then) = _$UserStatusDtoCopyWithImpl;
@useResult
$Res call({
@HasMin(1) String status
});




}
/// @nodoc
class _$UserStatusDtoCopyWithImpl<$Res>
    implements $UserStatusDtoCopyWith<$Res> {
  _$UserStatusDtoCopyWithImpl(this._self, this._then);

  final UserStatusDto _self;
  final $Res Function(UserStatusDto) _then;

/// Create a copy of UserStatusDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [UserStatusDto].
extension UserStatusDtoPatterns on UserStatusDto {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserStatusDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserStatusDto() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserStatusDto value)  $default,){
final _that = this;
switch (_that) {
case _UserStatusDto():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserStatusDto value)?  $default,){
final _that = this;
switch (_that) {
case _UserStatusDto() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@HasMin(1)  String status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserStatusDto() when $default != null:
return $default(_that.status);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@HasMin(1)  String status)  $default,) {final _that = this;
switch (_that) {
case _UserStatusDto():
return $default(_that.status);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@HasMin(1)  String status)?  $default,) {final _that = this;
switch (_that) {
case _UserStatusDto() when $default != null:
return $default(_that.status);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserStatusDto implements UserStatusDto {
  const _UserStatusDto({@HasMin(1) required this.status});
  factory _UserStatusDto.fromJson(Map<String, dynamic> json) => _$UserStatusDtoFromJson(json);

@override@HasMin(1) final  String status;

/// Create a copy of UserStatusDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserStatusDtoCopyWith<_UserStatusDto> get copyWith => __$UserStatusDtoCopyWithImpl<_UserStatusDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserStatusDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserStatusDto&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status);

@override
String toString() {
  return 'UserStatusDto(status: $status)';
}


}

/// @nodoc
abstract mixin class _$UserStatusDtoCopyWith<$Res> implements $UserStatusDtoCopyWith<$Res> {
  factory _$UserStatusDtoCopyWith(_UserStatusDto value, $Res Function(_UserStatusDto) _then) = __$UserStatusDtoCopyWithImpl;
@override @useResult
$Res call({
@HasMin(1) String status
});




}
/// @nodoc
class __$UserStatusDtoCopyWithImpl<$Res>
    implements _$UserStatusDtoCopyWith<$Res> {
  __$UserStatusDtoCopyWithImpl(this._self, this._then);

  final _UserStatusDto _self;
  final $Res Function(_UserStatusDto) _then;

/// Create a copy of UserStatusDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,}) {
  return _then(_UserStatusDto(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
