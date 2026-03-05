import 'package:supabase_flutter/supabase_flutter.dart';

class AppUser {
  static final supabase = Supabase.instance.client;

  static String name = '';
  static String userId = '';
  static bool isAdmin = false;

  static Future<void> load() async {
    final user = supabase.auth.currentUser;

    if (user == null) return;

    userId = user.id;

    final data = await supabase
        .from('profiles')
        .select()
        .eq('user_id', user.id)
        .single();

    name = data['name'] ?? '';
    isAdmin = data['is_admin'] ?? false;
  }
}