import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/native_bridge_service.dart';
import '../services/reply_engine.dart';
import '../services/storage_service.dart';
import '../utils/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKey = TextEditingController();
  bool _obscure = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final k = await context.read<StorageService>().loadApiKey();
    setState(() => _apiKey.text = k);
  }

  @override
  void dispose() {
    _apiKey.dispose();
    super.dispose();
  }

  Future<void> _saveKey() async {
    setState(() => _saving = true);
    await context.read<ReplyEngine>().updateApiKey(_apiKey.text.trim());
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API key updated')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<ReplyEngine>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _section('AI Engine'),
          TextField(
            controller: _apiKey,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Gemini API Key',
              hintText: 'AIza...',
              prefixIcon: const Icon(Icons.key),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _saving ? null : _saveKey,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            label: const Text('Save API key'),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF1D4ED8), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Get a free key at aistudio.google.com/app/apikey',
                    style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _section('Permissions'),
          _permissionTile(
            icon: Icons.notifications_active,
            title: 'Notification access',
            status: 'Required to read incoming WhatsApp/SMS',
            onTap: () => context.read<NativeBridgeService>().openNotificationListenerSettings(),
          ),
          const SizedBox(height: 8),
          _permissionTile(
            icon: Icons.picture_in_picture,
            title: 'Draw over other apps',
            status: 'Required to show the reply bubble',
            onTap: () => context.read<NativeBridgeService>().requestOverlayPermission(),
          ),
          const SizedBox(height: 24),

          _section('Status'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _row('Business configured', engine.profile.isConfigured),
                  _row('API key set', _apiKey.text.isNotEmpty),
                  _row('FAQs loaded', engine.faqs.isNotEmpty),
                  _row('Do\'s defined', engine.profile.dos.isNotEmpty),
                  _row('Don\'ts defined', engine.profile.donts.isNotEmpty),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          _section('About'),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.auto_awesome, color: AppTheme.primary),
            title: Text('ReplyGenius v1.0'),
            subtitle: Text('Calm AI co-pilot for customer replies'),
          ),
        ],
      ),
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 10),
        child: Text(t,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.primary)),
      );

  Widget _permissionTile({
    required IconData icon,
    required String title,
    required String status,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(status,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, bool ok) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked,
                color: ok ? AppTheme.accent : AppTheme.textMuted, size: 18),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
      );
}
