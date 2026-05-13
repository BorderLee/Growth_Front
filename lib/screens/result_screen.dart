import 'package:flutter/material.dart';
import '../api/api_models.dart';
import '../api/api_service.dart';
import 'widgets/section_card.dart';
import 'question_screen.dart';
import 'list_screen.dart';
//stt 변환 결과 창

const _departments = [
  '내과', '정형외과', '피부과', '안과', '이비인후과',
  '신경과', '외과', '산부인과', '소아청소년과', '정신건강의학과',
  '비뇨기과', '가정의학과', '응급의학과', '기타',
];

String _fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ─────────────────────────────────────────
class ResultScreen extends StatefulWidget {
  final String transcript;
  final String? warningMessage;
  final List<String>? initialSummary;
  final List<MedTerm>? initialTerms;

  const ResultScreen({
    super.key,
    required this.transcript,
    this.warningMessage,
    this.initialSummary,
    this.initialTerms,
  });

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

  bool _transcriptExpanded = false;
  bool _editingSummary = false;
  late List<TextEditingController> _summaryControllers;
  final _memoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _summaryControllers = [];

    if (widget.initialSummary != null) {
      _summary = List.from(widget.initialSummary!);
      _loadingSummary = false;
    }
    if (widget.initialTerms != null) {
      _terms = List.from(widget.initialTerms!);
      _loadingTerms = false;
    }

    if (widget.warningMessage == null) {
      if (_summary == null) _fetchSummary();
      if (_terms == null) _fetchTerms();
    }
  }

  @override
  void dispose() {
    for (final c in _summaryControllers) c.dispose();
    _memoController.dispose();
    super.dispose();
  }

  void _initSummaryControllers(List<String> items) {
    for (final c in _summaryControllers) c.dispose();
    _summaryControllers = items.map((s) => TextEditingController(text: s)).toList();
  }

  void _toggleEditSummary() {
    if (!_editingSummary && _summary != null) _initSummaryControllers(_summary!);
    if (_editingSummary) {
      final edited =
          _summaryControllers.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
      setState(() { _summary = edited; _editingSummary = false; });
    } else {
      setState(() => _editingSummary = true);
    }
  }

  Future<void> _fetchSummary() async {
    try {
      final res = await ApiService.instance.getSummary(widget.transcript);
      if (mounted) setState(() { _summary = res.summary; _loadingSummary = false; });
    } catch (e) {
      if (mounted) setState(() { _summaryError = e.toString(); _loadingSummary = false; });
    }
  }

  Future<void> _fetchTerms() async {
    try {
      final res = await ApiService.instance.getExplain(widget.transcript);
      if (mounted) setState(() { _terms = res.terms; _loadingTerms = false; });
    } catch (e) {
      if (mounted) setState(() { _termsError = e.toString(); _loadingTerms = false; });
    }
  }

  Future<void> _showSaveBottomSheet() async {
    final result = await showModalBottomSheet<({String dept, DateTime date})>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DepartmentPickerSheet(transcript: widget.transcript),
    );
    if (result == null || !mounted) return;
    await _doSave(result.dept, result.date);
  }

  Future<void> _doSave(String department, DateTime date) async {
    setState(() => _saving = true);
    try {
      final memo = _memoController.text.trim();
      final summaryToSave = List<String>.from(_summary ?? []);
      if (memo.isNotEmpty) summaryToSave.add('[메모] $memo');

      await ApiService.instance.saveRecord(
        SaveRecordRequest(
          date: _fmtDate(date),
          department: department,
          cleanText: widget.transcript,
          summary: summaryToSave,
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('저장 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSave = widget.warningMessage == null &&
        !_loadingSummary &&
        !_loadingTerms &&
        !_saving;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.blue[100],
          title: const Text('분석 결과'),
          bottom: kAnalysisTabBar,
        ),
        body: Column(
          children: [
            Expanded(
              child: TabBarView(
                children: [
                  _buildResultTab(),
                  QuestionTab(transcript: widget.transcript),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: _saving
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : FilledButton.icon(
                        onPressed: canSave ? _showSaveBottomSheet : null,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('저장하기',
                            style: TextStyle(fontSize: 16)),
                        style: FilledButton.styleFrom(
                          backgroundColor:Colors.blue[900],
                          minimumSize: const Size(double.infinity, 52),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultTab() {
    return SectionListView(
      children: [
        if (widget.warningMessage != null) ...[
          _ErrorText(widget.warningMessage!, icon: Icons.mic_off_outlined, color: Colors.orange),
          const SizedBox(height: 16),
        ],
        SectionCard(
          title: '원문 텍스트',
          trailing: TextButton.icon(
            onPressed: () =>
                setState(() => _transcriptExpanded = !_transcriptExpanded),
            icon: Icon(
              _transcriptExpanded ? Icons.expand_less : Icons.expand_more,
              size: 16,
            ),
            label: Text(_transcriptExpanded ? '줄이기' : '펼치기'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          child: Text(
            widget.transcript.isEmpty ? '(내용 없음)' : widget.transcript,
            style: const TextStyle(fontSize: 15, height: 1.5),
            maxLines: _transcriptExpanded ? null : 2,
            overflow: _transcriptExpanded
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
          ),
        ),
        SectionCard(
          title: '요약',
          subtitle: _editingSummary ? '내용을 수정한 후 완료를 누르세요.' : null,
          trailing: _summary != null && !_loadingSummary
              ? TextButton.icon(
                  onPressed: _toggleEditSummary,
                  icon: Icon(
                      _editingSummary ? Icons.check : Icons.edit_outlined,
                      size: 16),
                  label: Text(_editingSummary ? '완료' : '편집'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
              : null,
          child: _buildSummaryBody(),
        ),
        SectionCard(
          title: '추가 메모',
          child: TextField(
            controller: _memoController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: '기억해두고 싶은 내용을 입력하세요...',
            ),
          ),
        ),
        MedTermsSectionCard(child: _buildTermsBody()),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.amber),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '본 앱은 의료 정보 보조 도구이며, AI가 제공하는 정보는 참고용으로 정확한 내용은 반드시 담당 의사에게 확인하시기 바랍니다.',
                  style:
                      TextStyle(fontSize: 12, color: Colors.brown, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSummaryBody() {
    if (_loadingSummary) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: CircularProgressIndicator()));
    }
    if (_summaryError != null) return _ErrorText('오류: $_summaryError');
    if (_summary == null || _summary!.isEmpty) {
      return const Text('요약 결과가 없습니다.');
    }
    if (_editingSummary) {
      return Column(
        children: [
          for (int i = 0; i < _summaryControllers.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: _summaryControllers[i],
                maxLines: null,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.all(10),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    onPressed: () {
                      setState(() {
                        _summaryControllers[i].dispose();
                        _summaryControllers.removeAt(i);
                      });
                    },
                  ),
                ),
              ),
            ),
          TextButton.icon(
            onPressed: () =>
                setState(() => _summaryControllers.add(TextEditingController())),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('항목 추가'),
          ),
        ],
      );
    }
    return BulletList(items: _summary!);
  }

  Widget _buildTermsBody() {
    if (_loadingTerms) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: CircularProgressIndicator()));
    }
    if (_termsError != null) return _ErrorText('오류: $_termsError');
    if (_terms == null || _terms!.isEmpty) {
      return const Text('추출된 의료 용어가 없습니다.');
    }
    return TermChipList(terms: _terms!);
  }
}

// ─── 진료과 선택 바텀 시트 ────────────────────────────────
class _DepartmentPickerSheet extends StatefulWidget {
  final String transcript;
  const _DepartmentPickerSheet({required this.transcript});

  @override
  State<_DepartmentPickerSheet> createState() => _DepartmentPickerSheetState();
}

class _DepartmentPickerSheetState extends State<_DepartmentPickerSheet> {
  String _selectedDept = _departments.first;
  String? _aiDept;
  DateTime _selectedDate = DateTime.now();
  bool _loadingDept = true;

  @override
  void initState() {
    super.initState();
    _fetchAiDepartment();
  }

  Future<void> _fetchAiDepartment() async {
    try {
      final res = await ApiService.instance.getDepartment(widget.transcript);
      if (mounted) {
        setState(() {
          _aiDept = res.department;
          // AI 추천값이 목록에 있으면 기본 선택
          if (_departments.contains(res.department)) {
            _selectedDept = res.department;
          }
          _loadingDept = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDept = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPad + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 드래그 핸들
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('진료 기록 저장',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          // ── 날짜 ──────────────────────
          const Text('진료 날짜',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today_outlined, size: 16),
            label: Text(_fmtDate(_selectedDate)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              alignment: Alignment.centerLeft,
            ),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                helpText: '진료 날짜 선택',
                confirmText: '확인',
                cancelText: '취소',
              );
              if (picked != null && mounted) {
                setState(() => _selectedDate = picked);
              }
            },
          ),
          const SizedBox(height: 10),

          // ── 진료과 ────────────────────
          Row(
            children: [
              const Text('진료과',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(width: 8),
              if (_loadingDept)
                const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2))
              else if (_aiDept != null)
                AppBadge(
                  label: 'AI 추천',
                  backgroundColor: Colors.blue.shade50,
                  textColor: Colors.blue.shade700,
                  fontSize: 10,
                  borderRadius: 4,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _departments.map((dept) {
              final isSelected = dept == _selectedDept;
              final isAi = dept == _aiDept;
              return GestureDetector(
                onTap: () => setState(() => _selectedDept = dept),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: isAi && !isSelected
                        ? Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1.5)
                        : null,
                  ),
                  child: Text(
                    dept,
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight:
                          isAi ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // ── 저장 버튼 ─────────────────
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop((dept: _selectedDept, date: _selectedDate)),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            child: const Text('저장하기', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

// ─── 공통 위젯 ───────────────────────────────────────────
class _ErrorText extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color color;

  const _ErrorText(
    this.message, {
    this.icon = Icons.error_outline,
    this.color = Colors.red,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Text(message, style: TextStyle(color: color, fontSize: 13)),
        ),
      ],
    );
  }
}
