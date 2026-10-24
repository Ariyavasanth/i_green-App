import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../on_duty/presentation/widgets/on_duty_camera_page.dart';

class SiteVisitCameraPage extends StatelessWidget {
  const SiteVisitCameraPage({
    super.key,
    this.title = 'Capture Photo',
    this.subtitle = '',
    this.camera,
  });

  final String title;
  final String subtitle;
  final CameraDescription? camera;

  @override
  Widget build(BuildContext context) {
    return OnDutyCameraPage(
      title: title,
      subtitle: subtitle,
    );
  }
}

