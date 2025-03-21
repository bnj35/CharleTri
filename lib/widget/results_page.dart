import 'dart:io';

import 'package:flutter/material.dart';

class ResultsPage extends StatelessWidget {
  final List<Result> results;

  const ResultsPage({Key? key, required this.results}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Previous Results', style: TextStyle(
          fontFamily: 'SquadaOne',
          fontSize: 50.0,
          color: Color(0xFFD3D3D3),
          decoration: TextDecoration.none,
        )),
        backgroundColor: Color(0xFF000000),
      ),
      body: Container(
        color: Colors.black,
        child: ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final result = results[index];
            return ListTile(
              leading: Image.file(result.imageFile),
              title: Text(result.label, style: TextStyle(
                fontFamily: 'SquadaOne',
                fontSize: 35.0,
                color: Color(0xFFFFFFFF),
                decoration: TextDecoration.none,
              )),
              subtitle: Text('Accuracy: ${(result.accuracy * 100).toStringAsFixed(2)}%', style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 18.0,
                color: Colors.white,
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