import 'dart:ui';
import 'package:flutter/material.dart';

class TipGuideScreen extends StatelessWidget {
  const TipGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/bg_gradient.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildTopBar(context),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: const [
                    _HeroGuideCard(),
                    SizedBox(height: 18),
                    _SectionTitle(
                      title: '소소한 팁',
                      subtitle: '처음 시작할 때 알아두면 좋은 기본 가이드예요',
                    ),
                    SizedBox(height: 12),
                    _TipCard(
                      icon: Icons.location_searching_rounded,
                      title: '참나무 / 형광석 위치 확인',
                      description:
                      '지도 화면에서 오늘의 후보 위치와 확정 위치를 먼저 확인해보세요. '
                          '확정된 위치는 투표가 충분히 모였을 때 더 믿고 움직일 수 있어요.',
                    ),
                    _TipCard(
                      icon: Icons.how_to_vote_rounded,
                      title: '투표 정보 먼저 보기',
                      description:
                      '후보가 여러 개일 때는 무작정 이동하기보다 현재 투표 수를 먼저 확인해보는 게 좋아요. '
                          '확정 직전 후보인지 확인하면 시간을 아낄 수 있어요.',
                    ),
                    _TipCard(
                      icon: Icons.check_circle_outline_rounded,
                      title: '오늘의 할 일과 같이 보기',
                      description:
                      '홈의 오늘의 할 일과 지도 정보를 함께 보면 동선이 훨씬 깔끔해져요. '
                          '참나무, 형광석, 작물 물주기를 한 번에 묶어 움직이면 효율적이에요.',
                    ),
                    _TipCard(
                      icon: Icons.auto_awesome_rounded,
                      title: '레시피는 재료 화면과 같이 확인',
                      description:
                      '요리 탭에서 레시피만 보기보다 재료 탭까지 같이 보면 필요한 채집/상점 아이템을 빨리 파악할 수 있어요.',
                    ),
                    SizedBox(height: 18),
                    _SectionTitle(
                      title: '추천 루틴',
                      subtitle: '매일 가볍게 확인하면 좋은 흐름이에요',
                    ),
                    SizedBox(height: 12),
                    _RoutineCard(),
                    SizedBox(height: 18),
                    _SectionTitle(
                      title: '메모',
                      subtitle: '나중에는 서버 연동형 공략/공지/추천 루틴으로 확장하기 좋아요',
                    ),
                    SizedBox(height: 12),
                    _NoteCard(
                      text:
                      '현재는 정적 페이지로 구성했지만, 나중에 관리자 작성형 팁/공지 페이지로 바꾸면 유지보수가 훨씬 쉬워져요.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.70),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.55),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Material(
                  color: const Color(0xFFFFF1ED),
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
                        color: Color(0xFFFF8E7C),
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
                        '팁 가이드',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '게임을 조금 더 편하게 즐기기 위한 소소한 팁',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4F1),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xFFFFE0D9),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lightbulb_rounded,
                        size: 15,
                        color: Color(0xFFFF8E7C),
                      ),
                      SizedBox(width: 5),
                      Text(
                        'GUIDE',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFF8E7C),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroGuideCard extends StatelessWidget {
  const _HeroGuideCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFEAE4).withOpacity(0.95),
            const Color(0xFFFFF8F5).withOpacity(0.92),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFFFD6CC),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8E7C).withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              size: 28,
              color: Color(0xFFFF8E7C),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '키퍼노트 소소한 팁',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '참나무·형광석 확인, 투표 보기, 할 일과 동선 묶기처럼 '
                      '자주 쓰는 흐름을 짧게 정리해둔 페이지예요.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
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
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _TipCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFF4DDD7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1ED),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFFF8E7C),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF475569),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard();

  @override
  Widget build(BuildContext context) {
    final steps = [
      '홈에서 오늘의 할 일 확인하기',
      '지도에서 참나무 / 형광석 위치 확인하기',
      '필요한 재료를 요리 / 채집 탭에서 같이 확인하기',
      '남은 항목 체크하고 이벤트까지 보기',
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFF4DDD7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: List.generate(steps.length, (index) {
          return Padding(
            padding: EdgeInsets.only(bottom: index == steps.length - 1 ? 0 : 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF8E7C),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      steps[index],
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final String text;

  const _NoteCard({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F6).withOpacity(0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFFFE3DC),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.sticky_note_2_rounded,
            size: 20,
            color: Color(0xFFFF8E7C),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}