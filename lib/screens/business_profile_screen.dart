import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/business_profile.dart';
import '../services/reply_engine.dart';
import '../utils/theme.dart';

class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key});
  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _industry;
  late final TextEditingController _desc;
  late final TextEditingController _refund;
  late final TextEditingController _shipping;
  late final TextEditingController _contact;
  late final TextEditingController _escalation;
  late final TextEditingController _voice;

  late String _tone;
  late String _apology;
  late List<String> _dos;
  late List<String> _donts;

  @override
  void initState() {
    super.initState();
    final p = context.read<ReplyEngine>().profile;
    _name = TextEditingController(text: p.businessName);
    _industry = TextEditingController(text: p.industry);
    _desc = TextEditingController(text: p.description);
    _refund = TextEditingController(text: p.refundPolicy);
    _shipping = TextEditingController(text: p.shippingPolicy);
    _contact = TextEditingController(text: p.contactInfo);
    _escalation = TextEditingController(text: p.escalationContact);
    _voice = TextEditingController(text: p.brandVoiceSample);
    _tone = p.tone;
    _apology = p.apologyStyle;
    _dos = List.of(p.dos);
    _donts = List.of(p.donts);
  }

  @override
  void dispose() {
    for (final c in [
      _name, _industry, _desc, _refund, _shipping, _contact, _escalation, _voice,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final engine = context.read<ReplyEngine>();
    final existing = engine.profile;
    await engine.updateProfile(BusinessProfile(
      id: existing.id,
      businessName: _name.text.trim(),
      industry: _industry.text.trim(),
      description: _desc.text.trim(),
      tone: _tone,
      apologyStyle: _apology,
      dos: _dos,
      donts: _donts,
      refundPolicy: _refund.text.trim(),
      shippingPolicy: _shipping.text.trim(),
      contactInfo: _contact.text.trim(),
      brandVoiceSample: _voice.text.trim(),
      escalationContact: _escalation.text.trim(),
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
    ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Business profile updated — AI re-trained')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Business profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _section('Identity'),
            TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Business name *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _industry, decoration: const InputDecoration(labelText: 'Industry')),
            const SizedBox(height: 12),
            TextFormField(controller: _desc, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Description *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
            const SizedBox(height: 24),

            _section('Voice'),
            _segmented('Tone', _tone, const {
              'calm': 'Calm', 'professional': 'Professional', 'friendly': 'Friendly',
            }, (v) => setState(() => _tone = v)),
            const SizedBox(height: 12),
            _segmented('Apology', _apology, const {
              'soft': 'Soft', 'corporate': 'Corporate', 'warm': 'Warm',
            }, (v) => setState(() => _apology = v)),
            const SizedBox(height: 12),
            TextFormField(controller: _voice, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Brand voice sample')),
            const SizedBox(height: 24),

            _section('Policies'),
            TextFormField(controller: _refund, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'Refund policy')),
            const SizedBox(height: 12),
            TextFormField(controller: _shipping, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'Shipping policy')),
            const SizedBox(height: 12),
            TextFormField(controller: _contact, decoration: const InputDecoration(labelText: 'Support contact')),
            const SizedBox(height: 12),
            TextFormField(controller: _escalation, decoration: const InputDecoration(labelText: 'Escalation contact')),
            const SizedBox(height: 24),

            _section('Do\'s'),
            ..._dos.asMap().entries.map((e) => _listRow(e.value, () => setState(() => _dos.removeAt(e.key)))),
            _addChip(_dos, 'Add a "do"'),
            const SizedBox(height: 16),

            _section('Don\'ts'),
            ..._donts.asMap().entries.map((e) => _listRow(e.value, () => setState(() => _donts.removeAt(e.key)))),
            _addChip(_donts, 'Add a "don\'t"'),
            const SizedBox(height: 32),

            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save & re-train'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primary)),
      );

  Widget _listRow(String text, VoidCallback onRemove) => ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(text),
        trailing: IconButton(icon: const Icon(Icons.close, size: 18), onPressed: onRemove),
      );

  Widget _addChip(List<String> list, String hint) {
    final ctrl = TextEditingController();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(child: TextField(controller: ctrl, decoration: InputDecoration(hintText: hint, isDense: true))),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: () {
              final t = ctrl.text.trim();
              if (t.isEmpty) return;
              setState(() => list.add(t));
              ctrl.clear();
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _segmented(String label, String value, Map<String, String> opts, ValueChanged<String> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: opts.entries
              .map((e) => ChoiceChip(
                    label: Text(e.value),
                    selected: e.key == value,
                    onSelected: (_) => onChanged(e.key),
                    selectedColor: AppTheme.primary.withOpacity(0.15),
                  ))
              .toList(),
        ),
      ],
    );
  }
}
