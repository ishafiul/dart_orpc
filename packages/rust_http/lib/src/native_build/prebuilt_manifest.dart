// The prebuilt native libraries this version of rust_http downloads.
//
// Written by `dart run tool/prebuilt.dart update` after the rust_http
// prebuilt workflow has published a release. Do not edit by hand.

import 'prebuilt_release.dart';

/// The release whose libraries match this package's Rust sources, or null
/// when none has been published yet.
const PrebuiltRelease? prebuiltRelease = PrebuiltRelease(
  tag: 'rust_http-native-89fb6c123572dc7b',
  fingerprint: '89fb6c123572dc7baea04c86e5810d10a228996f13ade0e4f2180adcb9b914a9',
  sha256ByAsset: {
      'linux-arm64-librust_http.so': '3f6d35e00648c1573fc8f682670e0e212cdeb266ccf265c0eaeefa295a2d8fff',
      'linux-x64-librust_http.so': '8ea2475bd50264683dbd97f487d46615d84ecfdede0f7627713f5f26798315cf',
      'macos-arm64-librust_http.dylib': '695386094f43b4fc3bb2b75f5a182773b47357bea135388b6661ae4a78dbd8a1',
      'macos-x64-librust_http.dylib': '829e60f414a309210eadb9b978d0ced7fe843c4fd769c18e2fc12f78637c6503',
      'windows-x64-rust_http.dll': '6c2a28239cb18d3b71b527ffb6d7d1de32e8b719cb7e0d7a39a9680709600dd6',
  },
);
