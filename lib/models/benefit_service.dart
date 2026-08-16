import 'dart:convert';
import 'package:flutter/services.dart';
import 'benefit.dart';

class BenefitService {
  static Future<List<Benefit>> loadBenefits() async {
    // CHANGE THIS:
    // await rootBundle.loadString('assets/data/benefits.json');

    // TO THIS:
    final String response =
        await rootBundle.loadString('data/benefits.json');

    final List<dynamic> data = json.decode(response);
    return data.map((item) => Benefit.fromJson(item as Map<String, dynamic>)).toList();
  }
}