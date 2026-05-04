import 'package:flutter/material.dart';
import '../api/api_models.dart';
import '../api/api_service.dart';
import 'widgets/section_card.dart';

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail =
          await ApiService.instance.getRecordDetail(widget.recordId);
      if (mounted) {
        setState(() {
          _detail = detail;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('기록이 삭제되었습니다.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
        setState(() => _deleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_detail != null
            ? '${_detail!.date} · ${_detail!.department}'
            : '상세 기록'),
        actions: [
          if (_deleting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_detail != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: '기록 삭제',
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('불러오기 실패', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchDetail,
                icon: const Icon(Icons.refresh),
                label: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    final d = _detail!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoRow(d),
        const SizedBox(height: 16),
        SectionCard(
          title: '원문 텍스트',
          child: Text(
            d.cleanText.isEmpty ? '(내용 없음)' : d.cleanText,
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: '요약',
          child: d.summary.isEmpty
              ? const Text('요약 내용이 없습니다.')
              : BulletList(items: d.summary),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: '의료 용어',
          subtitle: '용어를 탭하면 설명을 볼 수 있습니다.',
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            d.department,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
