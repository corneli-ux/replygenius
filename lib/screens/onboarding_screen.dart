import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/business_profile.dart';
import '../services/reply_engine.dart';
import '../services/storage_service.dart';
import '../utils/theme.dart';

/// 5-step onboarding wizard that captures business context.
/// Each step builds a richer "training" for the AI.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _step = 0;

  final _nameCtrl = TextEditingController();
  final _industryCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _refundCtrl = TextEditingController();
  final _shippingCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _escalationCtrl = TextEditingController();
  final _voiceCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();

  String _tone = 'calm';
  String _apology = 'soft';
  final List<String> _dos = [];
  final List<String> _donts = [];
  final _doCtrl = TextEditingController();
  final _dontCtrl = TextEditingController();

  @override
  void dispose() {
    _pageCtrl.dispose();
    for (final c in [
      _nameCtrl,
      _industryCtrl,
      _descCtrl,
      _refundCtrl,
      _shippingCtrl,
      _contactCtrl,
      _escalationCtrl,
      _voiceCtrl,
      _apiKeyCtrl,
      _doCtrl,
      _dontCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _next() {
    if (_step < 4) {
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut);
      setState(() => _step++);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_step > 0) {
      _pageCtrl.previousPage(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut);
      setState(() => _step--);
    }
  }

  Future<void> _finish() async {
    final engine = context.read<ReplyEngine>();
    await engine.updateApiKey(_apiKeyCtrl.text.trim());
    await engine.updateProfile(BusinessProfile(
      id: 'default',
      businessName: _nameCtrl.text.trim(),
      industry: _industryCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      tone: _tone,
      apologyStyle: _apology,
      dos: _dos,
      donts: _donts,
      refundPolicy: _refundCtrl.text.trim(),
      shippingPolicy: _shippingCtrl.text.trim(),
      contactInfo: _contactCtrl.text.trim(),
      brandVoiceSample: _voiceCtrl.text.trim(),
      escalationContact: _escalationCtrl.text.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
    await context.read<StorageService>().markOnboardingDone();
    if (mounted) Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            _progressHeader(),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _stepBusiness(),
                  _stepVoice(),
                  _stepPolicies(),
                  _stepDosDonts(),
                  _stepApiKey(),
                ],
              ),
            ),
            _navButtons(),
          ],
        ),
      ),
    );
  }

  Widget _progressHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('ReplyGenius',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('Step ${_step + 1} / 5',
                  style: const TextStyle(color: AppTheme.textMuted)),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: (_step + 1) / 5,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
          ),
        ],
      ),
    );
  }

  Widget _navButtons() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          if (_step > 0)
            TextButton(onPressed: _back, child: const Text('Back'))
          else
            const SizedBox(width: 0),
          const Spacer(),
          FilledButton(
            onPressed: _next,
            child: Text(_step == 4 ? 'Finish setup' : 'Continue'),
          ),
        ],
      ),
    );
  }

  Widget _stepBusiness() => _StepShell(
        title: 'Tell us about your business',
        subtitle:
            'This is the foundation. The richer the context, the more on-brand '
            'and helpful every generated reply becomes.',
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
                labelText: 'Business name *',
                hintText: 'e.g. Sharma Sweets & Snacks'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _industryCtrl,
            decoration: const InputDecoration(
                labelText: 'Industry',
                hintText: 'e.g. Food delivery, Electronics, Salon'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Describe your business *',
              hintText:
                  'What you sell, who your customers are, what makes you different, your service hours, etc.',
            ),
          ),
        ],
      );

  Widget _stepVoice() => _StepShell(
        title: 'Set your tone',
        subtitle:
            'How should the AI sound when replying to angry customers? Pick a calm default — you can change this later.',
        children: [
          _segmented(
            label: 'Default tone',
            value: _tone,
            options: const {
              'calm': 'Calm & empathetic',
              'professional': 'Professional & firm',
              'friendly': 'Friendly & warm',
            },
            onChanged: (v) => setState(() => _tone = v),
          ),
          const SizedBox(height: 16),
          _segmented(
            label: 'Apology style',
            value: _apology,
            options: const {
              'soft': 'Soft & genuine',
              'corporate': 'Corporate & formal',
              'warm': 'Warm & personal',
            },
            onChanged: (v) => setState(() => _apology = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _voiceCtrl,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Sample of how YOU normally write (optional)',
              hintText:
                  'Paste 1-2 sentences in your real voice. The AI will mimic this style.',
            ),
          ),
        ],
      );

  Widget _stepPolicies() => _StepShell(
        title: 'Your policies',
        subtitle:
            'These become hard guardrails. The AI will respect them and never invent new ones.',
        children: [
          TextField(
            controller: _refundCtrl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Refund / return policy',
              hintText: 'e.g. Full refund within 7 days if product is unused.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _shippingCtrl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Shipping / delivery policy',
              hintText: 'e.g. Same-day delivery in city, 2-3 days elsewhere.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contactCtrl,
            decoration: const InputDecoration(
              labelText: 'Support contact (phone/email)',
              hintText: 'e.g. +91 98765 43210 / help@sharmasweets.in',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _escalationCtrl,
            decoration: const InputDecoration(
              labelText: 'Escalation contact (for serious issues)',
              hintText: 'e.g. Owner direct: +91 98765 43210',
            ),
          ),
        ],
      );

  Widget _stepDosDonts() => _StepShell(
        title: 'Do\'s & Don\'ts',
        subtitle:
            'Guardrails for the AI. List things it should always do and never do.',
        children: [
          _listEditor(
            label: 'Always do',
            items: _dos,
            controller: _doCtrl,
            hint: 'e.g. Offer 10% discount coupon for repeat issues',
          ),
          const SizedBox(height: 16),
          _listEditor(
            label: 'Never do',
            items: _donts,
            controller: _dontCtrl,
            hint: 'e.g. Never promise full refund without owner approval',
          ),
        ],
      );

  Widget _stepApiKey() => _StepShell(
        title: 'Connect Gemini AI',
        subtitle:
            'ReplyGenius uses Google\'s Gemini model to draft replies. Get a free API key at '
            'aistudio.google.com/app/apikey',
        children: [
          TextField(
            controller: _apiKeyCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Gemini API Key',
              hintText: 'AIza...',
              prefixIcon: Icon(Icons.key),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline, color: Color(0xFF1D4ED8), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your API key is stored encrypted on this device only. '
                    'It never leaves your phone — every reply is generated directly from your device to Google.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF1E3A8A)),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _segmented({
    required String label,
    required String value,
    required Map<String, String> options,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: options.entries.map((e) {
            final selected = e.key == value;
            return ChoiceChip(
              label: Text(e.value),
              selected: selected,
              onSelected: (_) => onChanged(e.key),
              selectedColor: AppTheme.primary.withOpacity(0.15),
              side: BorderSide(
                color: selected ? AppTheme.primary : const Color(0xFFCBD5E1),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _listEditor({
    required String label,
    required List<String> items,
    required TextEditingController controller,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(hintText: hint, isDense: true),
                onSubmitted: (_) => _add(items, controller),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: () => _add(items, controller),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((item) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(item),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => items.remove(item)),
              ),
            )),
      ],
    );
  }

  void _add(List<String> list, TextEditingController ctrl) {
    final t = ctrl.text.trim();
    if (t.isEmpty) return;
    setState(() {
      list.add(t);
      ctrl.clear();
    });
  }
}

class _StepShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  const _StepShell({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 14)),
          const SizedBox(height: 20),
          ...children,
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
