import 'package:dart_orpc/dart_orpc.dart';
import 'package:json_annotation/json_annotation.dart';

part 'strip_module.g.dart';

@luthor
// Reject extra keys at deserialization so the test proves Luthor removed them.
@JsonSerializable(disallowUnrecognizedKeys: true)
final class StripDto {
  const StripDto({required this.value});

  factory StripDto.fromJson(Map<String, Object?> json) =>
      _$StripDtoFromJson(json);

  final String value;

  Map<String, Object?> toJson() => _$StripDtoToJson(this);
}

@Controller('strip')
final class StripController {
  @RpcMethod(name: 'echo', path: RestMapping.post('/strip'))
  StripDto echo(@RpcInput() StripDto input) => input;
}

@Module(controllers: [StripController])
final class StripModule {
  const StripModule();
}
