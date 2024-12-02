import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'main.dart';
import 'dart:convert';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/services.dart';

late Interpreter interpreter;
List<double> outputData = []; // Added global variable for inference results

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool isWorking = false;
  String result = '';
  CameraController? cameraController;
  CameraImage? imgCamera;

  void initCamera() {
    cameraController = CameraController(cameras![0], ResolutionPreset.medium);
    cameraController!.initialize().then((value) {
      if (!mounted) {
        return;
      }

      setState(() {
        cameraController!.startImageStream((imageFrontStream) {
          if (!isWorking) {
            isWorking = true;
            imgCamera = imageFrontStream;
            print("Camera image captured: ${imgCamera != null}");
            runModelOnStreamFrames(imgCamera!); // Pass imgCamera to the method
          }
        });
      });
    });
  }

  void loadModel() async {
    try {
      interpreter = await Interpreter.fromAsset('model_unquant.tflite');
      print('Model loaded successfully');
    } catch (e) {
      print('Failed to load model: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  @override
  void dispose() {
    interpreter.close();
    cameraController?.dispose();
    super.dispose();
  }

  Uint8List preprocess(CameraImage cameraImage) {
    // Convert the camera image to a format usable by the model.
    img.Image image = img.Image.fromBytes(
      width: cameraImage.width,
      height: cameraImage.height,
      bytes: cameraImage.planes[0].bytes.buffer
          .asUint8List()
          .buffer, // Use .buffer to get ByteBuffer
    );

    // Resize image to 224x224
    img.Image resizedImage = img.copyResize(image, width: 224, height: 224);

    // Normalize pixel values to [-1, 1]
// Normalize pixel values to [-1, 1]
// Normalize pixel values to [-1, 1]
    List<double> normalized = [];
    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        // Get the pixel value at position (x, y)
        img.Pixel pixel = resizedImage.getPixel(x, y); // Get the Pixel object

        // Extract RGB components from the Pixel object
        int r = pixel.r.toInt(); // Red channel, cast to int
        int g = pixel.g.toInt(); // Green channel, cast to int
        int b = pixel.b.toInt(); // Blue channel, cast to int

        // Normalize each channel to the range [-1, 1]
        normalized.add(r / 127.5 - 1.0);
        normalized.add(g / 127.5 - 1.0);
        normalized.add(b / 127.5 - 1.0);
      }
    }

    return Uint8List.fromList(
        normalized.map((e) => (e * 127.5 + 127.5).toInt()).toList());
  }

  void runInference(Uint8List input) {
    // Allocate input and output tensors
    var inputTensor = interpreter.getInputTensor(0);
    var outputTensor = interpreter.getOutputTensor(0);
    var outputShape = outputTensor.shape;
    outputData = List.filled(outputShape.reduce((a, b) => a * b), 0.0);

    // Perform inference
    interpreter.run(input, outputData);

    // Process results
    print('Inference results: $outputData');
  }

  Future<List<String>> loadLabels() async {
    final labelData = await rootBundle.loadString('assets/labels.txt');
    return LineSplitter().convert(labelData);
  }

  void processResults(List<double> output, List<String> labels) {
    final predictions = List.generate(
      output.length,
      (i) => {'label': labels[i], 'confidence': output[i]},
    );

    predictions.sort((a, b) {
      // Use null-aware operators to handle potential null values
      double aConfidence =
          (a['confidence'] as double?) ?? 0.0; // Cast to double
      double bConfidence =
          (b['confidence'] as double?) ?? 0.0; // Cast to double
      return bConfidence.compareTo(aConfidence);
    });

    setState(() {
      result = predictions
          .take(5)
          .map((e) => '${e['label']}: ${e['confidence']}')
          .join('\n');
    });
    print('Top predictions: $result');
  }

  void runModelOnStreamFrames(CameraImage imgCamera) async {
    // Preprocess the image
    Uint8List input = preprocess(imgCamera);

    // Run inference
    runInference(input);

    // Process and display results
    List<String> labels = await loadLabels();
    processResults(outputData, labels);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Fruit and Vegie Detector'),
          backgroundColor: Color.fromARGB(255, 255, 184, 18),
          centerTitle: true,
        ),
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
                image: AssetImage('assets/fruit1.jpg'), fit: BoxFit.fill),
          ),
          child: Column(
            children: [
              Stack(
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 100.0),
                      height: 220,
                      width: 320,
                      child: Image.asset('assets/fruit2.jpg'),
                    ),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        initCamera();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(top: 65),
                        height: 270,
                        width: 360,
                        child: imgCamera == null
                            ? Container(
                                height: 270,
                                width: 360,
                                child: Icon(
                                  Icons.photo_camera_front,
                                  color: Colors.pink,
                                  size: 60,
                                ),
                              )
                            : AspectRatio(
                                aspectRatio:
                                    cameraController!.value.aspectRatio,
                                child: CameraPreview(cameraController!),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 55.0),
                  child: SingleChildScrollView(
                    child: Text(
                      result,
                      style: const TextStyle(
                        backgroundColor: Colors.black,
                        fontSize: 25.0,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
