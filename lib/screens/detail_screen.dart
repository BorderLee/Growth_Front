import 'package:flutter/material.dart';
import '../api/api_models.dart';
import '../api/api_service.dart';
import 'widgets/section_card.dart';
import 'question_screen.dart';
import 'result_screen.dart';

class RecordDetailScreen extends StatefulWidget {
  final String recordId;
  const RecordDetailScreen({super.key, required this.recordId});

  @override
  State<RecordDetailScreen> createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends State<RecordDetailScreen> {
  RecordDetail? _detail;
  bool _loading = true;
  String? _error;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() { _loading = true; _error = null; });
    try {
      final detail = await ApiService.instance.getRecordDetail(widget.recordId);
      if (mounted) setState(() { _detail = detail; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('기록 삭제'),
        content: const Text('이 진료 기록을 삭제하시겠습니까?\n삭제된 기록은 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ApiService.instance.deleteRecord(widget.recordId);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('기록이 삭제되었습니다.')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
        setState(() => _deleting = false);
      }
    }
  }

  void _goToEdit() {
    final d = _detail;
    if (d == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          transcript: d.cleanText,
          initialSummary: d.summary,
          initialTerms: d.terms,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(_detail != null
              ? '${_detail!.date} · ${_detail!.department}'
              : '상세 기록'),
          bottom: kAnalysisTabBar,
          actions: [
            if (_deleting)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              )
            else if (_detail != null) ...[
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: '편집하기',
                onPressed: _goToEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: '기록 삭제',
                onPressed: _confirmDelete,
              ),
            ],
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const ScreenLoading();
    if (_error != null) return ScreenError(message: _error!, onRetry: _fetchDetail);

    final d = _detail!;
    return TabBarView(
      children: [
        _buildDetailTab(d),
        QuestionTab(transcript: d.cleanText),
      ],
    );
  }

  Widget _buildDetailTab(RecordDetail d) {
    return SectionListView(
      children: [
        _buildInfoRow(d),
        SectionCard(
          title: '원문 텍스트',
          child: Text(
            d.cleanText.isEmpty ? '(내용 없음)' : d.cleanText,
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
        ),
        SectionCard(
          title: '요약',
          child: d.summary.isEmpty
              ? const Text('요약 내용이 없습니다.')
              : BulletList(items: d.summary),
        ),
        MedTermsSectionCard(
          child: d.terms.isEmpty
              ? const Text('추출된 의료 용어가 없습니다.')
              : TermChipList(terms: d.terms),
        ),
      ],
    );
  }

  Widget _buildInfoRow(RecordDetail d) {
    return Row(
      children: [
        const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text(d.date, style: const TextStyle(color: Colors.grey)),
        const SizedBox(width: 12),
        AppBadge(
          label: d.department,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          textColor: Theme.of(context).colorScheme.onPrimaryContainer,
          fontSize: 13,
        ),
      ],
    );
  }
}
