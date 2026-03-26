import 'package:flutter/material.dart';
import '../../api/api_models.dart';

/// 제목 + 선택적 부제목 + 자식을 감싸는 공통 섹션 카드
class SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const SectionCard({
    super.key,
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
                backgroundColor:
                    Theme.of(context).colorScheme.secondaryContainer,
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
