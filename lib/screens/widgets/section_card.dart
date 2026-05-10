import 'package:flutter/material.dart';
import '../../api/api_models.dart';

/// 제목 + 선택적 부제목 + 자식을 감싸는 공통 섹션 카드
class SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  const SectionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
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
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

/// 의료 용어 설명 팝업 다이얼로그
void showTermDialog(BuildContext context, MedTerm term) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(term.term,
          style: const TextStyle(fontWeight: FontWeight.bold)),
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

/// bullet(•) 형태의 문자열 목록
class BulletList extends StatelessWidget {
  final List<String> items;

  const BulletList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map((s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Expanded(
                        child: Text(s, style: const TextStyle(fontSize: 15))),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

/// 텍스트 배지 (진료과, AI 추천 등 레이블 표시용)
class AppBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final double fontSize;
  final double borderRadius;

  const AppBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.fontSize = 12,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// 전체 화면 로딩 상태
class ScreenLoading extends StatelessWidget {
  const ScreenLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

/// 전체 화면 에러 상태
class ScreenError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ScreenError({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
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
              message,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}

/// SectionCard 목록을 감싸는 공통 ListView
class SectionListView extends StatelessWidget {
  final List<Widget> children;
  final double spacing;

  const SectionListView({
    super.key,
    required this.children,
    this.spacing = 5,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      itemCount: children.length,
      separatorBuilder: (_, __) => SizedBox(height: spacing),
      itemBuilder: (_, i) => children[i],
    );
  }
}

/// 분석 결과 / 질문하기 공통 TabBar
const kAnalysisTabBar = TabBar(
  tabs: [Tab(text: '분석 결과'), Tab(text: '질문하기')],
);

/// '의료 용어' SectionCard — 타이틀·부제목 고정, 내용만 주입
class MedTermsSectionCard extends StatelessWidget {
  final Widget child;
  const MedTermsSectionCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) => SectionCard(
        title: '의료 용어',
        subtitle: '용어를 탭하면 설명을 볼 수 있습니다.',
        child: child,
      );
}

/// 의료 용어를 탭 가능한 칩으로 표시 (탭 시 showTermDialog 호출)
class TermChipList extends StatelessWidget {
  final List<MedTerm> terms;

  const TermChipList({super.key, required this.terms});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: terms
          .map((t) => ActionChip(
                label: Text(t.term),
                onPressed: () => showTermDialog(context, t),
                backgroundColor: Colors.blue[50],
                labelStyle: TextStyle(
                  color:
                      Theme.of(context).colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ))
          .toList(),
    );
  }
}
