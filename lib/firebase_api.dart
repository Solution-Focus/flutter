import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import "dart:convert";
import 'package:http/http.dart' as http;
import 'package:flutter_session_manager/flutter_session_manager.dart';


final navigatorKey = GlobalKey<NavigatorState>();

Future<void> handleBackgroundMessage(RemoteMessage message) async {
  print('Title: ${message.notification?.title}');
  print('Body: ${message.notification?.body}');
  print('Payload: ${message.data}');
}


class FirebaseApi {
    final _firebaseMessaging = FirebaseMessaging.instance;

    final _androidChannel = const AndroidNotificationChannel (
      'high_importance_channel',
      'High Importance Notifications',
      description : 'This channel is used for important notifications',
      importance: Importance.defaultImportance,
    );
    final _localNotifications = FlutterLocalNotificationsPlugin();


    void handleMessage(RemoteMessage? message){
      if (message == null) return;

      // navigatorKey.currentState?.pushNamed(
      //   NotificationScreen.route,
      //   arguments: message,
      // );
    }

    Future initLocalNotifications() async {
      const iOS = DarwinInitializationSettings();
      const android = AndroidInitializationSettings('@drawble/ic_launcher');
      const settings = InitializationSettings(android: android, iOS: iOS);

      await _localNotifications.initialize(
          settings,
          onDidReceiveNotificationResponse: (details) async {
            final message = RemoteMessage.fromMap(jsonDecode(details.payload!));
            handleMessage(message);
          }
      );

      final platform = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await platform?.createNotificationChannel(_androidChannel);
    }

    Future initPushNotifications() async {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.instance.getInitialMessage().then(handleMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(handleMessage);
      FirebaseMessaging.onBackgroundMessage(handleBackgroundMessage);
      FirebaseMessaging.onMessage.listen((message){
        final notification = message.notification;
        if(notification == null) return;
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
              android: AndroidNotificationDetails(
                _androidChannel.id,
                _androidChannel.name,
                channelDescription: _androidChannel.description,
                icon: '@drawable/ic_launcher',
              )
          ),
          payload: jsonEncode(message.toMap()),
        );
      });
    }

    Future<String> getFCMToken() async {
      await _firebaseMessaging.requestPermission();
      final fCMToken = await _firebaseMessaging.getToken();
      return fCMToken ?? ''; // 변수를 함수의 반환 값으로 사용
    }

    Future<void> initNotifications() async {
      var fCMToken = await getFCMToken(); // 함수에서 반환된 값을 변수에 저장
      var sessionManager = SessionManager();
      await sessionManager.set("id", '$fCMToken');
      var ii = (kIsWeb ? "Web" : Platform.isAndroid ? 'Aos' : 'iOS');

      print('Token: $fCMToken');

        http.Response response = await http.post(Uri.parse('http://heycosmetics.kr:446/api/v1/fcm/token'),
          headers: <String, String>{
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            "platform": "$ii",
            "token": fCMToken.toString(),
          }),
        );

        initPushNotifications();
        initLocalNotifications();

    }

}

