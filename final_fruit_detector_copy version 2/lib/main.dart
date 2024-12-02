import 'package:camera/camera.dart';
import 'package:final_fruit_detector/home.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

List<CameraDescription>? cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Fruit and Vegie Detector',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: Home(),
    );
  }
}
