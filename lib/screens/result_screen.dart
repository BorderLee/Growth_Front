import 'package:flutter/material.dart';
import '../api/api_models.dart';
import '../api/api_service.dart';

const _departments = [
  '내과',
  '외과',
  '소화기내과',
  '심장내과',
  '정형외과',
  '신경외과',
  '산부인과',
  '소아청소년과',
  '피부과',
  '안과',
  '이비인후과',
  '비뇨기과',
  '정신건강의학과',
  '가정의학과',
  '응급의학과',
  '기타',
];

class ResultScreen extends StatefulWidget {
  final String transcript;

  const ResultScreen({super.key, required this.transcript});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  List<String>? _summary;
  List<MedTerm>? _terms;
  bool _loadingSummary = true;
  bool _loadingTerms = true;
  String? _summaryError;
  String? _termsError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    await Future.wait([_fetchSummary(), _fetchTerms()]);
  }

  Future<void> _fetchSummary() async {
    try {
      final res = await ApiService.instance.getSummary(widget.transcript);
      if (mounted) {
        setState(() {
          _summary = res.summary;
          _loadingSummary = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _summaryError = e.toString();
          _loadingSummary = false;
        });
      }
    }
  }

  Future<void> _fetchTerms() async {
    try {
      final res = await ApiService.instance.getExplain(widget.transcript);
      if (mounted) {
        setState(() {
          _terms = res.terms;
          _loadingTerms = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _termsError = e.toString();
          _loadingTerms = false;
        });
      }
    }
  }

  void _showTermDialog(MedTerm term) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          term.term,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(term.description),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSaveDialog() async {
    String selectedDept = _departments.first;
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('기록 저장'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('날짜: $dateStr'),
              const SizedBox(height: 12),
              const Text('진료과 선택'),
              const SizedBox(height: 4),
              DropdownButton<String>(
                value: selectedDept,
                isExpanded: true,
                items: _departments
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => selectedDept = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await ApiService.instance.saveRecord(
        SaveRecordRequest(
          date: dateStr,
          department: selectedDept,
          cleanText: widget.transcript,
          summary: _summary ?? [],
          terms: _terms ?? [],
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('기록이 저장되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('분석 결과'),
        actions: [
          if (_saving)
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
          else
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: '기록 저장',
              onPressed: (_summary == null && _terms == null) ? null : _showSaveDialog,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildOriginalText(),
          const SizedBox(height: 20),
          _buildSummarySection(),
          const SizedBox(height: 20),
          _buildTermsSection(),
        ],
      ),
    );
  }

  Widget _buildOriginalText() {
    return _SectionCard(
      title: '원문 텍스트',
      child: Text(
        widget.transcript.isEmpty ? '(내용 없음)' : widget.transcript,
        style: const TextStyle(fontSize: 15, height: 1.5),
      ),
    );
  }

  Widget _buildSummarySection() {
    Widget body;
    if (_loadingSummary) {
      body = const Center(
          child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: CircularProgressIndicator(),
      ));
    } else if (_summaryError != null) {
      body = _ErrorText(_summaryError!);
    } else if (_summary == null || _summary!.isEmpty) {
      body = const Text('요약 결과가 없습니다.');
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _summary!
            .map(
              (s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(s, style: const TextStyle(fontSize: 15)),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      );
    }

    return _SectionCard(title: '요약', child: body);
  }

  Widget _buildTermsSection() {
    Widget body;
    if (_loadingTerms) {
      body = const Center(
          child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: CircularProgressIndicator(),
      ));
    } else if (_termsError != null) {
      body = _ErrorText(_termsError!);
    } else if (_terms == null || _terms!.isEmpty) {
      body = const Text('추출된 의료 용어가 없습니다.');
    } else {
      body = Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _terms!
            .map(
              (t) => ActionChip(
                label: Text(t.term),
                onPressed: () => _showTermDialog(t),
                backgroundColor:
                    Theme.of(context).colorScheme.secondaryContainer,
                labelStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
            .toList(),
      );
    }

    return _SectionCard(
      title: '의료 용어',
      subtitle: '용어를 탭하면 설명을 볼 수 있습니다.',
      child: body,
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline)),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  final String message;
  const _ErrorText(this.message);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '오류: $message',
            style: const TextStyle(color: Colors.red, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
