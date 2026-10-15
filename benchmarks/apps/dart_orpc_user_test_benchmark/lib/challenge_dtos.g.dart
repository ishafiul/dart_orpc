// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'challenge_dtos.dart';

// **************************************************************************
// RpcDtoFieldRefGenerator
// **************************************************************************

abstract final class HealthResponseDtoFields {
  static const database = RpcInputField<HealthResponseDto>('database');
  static const status = RpcInputField<HealthResponseDto>('status');
  static const uptimeSeconds = RpcInputField<HealthResponseDto>(
    'uptimeSeconds',
  );
}

abstract final class PostDtoFields {
  static const author = RpcInputField<PostDto>('author');
  static const body = RpcInputField<PostDto>('body');
  static const createdAt = RpcInputField<PostDto>('createdAt');
  static const id = RpcInputField<PostDto>('id');
  static const likeCount = RpcInputField<PostDto>('likeCount');
}

abstract final class FeedResponseDtoFields {
  static const posts = RpcInputField<FeedResponseDto>('posts');
}

abstract final class PostResponseDtoFields {
  static const post = RpcInputField<PostResponseDto>('post');
}

abstract final class LikeResponseDtoFields {
  static const alreadyLiked = RpcInputField<LikeResponseDto>('alreadyLiked');
  static const liked = RpcInputField<LikeResponseDto>('liked');
  static const postId = RpcInputField<LikeResponseDto>('postId');
}
