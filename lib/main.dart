import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;

void main() => runApp(DeliveryNoteScannerApp());

class DeliveryNoteScannerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Delivery Note Scanner',
      theme: ThemeData(primarySwatch: Colors.green),
      home: DeliveryNoteScannerPage(),
    );
  }
}

class DeliveryNoteScannerPage extends StatefulWidget {
  @override
  _DeliveryNoteScannerPageState createState() => _DeliveryNoteScannerPageState();
}

class _DeliveryNoteScannerPageState extends State<DeliveryNoteScannerPage> {
  File? _image;
  final picker = ImagePicker();

  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _matriculeController = TextEditingController();
  final TextEditingController _tonnageController = TextEditingController();

  Future<void> _getImageAndScan() async {
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      final inputImage = InputImage.fromFile(File(pickedFile.path));
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

      _parseAndFillFields(recognizedText.text);

      setState(() {
        _image = File(pickedFile.path);
      });

      await textRecognizer.close();
    }
  }

  void _parseAndFillFields(String text) {
    final date = RegExp(r'Date[:\s]*([\d]{2}[./-][\d]{2}[./-][\d]{4})')
        .firstMatch(text)
        ?.group(1) ?? '';

    final matricule = RegExp(r'Matricule[:\s]*([\w\s\.\-]+)')
        .firstMatch(text)
        ?.group(1)
        ?.trim() ?? '';

    final quantityMatch = RegExp(r'Quantité\s*\n\s*([\d,.]+)')
        .firstMatch(text);
    String tonnage = quantityMatch?.group(1)?.replaceAll(',', '.') ?? '';

    _dateController.text = date;
    _matriculeController.text = matricule;
    _tonnageController.text = tonnage;
  }

  Future<void> _uploadToGoogleSheets() async {
    final uri = Uri.parse('https://hook.eu2.make.com/4etw14jls6r9q8p5s9wjvh2y0c7qevq8');

    final response = await http.post(uri, body: {
      'date': _dateController.text,
      'matricule': _matriculeController.text,
      'tonnage': _tonnageController.text,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          response.statusCode == 200
              ? '✅ Uploaded successfully'
              : '❌ Upload failed: ${response.statusCode}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Delivery Note Scanner')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            if (_image != null) Image.file(_image!, height: 200),
            ElevatedButton(
              onPressed: _getImageAndScan,
              child: Text('Scan Delivery Note'),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _dateController,
              decoration: InputDecoration(labelText: 'Date'),
            ),
            TextField(
              controller: _matriculeController,
              decoration: InputDecoration(labelText: 'Matricule'),
            ),
            TextField(
              controller: _tonnageController,
              decoration: InputDecoration(labelText: 'Tonnage (e.g., 26.080)'),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _uploadToGoogleSheets,
              child: Text('Upload to Google Sheets'),
            ),
          ],
        ),
      ),
    );
  }
}
