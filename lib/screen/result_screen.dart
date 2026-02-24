import 'package:flutter/material.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  String _currentStatus = "번역 중...";
  bool _isSessionWarning = false; // 20분 세션 알림 상태

  // 임시 더미 데이터 [나중에 받아야 할 서버 응답 JSON 데이터 구조]
  final Map<String, dynamic> responseData = {
    "summary_3sent": [
      {
        "text": "환자분은 피부가 얇아 절개 없이 실로 묶는 매몰법이 가장 적합합니다.",
        "isUncertain": true
      },
      {
        "text": "수술 후 3일간은 냉찜질을 하고, 일주일간 눈을 비비지 않도록 주의해야 합니다.",
        "isUncertain": false
      },
      {
        "text": "큰 부기는 일주일 내에 빠지며, 완전히 자리 잡는 데는 약 3개월이 소요됩니다.",
        "isUncertain": true
      }
    ],
    "easy_terms": [
      {"term": "매몰법", "desc": "칼로 긋지 않고 작은 구멍을 통해 실로 쌍꺼풀을 만드는 방식입니다."},
      {"term": "안검하수", "desc": "눈을 뜨는 근육의 힘이 약해 눈꺼풀이 처지는 현상입니다."}
    ],
    "next_actions": [
      "처방된 안약을 하루 3번 규칙적으로 넣기",
      "취침 시 머리를 높게 하여 부기 예방하기",
    ],
    "warnings": [
      "눈 부위가 갑자기 심하게 붉어지거나 통증이 있을 시 즉시 내원",
      "시야가 흐릿해지거나 출혈이 멈추지 않을 경우 연락 요망",
      "렌즈 착용은 최소 2주 뒤부터 권장"
      "실밥 제거 전까지 눈가 메이크업 피하기",
      "격렬한 운동은 한 달 뒤부터 시작하기"
    ]
  };

  // 체크리스트 상태 설정
  late List<bool> _actionChecks;

  @override
  void initState() {
    super.initState();
    _actionChecks = List<bool>.filled(responseData['next_actions'].length, false);
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text("진료 요약 결과"),
      actions: [
          //상단 상태 표시
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Chip(
              label: Text(_currentStatus, style: const TextStyle(fontSize: 12)),
              backgroundColor: Colors.blue[100],
            ),
          )
        ],
      ),
    body: Column(
      children: [
        //상단 안내 문구
        if (_isSessionWarning)
          Container(
            color: Colors.amber[100],
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            child: const Text(
              "⚠️ 상담 시작 후 20분이 경과되었습니다. 원활한 저장을 위해 세션을 재시작해 주세요.",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildSummaryCard(responseData['summary_3sent']),
              _buildEasyTermsCard(responseData['easy_terms']),
              _buildActionCard(responseData['next_actions']),
              _buildWarningCard(responseData['warnings']),
            ],
          ),
        ),
       
        Container(
          width: double.infinity,
          color: Colors.grey[100],
          padding: const EdgeInsets.all(12.0),
          child: const Text(
            "* ⚠️ 표시가 있는 문장은 AI 인식 결과가 불분명할 수 있으니 반드시 의료진에게 재확인하세요.",
            style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    ),
  );
}

  // 1. 3문장 요약 카드
  Widget _buildSummaryCard(List<dynamic> sentences) {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("요약 결과", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Divider(),
            ...sentences.map((s) {
            bool isUncertain = s['isUncertain'] ?? false; // 불확실 여부 확인
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("• ", style: TextStyle(fontSize: 16, color: isUncertain ? Colors.red : Colors.black)),
                  Expanded(
                    child: Text(
                      isUncertain ? "⚠️ ${s['text']}" : s['text'],
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: isUncertain ? Colors.red : Colors.black, // 빨간색 처리
                        fontWeight: isUncertain ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // 2. 쉬운 말 용어 카드
  Widget _buildEasyTermsCard(List<dynamic> terms) {
    return Card(
      child: ExpansionTile(
        title: const Text("쉬운 용어 풀이", style: TextStyle(fontWeight: FontWeight.bold)),
        children: terms.map((t) => ListTile(
          title: Text(t['term'], style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(t['desc']),
        )).toList(),
      ),
    );
  }

  // 3. 환자 행동 가이드 (체크리스트 기능 포함)
  Widget _buildActionCard(List<dynamic> actions) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("환자 행동 가이드", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ...List.generate(actions.length, (index) => CheckboxListTile(
              value: _actionChecks[index],
              onChanged: (val) {
                setState(() => _actionChecks[index] = val!);
              },
              title: Text(actions[index]),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero, // 간격 최적화
            )),
          ],
        ),
      ),
    );
  }

  // 4. 주의사항
  Widget _buildWarningCard(List<dynamic> warnings) {
    return Card(
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("주의사항", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
            ...warnings.map((w) => Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text("! $w", style: const TextStyle(color: Colors.redAccent, fontSize: 15)),
            )),
          ],
        ),
      ),
    );
  }
}
