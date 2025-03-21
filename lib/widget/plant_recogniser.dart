import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../classifier/classifier.dart';
import '../styles.dart';
import 'plant_photo_view.dart';
import 'results_page.dart';

const _labelsFileName = 'labels.txt';
const _modelFileName = 'model_unquant.tflite';

class PlantRecogniser extends StatefulWidget {
  const PlantRecogniser({super.key});

  @override
  State<PlantRecogniser> createState() => _PlantRecogniserState();
}

enum _ResultStatus {
  notStarted,
  notFound,
  found,
}

class _PlantRecogniserState extends State<PlantRecogniser> {
  bool _isAnalyzing = false;
  bool _isLoading = true;
  final picker = ImagePicker();
  File? _selectedImageFile;

  // Result
  _ResultStatus _resultStatus = _ResultStatus.notStarted;
  String _plantLabel = ''; // Name of Error Message
  double _accuracy = 0.0;

  Classifier? _classifier;

  // Add this list to store previous results
  List<Result> _previousResults = [];

  @override
  void initState() {
    super.initState();
    _loadClassifier();
  }

  Future<void> _loadClassifier() async {
    try {
      debugPrint('Starting classifier loading process');
      debugPrint('Labels file path: $_labelsFileName');
      debugPrint('Model file path: $_modelFileName');

      final classifier = await Classifier.loadWith(
        labelsFileName: _labelsFileName,
        modelFileName: _modelFileName,
      );

      if (classifier == null) {
        debugPrint('Classifier initialization returned null');
        setState(() {
          _isLoading = false;
          _resultStatus = _ResultStatus.notStarted;
          _plantLabel = 'Error: Classifier initialization failed';
        });
        return;
      }

      debugPrint('Classifier successfully loaded');
      setState(() {
        _classifier = classifier;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Error in _loadClassifier: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() {
        _isLoading = false;
        _resultStatus = _ResultStatus.notFound;
        _plantLabel = 'Error loading classifier: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    return Scaffold(
      body: Container(
        color: kBgColor,
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(top: 30),
              child: _buildTitle(),
            ),
            const SizedBox(height: 20),
            _buildPhotolView(),
            const SizedBox(height: 10),
            _buildResultView(),
            const Spacer(flex: 5),
            _buildPickPhotoButton(
              title: 'Take a photo',
              source: ImageSource.camera,
            ),
            _buildPickPhotoButton(
              title: 'Pick from gallery',
              source: ImageSource.gallery,
            ),
            _buildViewResultsButton(), // Add this button
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotolView() {
    return Stack(
      alignment: AlignmentDirectional.center,
      children: [
        PlantPhotoView(file: _selectedImageFile),
        _buildAnalyzingText(),
      ],
    );
  }

  Widget _buildAnalyzingText() {
    if (!_isAnalyzing) {
      return const SizedBox.shrink();
    }
    return const Text('Analyzing...', style: kAnalyzingTextStyle);
  }

  Widget _buildTitle() {
    return const Text(
      'PFC',
      style: kTitleTextStyle,
      textAlign: TextAlign.center,
    );
  }

  Widget _buildPickPhotoButton({
    required ImageSource source,
    required String title,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ElevatedButton(
        // Changed from TextButton to ElevatedButton
        onPressed: () {
          debugPrint('Button pressed for source: $source');
          _onPickPhoto(source);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: kColorBrown,
          padding: EdgeInsets.zero,
        ),
        child: SizedBox(
          width: 300,
          height: 50,
          child: Center(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: kButtonFont,
                fontSize: 20.0,
                fontWeight: FontWeight.w600,
                color: kColorLightYellow,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewResultsButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ResultsPage(results: _previousResults),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: kColorBrown,
          padding: EdgeInsets.zero,
        ),
        child: const SizedBox(
          width: 300,
          height: 50,
          child: Center(
            child: Text(
              'View Previous Results',
              style: TextStyle(
                fontFamily: kButtonFont,
                fontSize: 20.0,
                fontWeight: FontWeight.w600,
                color: kColorLightYellow,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _setAnalyzing(bool flag) {
    setState(() {
      _isAnalyzing = flag;
    });
  }

  void _onPickPhoto(ImageSource source) async {
    try {
      debugPrint('Attempting to pick image from source: $source');
      final pickedFile = await picker.pickImage(source: source);
      debugPrint('PickedFile result: ${pickedFile?.path ?? "null"}');

      if (pickedFile == null) {
        debugPrint('No image selected');
        return;
      }

      final imageFile = File(pickedFile.path);
      debugPrint('Image file created: ${imageFile.path}');

      setState(() {
        _selectedImageFile = imageFile;
      });

      _analyzeImage(imageFile);
    } catch (e) {
      debugPrint('Error picking image: $e');
      // Optionally show an error message to the user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  void _analyzeImage(File image) {
    if (_classifier == null) {
      debugPrint('Classifier is not initialized');
      setState(() {
        _resultStatus = _ResultStatus.notFound;
        _plantLabel = 'Error: Classifier not ready';
        _accuracy = 0.0;
      });
      return;
    }

    _setAnalyzing(true);

    try {
      final imageInput = img.decodeImage(image.readAsBytesSync())!;
      final resultCategory = _classifier!.predict(imageInput);

      final result = resultCategory.score >= 0.8
          ? _ResultStatus.found
          : _ResultStatus.notFound;
      final plantLabel = resultCategory.label;
      final accuracy = resultCategory.score;

      setState(() {
        _resultStatus = result;
        _plantLabel = plantLabel;
        _accuracy = accuracy;
      });

      // Store the result
      _previousResults.add(Result(
        imageFile: image,
        label: plantLabel,
        accuracy: accuracy,
      ));
    } catch (e) {
      debugPrint('Error during image analysis: $e');
      setState(() {
        _resultStatus = _ResultStatus.notFound;
        _plantLabel = 'Error during analysis';
        _accuracy = 0.0;
      });
    } finally {
      _setAnalyzing(false);
    }
  }

  Widget _buildResultView() {
    var title = '';

    if (_resultStatus == _ResultStatus.notFound) {
      title = 'Fail to recognise';
    } else if (_resultStatus == _ResultStatus.found) {
      title = _plantLabel;
    } else {
      title = '';
    }

    var accuracyLabel = '';
    if (_resultStatus == _ResultStatus.found) {
      accuracyLabel = 'Accuracy: ${(_accuracy * 100).toStringAsFixed(2)}%';
    }

    return Column(
      children: [
        Text(title, style: kResultTextStyle),
        const SizedBox(height: 10),
        Text(accuracyLabel, style: kResultRatingTextStyle)
      ],
    );
  }
}