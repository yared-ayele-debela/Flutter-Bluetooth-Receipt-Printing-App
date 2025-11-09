import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'pages/sales_dashboard.dart';
import 'firebase_options.dart';
import 'services/api_service.dart';
import 'services/printer_service.dart';

// Background handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('📩 Background message received: ${message.notification?.title}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _initFirebaseMessaging();
  }

  Future<void> _initFirebaseMessaging() async {
    final fcm = FirebaseMessaging.instance;

    // ✅ Ask permission
    await fcm.requestPermission();

    // ✅ Get token and send to Laravel
    final token = await fcm.getToken();
    debugPrint("🔑 FCM Token: $token");

    if (token != null) {
      await http.post(
        Uri.parse("http://192.168.1.14:8000/api/save-fcm-token"),
        body: {'token': token},
      );
    }

    // ✅ Foreground message handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint("💬 Foreground message: ${message.notification?.title}");

      // 🔊 Play sound
      await player.play(AssetSource('sounds/notify.mp3'));

      // ✅ In-app heads-up bottom sheet with actions (Print now, View)
      final orderId = message.data['order_id']?.toString();
      final context = navigatorKey.currentContext;
      if (context != null) {
        _showInAppHeadsUp(context, orderId: orderId, title: message.notification?.title, body: message.notification?.body);
      }
    });

    // When user taps system notification to open the app
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      final orderId = message.data['order_id']?.toString();
      // Optionally navigate or show quick view when app is resumed
      final ctx = navigatorKey.currentContext;
      if (ctx != null && orderId != null) {
        _showInAppHeadsUp(ctx, orderId: orderId, title: message.notification?.title, body: message.notification?.body);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluetooth POS',
      navigatorKey: navigatorKey, // ✅ Add this line
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const SalesDashboard(),
    );
  }
}

// ✅ Global navigator key to show dialogs safely
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void _showInAppHeadsUp(BuildContext context, {String? orderId, String? title, String? body}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long),
                  const SizedBox(width: 8),
                  Expanded(child: Text(title ?? 'New Order', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                ],
              ),
              const SizedBox(height: 8),
              Text(body ?? 'Tap an action below.'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        if (orderId == null) return;
                        final api = ApiService();
                        final printer = PrinterService();
                        final order = await api.getOrderById(int.parse(orderId));
                        await printer.printOrder(context, order);
                      },
                      icon: const Icon(Icons.print),
                      label: const Text('Print now'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        // Here you can navigate to a details page if available
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Order'),
                            content: Text('Open order ID: ${orderId ?? '-'}'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.visibility),
                      label: const Text('View'),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      );
    },
  );
}
