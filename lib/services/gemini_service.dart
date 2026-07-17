import 'dart:convert';
import 'package:http/http.dart' as http;

/// Calls Google Gemini API to generate reply variants.
///
/// Uses gemini-1.5-flash-latest for speed & cost efficiency.
/// The system prompt (built by BusinessContextService) is the "training".
class GeminiService {
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/'
      'gemini-1.5-flash-latest:generateContent';

  final String apiKey;

  GeminiService(this.apiKey);

  bool get isConfigured => apiKey.isNotEmpty;

  /// Sends the system prompt + customer message, expects a JSON array of
  /// reply variants.
  Future<List<Map<String, dynamic>>> generateReplies({
    required String systemPrompt,
    required String customerMessage,
    required String conversationHistory,
    int variantCount = 2,
  }) async {
    if (!isConfigured) {
      throw StateError('Gemini API key not configured');
    }

    final userPrompt = '''
CONVERSATION SO FAR:
$conversationHistory

LATEST CUSTOMER MESSAGE:
"$customerMessage"

Generate $variantCount reply variants as a JSON array. Each variant must have:
{
  "id": "v1",
  "text": "the actual reply to send",
  "style": "calm | action | empathetic",
  "rationale": "one short sentence explaining why this reply works"
}

Rules:
- Reply text must be ready to send as-is (no placeholders, no brackets).
- Reply text must be 1-4 sentences.
- Never argue, never blame the customer, never be defensive.
- Acknowledge the emotion FIRST, then propose a concrete next step.
- Match the business tone configured in the system prompt.
- Return ONLY the JSON array, no markdown fences, no commentary.
''';

    final body = {
      'system_instruction': {
        'parts': [
          {'text': systemPrompt}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': userPrompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.7,
        'topP': 0.95,
        'maxOutputTokens': 1200,
        'responseMimeType': 'application/json',
      },
    };

    final uri = Uri.parse('$_endpoint?key=$apiKey');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Gemini API error ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      return [];
    }
    final text =
        candidates[0]['content']['parts'][0]['text'] as String? ?? '[]';

    // Clean up any stray markdown fences (defensive).
    String cleaned = text.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned
          .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
          .replaceFirst(RegExp(r'\s*```$'), '');
    }

    final List<dynamic> decoded = jsonDecode(cleaned) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
  }

  /// Lightweight call to detect anger level (1-5) and key emotional cues.
  Future<({int angerScore, String summary})> analyzeSentiment(
    String customerMessage,
  ) async {
    if (!isConfigured) {
      return (angerScore: 3, summary: 'Unable to analyze (no API key)');
    }

    final prompt = '''
Analyze this customer message and respond as JSON:
{"anger_score": <1-5>, "summary": "<one short sentence>"}

Message: "$customerMessage"

1 = perfectly calm, 5 = furious / threatening.
Return ONLY the JSON.
''';

    final body = {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.2,
        'maxOutputTokens': 200,
        'responseMimeType': 'application/json',
      },
    };

    final uri = Uri.parse('$_endpoint?key=$apiKey');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      return (angerScore: 3, summary: 'Analysis failed');
    }

    final data = jsonDecode(response.body);
    final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
    final parsed = jsonDecode(text) as Map<String, dynamic>;
    return (
      angerScore: (parsed['anger_score'] as num).toInt().clamp(1, 5),
      summary: parsed['summary'] as String? ?? '',
    );
  }
}
