import 'dart:typed_data';

import 'package:dart_orpc/dart_orpc.dart';

part 'challenge_dtos.g.dart';

final class HealthResponseDto {
  const HealthResponseDto({
    required this.status,
    required this.database,
    required this.uptimeSeconds,
  });

  final String status;
  final String database;
  final int uptimeSeconds;

  factory HealthResponseDto.fromJson(Map<String, dynamic> json) =>
      HealthResponseDto(
        status: json['status'] as String,
        database: json['db'] as String,
        uptimeSeconds: json['uptime_s'] as int,
      );

  Map<String, Object?> toJson() => {
    'status': status,
    'db': database,
    'uptime_s': uptimeSeconds,
  };
}

final class PostDto {
  const PostDto({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.author,
    required this.likeCount,
  });

  final int id;
  final String body;
  final String createdAt;
  final String author;
  final int likeCount;

  factory PostDto.fromJson(Map<String, dynamic> json) => PostDto(
    id: json['id'] as int,
    body: json['body'] as String,
    createdAt: json['created_at'] as String,
    author: json['author'] as String,
    likeCount: json['like_count'] as int,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'body': body,
    'created_at': createdAt,
    'author': author,
    'like_count': likeCount,
  };
}

final class FeedResponseDto implements RpcJsonBytes {
  const FeedResponseDto(this.posts);

  final List<PostDto> posts;

  factory FeedResponseDto.fromJson(Map<String, dynamic> json) =>
      FeedResponseDto(
        (json['posts'] as List<Object?>)
            .map(
              (post) => PostDto.fromJson(
                Map<String, dynamic>.from(post as Map<Object?, Object?>),
              ),
            )
            .toList(growable: false),
      );

  Map<String, Object?> toJson() => {
    'posts': [for (final post in posts) post.toJson()],
  };

  @override
  List<int> toJsonBytes() {
    final writer = _JsonBytesWriter();
    writer..writeAscii('{"posts":[');
    for (var index = 0; index < posts.length; index++) {
      if (index > 0) {
        writer.writeAscii(',');
      }
      _writePostJson(writer, posts[index]);
    }
    writer.writeAscii(']}');
    return writer.takeBytes();
  }
}

class PostResponseDto implements RpcJsonBytes {
  const PostResponseDto(this.post);

  final PostDto post;

  factory PostResponseDto.fromJson(Map<String, dynamic> json) =>
      PostResponseDto(
        PostDto.fromJson(
          Map<String, dynamic>.from(json['post'] as Map<Object?, Object?>),
        ),
      );

  Map<String, Object?> toJson() => {'post': post.toJson()};

  @override
  List<int> toJsonBytes() {
    final writer = _JsonBytesWriter();
    writer.writeAscii('{"post":');
    _writePostJson(writer, post);
    writer.writeAscii('}');
    return writer.takeBytes();
  }
}

final class CreatePostResponseDto extends PostResponseDto {
  const CreatePostResponseDto(super.post);

  factory CreatePostResponseDto.fromJson(Map<String, dynamic> json) =>
      CreatePostResponseDto(
        PostDto.fromJson(
          Map<String, dynamic>.from(json['post'] as Map<Object?, Object?>),
        ),
      );
}

final class LikeResponseDto {
  const LikeResponseDto({
    required this.liked,
    required this.alreadyLiked,
    required this.postId,
  });

  final bool liked;
  final bool alreadyLiked;
  final int postId;

  factory LikeResponseDto.fromJson(Map<String, dynamic> json) =>
      LikeResponseDto(
        liked: json['liked'] as bool,
        alreadyLiked: json['already_liked'] as bool,
        postId: json['post_id'] as int,
      );

  Map<String, Object?> toJson() => {
    'liked': liked,
    'already_liked': alreadyLiked,
    'post_id': postId,
  };
}

void _writePostJson(_JsonBytesWriter writer, PostDto post) {
  writer
    ..writeAscii('{"id":')
    ..writeInteger(post.id)
    ..writeAscii(',"body":')
    ..writeString(post.body)
    ..writeAscii(',"created_at":')
    ..writeString(post.createdAt)
    ..writeAscii(',"author":')
    ..writeString(post.author)
    ..writeAscii(',"like_count":')
    ..writeInteger(post.likeCount)
    ..writeAscii('}');
}

final class _JsonBytesWriter {
  static const _hexDigits = '0123456789abcdef';

  final BytesBuilder _bytes = BytesBuilder(copy: false);

  void writeAscii(String value) {
    for (var index = 0; index < value.length; index++) {
      _bytes.addByte(value.codeUnitAt(index));
    }
  }

  void writeInteger(int value) => writeAscii(value.toString());

  void writeString(String value) {
    _bytes.addByte(0x22);
    for (var index = 0; index < value.length; index++) {
      final firstCodeUnit = value.codeUnitAt(index);
      if (_isHighSurrogate(firstCodeUnit) && index + 1 < value.length) {
        final secondCodeUnit = value.codeUnitAt(index + 1);
        if (_isLowSurrogate(secondCodeUnit)) {
          final codePoint =
              0x10000 +
              ((firstCodeUnit - 0xd800) << 10) +
              (secondCodeUnit - 0xdc00);
          _writeCodePoint(codePoint);
          index++;
          continue;
        }
      }

      _writeCodePoint(_isSurrogate(firstCodeUnit) ? 0xfffd : firstCodeUnit);
    }
    _bytes.addByte(0x22);
  }

  void _writeCodePoint(int codePoint) {
    switch (codePoint) {
      case 0x22:
        _bytes.add(const [0x5c, 0x22]);
        return;
      case 0x5c:
        _bytes.add(const [0x5c, 0x5c]);
        return;
      case 0x08:
        _bytes.add(const [0x5c, 0x62]);
        return;
      case 0x0c:
        _bytes.add(const [0x5c, 0x66]);
        return;
      case 0x0a:
        _bytes.add(const [0x5c, 0x6e]);
        return;
      case 0x0d:
        _bytes.add(const [0x5c, 0x72]);
        return;
      case 0x09:
        _bytes.add(const [0x5c, 0x74]);
        return;
    }

    if (codePoint < 0x20) {
      _bytes.add(const [0x5c, 0x75, 0x30, 0x30]);
      _bytes.addByte(_hexDigits.codeUnitAt(codePoint >> 4));
      _bytes.addByte(_hexDigits.codeUnitAt(codePoint & 0x0f));
      return;
    }

    if (codePoint <= 0x7f) {
      _bytes.addByte(codePoint);
    } else if (codePoint <= 0x7ff) {
      _bytes
        ..addByte(0xc0 | (codePoint >> 6))
        ..addByte(0x80 | (codePoint & 0x3f));
    } else if (codePoint <= 0xffff) {
      _bytes
        ..addByte(0xe0 | (codePoint >> 12))
        ..addByte(0x80 | ((codePoint >> 6) & 0x3f))
        ..addByte(0x80 | (codePoint & 0x3f));
    } else {
      _bytes
        ..addByte(0xf0 | (codePoint >> 18))
        ..addByte(0x80 | ((codePoint >> 12) & 0x3f))
        ..addByte(0x80 | ((codePoint >> 6) & 0x3f))
        ..addByte(0x80 | (codePoint & 0x3f));
    }
  }

  List<int> takeBytes() => _bytes.takeBytes();
}

bool _isSurrogate(int codeUnit) => codeUnit >= 0xd800 && codeUnit <= 0xdfff;

bool _isHighSurrogate(int codeUnit) => codeUnit >= 0xd800 && codeUnit <= 0xdbff;

bool _isLowSurrogate(int codeUnit) => codeUnit >= 0xdc00 && codeUnit <= 0xdfff;
