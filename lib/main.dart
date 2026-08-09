import 'package:flutter/material.dart';
import 'package:spherex_chat/app.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:spherex_chat/config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseKey,
  );

  runApp(const SphereXChatApp());
}
