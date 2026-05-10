import 'package:flutter/material.dart';
import '../api/api_models.dart';
import '../api/api_service.dart';
import 'record_detail_screen.dart';
import 'widgets/section_card.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  List<RecordSummary>? _records;
  bool _loading = true;
  String? _error;
  String? _selectedDept;

  @override
  void initState() {
    super.initState();
    _fetchRecords();
  }

  Future<void> _fetchRecords() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = await ApiService.instance.getRecords();
      if (mounted) {
        setState(() {
          _records = records;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('진료 기록'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
            onPressed: _fetchRecords,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const ScreenLoading();
    if (_error != null) return ScreenError(message: _error!, onRetry: _fetchRecords);

    if (_records == null || _records!.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text('저장된 기록이 없습니다.',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    final depts = _records!.map((r) => r.department).toSet().toList()..sort();
    final filtered = _selectedDept == null
        ? _records!
        : _records!.where((r) => r.department == _selectedDept).toList();

    return Column(
      children: [
        if (depts.length > 1)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: const Text('전체'),
                    selected: _selectedDept == null,
                    onSelected: (_) => setState(() => _selectedDept = null),
                  ),
                ),
                for (final dept in depts)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(dept),
                      selected: _selectedDept == dept,
                      onSelected: (_) => setState(() => _selectedDept = dept),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchRecords,
            child: filtered.isEmpty
                ? const Center(
                    child: Text('해당 진료과 기록이 없습니다.',
                        style: TextStyle(color: Colors.grey)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (_, i) => _RecordTile(
                      record: filtered[i],
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              RecordDetailScreen(recordId: filtered[i].recordId),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _RecordTile extends StatelessWidget {
  final RecordSummary record;
  final VoidCallback onTap;

  const _RecordTile({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.medical_services_outlined,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          record.date,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(width: 8),
                        AppBadge(
                          label: record.department,
                          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                          textColor: Theme.of(context).colorScheme.onSecondaryContainer,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      record.summaryPreview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
