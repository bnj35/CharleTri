
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'classifier_category.dart';
import 'classifier_model.dart';

typedef ClassifierLabels = List<String>;

class Classifier {
  final ClassifierLabels _labels;
  final ClassifierModel _model;

  Classifier._({
    required ClassifierLabels labels,
    required ClassifierModel model,
  })  : _labels = labels,
        _model = model;

  static Future<Classifier?> loadWith({
    required String labelsFileName,
    required String modelFileName,
  }) async {
    try {
      final labels = await _loadLabels(labelsFileName);
      final model = await _loadModel(modelFileName);
      return Classifier._(labels: labels, model: model);
    } catch (e) {
      debugPrint('Can\'t initialize Classifier: ${e.toString()}');
      if (e is Error) {
        debugPrintStack(stackTrace: e.stackTrace);
      }
      return null;
    }
  }

  static Future<ClassifierModel> _loadModel(String modelFileName) async {
    try {
      debugPrint('Attempting to load model from asset: assets/$modelFileName');

      final options = InterpreterOptions()
        ..threads = 1
        ..useNnApiForAndroid = false;

      final interpreter = await Interpreter.fromAsset(
        'assets/$modelFileName',
        options: options,
      );

      interpreter.allocateTensors();

      debugPrint('Interpreter created successfully');

      final inputShape = interpreter.getInputTensor(0).shape;
      final outputShape = interpreter.getOutputTensor(0).shape;
      final inputType = interpreter.getInputTensor(0).type;
      final outputType = interpreter.getOutputTensor(0).type;

      debugPrint('Input shape: $inputShape');
      debugPrint('Output shape: $outputShape');
      debugPrint('Input type: $inputType');
      debugPrint('Output type: $outputType');

      return ClassifierModel(
        interpreter: interpreter,
        inputShape: inputShape,
        outputShape: outputShape,
        inputType: inputType,
        outputType: outputType,
      );
    } catch (e, stackTrace) {
      debugPrint('Error loading model: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  static Future<ClassifierLabels> _loadLabels(String labelsFileName) async {
    try {
      final labelsData = await rootBundle.loadString('assets/$labelsFileName');
      final labels = labelsData
          .split('\n')
          .where((label) => label.isNotEmpty)
          .map((label) {
        final spaceIndex = label.indexOf(' ');
        return spaceIndex == -1
            ? label.trim()
            : label.substring(spaceIndex).trim();
      }).toList();

      debugPrint('Labels loaded successfully: $labels');
      return labels;
    } catch (e, stackTrace) {
      debugPrint('Error loading labels: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  void close() {
    _model.interpreter.close();
  }

  // Run inference on an input image and return the top classification result
  ClassifierCategory predict(img.Image image) {
    debugPrint(
      'Image: ${image.width}x${image.height}, size: ${image.length} bytes',
    );

    try {
      // Preprocess the image to match model input requirements
      final processedImageData = _preProcessInput(image);
      debugPrint('Processed data length: ${processedImageData.length}');

      // Reshape processed image data to fit the expected input tensor shape [1, 224, 224, 3]
      final inputBuffer = processedImageData.reshape([1, 224, 224, 3]);

      // Create an output buffer to store the model's predictions, assuming output shape [1, 4]
      final outputBuffer = List.generate(1, (_) => List.filled(2, 0.0));

      debugPrint('Running inference...');
      debugPrint('Model expected input shape: ${_model.inputShape}');
      debugPrint('Model expected output shape: ${_model.outputShape}');

      // Run inference using the TensorFlow Lite model
      _model.interpreter.run(inputBuffer, outputBuffer);

      debugPrint('Raw output: $outputBuffer');

      // Flatten the output buffer to a Float32List for easier processing
      final flattenedOutput = Float32List.fromList(outputBuffer[0]);

      // Process the output to extract category probabilities and sort them
      final resultCategories = _postProcessOutput(flattenedOutput);
      final topResult =
          resultCategories.first; // Get the top classification result

      debugPrint('Top category: $topResult');
      return topResult;
    } catch (e, stackTrace) {
      debugPrint('Error during inference: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  List<ClassifierCategory> _postProcessOutput(Float32List outputBuffer) {
    final List<double> probabilities = outputBuffer.toList();
    final categoryList = <ClassifierCategory>[];

    for (var i = 0; i < _labels.length; i++) {
      final category = ClassifierCategory(_labels[i], probabilities[i]);
      categoryList.add(category);
      debugPrint('label: ${category.label}, score: ${category.score}');
    }

    categoryList.sort((a, b) => b.score.compareTo(a.score));
    return categoryList;
  }

  Float32List _preProcessInput(img.Image image) {
    final minLength = min(image.width, image.height);
    final cropX = (image.width - minLength) ~/ 2;
    final cropY = (image.height - minLength) ~/ 2;
    final croppedImage = img.copyCrop(image,
        x: cropX, y: cropY, width: minLength, height: minLength);
    final resizedImage = img.copyResize(croppedImage,
        width: 224, height: 224, interpolation: img.Interpolation.linear);

    final processedData = Float32List(1 * 224 * 224 * 3);

    for (var y = 0; y < 224; y++) {
      for (var x = 0; x < 224; x++) {
        final pixel = resizedImage.getPixel(x, y);
        final offset = (y * 224 * 3) + (x * 3);

        processedData[offset] = (pixel.r.toDouble() - 127.5) / 127.5;
        processedData[offset + 1] = (pixel.g.toDouble() - 127.5) / 127.5;
        processedData[offset + 2] = (pixel.b.toDouble() - 127.5) / 127.5;
      }
    }

    return processedData;
  }
}
