// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'todo_dtos.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CreateTodoDto {

@HasMin(1) String get title;
/// Create a copy of CreateTodoDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CreateTodoDtoCopyWith<CreateTodoDto> get copyWith => _$CreateTodoDtoCopyWithImpl<CreateTodoDto>(this as CreateTodoDto, _$identity);

  /// Serializes this CreateTodoDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CreateTodoDto&&(identical(other.title, title) || other.title == title));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title);

@override
String toString() {
  return 'CreateTodoDto(title: $title)';
}


}

/// @nodoc
abstract mixin class $CreateTodoDtoCopyWith<$Res>  {
  factory $CreateTodoDtoCopyWith(CreateTodoDto value, $Res Function(CreateTodoDto) _then) = _$CreateTodoDtoCopyWithImpl;
@useResult
$Res call({
@HasMin(1) String title
});




}
/// @nodoc
class _$CreateTodoDtoCopyWithImpl<$Res>
    implements $CreateTodoDtoCopyWith<$Res> {
  _$CreateTodoDtoCopyWithImpl(this._self, this._then);

  final CreateTodoDto _self;
  final $Res Function(CreateTodoDto) _then;

/// Create a copy of CreateTodoDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,}) {
  return _then(_self.copyWith(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [CreateTodoDto].
extension CreateTodoDtoPatterns on CreateTodoDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CreateTodoDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CreateTodoDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CreateTodoDto value)  $default,){
final _that = this;
switch (_that) {
case _CreateTodoDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CreateTodoDto value)?  $default,){
final _that = this;
switch (_that) {
case _CreateTodoDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@HasMin(1)  String title)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CreateTodoDto() when $default != null:
return $default(_that.title);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@HasMin(1)  String title)  $default,) {final _that = this;
switch (_that) {
case _CreateTodoDto():
return $default(_that.title);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@HasMin(1)  String title)?  $default,) {final _that = this;
switch (_that) {
case _CreateTodoDto() when $default != null:
return $default(_that.title);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CreateTodoDto implements CreateTodoDto {
  const _CreateTodoDto({@HasMin(1) required this.title});
  factory _CreateTodoDto.fromJson(Map<String, dynamic> json) => _$CreateTodoDtoFromJson(json);

@override@HasMin(1) final  String title;

/// Create a copy of CreateTodoDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CreateTodoDtoCopyWith<_CreateTodoDto> get copyWith => __$CreateTodoDtoCopyWithImpl<_CreateTodoDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CreateTodoDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CreateTodoDto&&(identical(other.title, title) || other.title == title));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title);

@override
String toString() {
  return 'CreateTodoDto(title: $title)';
}


}

/// @nodoc
abstract mixin class _$CreateTodoDtoCopyWith<$Res> implements $CreateTodoDtoCopyWith<$Res> {
  factory _$CreateTodoDtoCopyWith(_CreateTodoDto value, $Res Function(_CreateTodoDto) _then) = __$CreateTodoDtoCopyWithImpl;
@override @useResult
$Res call({
@HasMin(1) String title
});




}
/// @nodoc
class __$CreateTodoDtoCopyWithImpl<$Res>
    implements _$CreateTodoDtoCopyWith<$Res> {
  __$CreateTodoDtoCopyWithImpl(this._self, this._then);

  final _CreateTodoDto _self;
  final $Res Function(_CreateTodoDto) _then;

/// Create a copy of CreateTodoDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,}) {
  return _then(_CreateTodoDto(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$GetTodoDto {

@FromPath() int get id;
/// Create a copy of GetTodoDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GetTodoDtoCopyWith<GetTodoDto> get copyWith => _$GetTodoDtoCopyWithImpl<GetTodoDto>(this as GetTodoDto, _$identity);

  /// Serializes this GetTodoDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GetTodoDto&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id);

@override
String toString() {
  return 'GetTodoDto(id: $id)';
}


}

/// @nodoc
abstract mixin class $GetTodoDtoCopyWith<$Res>  {
  factory $GetTodoDtoCopyWith(GetTodoDto value, $Res Function(GetTodoDto) _then) = _$GetTodoDtoCopyWithImpl;
@useResult
$Res call({
@FromPath() int id
});




}
/// @nodoc
class _$GetTodoDtoCopyWithImpl<$Res>
    implements $GetTodoDtoCopyWith<$Res> {
  _$GetTodoDtoCopyWithImpl(this._self, this._then);

  final GetTodoDto _self;
  final $Res Function(GetTodoDto) _then;

/// Create a copy of GetTodoDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [GetTodoDto].
extension GetTodoDtoPatterns on GetTodoDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GetTodoDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GetTodoDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GetTodoDto value)  $default,){
final _that = this;
switch (_that) {
case _GetTodoDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GetTodoDto value)?  $default,){
final _that = this;
switch (_that) {
case _GetTodoDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@FromPath()  int id)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GetTodoDto() when $default != null:
return $default(_that.id);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@FromPath()  int id)  $default,) {final _that = this;
switch (_that) {
case _GetTodoDto():
return $default(_that.id);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@FromPath()  int id)?  $default,) {final _that = this;
switch (_that) {
case _GetTodoDto() when $default != null:
return $default(_that.id);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GetTodoDto implements GetTodoDto {
  const _GetTodoDto({@FromPath() required this.id});
  factory _GetTodoDto.fromJson(Map<String, dynamic> json) => _$GetTodoDtoFromJson(json);

@override@FromPath() final  int id;

/// Create a copy of GetTodoDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GetTodoDtoCopyWith<_GetTodoDto> get copyWith => __$GetTodoDtoCopyWithImpl<_GetTodoDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GetTodoDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GetTodoDto&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id);

@override
String toString() {
  return 'GetTodoDto(id: $id)';
}


}

/// @nodoc
abstract mixin class _$GetTodoDtoCopyWith<$Res> implements $GetTodoDtoCopyWith<$Res> {
  factory _$GetTodoDtoCopyWith(_GetTodoDto value, $Res Function(_GetTodoDto) _then) = __$GetTodoDtoCopyWithImpl;
@override @useResult
$Res call({
@FromPath() int id
});




}
/// @nodoc
class __$GetTodoDtoCopyWithImpl<$Res>
    implements _$GetTodoDtoCopyWith<$Res> {
  __$GetTodoDtoCopyWithImpl(this._self, this._then);

  final _GetTodoDto _self;
  final $Res Function(_GetTodoDto) _then;

/// Create a copy of GetTodoDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,}) {
  return _then(_GetTodoDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$UpdateTodoDto {

@FromPath() int get id;@JsonKey(includeIfNull: false) String? get title;@JsonKey(includeIfNull: false) bool? get completed;
/// Create a copy of UpdateTodoDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UpdateTodoDtoCopyWith<UpdateTodoDto> get copyWith => _$UpdateTodoDtoCopyWithImpl<UpdateTodoDto>(this as UpdateTodoDto, _$identity);

  /// Serializes this UpdateTodoDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UpdateTodoDto&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.completed, completed) || other.completed == completed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,completed);

@override
String toString() {
  return 'UpdateTodoDto(id: $id, title: $title, completed: $completed)';
}


}

/// @nodoc
abstract mixin class $UpdateTodoDtoCopyWith<$Res>  {
  factory $UpdateTodoDtoCopyWith(UpdateTodoDto value, $Res Function(UpdateTodoDto) _then) = _$UpdateTodoDtoCopyWithImpl;
@useResult
$Res call({
@FromPath() int id,@JsonKey(includeIfNull: false) String? title,@JsonKey(includeIfNull: false) bool? completed
});




}
/// @nodoc
class _$UpdateTodoDtoCopyWithImpl<$Res>
    implements $UpdateTodoDtoCopyWith<$Res> {
  _$UpdateTodoDtoCopyWithImpl(this._self, this._then);

  final UpdateTodoDto _self;
  final $Res Function(UpdateTodoDto) _then;

/// Create a copy of UpdateTodoDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = freezed,Object? completed = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,completed: freezed == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}


/// Adds pattern-matching-related methods to [UpdateTodoDto].
extension UpdateTodoDtoPatterns on UpdateTodoDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UpdateTodoDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UpdateTodoDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UpdateTodoDto value)  $default,){
final _that = this;
switch (_that) {
case _UpdateTodoDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UpdateTodoDto value)?  $default,){
final _that = this;
switch (_that) {
case _UpdateTodoDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@FromPath()  int id, @JsonKey(includeIfNull: false)  String? title, @JsonKey(includeIfNull: false)  bool? completed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UpdateTodoDto() when $default != null:
return $default(_that.id,_that.title,_that.completed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@FromPath()  int id, @JsonKey(includeIfNull: false)  String? title, @JsonKey(includeIfNull: false)  bool? completed)  $default,) {final _that = this;
switch (_that) {
case _UpdateTodoDto():
return $default(_that.id,_that.title,_that.completed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@FromPath()  int id, @JsonKey(includeIfNull: false)  String? title, @JsonKey(includeIfNull: false)  bool? completed)?  $default,) {final _that = this;
switch (_that) {
case _UpdateTodoDto() when $default != null:
return $default(_that.id,_that.title,_that.completed);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UpdateTodoDto implements UpdateTodoDto {
  const _UpdateTodoDto({@FromPath() required this.id, @JsonKey(includeIfNull: false) this.title, @JsonKey(includeIfNull: false) this.completed});
  factory _UpdateTodoDto.fromJson(Map<String, dynamic> json) => _$UpdateTodoDtoFromJson(json);

@override@FromPath() final  int id;
@override@JsonKey(includeIfNull: false) final  String? title;
@override@JsonKey(includeIfNull: false) final  bool? completed;

/// Create a copy of UpdateTodoDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UpdateTodoDtoCopyWith<_UpdateTodoDto> get copyWith => __$UpdateTodoDtoCopyWithImpl<_UpdateTodoDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UpdateTodoDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UpdateTodoDto&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.completed, completed) || other.completed == completed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,completed);

@override
String toString() {
  return 'UpdateTodoDto(id: $id, title: $title, completed: $completed)';
}


}

/// @nodoc
abstract mixin class _$UpdateTodoDtoCopyWith<$Res> implements $UpdateTodoDtoCopyWith<$Res> {
  factory _$UpdateTodoDtoCopyWith(_UpdateTodoDto value, $Res Function(_UpdateTodoDto) _then) = __$UpdateTodoDtoCopyWithImpl;
@override @useResult
$Res call({
@FromPath() int id,@JsonKey(includeIfNull: false) String? title,@JsonKey(includeIfNull: false) bool? completed
});




}
/// @nodoc
class __$UpdateTodoDtoCopyWithImpl<$Res>
    implements _$UpdateTodoDtoCopyWith<$Res> {
  __$UpdateTodoDtoCopyWithImpl(this._self, this._then);

  final _UpdateTodoDto _self;
  final $Res Function(_UpdateTodoDto) _then;

/// Create a copy of UpdateTodoDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = freezed,Object? completed = freezed,}) {
  return _then(_UpdateTodoDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,completed: freezed == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}


/// @nodoc
mixin _$TodoResponseDto {

 int get id;@HasMin(1) String get title; bool get completed; DateTime get createdAt;
/// Create a copy of TodoResponseDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TodoResponseDtoCopyWith<TodoResponseDto> get copyWith => _$TodoResponseDtoCopyWithImpl<TodoResponseDto>(this as TodoResponseDto, _$identity);

  /// Serializes this TodoResponseDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TodoResponseDto&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.completed, completed) || other.completed == completed)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,completed,createdAt);

@override
String toString() {
  return 'TodoResponseDto(id: $id, title: $title, completed: $completed, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $TodoResponseDtoCopyWith<$Res>  {
  factory $TodoResponseDtoCopyWith(TodoResponseDto value, $Res Function(TodoResponseDto) _then) = _$TodoResponseDtoCopyWithImpl;
@useResult
$Res call({
 int id,@HasMin(1) String title, bool completed, DateTime createdAt
});




}
/// @nodoc
class _$TodoResponseDtoCopyWithImpl<$Res>
    implements $TodoResponseDtoCopyWith<$Res> {
  _$TodoResponseDtoCopyWithImpl(this._self, this._then);

  final TodoResponseDto _self;
  final $Res Function(TodoResponseDto) _then;

/// Create a copy of TodoResponseDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? completed = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,completed: null == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [TodoResponseDto].
extension TodoResponseDtoPatterns on TodoResponseDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TodoResponseDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TodoResponseDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TodoResponseDto value)  $default,){
final _that = this;
switch (_that) {
case _TodoResponseDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TodoResponseDto value)?  $default,){
final _that = this;
switch (_that) {
case _TodoResponseDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id, @HasMin(1)  String title,  bool completed,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TodoResponseDto() when $default != null:
return $default(_that.id,_that.title,_that.completed,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id, @HasMin(1)  String title,  bool completed,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _TodoResponseDto():
return $default(_that.id,_that.title,_that.completed,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id, @HasMin(1)  String title,  bool completed,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _TodoResponseDto() when $default != null:
return $default(_that.id,_that.title,_that.completed,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TodoResponseDto implements TodoResponseDto {
  const _TodoResponseDto({required this.id, @HasMin(1) required this.title, required this.completed, required this.createdAt});
  factory _TodoResponseDto.fromJson(Map<String, dynamic> json) => _$TodoResponseDtoFromJson(json);

@override final  int id;
@override@HasMin(1) final  String title;
@override final  bool completed;
@override final  DateTime createdAt;

/// Create a copy of TodoResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TodoResponseDtoCopyWith<_TodoResponseDto> get copyWith => __$TodoResponseDtoCopyWithImpl<_TodoResponseDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TodoResponseDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TodoResponseDto&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.completed, completed) || other.completed == completed)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,completed,createdAt);

@override
String toString() {
  return 'TodoResponseDto(id: $id, title: $title, completed: $completed, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$TodoResponseDtoCopyWith<$Res> implements $TodoResponseDtoCopyWith<$Res> {
  factory _$TodoResponseDtoCopyWith(_TodoResponseDto value, $Res Function(_TodoResponseDto) _then) = __$TodoResponseDtoCopyWithImpl;
@override @useResult
$Res call({
 int id,@HasMin(1) String title, bool completed, DateTime createdAt
});




}
/// @nodoc
class __$TodoResponseDtoCopyWithImpl<$Res>
    implements _$TodoResponseDtoCopyWith<$Res> {
  __$TodoResponseDtoCopyWithImpl(this._self, this._then);

  final _TodoResponseDto _self;
  final $Res Function(_TodoResponseDto) _then;

/// Create a copy of TodoResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? completed = null,Object? createdAt = null,}) {
  return _then(_TodoResponseDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,completed: null == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$TodoListResponseDto {

 List<TodoResponseDto> get items;
/// Create a copy of TodoListResponseDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TodoListResponseDtoCopyWith<TodoListResponseDto> get copyWith => _$TodoListResponseDtoCopyWithImpl<TodoListResponseDto>(this as TodoListResponseDto, _$identity);

  /// Serializes this TodoListResponseDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TodoListResponseDto&&const DeepCollectionEquality().equals(other.items, items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(items));

@override
String toString() {
  return 'TodoListResponseDto(items: $items)';
}


}

/// @nodoc
abstract mixin class $TodoListResponseDtoCopyWith<$Res>  {
  factory $TodoListResponseDtoCopyWith(TodoListResponseDto value, $Res Function(TodoListResponseDto) _then) = _$TodoListResponseDtoCopyWithImpl;
@useResult
$Res call({
 List<TodoResponseDto> items
});




}
/// @nodoc
class _$TodoListResponseDtoCopyWithImpl<$Res>
    implements $TodoListResponseDtoCopyWith<$Res> {
  _$TodoListResponseDtoCopyWithImpl(this._self, this._then);

  final TodoListResponseDto _self;
  final $Res Function(TodoListResponseDto) _then;

/// Create a copy of TodoListResponseDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? items = null,}) {
  return _then(_self.copyWith(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<TodoResponseDto>,
  ));
}

}


/// Adds pattern-matching-related methods to [TodoListResponseDto].
extension TodoListResponseDtoPatterns on TodoListResponseDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TodoListResponseDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TodoListResponseDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TodoListResponseDto value)  $default,){
final _that = this;
switch (_that) {
case _TodoListResponseDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TodoListResponseDto value)?  $default,){
final _that = this;
switch (_that) {
case _TodoListResponseDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<TodoResponseDto> items)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TodoListResponseDto() when $default != null:
return $default(_that.items);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<TodoResponseDto> items)  $default,) {final _that = this;
switch (_that) {
case _TodoListResponseDto():
return $default(_that.items);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<TodoResponseDto> items)?  $default,) {final _that = this;
switch (_that) {
case _TodoListResponseDto() when $default != null:
return $default(_that.items);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TodoListResponseDto implements TodoListResponseDto {
  const _TodoListResponseDto({required final  List<TodoResponseDto> items}): _items = items;
  factory _TodoListResponseDto.fromJson(Map<String, dynamic> json) => _$TodoListResponseDtoFromJson(json);

 final  List<TodoResponseDto> _items;
@override List<TodoResponseDto> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}


/// Create a copy of TodoListResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TodoListResponseDtoCopyWith<_TodoListResponseDto> get copyWith => __$TodoListResponseDtoCopyWithImpl<_TodoListResponseDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TodoListResponseDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TodoListResponseDto&&const DeepCollectionEquality().equals(other._items, _items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_items));

@override
String toString() {
  return 'TodoListResponseDto(items: $items)';
}


}

/// @nodoc
abstract mixin class _$TodoListResponseDtoCopyWith<$Res> implements $TodoListResponseDtoCopyWith<$Res> {
  factory _$TodoListResponseDtoCopyWith(_TodoListResponseDto value, $Res Function(_TodoListResponseDto) _then) = __$TodoListResponseDtoCopyWithImpl;
@override @useResult
$Res call({
 List<TodoResponseDto> items
});




}
/// @nodoc
class __$TodoListResponseDtoCopyWithImpl<$Res>
    implements _$TodoListResponseDtoCopyWith<$Res> {
  __$TodoListResponseDtoCopyWithImpl(this._self, this._then);

  final _TodoListResponseDto _self;
  final $Res Function(_TodoListResponseDto) _then;

/// Create a copy of TodoListResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? items = null,}) {
  return _then(_TodoListResponseDto(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<TodoResponseDto>,
  ));
}


}


/// @nodoc
mixin _$DeleteTodoResponseDto {

 bool get deleted;
/// Create a copy of DeleteTodoResponseDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeleteTodoResponseDtoCopyWith<DeleteTodoResponseDto> get copyWith => _$DeleteTodoResponseDtoCopyWithImpl<DeleteTodoResponseDto>(this as DeleteTodoResponseDto, _$identity);

  /// Serializes this DeleteTodoResponseDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeleteTodoResponseDto&&(identical(other.deleted, deleted) || other.deleted == deleted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,deleted);

@override
String toString() {
  return 'DeleteTodoResponseDto(deleted: $deleted)';
}


}

/// @nodoc
abstract mixin class $DeleteTodoResponseDtoCopyWith<$Res>  {
  factory $DeleteTodoResponseDtoCopyWith(DeleteTodoResponseDto value, $Res Function(DeleteTodoResponseDto) _then) = _$DeleteTodoResponseDtoCopyWithImpl;
@useResult
$Res call({
 bool deleted
});




}
/// @nodoc
class _$DeleteTodoResponseDtoCopyWithImpl<$Res>
    implements $DeleteTodoResponseDtoCopyWith<$Res> {
  _$DeleteTodoResponseDtoCopyWithImpl(this._self, this._then);

  final DeleteTodoResponseDto _self;
  final $Res Function(DeleteTodoResponseDto) _then;

/// Create a copy of DeleteTodoResponseDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? deleted = null,}) {
  return _then(_self.copyWith(
deleted: null == deleted ? _self.deleted : deleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [DeleteTodoResponseDto].
extension DeleteTodoResponseDtoPatterns on DeleteTodoResponseDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeleteTodoResponseDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeleteTodoResponseDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeleteTodoResponseDto value)  $default,){
final _that = this;
switch (_that) {
case _DeleteTodoResponseDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeleteTodoResponseDto value)?  $default,){
final _that = this;
switch (_that) {
case _DeleteTodoResponseDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool deleted)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeleteTodoResponseDto() when $default != null:
return $default(_that.deleted);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool deleted)  $default,) {final _that = this;
switch (_that) {
case _DeleteTodoResponseDto():
return $default(_that.deleted);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool deleted)?  $default,) {final _that = this;
switch (_that) {
case _DeleteTodoResponseDto() when $default != null:
return $default(_that.deleted);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DeleteTodoResponseDto implements DeleteTodoResponseDto {
  const _DeleteTodoResponseDto({this.deleted = true});
  factory _DeleteTodoResponseDto.fromJson(Map<String, dynamic> json) => _$DeleteTodoResponseDtoFromJson(json);

@override@JsonKey() final  bool deleted;

/// Create a copy of DeleteTodoResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeleteTodoResponseDtoCopyWith<_DeleteTodoResponseDto> get copyWith => __$DeleteTodoResponseDtoCopyWithImpl<_DeleteTodoResponseDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeleteTodoResponseDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeleteTodoResponseDto&&(identical(other.deleted, deleted) || other.deleted == deleted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,deleted);

@override
String toString() {
  return 'DeleteTodoResponseDto(deleted: $deleted)';
}


}

/// @nodoc
abstract mixin class _$DeleteTodoResponseDtoCopyWith<$Res> implements $DeleteTodoResponseDtoCopyWith<$Res> {
  factory _$DeleteTodoResponseDtoCopyWith(_DeleteTodoResponseDto value, $Res Function(_DeleteTodoResponseDto) _then) = __$DeleteTodoResponseDtoCopyWithImpl;
@override @useResult
$Res call({
 bool deleted
});




}
/// @nodoc
class __$DeleteTodoResponseDtoCopyWithImpl<$Res>
    implements _$DeleteTodoResponseDtoCopyWith<$Res> {
  __$DeleteTodoResponseDtoCopyWithImpl(this._self, this._then);

  final _DeleteTodoResponseDto _self;
  final $Res Function(_DeleteTodoResponseDto) _then;

/// Create a copy of DeleteTodoResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? deleted = null,}) {
  return _then(_DeleteTodoResponseDto(
deleted: null == deleted ? _self.deleted : deleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
