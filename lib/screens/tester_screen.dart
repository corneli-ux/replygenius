import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/business_context_service.dart';
import '../services/gemini_service.dart';
import '../services/reply_engine.dart';
import '../utils/theme.dart';
import '../widgets/sentiment_badge.dart';

/// Manual playground — type a customer message, see the AI's reply variants.
class TesterScreen extends StatefulWidget {
  const TesterScreen({super.key});
  @override
  State<TesterScreen> createState() => _TesterScreenState();
}

class _TesterScreenState extends State<TesterScreen> {
  final _msgCtrl = TextEditingController();
  bool _busy = false;
  int? _anger;
  String? _summary;
  List<Map<String, dynamic>> _variants = [];
  String? _error;

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _variants = [];
      _anger = null;
      _summary = null;
    });

    try {
      final engine = context.read<ReplyEngine>();
      if (!engine.isConfigured) {
        throw StateError('Configure business profile and API key first (Settings).');
      }
      // Pull the current API key from secure storage via the engine.
      final apiKey = await engine.currentApiKey();
      final gemini = GeminiService(apiKey);

      final sentiment = await gemini.analyzeSentiment(text);
      final prompt = BusinessContextService(
        profile: engine.profile,
        faqs: engine.faqs,
      ).buildSystemPrompt();
      final variants = await gemini.generateReplies(
        systemPrompt: prompt,
        customerMessage: text,
        conversationHistory: '(manual test — no prior conversation)',
        variantCount: 2,
      );
      setState(() {
        _anger = sentiment.angerScore;
        _summary = sentiment.summary;
        _variants = variants;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reply copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test a reply')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Simulate a customer message',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text(
            'Type an angry (or any) customer message below and see how ReplyGenius would respond.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _msgCtrl,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText:
                  'e.g. This is the third time my order has arrived broken! I want a refund NOW or I am reporting you!',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _generate,
            icon: _busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            label: const Text('Generate reply'),
          ),
          const SizedBox(height: 20),

          if (_anger != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    SentimentBadge(angerScore: _anger!),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(_summary ?? '',
                          style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (_error != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Text(_error!,
                  style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13)),
            ),

          ..._variants.map((v) => _variantCard(v)),
        ],
      ),
    );
  }

  Widget _variantCard(Map<String, dynamic> v) {
    final text = v['text'] as String? ?? '';
    final style = v['style'] as String? ?? 'calm';
    final rationale = v['rationale'] as String? ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(style.toUpperCase(),
                  style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11)),
            ),
            const SizedBox(height: 10),
            Text(text, style: const TextStyle(fontSize: 14, height: 1.4)),
            if (rationale.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(rationale,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textMuted, fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _copy(text),
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
