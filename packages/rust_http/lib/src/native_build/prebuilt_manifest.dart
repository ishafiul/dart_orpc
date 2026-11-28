// The prebuilt native libraries this version of rust_http downloads.
//
// Written by `dart run tool/prebuilt.dart update` after the rust_http
// prebuilt workflow has published a release. Do not edit by hand.

import 'prebuilt_release.dart';

/// The release whose libraries match this package's Rust sources, or null
/// when none has been published yet.
const PrebuiltRelease? prebuiltRelease = PrebuiltRelease(
  tag: 'rust_http-native-5bb39373f185b1b1',
  fingerprint: '5bb39373f185b1b1776aad019bea3a15ddf9782b99765d37c5593b4fca469f44',
  sha256ByAsset: {
      'linux-arm64-librust_http.so': 'b4f15cff41f38f0d9cdb2fafeda200bae68bf3e39c5a2378293bf940e257a263',
      'linux-x64-librust_http.so': '8dd1e0b03c0484d7be9e8e64798437afe7be3454b94030f2844e09aaa47890ee',
      'macos-arm64-librust_http.dylib': '98447e0167be9926dae8c42656971505cbd542e50d653e836fc84b3cc737cbfb',
      'macos-x64-librust_http.dylib': '356881e07acbbca618a18e5cb328e0f6165202d7e3d611d8f44a522be2f4b5ce',
      'windows-x64-rust_http.dll': '347b03b8243b3193dd89be7f1bf745be096024bd461d806e2cda5732a1707f28',
  },
);
