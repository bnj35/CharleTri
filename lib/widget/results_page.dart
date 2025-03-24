import 'dart:io';

import 'package:flutter/material.dart';
import 'package:trash_recognizer_min_2025/styles.dart';

class ResultsPage extends StatelessWidget {
  final List<Result> results;

  const ResultsPage({Key? key, required this.results}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account', style: TextStyle(
          fontFamily: 'SquadaOne',
          fontSize: 50.0,
          color: kColorBlue,
          decoration: TextDecoration.none,
        )),
        backgroundColor: kBgColor,
      ),
      body: Container(
        color: kBgColor,
        child: ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final result = results[index];
            return ListTile(
              leading: Image.file(result.imageFile),
              title: Text(result.label, style: TextStyle(
                fontFamily: 'SquadaOne',
                fontSize: 35.0,
                color: kColorBlue,
                decoration: TextDecoration.none,
              )),
              subtitle: Text('Accuracy: ${(result.accuracy * 100).toStringAsFixed(2)}%', style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 18.0,
                color: kColorBlack,
                decoration: TextDecoration.none,
              )),
            );
          },
        ),
      ),
    );
  }
}

class Result {
  final File imageFile;
  final String label;
  final double accuracy;

  Result({required this.imageFile, required this.label, required this.accuracy});
}