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
    final writer = RpcJsonWriter();
    writer..writeRaw('{"posts":[');
    for (var index = 0; index < posts.length; index++) {
      if (index > 0) {
        writer.writeRaw(',');
      }
      _writePostJson(writer, posts[index]);
    }
    writer.writeRaw(']}');
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
    final writer = RpcJsonWriter();
    writer.writeRaw('{"post":');
    _writePostJson(writer, post);
    writer.writeRaw('}');
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

void _writePostJson(RpcJsonWriter writer, PostDto post) {
  writer
    ..writeRaw('{"id":')
    ..writeInt(post.id)
    ..writeRaw(',"body":')
    ..writeString(post.body)
    ..writeRaw(',"created_at":')
    ..writeString(post.createdAt)
    ..writeRaw(',"author":')
    ..writeString(post.author)
    ..writeRaw(',"like_count":')
    ..writeInt(post.likeCount)
    ..writeRaw('}');
}
