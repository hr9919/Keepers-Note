import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/redeem_code_item.dart';
import 'services/redeem_code_api_service.dart';


PreferredSizeWidget _keepersDetailGlassAppBar(
    BuildContext context, {
      required String title,
      String subtitle = '',
      Widget? trailing,
    }) {
  final topPadding = MediaQuery.of(context).padding.top;

  return PreferredSize(
    preferredSize: Size.fromHeight(topPadding + 66),
    child: ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(26),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: EdgeInsets.fromLTRB(14, topPadding + 8, 14, 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.78),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(26),
            ),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.76),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.035),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              _keepersDetailRoundButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.maybePop(context),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF2D3436),
                        letterSpacing: -0.4,
                      ),
                    ),
                    if (subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF9AA4B2),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              trailing ?? const SizedBox(width: 42, height: 42),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _keepersDetailRoundButton({
  required IconData icon,
  required VoidCallback onTap,
  Color backgroundColor = const Color(0xFFFFFFFF),
  Color iconColor = const Color(0xFF2D3436),
  Color borderColor = const Color(0xFFFFE2DA),
}) {
  return Material(
    color: backgroundColor.withOpacity(backgroundColor == Colors.white ? 0.92 : 1.0),
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.025),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 19,
          color: iconColor,
        ),
      ),
    ),
  );
}

class RedeemCodeScreen extends StatefulWidget {
  final bool isAdmin;
  final String userId;

  const RedeemCodeScreen({
    super.key,
    required this.isAdmin,
    required this.userId,
  });

  @override
  State<RedeemCodeScreen> createState() => _RedeemCodeScreenState();
}

class _RedeemCodeScreenState extends State<RedeemCodeScreen> {
  bool _isLoading = true;
  List<RedeemCodeItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadRedeemCodes();
  }

  Future<void> _loadRedeemCodes() async {
    setState(() => _isLoading = true);

    try {
      final items = await RedeemCodeApiService.fetchRedeemCodes();

      if (!mounted) return;
      setState(() {
        _items = items;
      });
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('리딤코드 목록을 불러오지 못했어요.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<RedeemCodeItem> get _activeItems {
    final now = DateTime.now();

    final list = _items
        .where((e) => e.active && e.expiresAt.isAfter(now))
        .toList();

    list.sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    return list;
  }

  List<RedeemCodeItem> get _expiredItems {
    final now = DateTime.now();

    final list = _items
        .where((e) => !e.active || !e.expiresAt.isAfter(now))
        .toList();

    list.sort((a, b) => b.expiresAt.compareTo(a.expiresAt));
    return list;
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  int _remainingDays(DateTime expiresAt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expireDate = DateTime(expiresAt.year, expiresAt.month, expiresAt.day);
    return expireDate.difference(today).inDays;
  }

  void _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    _showSnackBar('리딤코드가 복사되었어요.');
  }

  void _showSnackBar(String message) {
    final media = MediaQuery.of(context);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            media.padding.bottom + 18,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _openCreateSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RedeemCodeCreateSheet(
        userId: widget.userId,
      ),
    );

    if (created == true) {
      await _loadRedeemCodes();
      if (!mounted) return;
      _showSnackBar('리딤코드가 등록되었어요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeItems = _activeItems;
    final expiredItems = _expiredItems;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBFA),
      appBar: _keepersDetailGlassAppBar(
        context,
        title: '리딤 코드',
        subtitle: '리딤 코드를 확인하고 사용하세요!',
        trailing: widget.isAdmin
            ? _keepersDetailRoundButton(
          icon: Icons.add_rounded,
          onTap: _openCreateSheet,
          backgroundColor: const Color(0xFFFF8E7C),
          iconColor: Colors.white,
          borderColor: const Color(0xFFFF8E7C),
        )
            : null,
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: const Color(0xFFFF8E7C),
          onRefresh: _loadRedeemCodes,
          child: _isLoading
              ? const CustomScrollView(
            physics: AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFFF8E7C),
                  ),
                ),
              ),
            ],
          )
              : CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      _buildInfoCard(),
                      const SizedBox(height: 18),
                      _buildSectionTitle(
                        title: '사용 가능한 리딤코드',
                        count: activeItems.length,
                      ),
                      const SizedBox(height: 10),
                      if (activeItems.isEmpty)
                        _buildEmptyCard('사용 가능한 리딤코드가 없어요.')
                      else
                        ...activeItems.map(
                              (item) => _buildRedeemCodeCard(item),
                        ),
                      const SizedBox(height: 24),
                      _buildSectionTitle(
                        title: '만료된 리딤코드',
                        count: expiredItems.length,
                      ),
                      const SizedBox(height: 10),
                      if (expiredItems.isEmpty)
                        _buildEmptyCard('만료된 리딤코드가 없어요.')
                      else
                        ...expiredItems.map(
                              (item) => _buildRedeemCodeCard(
                            item,
                            expired: true,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFFF8E7C).withOpacity(0.10),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Material(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.pop(context),
              child: const SizedBox(
                width: 42,
                height: 42,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: Color(0xFF475569),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '리딤 코드',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.4,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '리딤 코드를 확인하고 사용하세요!',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          if (widget.isAdmin)
            Material(
              color: const Color(0xFFFF8E7C),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _openCreateSheet,
                child: const SizedBox(
                  width: 42,
                  height: 42,
                  child: Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFF4F1),
            Color(0xFFFFFBFA),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFFF8E7C).withOpacity(0.13),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFFF8E7C).withOpacity(0.13),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.card_giftcard_rounded,
              color: Color(0xFFFF8E7C),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '코드를 누르면 바로 복사할 수 있어요.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({
    required String title,
    required int count,
  }) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF94A3B8),
        ),
      ),
    );
  }

  Widget _buildRedeemCodeCard(
      RedeemCodeItem item, {
        bool expired = false,
      }) {
    final days = _remainingDays(item.expiresAt);

    final Color cardColor =
    expired ? const Color(0xFFF1F5F9) : Colors.white;
    final Color mainColor =
    expired ? const Color(0xFF94A3B8) : const Color(0xFF0F172A);
    final Color accentColor =
    expired ? const Color(0xFF94A3B8) : const Color(0xFFFF8E7C);

    final String badgeText = expired
        ? '만료됨'
        : days == 0
        ? '오늘 만료'
        : 'D-$days';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: expired ? null : () => _copyCode(item.code),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: expired
                    ? const Color(0xFFE2E8F0)
                    : const Color(0xFFFF8E7C).withOpacity(0.14),
              ),
              boxShadow: expired
                  ? []
                  : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.code,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: mainColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(expired ? 0.12 : 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  item.reward,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: expired
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 15,
                      color: expired
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFFFF8E7C),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${_formatDate(item.expiresAt)}까지',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: expired
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    const Spacer(),
                    if (!expired)
                      Row(
                        children: const [
                          Icon(
                            Icons.copy_rounded,
                            size: 15,
                            color: Color(0xFFFF8E7C),
                          ),
                          SizedBox(width: 4),
                          Text(
                            '복사',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFFF8E7C),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RedeemCodeCreateSheet extends StatefulWidget {
  final String userId;

  const _RedeemCodeCreateSheet({
    required this.userId,
  });

  @override
  State<_RedeemCodeCreateSheet> createState() =>
      _RedeemCodeCreateSheetState();
}

class _RedeemCodeCreateSheetState extends State<_RedeemCodeCreateSheet> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _rewardController = TextEditingController();

  DateTime? _expiresAt;
  bool _isSaving = false;

  @override
  void dispose() {
    _codeController.dispose();
    _rewardController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: DateTime(now.year + 3),
      helpText: '유효 기간 선택',
      cancelText: '취소',
      confirmText: '선택',
    );

    if (picked == null) return;

    setState(() {
      _expiresAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        23,
        59,
        59,
      );
    });
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    final code = _codeController.text.trim();
    final reward = _rewardController.text.trim();

    if (code.isEmpty || reward.isEmpty || _expiresAt == null) {
      _showLocalSnackBar('리딤코드, 보상 내용, 유효 기간을 모두 입력해주세요.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await RedeemCodeApiService.createRedeemCode(
        userId: widget.userId,
        code: code,
        reward: reward,
        expiresAt: _expiresAt!,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showLocalSnackBar('등록 중 문제가 발생했어요.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showLocalSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: const BoxDecoration(
          color: Color(0xFFFFFBFA),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(30),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '리딤코드 등록',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _codeController,
                hintText: '리딤코드',
                icon: Icons.confirmation_number_rounded,
              ),
              const SizedBox(height: 10),
              _buildTextField(
                controller: _rewardController,
                hintText: '보상 내용',
                icon: Icons.card_giftcard_rounded,
                maxLines: 3,
              ),
              const SizedBox(height: 10),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 15,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.event_rounded,
                          color: Color(0xFFFF8E7C),
                          size: 21,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _expiresAt == null
                                ? '유효 기간 선택'
                                : '${_formatDate(_expiresAt!)}까지',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _expiresAt == null
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8E7C),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    disabledBackgroundColor: const Color(0xFFFFC8BE),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    '등록하기',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        textInputAction:
        maxLines == 1 ? TextInputAction.next : TextInputAction.newline,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: const TextStyle(
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Icon(
            icon,
            color: const Color(0xFFFF8E7C),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 15,
          ),
        ),
      ),
    );
  }
}