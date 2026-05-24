import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return _web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _android;

      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );

      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );

      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );

      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );

      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions _web = FirebaseOptions(
    apiKey: 'AIzaSyBK8jzFQtUR6yPuY7aKTsvheOkVcHh9dqQ',
    appId: '1:231631929604:web:a6abb14773a8847e235051',
    messagingSenderId: '231631929604',
    projectId: 'window-register',
    authDomain: 'window-register.firebaseapp.com',
    storageBucket: 'window-register.firebasestorage.app',
    measurementId: 'G-NZ90M1R3CX',
  );

  static const FirebaseOptions _android = FirebaseOptions(
    apiKey: 'AIzaSyAqAFQVXrjQPtzXOv5c62UKb6Wb95dE31Y',
    appId: '1:231631929604:android:6b0eb493d18c8e64235051',
    messagingSenderId: '231631929604',
    projectId: 'window-register',
    storageBucket: 'window-register.firebasestorage.app',
  );
}