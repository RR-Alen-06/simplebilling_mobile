import 'package:simplebilling_mobile/data/repositories/api_repository.dart';

class SequenceService {
  SequenceService._();

  /// Atomic sequential identifier generator (RPC + Fallback)
  static Future<String> getNextSequence(String key) async {
    return await ApiRepository.getNextSequence(key);
  }
}
