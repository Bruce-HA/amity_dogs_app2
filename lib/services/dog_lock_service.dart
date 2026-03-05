import 'package:supabase_flutter/supabase_flutter.dart';

class DogLockService {
  static final supabase = Supabase.instance.client;

  static Future toggleLock({
    required String dogId,
    required bool locked,
  }) async {
    await supabase.from('dogs').update({'locked': !locked}).eq('id', dogId);
  }
}
