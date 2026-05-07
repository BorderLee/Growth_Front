import 'package:flutter/material.dart';
import '../../api/api_models.dart';
import '../../api/api_service.dart';
import 'section_card.dart';

class _NextVisitItem {
  String text;
  bool checked;
  _NextVisitItem(this.text) : checked = false;
}

class QuestionTab extends StatefulWidget {
  final String transcript;
  const QuestionTab({super.key, required this.transcript});

  @override
  State<QuestionTab> createState() => _QuestionTabState();
}

class _QuestionTabState extends State<QuestionTab> {
  final _questionController = TextEditingController();
  String? _submittedQuestion;
  bool _buttonEnabled = false;
  bool _loading = false;
  QuestionResponse? _response;

  final List<_NextVisitItem> _nextVisitItems = [];

  @override
  void initState() {
    super.initState();
    _questionController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _questionController.removeListener(_onTextChanged);
    _questionController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _questionController.text;
    final hasContent = text.trim().isNotEmpty;
    // 제출 후에는 텍스트가 제출 당시와 달라야 활성화
    final isDifferent = _submittedQuestion == null || text != _submittedQuestion;
    setState(() => _buttonEnabled = hasContent && isDifferent);
  }

  Future<void> _submitQuestion() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) return;

    _submittedQuestion = _questionController.text;
    setState(() {
      _buttonEnabled = false;
      _loading = true;
      _response = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('질문 완료되었습니다'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    try {
      final res = await ApiService.instance.askQuestion(question, widget.transcript);
      if (mounted) setState(() { _response = res; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류가 발생했습니다: $e')),
        );
      }
    }
  }

  void _sendToDoctor() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('의사에게 질문이 전송되었습니다.')),
    );
  }

  void _addNextVisitItem() {
    showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('질문 추가'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '질문을 입력하세요',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
              child: const Text('추가'),
            ),
          ],
        );
      },
    ).then((text) {
      if (text != null && text.isNotEmpty) {
        setState(() => _nextVisitItems.add(_NextVisitItem(text)));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final showSendToDoctor = _response != null && !_response!.canAnswer;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildQuestionInput(),
            const SizedBox(height: 16),
            _buildAiAnswerSection(),
            const SizedBox(height: 16),
            _buildNextVisitSection(),
            const SizedBox(height: 16),
            _buildUrgentSection(),
            const SizedBox(height: 16),
            _buildDisclaimer(),
            const SizedBox(height: 80),
          ],
        ),
        if (showSendToDoctor)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              onPressed: _sendToDoctor,
              icon: const Icon(Icons.send),
              label: const Text('전송하기'),
            ),
          ),
      ],
    );
  }

  Widget _buildQuestionInput() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _questionController,
                decoration: const InputDecoration(
                  hintText: '진료 후 궁금한 점을 입력하세요...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                maxLines: null,
                textInputAction: TextInputAction.done,
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: FilledButton(
                onPressed: _buttonEnabled ? _submitQuestion : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  minimumSize: Size.zero,
                ),
                child: const Text('전송'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiAnswerSection() {
    return SectionCard(
      title: 'AI 답변',
      child: _buildAiAnswerBody(),
    );
  }

  Widget _buildAiAnswerBody() {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_response == null) {
      return const Text(
        '질문을 입력하고 전송하면 AI가 답변을 드립니다.',
        style: TextStyle(color: Colors.grey, fontSize: 14),
      );
    }

    if (_response!.canAnswer) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Q. ${_submittedQuestion?.trim() ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3,
                ),
              ),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
            ),
            child: Text(
              _response!.answer ?? '',
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                '이 답변은 의학적 조언이 아닙니다.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      );
    }

    // AI가 답변할 수 없는 경우
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 18, color: Colors.orange),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            '이 질문은 AI가 답변할 수 없어요!\n진료가 예정된 의사에 질문을 전송할게요',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildNextVisitSection() {
    return SectionCard(
      title: '다음 진료 때 물어볼 것',
      trailing: IconButton(
        icon: const Icon(Icons.add, size: 20),
        onPressed: _addNextVisitItem,
        tooltip: '질문 추가',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
      child: _nextVisitItems.isEmpty
          ? const Text(
              '+ 버튼으로 다음 진료 때 물어볼 질문을 추가하세요.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            )
          : Column(
              children: [
                for (int i = 0; i < _nextVisitItems.length; i++)
                  CheckboxListTile(
                    value: _nextVisitItems[i].checked,
                    onChanged: (v) {
                      setState(() => _nextVisitItems[i].checked = v ?? false);
                    },
                    title: Text(
                      _nextVisitItems[i].text,
                      style: TextStyle(
                        fontSize: 14,
                        decoration: _nextVisitItems[i].checked
                            ? TextDecoration.lineThrough
                            : null,
                        color: _nextVisitItems[i].checked ? Colors.grey : null,
                      ),
                    ),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
              ],
            ),
    );
  }

  Widget _buildUrgentSection() {
    final symptoms = _response?.urgentSymptoms ?? [];

    return SectionCard(
      title: '지금 바로 확인 필요',
      child: symptoms.isEmpty
          ? Text(
              '아직 긴급 증상이 없어요',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: symptoms
                  .map(
                    (s) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_rounded,
                              size: 16, color: Colors.red),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(s, style: const TextStyle(fontSize: 14)),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildDisclaimer() {
    return Text(
      '본 서비스는 의료법상 의료행위를 제공하지 않으며, 질병의 진단·치료·예방을 목적으로 하지 않습니다. '
      '제공되는 결과 및 콘텐츠는 AI 기반 참고 정보로서 정확성이나 완전성을 보장하지 않으며, '
      '의학적 판단의 근거로 단독 사용되어서는 안 됩니다.',
      style: TextStyle(
        fontSize: 11,
        color: Colors.grey[500],
        height: 1.5,
      ),
      textAlign: TextAlign.center,
    );
  }
}
