import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'models/event_item.dart';
import 'services/event_api_service.dart';

class EventScreen extends StatefulWidget {
  final bool isAdmin;

  const EventScreen({
    super.key,
    required this.isAdmin,
  });

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  List<EventItem> _events = [];
  bool _isLoading = true;
  String? _error;
  int? _kakaoId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadKakaoId();
    await _loadEvents();
  }

  Future<void> _loadKakaoId() async {
    try {
      final user = await UserApi.instance.me();
      _kakaoId = user.id?.toInt();
    } catch (e) {
      debugPrint('카카오 ID 불러오기 실패: $e');
    }
  }

  Future<void> _loadEvents() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final events = widget.isAdmin
          ? await EventApiService.fetchAllEvents()
          : await EventApiService.fetchActiveEvents();

      if (!mounted) return;
      setState(() {
        _events = events;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _openCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventEditSheet(
        kakaoId: _kakaoId,
        onSaved: _loadEvents,
      ),
    );
  }

  void _openEditSheet(EventItem event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventEditSheet(
        kakaoId: _kakaoId,
        event: event,
        onSaved: _loadEvents,
      ),
    );
  }

  Future<void> _deleteEvent(EventItem event) async {
    if (_kakaoId == null) return;

    try {
      await EventApiService.deleteEvent(
        eventId: event.id,
        kakaoId: _kakaoId!,
      );
      await _loadEvents();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 실패: $e')),
      );
    }
  }

  Future<void> _toggleEvent(EventItem event) async {
    if (_kakaoId == null) return;

    try {
      await EventApiService.toggleEvent(
        eventId: event.id,
        kakaoId: _kakaoId!,
      );
      await _loadEvents();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('상태 변경 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF8),
      floatingActionButton: widget.isAdmin
          ? FloatingActionButton(
        onPressed: _openCreateSheet,
        backgroundColor: const Color(0xFFFF8E7C),
        child: const Icon(Icons.add, color: Colors.white),
      )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadEvents,
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new),
            ),
          ),
          Text(
            widget.isAdmin ? '이벤트 관리' : '진행 중 이벤트',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    if (_events.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(
            child: Text(
              '표시할 이벤트가 없어요',
              style: TextStyle(fontSize: 15, color: Colors.grey),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      itemCount: _events.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, index) {
        final event = _events[index];
        return _buildEventCard(event);
      },
    );
  }

  Widget _buildEventCard(EventItem event) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (event.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(22)),
              child: Image.network(
                event.imageUrl,
                width: double.infinity,
                height: 160,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 160,
                  color: const Color(0xFFFFF1EE),
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_not_supported_outlined),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (widget.isAdmin)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: event.isActive
                              ? const Color(0xFFFFF1EE)
                              : const Color(0xFFF1F3F5),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          event.isActive ? '활성' : '비활성',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: event.isActive
                                ? const Color(0xFFFF8E7C)
                                : const Color(0xFF7B8794),
                          ),
                        ),
                      ),
                  ],
                ),
                if (event.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    event.subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF666666),
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  '${event.startAt.toLocal()} ~ ${event.endAt.toLocal()}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9AA1A9),
                  ),
                ),
                if (widget.isAdmin) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _toggleEvent(event),
                          child: Text(event.isActive ? '비활성화' : '활성화'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _openEditSheet(event),
                          child: const Text('수정'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _deleteEvent(event),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF8E7C),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('삭제'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EventEditSheet extends StatefulWidget {
  final int? kakaoId;
  final EventItem? event;
  final Future<void> Function() onSaved;

  const EventEditSheet({
    super.key,
    required this.kakaoId,
    required this.onSaved,
    this.event,
  });

  @override
  State<EventEditSheet> createState() => _EventEditSheetState();
}

class _EventEditSheetState extends State<EventEditSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _subtitleController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _linkUrlController;
  late final TextEditingController _sortOrderController;

  late DateTime _startAt;
  late DateTime _endAt;
  bool _isActive = true;
  bool _isSubmitting = false;

  bool get _isEdit => widget.event != null;

  @override
  void initState() {
    super.initState();
    final e = widget.event;

    _titleController = TextEditingController(text: e?.title ?? '');
    _subtitleController = TextEditingController(text: e?.subtitle ?? '');
    _imageUrlController = TextEditingController(text: e?.imageUrl ?? '');
    _linkUrlController = TextEditingController(text: e?.linkUrl ?? '');
    _sortOrderController =
        TextEditingController(text: '${e?.sortOrder ?? 0}');
    _startAt = e?.startAt ?? DateTime.now();
    _endAt = e?.endAt ?? DateTime.now().add(const Duration(days: 7));
    _isActive = e?.isActive ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _imageUrlController.dispose();
    _linkUrlController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (widget.kakaoId == null) return;
    if (_titleController.text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      debugPrint('=== 앱 저장 요청 ===');
      debugPrint('isEdit=$_isEdit');
      debugPrint('kakaoId=${widget.kakaoId}');
      if (_isEdit) {
        debugPrint('eventId=${widget.event!.id}');
      }
      debugPrint('title=${_titleController.text.trim()}');
      debugPrint('subtitle=${_subtitleController.text.trim()}');
      debugPrint('imageUrl=${_imageUrlController.text.trim()}');
      debugPrint('linkUrl=${_linkUrlController.text.trim()}');
      debugPrint('startAt=$_startAt');
      debugPrint('endAt=$_endAt');
      debugPrint('isActive=$_isActive');
      debugPrint('sortOrder=${_sortOrderController.text.trim()}');

      if (_isEdit) {
        await EventApiService.updateEvent(
          eventId: widget.event!.id,
          kakaoId: widget.kakaoId!,
          title: _titleController.text.trim(),
          subtitle: _subtitleController.text.trim(),
          imageUrl: _imageUrlController.text.trim(),
          linkUrl: _linkUrlController.text.trim(),
          startAt: _startAt,
          endAt: _endAt,
          isActive: _isActive,
          sortOrder: int.tryParse(_sortOrderController.text.trim()) ?? 0,
        );
      } else {
        await EventApiService.createEvent(
          kakaoId: widget.kakaoId!,
          title: _titleController.text.trim(),
          subtitle: _subtitleController.text.trim(),
          imageUrl: _imageUrlController.text.trim(),
          linkUrl: _linkUrlController.text.trim(),
          startAt: _startAt,
          endAt: _endAt,
          isActive: _isActive,
          sortOrder: int.tryParse(_sortOrderController.text.trim()) ?? 0,
        );
      }

      await widget.onSaved();
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickDateTime(bool isStart) async {
    final initial = isStart ? _startAt : _endAt;

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );

    if (time == null || !mounted) return;

    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      if (isStart) {
        _startAt = picked;
      } else {
        _endAt = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEdit ? '이벤트 수정' : '이벤트 추가',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: '제목'),
            ),
            TextField(
              controller: _subtitleController,
              decoration: const InputDecoration(labelText: '설명'),
            ),
            TextField(
              controller: _imageUrlController,
              decoration: const InputDecoration(labelText: '이미지 URL'),
            ),
            TextField(
              controller: _linkUrlController,
              decoration: const InputDecoration(labelText: '링크 URL'),
            ),
            TextField(
              controller: _sortOrderController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '정렬 순서'),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              title: const Text('활성 상태'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('시작일'),
              subtitle: Text(_startAt.toString()),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _pickDateTime(true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('종료일'),
              subtitle: Text(_endAt.toString()),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _pickDateTime(false),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8E7C),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(_isSubmitting ? '저장 중...' : '저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}