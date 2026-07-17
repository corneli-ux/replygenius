import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/business_profile.dart';
import '../models/faq.dart';

/// Local persistence layer.
/// - Business profile & FAQs → SharedPreferences (no secrets)
/// - API key → flutter_secure_storage (encrypted at rest)
class StorageService {
  static const _profileKey = 'business_profile_v1';
  static const _faqsKey = 'faqs_v1';
  static const _apiKeyKey = 'gemini_api_key_v1';
  static const _onboardingDoneKey = 'onboarding_done_v1';

  final _secureStorage = const FlutterSecureStorage();

  // ---------- Business Profile ----------
  Future<BusinessProfile> loadProfile() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_profileKey);
    if (raw == null) return BusinessProfile.empty();
    return BusinessProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveProfile(BusinessProfile profile) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_profileKey, jsonEncode(profile.toJson()));
  }

  // ---------- FAQs ----------
  Future<List<FAQ>> loadFaqs() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_faqsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => FAQ.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveFaqs(List<FAQ> faqs) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
      _faqsKey,
      jsonEncode(faqs.map((e) => e.toJson()).toList()),
    );
  }

  // ---------- API Key (secure) ----------
  Future<String> loadApiKey() async {
    return await _secureStorage.read(key: _apiKeyKey) ?? '';
  }

  Future<void> saveApiKey(String key) async {
    await _secureStorage.write(key: _apiKeyKey, value: key);
  }

  // ---------- Onboarding ----------
  Future<bool> isOnboardingDone() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_onboardingDoneKey) ?? false;
  }

  Future<void> markOnboardingDone() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_onboardingDoneKey, true);
  }
}
