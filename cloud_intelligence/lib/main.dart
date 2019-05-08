import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:camera/camera.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'video_player.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  final db = Firestore.instance;
  db.settings(timestampsInSnapshotsEnabled: true, persistenceEnabled: false);

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  // final IVideoService _videoService = FirestoreVideoService();
  StorageUploadTask _task;

  List<CameraDescription> cameras;
  CameraController controller;
  String imagePath;
  String videoPath;
  VideoPlayerController videoController;
  VoidCallback videoPlayerListener;

  Future _getVideo() async {
    final video = await ImagePicker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      uploadFile(video);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Google Cloud Video Intelligence ML'),
        actions: <Widget>[
          FlatButton(
            textColor: Colors.white,
            onPressed: () {
              _getVideo();
            },
            child: Text("Pick from Gallery"),
          )
        ],
      ),
      body: cameras == null
          ? null
          : Column(
              children: <Widget>[
                Expanded(
                  child: Container(
                    child: Padding(
                      padding: const EdgeInsets.all(1.0),
                      child: Center(
                        child: _cameraPreviewWidget(),
                      ),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      border: Border.all(
                        color: controller != null &&
                                controller.value.isRecordingVideo
                            ? Colors.redAccent
                            : Colors.grey,
                        width: 3.0,
                      ),
                    ),
                  ),
                ),
                _task != null ? Text('Uploading') : _captureControlRowWidget(),
                Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: _task != null
                        ? <Widget>[]
                        : <Widget>[
                            _cameraTogglesRowWidget(),
                          ],
                  ),
                ),
              ],
            ),
    );
  }

  void initializeCamera() async {
    try {
      final cameras = await availableCameras();
      setState(() {
        this.cameras = cameras;
      });
    } on CameraException catch (e) {
      print(e.description);
    }
  }

  IconData getCameraLensIcon(CameraLensDirection direction) {
    switch (direction) {
      case CameraLensDirection.back:
        return Icons.camera_rear;
      case CameraLensDirection.front:
        return Icons.camera_front;
      case CameraLensDirection.external:
        return Icons.camera;
    }
    throw ArgumentError('Unknown lens direction');
  }

  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  /// Display the preview from the camera (or a message if the preview is not available).
  Widget _cameraPreviewWidget() {
    if (controller == null || !controller.value.isInitialized) {
      return const Text(
        'Tap a camera',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24.0,
          fontWeight: FontWeight.w900,
        ),
      );
    } else {
      return AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: CameraPreview(controller),
      );
    }
  }

  /// Display the control bar with buttons to take pictures and record videos.
  Widget _captureControlRowWidget() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      mainAxisSize: MainAxisSize.max,
      children: <Widget>[
        IconButton(
          icon: const Icon(Icons.videocam),
          color: Colors.blue,
          onPressed: controller != null &&
                  controller.value.isInitialized &&
                  !controller.value.isRecordingVideo
              ? onVideoRecordButtonPressed
              : null,
        ),
        IconButton(
          icon: const Icon(Icons.stop),
          color: Colors.red,
          onPressed: controller != null &&
                  controller.value.isInitialized &&
                  controller.value.isRecordingVideo
              ? onStopButtonPressed
              : null,
        )
      ],
    );
  }

  /// Display a row of toggle to select the camera (or a message if no camera is available).
  Widget _cameraTogglesRowWidget() {
    final List<Widget> toggles = <Widget>[];

    if (cameras.isEmpty) {
      return const Text('No camera found');
    } else {
      for (CameraDescription cameraDescription in cameras) {
        toggles.add(
          SizedBox(
            width: 90.0,
            child: RadioListTile<CameraDescription>(
              title: Icon(getCameraLensIcon(cameraDescription.lensDirection)),
              groupValue: controller?.description,
              value: cameraDescription,
              onChanged: controller != null && controller.value.isRecordingVideo
                  ? null
                  : onNewCameraSelected,
            ),
          ),
        );
      }
    }

    return Row(children: toggles);
  }

  String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();

  void showInSnackBar(String message) {
    _scaffoldKey.currentState.showSnackBar(
      SnackBar(content: Text(message), duration: Duration(seconds: 2)),
    );
  }

  void onNewCameraSelected(CameraDescription cameraDescription) async {
    if (controller != null) {
      await controller.dispose();
    }
    controller = CameraController(cameraDescription, ResolutionPreset.high);

    // If the controller is updated then update the UI.
    controller.addListener(() {
      if (mounted) setState(() {});
      if (controller.value.hasError) {
        showInSnackBar('Camera error ${controller.value.errorDescription}');
      }
    });

    try {
      await controller.initialize();
    } on CameraException catch (e) {
      _showCameraException(e);
    }

    if (mounted) {
      setState(() {});
    }
  }

  void onVideoRecordButtonPressed() {
    startVideoRecording().then((String filePath) {
      if (mounted) setState(() {});
    });
  }

  void onStopButtonPressed() {
    stopVideoRecording().then((_) {
      if (mounted) setState(() {});
      if (videoPath != null) {
        uploadFile(File(videoPath));
      }
    });
  }

  Future<String> startVideoRecording() async {
    if (!controller.value.isInitialized) {
      showInSnackBar('Error: select a camera first.');
      return null;
    }

    final Directory extDir = await getTemporaryDirectory();
    final String dirPath = '${extDir.path}/Movies/flutter_test';
    await Directory(dirPath).create(recursive: true);
    final String filePath = '$dirPath/${timestamp()}.mp4';

    if (controller.value.isRecordingVideo) {
      return null;
    }

    try {
      videoPath = filePath;
      await controller.startVideoRecording(filePath);
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
    return filePath;
  }

  Future<void> stopVideoRecording() async {
    if (!controller.value.isRecordingVideo) {
      return null;
    }

    try {
      await controller.stopVideoRecording();
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
  }

  uploadFile(File file) {
    final uuid = Uuid().v4();

    final StorageReference ref = _storage.ref().child("$uuid.mp4");
    final StorageUploadTask task = ref.putFile(
      file,
      StorageMetadata(
        contentType: 'video/mp4',
      ),
    );

    setState(() {
      _task = task;
    });

    task.onComplete.then((value) {
      showInSnackBar('Uploaded Video!');

      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => VideoPlayerWidget(
                  uuid: uuid,
                  file: file,
                )),
      );

      setState(() {
        _task = null;
        videoPath = null;
      });
    }, onError: (error) {
      setState(() {
        _task = null;
        videoPath = null;
      });

      showInSnackBar('Upload Fails');
    });

    showInSnackBar('Uploading Video...');
  }

  void _showCameraException(CameraException e) {
    showInSnackBar('Error: ${e.code}\n${e.description}');
  }
}
