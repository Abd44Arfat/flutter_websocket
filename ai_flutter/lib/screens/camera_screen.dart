import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/websocket_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      model: PoseDetectionModel.base,
    ),
  );
  final WebSocketService _webSocketService = WebSocketService();
  String _prediction = '';
  double _confidence = 0.0;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _webSocketService.connect();
    _webSocketService.predictions.listen((data) {
      setState(() {
        _prediction = data['action'] ?? '';
        _confidence = data['confidence'] ?? 0.0;
      });
    });
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    final status = await Permission.camera.request();
    if (status.isDenied) return;

    _controller = CameraController(
      cameras.first,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.bgra8888,
    );

    await _controller!.initialize();
    if (!mounted) return;

    const frameInterval = Duration(milliseconds: 100);
    DateTime lastProcessed = DateTime.now();

    _controller!.startImageStream((image) {
      if (_isProcessing) return;
      
      final now = DateTime.now();
      if (now.difference(lastProcessed) < frameInterval) return;
      lastProcessed = now;
      
      _isProcessing = true;
      _processImage(image);
    });

    setState(() {});
  }

  Future<void> _processImage(CameraImage image) async {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final InputImageRotation imageRotation = InputImageRotation.rotation0deg;
      final InputImageFormat inputImageFormat = InputImageFormat.bgra8888;

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: imageSize,
          rotation: imageRotation,
          format: inputImageFormat,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      final poses = await _poseDetector.processImage(inputImage);
      if (poses.isNotEmpty) {
        final pose = poses.first;
        final keypoints = _extractKeypoints(pose);
        _webSocketService.sendKeypoints(keypoints);
      }
    } catch (e) {
      print('Error processing image: $e');
    } finally {
      _isProcessing = false;
    }
  }

  List<double> _extractKeypoints(Pose pose) {
    List<double> keypoints = [];
    
    // Extract left hand keypoints
    final leftHandLandmarks = [
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.leftIndex,
      PoseLandmarkType.leftPinky,
      PoseLandmarkType.leftThumb,
    ];

    for (final type in leftHandLandmarks) {
      final landmark = pose.landmarks[type];
      if (landmark != null) {
        keypoints.addAll([landmark.x, landmark.y, landmark.z]);
      } else {
        keypoints.addAll([0.0, 0.0, 0.0]);
      }
    }

    // Extract right hand keypoints
    final rightHandLandmarks = [
      PoseLandmarkType.rightWrist,
      PoseLandmarkType.rightIndex,
      PoseLandmarkType.rightPinky,
      PoseLandmarkType.rightThumb,
    ];

    for (final type in rightHandLandmarks) {
      final landmark = pose.landmarks[type];
      if (landmark != null) {
        keypoints.addAll([landmark.x, landmark.y, landmark.z]);
      } else {
        keypoints.addAll([0.0, 0.0, 0.0]);
      }
    }

    // Pad with zeros if needed
    while (keypoints.length < 126) {
      keypoints.add(0.0);
    }

    return keypoints;
  }

  @override
  void dispose() {
    _controller?.dispose();
    _poseDetector.close();
    _webSocketService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Language Detection'),
      ),
      body: Stack(
        children: [
          CameraPreview(_controller!),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black54,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Prediction: $_prediction',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Confidence: ${(_confidence * 100).toStringAsFixed(2)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 