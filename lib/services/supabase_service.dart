import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static Future<void> init() async {
    await Supabase.initialize(
      url: 'https://ixrwemsygrnzivdovqww.supabase.co',
      publishableKey: 'sb_publishable_ZCTcD95nrMmI_lr0rxdp5A_on5to7re',
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
