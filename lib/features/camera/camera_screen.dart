import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'camera_notifier.dart';

class CameraScreen extends ConsumerWidget {
  final String conversationId;

  const CameraScreen({super.key, required this.conversationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(cameraProvider(conversationId));
    return const Placeholder();
  }
}
