import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final firestore = FirebaseFirestore.instance;

  // Загружаем данные
  final jsonString = await rootBundle.loadString('assets/poland_cities.json');
  final List<dynamic> cities = json.decode(jsonString);

  print('📦 Загружено городов: ${cities.length}');

  WriteBatch batch = firestore.batch();
  int batchCounter = 0;
  int successCount = 0;
  int skippedCount = 0;

  for (final city in cities) {
    try {
      final name = city['city']?.toString().trim() ?? '';
      final lat = double.tryParse(city['lat'].toString()) ?? 0.0;
      final lng = double.tryParse(city['lng'].toString()) ?? 0.0;

      if (name.isEmpty || lat == 0 || lng == 0) {
        skippedCount++;
        continue;
      }

      final docId = _generateDocId(name);

      final ref = firestore.collection('locations').doc(docId);

      batch.set(ref, {
        'name': name,
        'nameLower': name.toLowerCase(),
        'lat': lat,
        'lng': lng,
        'country': 'Poland',
        'countryCode': city['iso2']?.toString() ?? 'PL',
        'region': city['admin_name']?.toString() ?? '',
        'population': int.tryParse(city['population'].toString()) ?? 0,
        'capital': city['capital']?.toString() ?? '',
        'type': 'city',
        'createdAt': FieldValue.serverTimestamp(),
      });

      successCount++;
      batchCounter++;

      // Отправляем batch каждые 450 записей (ограничение Firestore)
      if (batchCounter >= 450) {
        await batch.commit();
        print('✅ Загружено: $successCount');

        batch = firestore.batch();
        batchCounter = 0;
      }
    } catch (e) {
      skippedCount++;
      print('❌ Ошибка при обработке города: $e');
    }
  }

  // Отправляем остаток
  if (batchCounter > 0) {
    await batch.commit();
  }

  print('\n🎉 Импорт завершён');
  print('✅ Успешно: $successCount');
  print('⚠️ Пропущено: $skippedCount');
}

/// Генерация понятного ID документа
String _generateDocId(String name) {
  return name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9ąćęłńóśźż]'), '_')
      .replaceAll(RegExp(r'_+'), '_');
}