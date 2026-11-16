// The prebuilt native libraries this version of rust_http downloads.
//
// Written by `dart run tool/prebuilt.dart update` after the rust_http
// prebuilt workflow has published a release. Do not edit by hand.

import 'prebuilt_release.dart';

/// The release whose libraries match this package's Rust sources, or null
/// when none has been published yet.
const PrebuiltRelease? prebuiltRelease = PrebuiltRelease(
  tag: 'rust_http-native-ed34a924f031458a',
  fingerprint: 'ed34a924f031458a9f153eb32b003c393e5aff88b8f2c530cf0545af369df7b4',
  sha256ByAsset: {
      'linux-arm64-librust_http.so': 'af0f8cca15ab8e998fde46fc5fdcc2c1da7c9571de3dd31dbca71ef4860ca850',
      'linux-x64-librust_http.so': '776ba0f9fdc1689a225d282b07f62b5fb61a33843b856066c55ae8ee5b9509a1',
      'macos-arm64-librust_http.dylib': 'b3398d67491d9d644443cbae9cb0d64c860806d66f9a78440b0005506268bda4',
      'macos-x64-librust_http.dylib': '0731aec4942ce3a5200116f3ef31d2c1e97c39ab712d54fe7d05b86c3b46dd9f',
      'windows-x64-rust_http.dll': '62f15ce9df3c105f0c9ed6082047c932879bece6fea52b97069affb1eaba7fc6',
  },
);
