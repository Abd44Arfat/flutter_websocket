// import 'package:flutter/material.dart';
// import 'package:camera/camera.dart';
// import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'dart:typed_data';
// import 'package:flutter/services.dart';

// late List<CameraDescription> cameras;

// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   cameras = await availableCameras();
//   runApp(SignTranslatorApp());
// }

// class SignTranslatorApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Real-Time Sign Translator',
//       theme: ThemeData(primarySwatch: Colors.deepPurple),
//       home: SignTranslator(),
//     );
//   }
// }

// class SignTranslator extends StatefulWidget {
//   @override
//   _SignTranslatorState createState() => _SignTranslatorState();
// }

// class _SignTranslatorState extends State<SignTranslator> {
//   late CameraController _cameraController;
//   late PoseDetector _poseDetector;
//   bool _isDetecting = false;
//   List<List<double>> sequence = [];
//   String result = "Waiting...";

//   @override
//   void initState() {
//     super.initState();
//     _initializeCamera();
//     _poseDetector = PoseDetector(options: PoseDetectorOptions());
//   }

//   Future<void> _initializeCamera() async {
//     _cameraController = CameraController(cameras[0], ResolutionPreset.medium);
//     await _cameraController.initialize();
//     _cameraController.startImageStream((CameraImage image) async {
//       if (_isDetecting) return;
//       _isDetecting = true;
//       await _processImage(image);
//       _isDetecting = false;
//     });
//   }

//   Future<void> _processImage(CameraImage image) async {
//     try {
//       final WriteBuffer allBytes = WriteBuffer();
//       for (Plane plane in image.planes) {
//         allBytes.putUint8List(plane.bytes);
//       }
//       final bytes = allBytes.done().buffer.asUint8List();
//       final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());

//       final inputImage = InputImage.fromBytes(
//         bytes: bytes,
//         inputImageData: InputImageData(
//           size: imageSize,
//           imageRotation: InputImageRotation.rotation0deg,
//           inputImageFormat: InputImageFormat.nv21,
//           planeData: image.planes.map(
//             (Plane plane) => InputImagePlaneMetadata(
//               bytesPerRow: plane.bytesPerRow,
//               height: plane.height,
//               width: plane.width,
//             ),
//           ).toList(),
//         ),
//       );

//       final poses = await _poseDetector.processImage(inputImage);
//       if (poses.isNotEmpty) {
//         final pose = poses.first;
//         final landmarks = pose.landmarks;
//         List<double> keypoints = [];

//         for (final l in landmarks.values) {
//           keypoints.addAll([l.x, l.y, l.z ?? 0.0]);
//         }

//         if (keypoints.length >= 126) {
//           sequence.add(keypoints.sublist(0, 126));
//           if (sequence.length > 30) sequence.removeAt(0);
//         }

//         if (sequence.length == 30) {
//           await _sendToServer(sequence);
//         }
//       }
//     } catch (e) {
//       print("Error processing image: $e");
//     }
//   }

//   Future<void> _sendToServer(List<List<double>> seq) async {
//     try {
//       final response = await http.post(
//         Uri.parse("http://<YOUR-IP>:8000/predict"),
//         headers: {"Content-Type": "application/json"},
//         body: jsonEncode({"sequence": seq}),
//       );

//       if (response.statusCode == 200) {
//         final res = jsonDecode(response.body);
//         setState(() {
//           result = "${res["class"]} (${(res["confidence"] * 100).toStringAsFixed(1)}%)";
//         });
//       } else {
//         print("Server error: ${response.statusCode}");
//       }
//     } catch (e) {
//       print("Error sending to server: $e");
//     }
//   }

//   @override
//   void dispose() {
//     _cameraController.dispose();
//     _poseDetector.close();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text("Real-Time Sign Translator")),
//       body: Column(
//         children: [
//           if (_cameraController.value.isInitialized)
//             AspectRatio(
//               aspectRatio: _cameraController.value.aspectRatio,
//               child: CameraPreview(_cameraController),
//             ),
//           SizedBox(height: 16),
//           Text(result, style: TextStyle(fontSize: 22)),
//         ],
//       ),
//     );
//   }
// }
