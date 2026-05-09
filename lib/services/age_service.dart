import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class AgeResult {
  final bool passed;
  final int? detectedAge;
  final String message;

  const AgeResult({
    required this.passed,
    required this.message,
    this.detectedAge,
  });
}

class AgeService {
  static const String _apiKey    = 'bv4e3POTXwBXCQlgsb0vKHNQVnUahyGj';
  static const String _apiSecret = 'vCTTo5hBk_iIdxEgARxclagfdSBwaSc8';

  static const String _endpoint =
      'https://api-us.faceplusplus.com/facepp/v3/detect';

  static const int _minAge = 14;

  static final AgeService _instance = AgeService._internal();
  factory AgeService() => _instance;
  AgeService._internal();

  Future<AgeResult> verify(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse(_endpoint),
        body: {
          'api_key': _apiKey,
          'api_secret': _apiSecret,
          'image_base64': base64Image,
          'return_attributes': 'age',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        return const AgeResult(
          passed: false,
          message: 'Ошибка сервера. Попробуйте ещё раз.',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final faces = json['faces'] as List<dynamic>?;

      if (faces == null || faces.isEmpty) {
        return const AgeResult(
          passed: false,
          message: 'Лицо не обнаружено. Встаньте ближе к камере.',
        );
      }

      final attributes = faces[0]['attributes'] as Map<String, dynamic>?;
      final age = (attributes?['age']?['value'] as num?)?.toInt();

      if (age == null) {
        return const AgeResult(
          passed: false,
          message: 'Не удалось определить возраст.',
        );
      }

      if (age >= _minAge) {
        return AgeResult(
          passed: true,
          detectedAge: age,
          message: 'Возраст подтверждён (~$age лет)',
        );
      } else {
        return AgeResult(
          passed: false,
          detectedAge: age,
          message: 'Доступ запрещён. Вам меньше $_minAge лет.',
        );
      }
    } on SocketException {
      return const AgeResult(
        passed: false,
        message: 'Нет подключения к интернету.',
      );
    } catch (_) {
      return const AgeResult(
        passed: false,
        message: 'Произошла ошибка. Попробуйте ещё раз.',
      );
    }
  }
}
