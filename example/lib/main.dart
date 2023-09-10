import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pencil_kit/pencil_kit.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final PencilKitController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('PencilKit Example'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => controller.clear(),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => controller.save("Demo"),
            ),
          ],
        ),
        body: PencilKit(
          onPencilKitViewCreated: (controller) => this.controller = controller,
          alwaysBounceVertical: false,
          alwaysBounceHorizontal: true,
          isRulerActive: false,
          drawingPolicy: PencilKitIos14DrawingPolicy.anyInput,
          onToolPickerVisibilityChanged: (isVisible) {
            if (kDebugMode) {
              print('isToolPickerVisible $isVisible');
            }
          },
          onRulerActiveChanged: (isRulerActive) {
            if (kDebugMode) {
              print('isRulerActive $isRulerActive');
            }
          },
          backgroundColor: Colors.blue.withOpacity(0.1),
          isOpaque: false,
        ),
      ),
    );
  }
}
