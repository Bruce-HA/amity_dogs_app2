import 'package:supabase_flutter/supabase_flutter.dart';

class AppUser {
  static final supabase = Supabase.instance.client;

  static String userId = '';
  static String name = '';

  static bool isAdmin = false;
  static bool isBreeder = false;
  static bool isHelper = false;
  static bool isDriver = false;

  static Future<void> load() async {
    final user = supabase.auth.currentUser;

    if (user == null) return;

    userId = user.id;

    final data = await supabase
        .from('app_users')
        .select()
        .eq('id', user.id)
        .single();

    // 👇 THIS IS THE IMPORTANT PART
    name =
        '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim();

    isAdmin = data['is_admin'] ?? false;
    isBreeder = data['is_breeder'] ?? false;
    isHelper = data['is_helper'] ?? false;
    isDriver = data['is_driver'] ?? false;
  }
}