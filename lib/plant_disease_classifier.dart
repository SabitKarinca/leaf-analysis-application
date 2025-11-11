// plant_disease_classifier.dart
import 'dart:typed_data';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class PlantDiseaseClassifier {
  static const String _modelPath = 'assets/models/plant_disease_model.tflite';
  static const String _labelsPath = 'assets/models/labels.txt';
  
  Interpreter? _interpreter;
  List<String> _labels = [];
  
  static const int inputSize = 256; 
  static const int numChannels = 3;
  static const double _confidenceThreshold = 0.15; 
  
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
  
  /// Modeli ve etiketleri yükler
  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(_modelPath);
      
      final labelsData = await rootBundle.loadString(_labelsPath);
      _labels = labelsData
          .split('\n')
          .map((label) => label.trim())
          .where((label) => label.isNotEmpty)
          .toList();
      
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final expectedClasses = outputShape[1];
      
      print('Model başarıyla yüklendi');
      print('Model beklenen sınıf sayısı: $expectedClasses');
      print('Labels.txt içindeki sınıf sayısı: ${_labels.length}');
      
      // UYARI: Eğer sınıf sayısı uyuşmuyorsa
      if (_labels.length > expectedClasses) {
        print('⚠️ UYARI: Label sayısı model output sayısından fazla!');
        print('⚠️ İlk $expectedClasses label kullanılacak.');
        _labels = _labels.take(expectedClasses).toList();
      } else if (_labels.length < expectedClasses) {
        print('⚠️ UYARI: Label sayısı model output sayısından az!');
        // Eksik labeller için placeholder ekle
        while (_labels.length < expectedClasses) {
          _labels.add('Unknown_Class_${_labels.length}');
        }
      }
      
      print('Kullanılan sınıflar (${_labels.length} adet):');
      for (int i = 0; i < _labels.length; i++) {
        print('  $i: ${_labels[i]}');
      }
      print('Model input shape: ${_interpreter!.getInputTensor(0).shape}');
      print('Model output shape: ${_interpreter!.getOutputTensor(0).shape}');
    } catch (e) {
      print('Model yüklenirken hata: $e');
      rethrow;
    }
  }
  
  /// Görüntüyü sınıflandırır ve sonuçları döndürür
  Future<Map<String, double>> classifyImage(File imageFile) async {
    if (_interpreter == null) {
      throw Exception('Model henüz yüklenmedi. Önce loadModel() çağırın.');
    }
    
    try {
      print('\n=== YAPRAK SINIFLANDIRMA BAŞLADI ===');
      print('Dosya yolu: ${imageFile.path}');
      
      final input = await _preprocessImage(imageFile);
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final numClasses = outputShape[1];
      final output = List.filled(numClasses, 0.0).reshape([1, numClasses]);
      final reshapedInput = input.reshape([1, inputSize, inputSize, numChannels]);
      
      print('Model çalıştırılıyor...');
      final stopwatch = Stopwatch()..start();
      _interpreter!.run(reshapedInput, output);
      stopwatch.stop();
      print('İnferans süresi: ${stopwatch.elapsedMilliseconds}ms');
      
      final rawResults = output[0] as List<double>;
      print('\nHam model çıktıları ($numClasses sınıf):');
      for (int i = 0; i < rawResults.length; i++) {
        print('  $i: ${rawResults[i].toStringAsFixed(4)}');
      }
      
      final softmaxResults = _applySoftmax(rawResults);
      final softmaxSum = softmaxResults.reduce((a, b) => a + b);
      print('Softmax toplamı: ${softmaxSum.toStringAsFixed(6)}');
      
      final results = <String, double>{};
      for (int i = 0; i < _labels.length && i < softmaxResults.length; i++) {
        results[_labels[i]] = softmaxResults[i];
      }
      
      final sortedResults = results.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      print('\n=== EN İYİ 5 TAHMİN ===');
      for (int i = 0; i < math.min(5, sortedResults.length); i++) {
        print('${i + 1}. ${sortedResults[i].key}: ${(sortedResults[i].value * 100).toStringAsFixed(2)}%');
      }
      
      final maxConfidence = getMaxConfidence(results);
      print('\nEn yüksek güven skoru: ${(maxConfidence * 100).toStringAsFixed(2)}%');
      print('Eşik değeri: ${(_confidenceThreshold * 100).toStringAsFixed(2)}%');
      print('Sonuç: ${maxConfidence > _confidenceThreshold ? "GEÇERLİ" : "BELİRSİZ"}');
      
      print('=== SINIFLANDIRMA BİTTİ ===\n');
      return results;
    } catch (e) {
      print('Sınıflandırma hatası: $e');
      rethrow;
    }
  }
  
  /// Görüntüyü model için uygun formata dönüştürür
  Future<Float32List> _preprocessImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      
      if (image == null) {
        throw Exception('Görüntü decode edilemedi');
      }
      
      print('=== GÖRÜNTÜ ÖN İŞLEME ===');
      print('Orijinal boyut: ${image.width}x${image.height}');
      
      if (image.numChannels != 3) {
        image = img.Image.from(image);
      }
      
      // Bilinear interpolation ile resize (Keras default)
      image = img.copyResize(
        image,
        width: inputSize,
        height: inputSize,
        interpolation: img.Interpolation.linear,
      );
      print('İşlenmiş boyut: ${image.width}x${image.height}');
      
      final input = Float32List(inputSize * inputSize * numChannels);
      int bufferIndex = 0;
      

      for (int y = 0; y < inputSize; y++) {
        for (int x = 0; x < inputSize; x++) {
          final pixel = image.getPixel(x, y);
          // RAW değerler: 0-255 arası (float32 olarak)
          input[bufferIndex++] = pixel.r.toDouble();
          input[bufferIndex++] = pixel.g.toDouble();
          input[bufferIndex++] = pixel.b.toDouble();
        }
      }
      
      print('Piksel değer aralığı: [${input.reduce(math.min).toStringAsFixed(1)}, ${input.reduce(math.max).toStringAsFixed(1)}]');
      print('Ortalama: ${(input.reduce((a, b) => a + b) / input.length).toStringAsFixed(1)}');
      print('Normalizasyon: YOK (raw 0-255 değerler)');
      
      return input;
    } catch (e) {
      print('Görüntü ön işleme hatası: $e');
      rethrow;
    }
  }
  
  /// Görüntüyü aspect ratio'yu koruyarak yeniden boyutlandırır (padding ile)
  img.Image _resizeImageWithPadding(img.Image src, int targetWidth, int targetHeight) {
    final srcAspect = src.width / src.height;
    final targetAspect = targetWidth / targetHeight;
    
    int newWidth, newHeight;
    
    if (srcAspect > targetAspect) {
      newWidth = targetWidth;
      newHeight = (targetWidth / srcAspect).round();
    } else {
      newHeight = targetHeight;
      newWidth = (targetHeight * srcAspect).round();
    }
    
    final resized = img.copyResize(
      src, 
      width: newWidth, 
      height: newHeight,
      interpolation: img.Interpolation.linear,
    );
    
    // Gri arka plan ile merkeze yerleştir
    final canvas = img.Image(width: targetWidth, height: targetHeight);
    img.fill(canvas, color: img.ColorRgb8(128, 128, 128));
    
    final offsetX = (targetWidth - newWidth) ~/ 2;
    final offsetY = (targetHeight - newHeight) ~/ 2;
    
    img.compositeImage(canvas, resized, dstX: offsetX, dstY: offsetY);
    return canvas;
  }
  
  /// Softmax fonksiyonu
  List<double> _applySoftmax(List<double> logits) {
    if (logits.isEmpty) return [];
    
    final maxLogit = logits.reduce((a, b) => a > b ? a : b);
    final expValues = logits.map((x) {
      final expVal = math.exp(x - maxLogit);
      return expVal.isFinite ? expVal : 0.0;
    }).toList();
    
    final sumExp = expValues.reduce((a, b) => a + b);
    if (sumExp == 0.0) {
      return List.filled(logits.length, 1.0 / logits.length);
    }
    
    return expValues.map((x) => x / sumExp).toList();
  }
  
  /// En yüksek güven skoruna sahip sınıfı döndürür
  String getPredictedClass(Map<String, double> results) {
    if (results.isEmpty) return 'Bilinmeyen';
    
    double maxConfidence = 0.0;
    String predictedClass = 'Bilinmeyen';
    
    results.forEach((className, confidence) {
      if (confidence > maxConfidence) {
        maxConfidence = confidence;
        predictedClass = className;
      }
    });
    
    return predictedClass;
  }
  
  /// En yüksek güven skorunu döndürür
  double getMaxConfidence(Map<String, double> results) {
    if (results.isEmpty) return 0.0;
    return results.values.reduce((a, b) => a > b ? a : b);
  }
  
  /// Güven skorunun yeterli olup olmadığını kontrol eder
  bool isConfidenceAcceptable(Map<String, double> results) {
    return getMaxConfidence(results) > _confidenceThreshold;
  }
  
  /// En yüksek N tahmin döndürür
  List<MapEntry<String, double>> getTopPredictions(Map<String, double> results, {int topK = 3}) {
    final sortedResults = results.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sortedResults.take(topK).toList();
  }
  
  /// Sınıfı Türkçe formata çevirir
  String formatClassName(String className) {
    return className
        .replaceAll('_', ' ')
        .replaceAll('healthy', 'Sağlıklı')
        .replaceAll('Dolmalik', 'Dolmalık')
        .replaceAll('biber', 'Biber')
        .replaceAll('Bakteriyel leke', 'Bakteriyel Leke')
        .replaceAll('domates', 'Domates')
        .replaceAll('Septoria leaf', 'Septoria Yaprak Lekesi')
        .replaceAll('Bacterial spot', 'Bakteriyel Leke')
        .replaceAll('Kirmizi orumcek', 'Kırmızı Örümcek Akarı')
        .replaceAll('mosaic virus', 'Mozaik Virüsü')
        .replaceAll('Yaprak kufu', 'Yaprak Küfü')
        .replaceAll('yaprak lekesi', 'Yaprak Lekesi')
        .replaceAll('Yellow Leaf Curl Virus', 'Sarı Yaprak Kıvırcıklığı Virüsü')
        .replaceAll('Alternaria solani', 'Erken Yanıklık (Alternaria)')
        .replaceAll('Phytophthora infestans', 'Geç Yanıklık (Phytophthora)')
        .replaceAll('Patates', 'Patates')
        .replaceAll('patates', 'Patates');
  }
  
  /// Bitki türünü tespit eder
  String getPlantType(String className) {
    if (className.toLowerCase().contains('biber') || className.toLowerCase().contains('dolmalik')) {
      return '🌶️ Dolmalık Biber';
    } else if (className.toLowerCase().contains('domates')) {
      return '🍅 Domates';
    } else if (className.toLowerCase().contains('patates')) {
      return '🥔 Patates';
    }
    return '🌱 Bilinmeyen Bitki';
  }
  
  /// Hastalık durumunu tespit eder
  bool isHealthy(String className) {
    return className.toLowerCase().contains('healthy') || 
           className.toLowerCase().contains('sağlıklı');
  }
  
  bool get isModelLoaded => _interpreter != null;
  List<String> get labels => List.from(_labels);
  double get confidenceThreshold => _confidenceThreshold;
}