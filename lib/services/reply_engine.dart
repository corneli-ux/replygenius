import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/business_profile.dart';
import '../models/customer_message.dart';
import '../models/faq.dart';
import '../models/reply_history.dart';
import 'business_context_service.dart';
import 'gemini_service.dart';
import 'history_service.dart';
import 'native_bridge_service.dart';
import 'storage_service.dart';

/// Central orchestrator. Wires everything together:
///   - listens to incoming customer messages (from NotificationListener)
///   - analyzes anger
///   - builds the trained system prompt
///   - calls Gemini for reply variants
///   - pushes variants to the native overlay
///   - on escalation (anger=5 or keywords), fires a local notification
class ReplyEngine extends ChangeNotifier {
  final StorageService _storage;
  final NativeBridgeService _bridge;
  final HistoryService _history;
  GeminiService _gemini;

  BusinessProfile _profile = BusinessProfile.empty();
  List<FAQ> _faqs = [];
  String _apiKey = '';
  StreamSubscription<CustomerMessage>? _msgSub;
  bool _isGenerating = false;
  String _lastStatus = 'Idle';

  ReplyEngine({
    required StorageService storage,
    required NativeBridgeService bridge,
    required HistoryService history,
    required GeminiService gemini,
  })  : _storage = storage,
        _bridge = bridge,
        _history = history,
        _gemini = gemini {
    _msgSub = _bridge.messageStream.listen(_handleIncoming);
  }

  BusinessProfile get profile => _profile;
  List<FAQ> get faqs => _faqs;
  bool get isGenerating => _isGenerating;
  String get lastStatus => _lastStatus;
  bool get isConfigured => _profile.isConfigured && _apiKey.isNotEmpty;

  /// Expose the in-memory API key for screens that need to call Gemini directly.
  Future<String> currentApiKey() async => _apiKey;

  /// Load everything from disk on app start.
  Future<void> initialize() async {
    _profile = await _storage.loadProfile();
    _faqs = await _storage.loadFaqs();
    _apiKey = await _storage.loadApiKey();
    _gemini = GeminiService(_apiKey);
    notifyListeners();
  }

  Future<void> updateProfile(BusinessProfile p) async {
    _profile = p;
    await _storage.saveProfile(p);
    notifyListeners();
  }

  Future<void> updateFaqs(List<FAQ> faqs) async {
    _faqs = faqs;
    await _storage.saveFaqs(faqs);
    notifyListeners();
  }

  Future<void> updateApiKey(String key) async {
    _apiKey = key;
    _gemini = GeminiService(key);
    await _storage.saveApiKey(key);
    notifyListeners();
  }

  void _setStatus(String s) {
    _lastStatus = s;
    notifyListeners();
  }

  Future<void> _handleIncoming(CustomerMessage msg) async {
    if (!isConfigured) {
      _setStatus('Skipped "${msg.sender}" — app not configured');
      return;
    }
    if (_isGenerating) {
      _setStatus('Busy — queued message from ${msg.sender}');
      return;
    }

    _isGenerating = true;
    _setStatus('Analyzing message from ${msg.sender}...');
    notifyListeners();

    try {
      // 1. Sentiment analysis (anger 1-5)
      final sentiment = await _gemini.analyzeSentiment(msg.text);

      // 2. Build trained system prompt from business profile + FAQs
      final systemPrompt = BusinessContextService(
        profile: _profile,
        faqs: _faqs,
      ).buildSystemPrompt();

      // 3. Generate reply variants
      final variants = await _gemini.generateReplies(
        systemPrompt: systemPrompt,
        customerMessage: msg.text,
        conversationHistory:
            '(no prior context — this is the first captured message in this session)',
        variantCount: 2,
      );

      // 4. Push to native overlay
      await _bridge.showOverlay(
        sender: msg.sender,
        message: msg.text,
        angerScore: sentiment.angerScore,
        variants: variants,
      );

      // 5. Persist to history
      if (variants.isNotEmpty) {
        await _history.insert(ReplyHistoryEntry(
          id: msg.id,
          channel: msg.channel,
          sender: msg.sender,
          incomingMessage: msg.text,
          sentReply: variants.first['text'] as String,
          angerScore: sentiment.angerScore,
          timestamp: DateTime.now(),
        ));
      }

      _setStatus('Reply ready for ${msg.sender} '
          '(anger ${sentiment.angerScore}/5)');
    } catch (e) {
      _setStatus('Error: $e');
      debugPrint('ReplyEngine error: $e');
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    super.dispose();
  }
}
