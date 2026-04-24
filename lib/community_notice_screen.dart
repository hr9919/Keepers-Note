import 'dart:ui';
import 'package:flutter/material.dart';

class CommunityNotice {
  final int id;
  final String emoji;
  final String title;
  final String summary;
  final String body;

  const CommunityNotice({
    required this.id,
    required this.emoji,
    required this.title,
    required this.summary,
    required this.body,
  });

  static const List<CommunityNotice> defaultNotices = [
    CommunityNotice(
      id: 1,
      emoji: '📌',
      title: '커뮤니티 이용 규칙 안내',
      summary: '타운키퍼를 위한 소통 규칙입니다😉💗',
      body: '',
    ),
  ];
}

class CommunityNoticeScreen extends StatefulWidget {
  final List<CommunityNotice> notices;

  const CommunityNoticeScreen({
    super.key,
    this.notices = CommunityNotice.defaultNotices,
  });

  @override
  State<CommunityNoticeScreen> createState() => _CommunityNoticeScreenState();
}

class _CommunityNoticeScreenState extends State<CommunityNoticeScreen> {
  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFFFFFFF);

    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 84, 20, 32),
              children: const [
                _SectionTitle(
                  title: '커뮤니티 공지',
                  subtitle: '키퍼노트 커뮤니티를 더 편하게 이용하기 위한 안내입니다.',
                ),
                SizedBox(height: 14),
                _NoticeSummaryCard(),
                SizedBox(height: 80),
              ],
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: _buildTopBar(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Colors.white.withOpacity(0.82),
            border: Border.all(
              color: const Color(0xFFFFE6DE).withOpacity(0.95),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF8E7C).withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _TopBarButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.pop(context),
                ),
              ),
              const Center(
                child: Text(
                  '공지사항',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                    letterSpacing: -0.3,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TopBarButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final splash = const Color(0xFFFFD9D1).withOpacity(0.35);
    final highlight = const Color(0xFFFFEEE9).withOpacity(0.70);

    return Material(
      color: Colors.white.withOpacity(0.55),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        splashColor: splash,
        highlightColor: highlight,
        overlayColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.pressed)) return splash;
          if (states.contains(MaterialState.hovered)) {
            return const Color(0xFFFFF3EF).withOpacity(0.45);
          }
          return null;
        }),
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFFFE7E0),
            ),
          ),
          child: Icon(
            icon,
            size: 17,
            color: const Color(0xFFFF8E7C),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, right: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
              letterSpacing: -0.35,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12.8,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeRuleItem {
  final String title;
  final List<_NoticeTextPart> parts;

  const _NoticeRuleItem({
    required this.title,
    required this.parts,
  });
}

class _NoticeTextPart {
  final String text;
  final bool highlight;

  const _NoticeTextPart(
      this.text, {
        this.highlight = false,
      });
}

class _NoticeSummaryCard extends StatelessWidget {
  const _NoticeSummaryCard();

  @override
  Widget build(BuildContext context) {
    const items = [
      _NoticeRuleItem(
        title: '서로를 존중하는 표현을 사용해주세요',
        parts: [
          _NoticeTextPart('욕설 / 비방 / 조롱 / 혐오 표현', highlight: true),
          _NoticeTextPart('은 사용할 수 없습니다. 다른 유저에게 불쾌감을 주는 표현은 숨김 또는 삭제될 수 있습니다.'),
        ],
      ),
      _NoticeRuleItem(
        title: '광고 및 도배성 게시글은 허용되지 않습니다',
        parts: [
          _NoticeTextPart('광고 / 외부 홍보 / 거래 유도 / 반복 게시글', highlight: true),
          _NoticeTextPart('은 커뮤니티 목적과 맞지 않으며 삭제 대상이 될 수 있습니다.'),
        ],
      ),
      _NoticeRuleItem(
        title: '게임과 무관한 내용은 자제해주세요',
        parts: [
          _NoticeTextPart('게임 외적인 일상 이야기 및 개인적인 내용', highlight: true),
          _NoticeTextPart('은 과도하게 작성하지 않는 것을 권장합니다.'),
        ],
      ),
      _NoticeRuleItem(
        title: '전체 공개 글은 공공 공간입니다',
        parts: [
          _NoticeTextPart('게임 정보 공유 / 질문 / 인게임 방문 / 도움 요청', highlight: true),
          _NoticeTextPart('과 같이 게임 플레이와 관련된 소통은 가능합니다.'),
        ],
      ),
      _NoticeRuleItem(
        title: '과도한 친목 및 외부 연락 유도는 제한됩니다',
        parts: [
          _NoticeTextPart('개인 연락처 / 카카오톡 / 디스코드 / 오픈채팅 공유', highlight: true),
          _NoticeTextPart('와 특정 유저 간 사적 대화 유도는 제한될 수 있습니다.'),
        ],
      ),
      _NoticeRuleItem(
        title: '팔로워 전용 글에서는 자유롭게 소통할 수 있습니다',
        parts: [
          _NoticeTextPart('팔로워 전용 글', highlight: true),
          _NoticeTextPart('에서는 비교적 자유로운 소통이 가능합니다. 단, 욕설 / 비방 / 조롱 / 혐오 표현 금지 및 광고 / 외부 홍보 / 거래 유도 / 반복 게시글 금지 등 기본 규칙은 동일하게 적용됩니다.'),
        ],
      ),
      _NoticeRuleItem(
        title: '문제가 있는 글은 신고해주세요',
        parts: [
          _NoticeTextPart('규칙 위반 글 / 광고성 글 / 도배성 글 / 과도한 친목 유도 글', highlight: true),
          _NoticeTextPart('은 신고 대상이며 관리자 확인 후 조치될 수 있습니다.'),
        ],
      ),
      _NoticeRuleItem(
        title: '운영 기준은 상황에 따라 적용됩니다',
        parts: [
          _NoticeTextPart('반복적인 규칙 위반', highlight: true),
          _NoticeTextPart('이 발생할 경우 이용이 제한될 수 있습니다.'),
        ],
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: const Color(0xFFF1F3F5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8E7C).withOpacity(0.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isLast = index == items.length - 1;

          return Column(
            children: [
              _NoticeRuleRow(
                number: index + 1,
                item: item,
              ),
              if (!isLast)
                const Padding(
                  padding: EdgeInsets.fromLTRB(42, 15, 0, 15),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFF1EAE6),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _NoticeRuleRow extends StatelessWidget {
  final int number;
  final _NoticeRuleItem item;

  const _NoticeRuleRow({
    required this.number,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF2ED),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFFFE0D6)),
          ),
          child: Text(
            '$number',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Color(0xFFFF8E7C),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 14.3,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                    height: 1.28,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 6),
                RichText(
                  text: TextSpan(
                    children: item.parts.map((part) {
                      return TextSpan(
                        text: part.text,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: part.highlight
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: part.highlight
                              ? const Color(0xFFFF8E7C)
                              : const Color(0xFF6B7280),
                          height: 1.5,
                          letterSpacing: -0.05,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
