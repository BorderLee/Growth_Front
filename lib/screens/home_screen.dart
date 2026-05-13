import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:medexplain/api/app_config.dart';
import 'package:medexplain/controllers/recording_controller.dart';
import 'package:medexplain/stt/ws_transport.dart';
import 'list_screen.dart';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final RecordingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = RecordingController();
    _ctrl.init();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── actions ────────────────────────────────────────────────────────────────

  Future<void> _toggleListening() async {
    if (!_ctrl.isListening) {
      final ok = await _ctrl.checkPermission();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('마이크 권한이 필요합니다. 설정에서 권한을 허용해주세요.')),
          );
        }
        return;
      }
    }
    await _ctrl.toggleListening();
  }

  void _goToResult() {
    final text = _ctrl.transcriptStore.combinedText.trim();
    final warning = _ctrl.transcriptStore.warningMessage;

    if (text.isEmpty && warning == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('아직 STT 결과가 도착하지 않았습니다. 잠시 후 다시 눌러주세요.'),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ResultScreen(transcript: text, warningMessage: warning),
      ),
    );
  }

  void _goToRecords() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RecordsScreen()),
    );
  }

  void _showServerSettingDialog() {
    getServerIp().then((currentIp) {
      if (!mounted) return;
      final controller = TextEditingController(text: currentIp);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('서버 IP 설정'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'IP 주소',
              hintText: '예: 192.168.0.10',
            ),
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                await saveServerIp(controller.text.trim());
                if (!mounted) return;
                // ignore: use_build_context_synchronously
                Navigator.pop(ctx);
                await _ctrl.reinitWs();
              },
              child: const Text('저장'),
            ),
          ],
        ),
      );
    });
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _ctrl,
      builder: (context, _) => Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: _buildAppBar(),
        body: _buildBody(),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 16,
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/MedExplain.png',
              height: 36,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.folder, color: Colors.amber),
          tooltip: '진료 기록',
          onPressed: _goToRecords,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            if (value == 'settings') _showServerSettingDialog();
            if (value == 'logout') FirebaseAuth.instance.signOut();
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: 'settings',
              child: Row(children: [
                Icon(Icons.settings_outlined, size: 18),
                SizedBox(width: 8),
                Text('서버 설정'),
              ]),
            ),
            const PopupMenuItem(
              value: 'logout',
              child: Row(children: [
                Icon(Icons.logout, size: 18),
                SizedBox(width: 8),
                Text('로그아웃'),
              ]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: _buildConnectionStatus(),
        ),
        Expanded(
          child: _ctrl.analyzing
              ? _buildAnalyzingState()
              : (_ctrl.isListening || _ctrl.hasResult)
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: _buildTextCard(),
                    )
                  : _buildEmptyState(),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: _buildBottomButtons(),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionStatus() {
    final (color, label) = switch (_ctrl.connState) {
      WsConnState.connected => (Colors.green, '서버 연결됨'),
      WsConnState.connecting || WsConnState.reconnecting =>
        (Colors.orange, '연결 중...'),
      _ => (Colors.red, '서버 연결 안됨'),
    };

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
              fontSize: 13, color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildAnalyzingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            '녹음 분석 중...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.medical_services_outlined,
                size: 56,
                color: Colors.blue.shade400,
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              '진료실에서 의사 설명을\n녹음해 보세요',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, height: 1.4),
            ),
            const SizedBox(height: 24),
            Text(
              'AI가 핵심 내용을 요약하고\n어려운 용어를 쉽게 설명해 드려요',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: Colors.grey.shade500, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextCard() {
    final text = _ctrl.transcriptStore.combinedText.trim();
    final warning = _ctrl.transcriptStore.warningMessage;
    final displayText = text.isNotEmpty ? text : (warning ?? '');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.mic_outlined, size: 16),
                const SizedBox(width: 6),
                Text(
                  _ctrl.isListening ? '녹음 중...' : '인식된 텍스트',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                if (_ctrl.isListening) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.35,
              ),
              child: SingleChildScrollView(
                child: Text(
                  displayText.isEmpty ? '음성 인식 대기 중...' : displayText,
                  style: const TextStyle(fontSize: 15, height: 1.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButtons() {
    if (_ctrl.analyzing) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
        ),
        child: const Text('분석 중...', style: TextStyle(fontSize: 16)),
      );
    }

    if (_ctrl.isListening) {
      return FilledButton.icon(
        onPressed: _toggleListening,
        icon: const Icon(Icons.stop),
        label: const Text('녹음 종료', style: TextStyle(fontSize: 16)),
        style: FilledButton.styleFrom(backgroundColor: Colors.red),
      );
    }

    if (_ctrl.hasResult) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: _goToResult,
            icon: const Icon(Icons.auto_awesome),
            label:
                const Text('AI 분석 결과 보기', style: TextStyle(fontSize: 16)),
            style: FilledButton.styleFrom(backgroundColor: Colors.blue),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _ctrl.reset,
            icon: const Icon(Icons.mic),
            label: const Text('다시 녹음', style: TextStyle(fontSize: 16)),
          ),
        ],
      );
    }

    return ElevatedButton.icon(
      onPressed: _toggleListening,
      icon: const Icon(Icons.mic),
      label: const Text('녹음 시작', style: TextStyle(fontSize: 16)),
    );
  }
}
