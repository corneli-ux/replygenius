import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/native_bridge_service.dart';
import '../services/reply_engine.dart';
import '../utils/theme.dart';
import '../widgets/sentiment_badge.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPermissions());
  }

  Future<void> _checkPermissions() async {
    final bridge = context.read<NativeBridgeService>();
    final notif = await bridge.isNotificationAccessGranted();
    final overlay = await bridge.isOverlayPermissionGranted();
    if (!notif || !overlay) {
      if (mounted) _showPermissionSheet(notif, overlay);
    }
  }

  void _showPermissionSheet(bool notif, bool overlay) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enable ReplyGenius',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
                'Two permissions are needed for the app to read incoming '
                'messages and show reply suggestions over WhatsApp/SMS.',
                style: TextStyle(color: AppTheme.textMuted)),
            const SizedBox(height: 20),
            if (!notif) _permissionRow('Notification access', 'Required to read incoming WhatsApp & SMS messages', Icons.notifications_active, () async {
              await context.read<NativeBridgeService>().openNotificationListenerSettings();
            }),
            if (!overlay) ...[
              const SizedBox(height: 12),
              _permissionRow('Display over other apps', 'Required to show the reply bubble over your chat', Icons.picture_in_picture, () async {
                await context.read<NativeBridgeService>().requestOverlayPermission();
              }),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('I\'ve enabled them'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _permissionRow(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
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
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<ReplyEngine>();
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('ReplyGenius'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.pushNamed(context, '/history'),
            tooltip: 'Reply history',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _statusCard(engine),
          const SizedBox(height: 16),
          _quickActions(),
          const SizedBox(height: 16),
          _howItWorks(),
          const SizedBox(height: 16),
          _profileSummary(engine),
        ],
      ),
    );
  }

  Widget _statusCard(ReplyEngine engine) {
    final ready = engine.isConfigured;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primary, AppTheme.primaryDark],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      ready ? Icons.check_circle : Icons.error_outline,
                      color: Colors.white, size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(ready ? 'Ready' : 'Setup incomplete',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const Spacer(),
              if (engine.isGenerating)
                const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            engine.profile.businessName.isEmpty
                ? 'Your calm AI co-pilot'
                : engine.profile.businessName,
            style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            engine.lastStatus,
            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Icon(Icons.shield_outlined, color: Colors.white70, size: 16),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Listening for WhatsApp & SMS messages',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickActions() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _actionCard(
          icon: Icons.business_center,
          title: 'Business profile',
          subtitle: 'Edit training data',
          onTap: () => Navigator.pushNamed(context, '/profile'),
        ),
        _actionCard(
          icon: Icons.quiz_outlined,
          title: 'FAQ knowledge',
          subtitle: 'Add Q&As',
          onTap: () => Navigator.pushNamed(context, '/faq'),
        ),
        _actionCard(
          icon: Icons.science_outlined,
          title: 'Test a reply',
          subtitle: 'Simulate a message',
          onTap: () => Navigator.pushNamed(context, '/tester'),
        ),
        _actionCard(
          icon: Icons.history,
          title: 'Reply history',
          subtitle: 'Past replies',
          onTap: () => Navigator.pushNamed(context, '/history'),
        ),
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppTheme.primary, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _howItWorks() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('How it works',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 12),
            _step(1, 'Customer sends an angry WhatsApp or SMS'),
            _step(2, 'ReplyGenius analyzes the emotion & anger level'),
            _step(3, 'AI drafts 2 calm, skillful reply options'),
            _step(4, 'Bubble appears over your chat — tap to copy'),
            _step(5, 'Paste into WhatsApp — issue defused'),
          ],
        ),
      ),
    );
  }

  Widget _step(int n, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('$n', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _profileSummary(ReplyEngine engine) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Current training', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/profile'),
                  child: const Text('Edit'),
                ),
              ],
            ),
            const Divider(),
            _kv('Business', engine.profile.businessName.isEmpty ? '—' : engine.profile.businessName),
            _kv('Industry', engine.profile.industry.isEmpty ? '—' : engine.profile.industry),
            _kv('Tone', engine.profile.tone),
            _kv('FAQs', '${engine.faqs.length} entries'),
            _kv('Do\'s', '${engine.profile.dos.length} rules'),
            _kv('Don\'ts', '${engine.profile.donts.length} rules'),
            const SizedBox(height: 12),
            const SentimentBadge(angerScore: 3),
            const SizedBox(height: 4),
            const Text('Sample badge: how an incoming message\'s anger will be displayed.',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(k, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
            const Spacer(),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      );
}
