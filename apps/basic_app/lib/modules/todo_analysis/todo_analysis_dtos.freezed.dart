// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'todo_analysis_dtos.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TodoAnalysisSummaryDto {

 int get total; int get completed; int get pending; double get completionRate;
/// Create a copy of TodoAnalysisSummaryDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TodoAnalysisSummaryDtoCopyWith<TodoAnalysisSummaryDto> get copyWith => _$TodoAnalysisSummaryDtoCopyWithImpl<TodoAnalysisSummaryDto>(this as TodoAnalysisSummaryDto, _$identity);

  /// Serializes this TodoAnalysisSummaryDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TodoAnalysisSummaryDto&&(identical(other.total, total) || other.total == total)&&(identical(other.completed, completed) || other.completed == completed)&&(identical(other.pending, pending) || other.pending == pending)&&(identical(other.completionRate, completionRate) || other.completionRate == completionRate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,total,completed,pending,completionRate);

@override
String toString() {
  return 'TodoAnalysisSummaryDto(total: $total, completed: $completed, pending: $pending, completionRate: $completionRate)';
}


}

/// @nodoc
abstract mixin class $TodoAnalysisSummaryDtoCopyWith<$Res>  {
  factory $TodoAnalysisSummaryDtoCopyWith(TodoAnalysisSummaryDto value, $Res Function(TodoAnalysisSummaryDto) _then) = _$TodoAnalysisSummaryDtoCopyWithImpl;
@useResult
$Res call({
 int total, int completed, int pending, double completionRate
});




}
/// @nodoc
class _$TodoAnalysisSummaryDtoCopyWithImpl<$Res>
    implements $TodoAnalysisSummaryDtoCopyWith<$Res> {
  _$TodoAnalysisSummaryDtoCopyWithImpl(this._self, this._then);

  final TodoAnalysisSummaryDto _self;
  final $Res Function(TodoAnalysisSummaryDto) _then;

/// Create a copy of TodoAnalysisSummaryDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? total = null,Object? completed = null,Object? pending = null,Object? completionRate = null,}) {
  return _then(_self.copyWith(
total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,completed: null == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as int,pending: null == pending ? _self.pending : pending // ignore: cast_nullable_to_non_nullable
as int,completionRate: null == completionRate ? _self.completionRate : completionRate // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [TodoAnalysisSummaryDto].
extension TodoAnalysisSummaryDtoPatterns on TodoAnalysisSummaryDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TodoAnalysisSummaryDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TodoAnalysisSummaryDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TodoAnalysisSummaryDto value)  $default,){
final _that = this;
switch (_that) {
case _TodoAnalysisSummaryDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TodoAnalysisSummaryDto value)?  $default,){
final _that = this;
switch (_that) {
case _TodoAnalysisSummaryDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int total,  int completed,  int pending,  double completionRate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TodoAnalysisSummaryDto() when $default != null:
return $default(_that.total,_that.completed,_that.pending,_that.completionRate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int total,  int completed,  int pending,  double completionRate)  $default,) {final _that = this;
switch (_that) {
case _TodoAnalysisSummaryDto():
return $default(_that.total,_that.completed,_that.pending,_that.completionRate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int total,  int completed,  int pending,  double completionRate)?  $default,) {final _that = this;
switch (_that) {
case _TodoAnalysisSummaryDto() when $default != null:
return $default(_that.total,_that.completed,_that.pending,_that.completionRate);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TodoAnalysisSummaryDto implements TodoAnalysisSummaryDto {
  const _TodoAnalysisSummaryDto({required this.total, required this.completed, required this.pending, required this.completionRate});
  factory _TodoAnalysisSummaryDto.fromJson(Map<String, dynamic> json) => _$TodoAnalysisSummaryDtoFromJson(json);

@override final  int total;
@override final  int completed;
@override final  int pending;
@override final  double completionRate;

/// Create a copy of TodoAnalysisSummaryDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TodoAnalysisSummaryDtoCopyWith<_TodoAnalysisSummaryDto> get copyWith => __$TodoAnalysisSummaryDtoCopyWithImpl<_TodoAnalysisSummaryDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TodoAnalysisSummaryDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TodoAnalysisSummaryDto&&(identical(other.total, total) || other.total == total)&&(identical(other.completed, completed) || other.completed == completed)&&(identical(other.pending, pending) || other.pending == pending)&&(identical(other.completionRate, completionRate) || other.completionRate == completionRate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,total,completed,pending,completionRate);

@override
String toString() {
  return 'TodoAnalysisSummaryDto(total: $total, completed: $completed, pending: $pending, completionRate: $completionRate)';
}


}

/// @nodoc
abstract mixin class _$TodoAnalysisSummaryDtoCopyWith<$Res> implements $TodoAnalysisSummaryDtoCopyWith<$Res> {
  factory _$TodoAnalysisSummaryDtoCopyWith(_TodoAnalysisSummaryDto value, $Res Function(_TodoAnalysisSummaryDto) _then) = __$TodoAnalysisSummaryDtoCopyWithImpl;
@override @useResult
$Res call({
 int total, int completed, int pending, double completionRate
});




}
/// @nodoc
class __$TodoAnalysisSummaryDtoCopyWithImpl<$Res>
    implements _$TodoAnalysisSummaryDtoCopyWith<$Res> {
  __$TodoAnalysisSummaryDtoCopyWithImpl(this._self, this._then);

  final _TodoAnalysisSummaryDto _self;
  final $Res Function(_TodoAnalysisSummaryDto) _then;

/// Create a copy of TodoAnalysisSummaryDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? total = null,Object? completed = null,Object? pending = null,Object? completionRate = null,}) {
  return _then(_TodoAnalysisSummaryDto(
total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,completed: null == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as int,pending: null == pending ? _self.pending : pending // ignore: cast_nullable_to_non_nullable
as int,completionRate: null == completionRate ? _self.completionRate : completionRate // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
