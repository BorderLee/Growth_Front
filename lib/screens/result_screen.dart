import 'package:flutter/material.dart';
import '../api/api_models.dart';
import '../api/api_service.dart';
import 'widgets/section_card.dart';
import 'records_screen.dart';

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
  final String? warningMessage;
  const ResultScreen({super.key, required this.transcript, this.warningMessage});

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
    if (widget.warningMessage == null) _fetchAll();
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

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';


  Future<void> _showSaveDialog() async {
    String selectedDept = _departments.first;
    DateTime selectedDate = DateTime.now();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('진료 기록 저장'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('진료 날짜',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text(_formatDate(selectedDate)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  alignment: Alignment.centerLeft,
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    helpText: '진료 날짜 선택',
                    confirmText: '확인',
                    cancelText: '취소',
                  );
                  if (picked != null) {
                    setDialogState(() => selectedDate = picked);
                  }
                },
              ),
              const SizedBox(height: 16),
              const Text('진료과',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: selectedDept,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
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
            FilledButton.icon(
              onPressed: () => Navigator.of(ctx).pop(true),
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('저장하기'),
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
          date: _formatDate(selectedDate),
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
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const RecordsScreen()),
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
              onPressed: (_loadingSummary || _loadingTerms) ? null : _showSaveDialog,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: '원문 텍스트',
            child: Text(
              widget.transcript.isEmpty ? '(내용 없음)' : widget.transcript,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: '요약',
            child: _buildSummaryBody(),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: '의료 용어',
            subtitle: '용어를 탭하면 설명을 볼 수 있습니다.',
            child: _buildTermsBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBody() {
    if (_loadingSummary) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: CircularProgressIndicator(),
      ));
    }
    if (_summaryError != null) return _ErrorText(_summaryError!);
    if (_summary == null || _summary!.isEmpty) {
      return const Text('요약 결과가 없습니다.');
    }
    return BulletList(items: _summary!);
  }

  Widget _buildTermsBody() {
    if (_loadingTerms) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: CircularProgressIndicator(),
      ));
    }
    if (_termsError != null) return _ErrorText(_termsError!);
    if (_terms == null || _terms!.isEmpty) {
      return const Text('추출된 의료 용어가 없습니다.');
    }
    return TermChipList(terms: _terms!);
  }
}

/// 인라인 오류 표시 (섹션 카드 내부용)
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

//음성이 인식되지 않았을 때
class _WarningText extends StatelessWidget {
  final String message;
  const _WarningText(this.message);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.mic_off_outlined, color: Colors.orange, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Colors.orange, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
