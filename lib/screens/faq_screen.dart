import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/faq.dart';
import '../services/reply_engine.dart';
import '../utils/theme.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});
  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  late List<FAQ> _faqs;

  @override
  void initState() {
    super.initState();
    _faqs = List.of(context.read<ReplyEngine>().faqs);
  }

  Future<void> _persist() async {
    await context.read<ReplyEngine>().updateFaqs(_faqs);
  }

  void _addOrEdit([FAQ? existing]) async {
    final q = TextEditingController(text: existing?.question ?? '');
    final a = TextEditingController(text: existing?.answer ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add FAQ' : 'Edit FAQ'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: q, decoration: const InputDecoration(labelText: 'Question', hintText: 'e.g. What is your return window?')),
              const SizedBox(height: 12),
              TextField(controller: a, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Answer')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (result != true) return;
    if (q.text.trim().isEmpty || a.text.trim().isEmpty) return;

    setState(() {
      if (existing != null) {
        final i = _faqs.indexWhere((f) => f.id == existing.id);
        if (i >= 0) {
          _faqs[i] = FAQ(
            id: existing.id,
            question: q.text.trim(),
            answer: a.text.trim(),
            createdAt: existing.createdAt,
          );
        }
      } else {
        _faqs.add(FAQ(
          id: const Uuid().v4(),
          question: q.text.trim(),
          answer: a.text.trim(),
          createdAt: DateTime.now(),
        ));
      }
    });
    await _persist();
  }

  void _delete(String id) async {
    setState(() => _faqs.removeWhere((f) => f.id == id));
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FAQ knowledge')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEdit(),
        child: const Icon(Icons.add),
      ),
      body: _faqs.isEmpty
          ? _emptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _faqs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final f = _faqs[i];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(14),
                    title: Text(f.question, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(f.answer, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') _addOrEdit(f);
                        if (v == 'delete') _delete(f.id);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _emptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.quiz_outlined, size: 64, color: AppTheme.primary.withOpacity(0.4)),
              const SizedBox(height: 12),
              const Text('No FAQs yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text(
                'Add common questions and their official answers. The AI will lean on these facts when replying to customers.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      );
}
