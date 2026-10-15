// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auth_dtos.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SignUpDto {

@HasMin(3) String get name;@IsEmail(message: 'Enter a valid email address.')@HasMax(254) String get email;@HasMin(8)@HasMax(72)@MatchRegex(r'^(?=.*[A-Za-z])(?=.*\d).+$', message: 'Password must contain at least one letter and one number.') String get password;
/// Create a copy of SignUpDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SignUpDtoCopyWith<SignUpDto> get copyWith => _$SignUpDtoCopyWithImpl<SignUpDto>(this as SignUpDto, _$identity);

  /// Serializes this SignUpDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SignUpDto&&(identical(other.name, name) || other.name == name)&&(identical(other.email, email) || other.email == email)&&(identical(other.password, password) || other.password == password));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,email,password);

@override
String toString() {
  return 'SignUpDto(name: $name, email: $email, password: $password)';
}


}

/// @nodoc
abstract mixin class $SignUpDtoCopyWith<$Res>  {
  factory $SignUpDtoCopyWith(SignUpDto value, $Res Function(SignUpDto) _then) = _$SignUpDtoCopyWithImpl;
@useResult
$Res call({
@HasMin(3) String name,@IsEmail(message: 'Enter a valid email address.')@HasMax(254) String email,@HasMin(8)@HasMax(72)@MatchRegex(r'^(?=.*[A-Za-z])(?=.*\d).+$', message: 'Password must contain at least one letter and one number.') String password
});




}
/// @nodoc
class _$SignUpDtoCopyWithImpl<$Res>
    implements $SignUpDtoCopyWith<$Res> {
  _$SignUpDtoCopyWithImpl(this._self, this._then);

  final SignUpDto _self;
  final $Res Function(SignUpDto) _then;

/// Create a copy of SignUpDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? email = null,Object? password = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [SignUpDto].
extension SignUpDtoPatterns on SignUpDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SignUpDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SignUpDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SignUpDto value)  $default,){
final _that = this;
switch (_that) {
case _SignUpDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SignUpDto value)?  $default,){
final _that = this;
switch (_that) {
case _SignUpDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@HasMin(3)  String name, @IsEmail(message: 'Enter a valid email address.')@HasMax(254)  String email, @HasMin(8)@HasMax(72)@MatchRegex(r'^(?=.*[A-Za-z])(?=.*\d).+$', message: 'Password must contain at least one letter and one number.')  String password)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SignUpDto() when $default != null:
return $default(_that.name,_that.email,_that.password);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@HasMin(3)  String name, @IsEmail(message: 'Enter a valid email address.')@HasMax(254)  String email, @HasMin(8)@HasMax(72)@MatchRegex(r'^(?=.*[A-Za-z])(?=.*\d).+$', message: 'Password must contain at least one letter and one number.')  String password)  $default,) {final _that = this;
switch (_that) {
case _SignUpDto():
return $default(_that.name,_that.email,_that.password);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@HasMin(3)  String name, @IsEmail(message: 'Enter a valid email address.')@HasMax(254)  String email, @HasMin(8)@HasMax(72)@MatchRegex(r'^(?=.*[A-Za-z])(?=.*\d).+$', message: 'Password must contain at least one letter and one number.')  String password)?  $default,) {final _that = this;
switch (_that) {
case _SignUpDto() when $default != null:
return $default(_that.name,_that.email,_that.password);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SignUpDto implements SignUpDto {
  const _SignUpDto({@HasMin(3) required this.name, @IsEmail(message: 'Enter a valid email address.')@HasMax(254) required this.email, @HasMin(8)@HasMax(72)@MatchRegex(r'^(?=.*[A-Za-z])(?=.*\d).+$', message: 'Password must contain at least one letter and one number.') required this.password});
  factory _SignUpDto.fromJson(Map<String, dynamic> json) => _$SignUpDtoFromJson(json);

@override@HasMin(3) final  String name;
@override@IsEmail(message: 'Enter a valid email address.')@HasMax(254) final  String email;
@override@HasMin(8)@HasMax(72)@MatchRegex(r'^(?=.*[A-Za-z])(?=.*\d).+$', message: 'Password must contain at least one letter and one number.') final  String password;

/// Create a copy of SignUpDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SignUpDtoCopyWith<_SignUpDto> get copyWith => __$SignUpDtoCopyWithImpl<_SignUpDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SignUpDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SignUpDto&&(identical(other.name, name) || other.name == name)&&(identical(other.email, email) || other.email == email)&&(identical(other.password, password) || other.password == password));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,email,password);

@override
String toString() {
  return 'SignUpDto(name: $name, email: $email, password: $password)';
}


}

/// @nodoc
abstract mixin class _$SignUpDtoCopyWith<$Res> implements $SignUpDtoCopyWith<$Res> {
  factory _$SignUpDtoCopyWith(_SignUpDto value, $Res Function(_SignUpDto) _then) = __$SignUpDtoCopyWithImpl;
@override @useResult
$Res call({
@HasMin(3) String name,@IsEmail(message: 'Enter a valid email address.')@HasMax(254) String email,@HasMin(8)@HasMax(72)@MatchRegex(r'^(?=.*[A-Za-z])(?=.*\d).+$', message: 'Password must contain at least one letter and one number.') String password
});




}
/// @nodoc
class __$SignUpDtoCopyWithImpl<$Res>
    implements _$SignUpDtoCopyWith<$Res> {
  __$SignUpDtoCopyWithImpl(this._self, this._then);

  final _SignUpDto _self;
  final $Res Function(_SignUpDto) _then;

/// Create a copy of SignUpDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? email = null,Object? password = null,}) {
  return _then(_SignUpDto(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$LoginDto {

@IsEmail(message: 'Enter a valid email address.')@HasMax(254) String get email;@HasMin(8)@HasMax(72)@MatchRegex(r'^(?=.*[A-Za-z])(?=.*\d).+$', message: 'Password must contain at least one letter and one number.') String get password;
/// Create a copy of LoginDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LoginDtoCopyWith<LoginDto> get copyWith => _$LoginDtoCopyWithImpl<LoginDto>(this as LoginDto, _$identity);

  /// Serializes this LoginDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LoginDto&&(identical(other.email, email) || other.email == email)&&(identical(other.password, password) || other.password == password));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,email,password);

@override
String toString() {
  return 'LoginDto(email: $email, password: $password)';
}


}

/// @nodoc
abstract mixin class $LoginDtoCopyWith<$Res>  {
  factory $LoginDtoCopyWith(LoginDto value, $Res Function(LoginDto) _then) = _$LoginDtoCopyWithImpl;
@useResult
$Res call({
@IsEmail(message: 'Enter a valid email address.')@HasMax(254) String email,@HasMin(8)@HasMax(72)@MatchRegex(r'^(?=.*[A-Za-z])(?=.*\d).+$', message: 'Password must contain at least one letter and one number.') String password
});




}
/// @nodoc
class _$LoginDtoCopyWithImpl<$Res>
    implements $LoginDtoCopyWith<$Res> {
  _$LoginDtoCopyWithImpl(this._self, this._then);

  final LoginDto _self;
  final $Res Function(LoginDto) _then;

/// Create a copy of LoginDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? email = null,Object? password = null,}) {
  return _then(_self.copyWith(
email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [LoginDto].
extension LoginDtoPatterns on LoginDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LoginDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LoginDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LoginDto value)  $default,){
final _that = this;
switch (_that) {
case _LoginDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LoginDto value)?  $default,){
final _that = this;
switch (_that) {
case _LoginDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@IsEmail(message: 'Enter a valid email address.')@HasMax(254)  String email, @HasMin(8)@HasMax(72)@MatchRegex(r'^(?=.*[A-Za-z])(?=.*\d).+$', message: 'Password must contain at least one letter and one number.')  String password)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LoginDto() when $default != null:
return $default(_that.email,_that.password);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@IsEmail(message: 'Enter a valid email address.')@HasMax(254)  String email, @HasMin(8)@HasMax(72)@MatchRegex(r'^(?=.*[A-Za-z])(?=.*\d).+$', message: 'Password must contain at least one letter and one number.')  String password)  $default,) {final _that = this;
switch (_that) {
case _LoginDto():
return $default(_that.email,_that.password);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@IsEmail(message: 'Enter a valid email address.')@HasMax(254)  String email, @HasMin(8)@HasMax(72)@MatchRegex(r'^(?=.*[A-Za-z])(?=.*\d).+$', message: 'Password must contain at least one letter and one number.')  String password)?  $default,) {final _that = this;
switch (_that) {
case _LoginDto() when $default != null:
return $default(_that.email,_that.password);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LoginDto implements LoginDto {
  const _LoginDto({@IsEmail(message: 'Enter a valid email address.')@HasMax(254) required this.email, @HasMin(8)@HasMax(72)@MatchRegex(r'^(?=.*[A-Za-z])(?=.*\d).+$', message: 'Password must contain at least one letter and one number.') required this.password});
  factory _LoginDto.fromJson(Map<String, dynamic> json) => _$LoginDtoFromJson(json);

@override@IsEmail(message: 'Enter a valid email address.')@HasMax(254) final  String email;
@override@HasMin(8)@HasMax(72)@MatchRegex(r'^(?=.*[A-Za-z])(?=.*\d).+$', message: 'Password must contain at least one letter and one number.') final  String password;

/// Create a copy of LoginDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LoginDtoCopyWith<_LoginDto> get copyWith => __$LoginDtoCopyWithImpl<_LoginDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LoginDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LoginDto&&(identical(other.email, email) || other.email == email)&&(identical(other.password, password) || other.password == password));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,email,password);

@override
String toString() {
  return 'LoginDto(email: $email, password: $password)';
}


}

/// @nodoc
abstract mixin class _$LoginDtoCopyWith<$Res> implements $LoginDtoCopyWith<$Res> {
  factory _$LoginDtoCopyWith(_LoginDto value, $Res Function(_LoginDto) _then) = __$LoginDtoCopyWithImpl;
@override @useResult
$Res call({
@IsEmail(message: 'Enter a valid email address.')@HasMax(254) String email,@HasMin(8)@HasMax(72)@MatchRegex(r'^(?=.*[A-Za-z])(?=.*\d).+$', message: 'Password must contain at least one letter and one number.') String password
});




}
/// @nodoc
class __$LoginDtoCopyWithImpl<$Res>
    implements _$LoginDtoCopyWith<$Res> {
  __$LoginDtoCopyWithImpl(this._self, this._then);

  final _LoginDto _self;
  final $Res Function(_LoginDto) _then;

/// Create a copy of LoginDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? email = null,Object? password = null,}) {
  return _then(_LoginDto(
email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$AuthUserDto {

 String get id; String get name; String get email;
/// Create a copy of AuthUserDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthUserDtoCopyWith<AuthUserDto> get copyWith => _$AuthUserDtoCopyWithImpl<AuthUserDto>(this as AuthUserDto, _$identity);

  /// Serializes this AuthUserDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthUserDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.email, email) || other.email == email));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,email);

@override
String toString() {
  return 'AuthUserDto(id: $id, name: $name, email: $email)';
}


}

/// @nodoc
abstract mixin class $AuthUserDtoCopyWith<$Res>  {
  factory $AuthUserDtoCopyWith(AuthUserDto value, $Res Function(AuthUserDto) _then) = _$AuthUserDtoCopyWithImpl;
@useResult
$Res call({
 String id, String name, String email
});




}
/// @nodoc
class _$AuthUserDtoCopyWithImpl<$Res>
    implements $AuthUserDtoCopyWith<$Res> {
  _$AuthUserDtoCopyWithImpl(this._self, this._then);

  final AuthUserDto _self;
  final $Res Function(AuthUserDto) _then;

/// Create a copy of AuthUserDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? email = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [AuthUserDto].
extension AuthUserDtoPatterns on AuthUserDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AuthUserDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AuthUserDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AuthUserDto value)  $default,){
final _that = this;
switch (_that) {
case _AuthUserDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AuthUserDto value)?  $default,){
final _that = this;
switch (_that) {
case _AuthUserDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String email)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AuthUserDto() when $default != null:
return $default(_that.id,_that.name,_that.email);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String email)  $default,) {final _that = this;
switch (_that) {
case _AuthUserDto():
return $default(_that.id,_that.name,_that.email);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String email)?  $default,) {final _that = this;
switch (_that) {
case _AuthUserDto() when $default != null:
return $default(_that.id,_that.name,_that.email);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AuthUserDto implements AuthUserDto {
  const _AuthUserDto({required this.id, required this.name, required this.email});
  factory _AuthUserDto.fromJson(Map<String, dynamic> json) => _$AuthUserDtoFromJson(json);

@override final  String id;
@override final  String name;
@override final  String email;

/// Create a copy of AuthUserDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AuthUserDtoCopyWith<_AuthUserDto> get copyWith => __$AuthUserDtoCopyWithImpl<_AuthUserDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AuthUserDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AuthUserDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.email, email) || other.email == email));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,email);

@override
String toString() {
  return 'AuthUserDto(id: $id, name: $name, email: $email)';
}


}

/// @nodoc
abstract mixin class _$AuthUserDtoCopyWith<$Res> implements $AuthUserDtoCopyWith<$Res> {
  factory _$AuthUserDtoCopyWith(_AuthUserDto value, $Res Function(_AuthUserDto) _then) = __$AuthUserDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String email
});




}
/// @nodoc
class __$AuthUserDtoCopyWithImpl<$Res>
    implements _$AuthUserDtoCopyWith<$Res> {
  __$AuthUserDtoCopyWithImpl(this._self, this._then);

  final _AuthUserDto _self;
  final $Res Function(_AuthUserDto) _then;

/// Create a copy of AuthUserDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? email = null,}) {
  return _then(_AuthUserDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$AuthResponseDto {

 String get accessToken; String get tokenType; int get expiresIn; AuthUserDto get user;
/// Create a copy of AuthResponseDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthResponseDtoCopyWith<AuthResponseDto> get copyWith => _$AuthResponseDtoCopyWithImpl<AuthResponseDto>(this as AuthResponseDto, _$identity);

  /// Serializes this AuthResponseDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthResponseDto&&(identical(other.accessToken, accessToken) || other.accessToken == accessToken)&&(identical(other.tokenType, tokenType) || other.tokenType == tokenType)&&(identical(other.expiresIn, expiresIn) || other.expiresIn == expiresIn)&&(identical(other.user, user) || other.user == user));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,accessToken,tokenType,expiresIn,user);

@override
String toString() {
  return 'AuthResponseDto(accessToken: $accessToken, tokenType: $tokenType, expiresIn: $expiresIn, user: $user)';
}


}

/// @nodoc
abstract mixin class $AuthResponseDtoCopyWith<$Res>  {
  factory $AuthResponseDtoCopyWith(AuthResponseDto value, $Res Function(AuthResponseDto) _then) = _$AuthResponseDtoCopyWithImpl;
@useResult
$Res call({
 String accessToken, String tokenType, int expiresIn, AuthUserDto user
});


$AuthUserDtoCopyWith<$Res> get user;

}
/// @nodoc
class _$AuthResponseDtoCopyWithImpl<$Res>
    implements $AuthResponseDtoCopyWith<$Res> {
  _$AuthResponseDtoCopyWithImpl(this._self, this._then);

  final AuthResponseDto _self;
  final $Res Function(AuthResponseDto) _then;

/// Create a copy of AuthResponseDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? accessToken = null,Object? tokenType = null,Object? expiresIn = null,Object? user = null,}) {
  return _then(_self.copyWith(
accessToken: null == accessToken ? _self.accessToken : accessToken // ignore: cast_nullable_to_non_nullable
as String,tokenType: null == tokenType ? _self.tokenType : tokenType // ignore: cast_nullable_to_non_nullable
as String,expiresIn: null == expiresIn ? _self.expiresIn : expiresIn // ignore: cast_nullable_to_non_nullable
as int,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as AuthUserDto,
  ));
}
/// Create a copy of AuthResponseDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AuthUserDtoCopyWith<$Res> get user {
  
  return $AuthUserDtoCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}


/// Adds pattern-matching-related methods to [AuthResponseDto].
extension AuthResponseDtoPatterns on AuthResponseDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AuthResponseDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AuthResponseDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AuthResponseDto value)  $default,){
final _that = this;
switch (_that) {
case _AuthResponseDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AuthResponseDto value)?  $default,){
final _that = this;
switch (_that) {
case _AuthResponseDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String accessToken,  String tokenType,  int expiresIn,  AuthUserDto user)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AuthResponseDto() when $default != null:
return $default(_that.accessToken,_that.tokenType,_that.expiresIn,_that.user);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String accessToken,  String tokenType,  int expiresIn,  AuthUserDto user)  $default,) {final _that = this;
switch (_that) {
case _AuthResponseDto():
return $default(_that.accessToken,_that.tokenType,_that.expiresIn,_that.user);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String accessToken,  String tokenType,  int expiresIn,  AuthUserDto user)?  $default,) {final _that = this;
switch (_that) {
case _AuthResponseDto() when $default != null:
return $default(_that.accessToken,_that.tokenType,_that.expiresIn,_that.user);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AuthResponseDto implements AuthResponseDto {
  const _AuthResponseDto({required this.accessToken, this.tokenType = 'Bearer', required this.expiresIn, required this.user});
  factory _AuthResponseDto.fromJson(Map<String, dynamic> json) => _$AuthResponseDtoFromJson(json);

@override final  String accessToken;
@override@JsonKey() final  String tokenType;
@override final  int expiresIn;
@override final  AuthUserDto user;

/// Create a copy of AuthResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AuthResponseDtoCopyWith<_AuthResponseDto> get copyWith => __$AuthResponseDtoCopyWithImpl<_AuthResponseDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AuthResponseDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AuthResponseDto&&(identical(other.accessToken, accessToken) || other.accessToken == accessToken)&&(identical(other.tokenType, tokenType) || other.tokenType == tokenType)&&(identical(other.expiresIn, expiresIn) || other.expiresIn == expiresIn)&&(identical(other.user, user) || other.user == user));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,accessToken,tokenType,expiresIn,user);

@override
String toString() {
  return 'AuthResponseDto(accessToken: $accessToken, tokenType: $tokenType, expiresIn: $expiresIn, user: $user)';
}


}

/// @nodoc
abstract mixin class _$AuthResponseDtoCopyWith<$Res> implements $AuthResponseDtoCopyWith<$Res> {
  factory _$AuthResponseDtoCopyWith(_AuthResponseDto value, $Res Function(_AuthResponseDto) _then) = __$AuthResponseDtoCopyWithImpl;
@override @useResult
$Res call({
 String accessToken, String tokenType, int expiresIn, AuthUserDto user
});


@override $AuthUserDtoCopyWith<$Res> get user;

}
/// @nodoc
class __$AuthResponseDtoCopyWithImpl<$Res>
    implements _$AuthResponseDtoCopyWith<$Res> {
  __$AuthResponseDtoCopyWithImpl(this._self, this._then);

  final _AuthResponseDto _self;
  final $Res Function(_AuthResponseDto) _then;

/// Create a copy of AuthResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? accessToken = null,Object? tokenType = null,Object? expiresIn = null,Object? user = null,}) {
  return _then(_AuthResponseDto(
accessToken: null == accessToken ? _self.accessToken : accessToken // ignore: cast_nullable_to_non_nullable
as String,tokenType: null == tokenType ? _self.tokenType : tokenType // ignore: cast_nullable_to_non_nullable
as String,expiresIn: null == expiresIn ? _self.expiresIn : expiresIn // ignore: cast_nullable_to_non_nullable
as int,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as AuthUserDto,
  ));
}

/// Create a copy of AuthResponseDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AuthUserDtoCopyWith<$Res> get user {
  
  return $AuthUserDtoCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}

// dart format on
