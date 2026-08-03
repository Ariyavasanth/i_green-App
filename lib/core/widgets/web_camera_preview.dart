/// Cross-platform camera widget.
///
/// On web, uses dart:html getUserMedia API.
/// On mobile, the calling code should use the `camera` package directly.
///
/// This file exports [WebCameraController] and [WebCameraPreview] via
/// conditional imports so that mobile builds don't pull in dart:html.
library;

export 'web_camera_stub.dart'
    if (dart.library.html) 'web_camera_web.dart';
