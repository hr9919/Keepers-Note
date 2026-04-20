import 'dart:ui';
import 'package:flutter/material.dart';

class TipGuideScreen extends StatefulWidget {
  const TipGuideScreen({super.key});

  @override
  State<TipGuideScreen> createState() => _TipGuideScreenState();
}

class _TipGuideScreenState extends State<TipGuideScreen> {
  final Set<int> _expandedIndexes = {};

  void _toggleExpanded(int index) {
    setState(() {
      if (_expandedIndexes.contains(index)) {
        _expandedIndexes.remove(index);
      } else {
        _expandedIndexes.add(index);
      }
    });
  }

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
              children: [
                const _SectionTitle(
                  title: '추천 루틴',
                  subtitle: '새로 이사온 타운키퍼를 위한 루틴 정리',
                ),
                const SizedBox(height: 14),

                const _RoutineCard(),
                
                const SizedBox(height: 24),
                const _SectionTitle(
                  title: '앱 기능 안내',
                  subtitle: '전체 구성을 먼저 보고, 필요한 항목만 펼쳐서 자세히 확인해보세요.',
                ),
                const SizedBox(height: 14),

                _ExpandableGuideCard(
                  isExpanded: _expandedIndexes.contains(0),
                  onTap: () => _toggleExpanded(0),
                  emoji: '🪪',
                  title: '프로필 / 설정',
                  summary: '프로필 설정 / UID 입력 및 복사 기능',
                  details: const [
                    '프로필 사진과 배경화면을 설정할 수 있어요.',
                    'UID를 입력해두고 복사해서 편하게 사용할 수 있어요.',
                  ],
                ),
                _ExpandableGuideCard(
                  isExpanded: _expandedIndexes.contains(1),
                  onTap: () => _toggleExpanded(1),
                  emoji: '🏠',
                  title: '홈 화면',
                  summary: '이벤트 확인, 할 일 체크, 통합 검색',
                  details: const [
                    '현재 진행 중인 이벤트를 메인 화면에서 바로 확인할 수 있어요.',
                    '오늘의 할 일 체크리스트는 매일 오전 6시에 초기화돼요.',
                    '홈 화면의 통합 검색으로 인게임 아이템을 한 번에 검색할 수 있어요.',
                  ],
                ),
                _ExpandableGuideCard(
                  isExpanded: _expandedIndexes.contains(2),
                  onTap: () => _toggleExpanded(2),
                  emoji: '🌤️',
                  title: '날씨 / 지도',
                  summary: '날씨 예보 및 NPC·자원 위치 확인',
                  details: const [
                    '관리자가 매일 업데이트 해주는 인게임 날씨 예보를 확인할 수 있어요.',
                    '그 자리 참나무와 완벽한 형광석 위치는 매일 오전 6시에 초기화돼요.',
                    '참나무 / 형광석 투표가 5표 이상 모이거나 관리자가 확정하면 오늘의 위치를 확인할 수 있어요.',
                    'NPC, 동물 친구들, 기타 자원 위치도 함께 볼 수 있어요.',
                  ],
                ),
                _ExpandableGuideCard(
                  isExpanded: _expandedIndexes.contains(3),
                  onTap: () => _toggleExpanded(3),
                  emoji: '📚',
                  title: '도감 / 검색 / 편의 기능',
                  summary: '업적, 요리, 생물, 원예 도감 및 검색 기능',
                  details: const [
                    '업적 도감을 확인할 수 있어요.',
                    '요리 레시피와 재료 도감을 볼 수 있고, 성급별 가격 확인도 가능해요.',
                    '재료 상세에서 만들 수 있는 요리도 확인할 수 있어요.',
                    '생물 도감에서 시간, 위치, 날씨 정보를 함께 볼 수 있어요.',
                    '꽃 종류와 교배 공식도 확인할 수 있어요.',
                  ],
                ),
                _ExpandableGuideCard(
                  isExpanded: _expandedIndexes.contains(4),
                  onTap: () => _toggleExpanded(4),
                  emoji: '🐾',
                  title: '애완동물',
                  summary: '애완동물 등록·관리 및 간식 실험실 기능',
                  details: const [
                    '애완동물을 등록하고 관리할 수 있어요.',
                    '최애 간식을 찾기 위한 간식 실험실 기능을 사용할 수 있어요.',
                  ],
                ),

                const SizedBox(height: 24),

                const _SectionTitle(
                  title: '준비 중인 기능',
                  subtitle: '추후 업데이트 예정인 기능들이에요.',
                ),
                const SizedBox(height: 14),

                _ExpandableGuideCard(
                  isExpanded: _expandedIndexes.contains(5),
                  onTap: () => _toggleExpanded(5),
                  emoji: '🛋️',
                  title: '가구 / 옷 도감',
                  summary: '가구 및 옷 데이터 수집 중',
                  details: const [
                    '가구 및 옷 데이터가 모이면 도감 기능이 추가될 예정이에요.',
                  ],
                  badgeText: '준비중',
                ),
                _ExpandableGuideCard(
                  isExpanded: _expandedIndexes.contains(6),
                  onTap: () => _toggleExpanded(6),
                  emoji: '💬',
                  title: '미니 커뮤니티',
                  summary: '가구 배치 및 코디 공유',
                  details: const [
                    '가구 배치와 코디를 가볍게 자랑할 수 있는 미니 커뮤니티 기능을 준비 중이에요.',
                  ],
                  badgeText: '준비중',
                ),
                _ExpandableGuideCard(
                  isExpanded: _expandedIndexes.contains(7),
                  onTap: () => _toggleExpanded(7),
                  emoji: '⏰',
                  title: '재배 / 채집 타이머',
                  summary: '작물 재배와 자원 채집 시간  관리',
                  details: const [
                    '작물 재배 타이머 기능이 추가될 예정이에요.',
                    '리젠 시간에 맞춰 자원 채집을 도와주는 타이머 기능도 함께 준비 중이에요.',
                  ],
                  badgeText: '준비중',
                ),
                _ExpandableGuideCard(
                  isExpanded: _expandedIndexes.contains(8),
                  onTap: () => _toggleExpanded(8),
                  emoji: '🐶',
                  title: '애완동물 도감',
                  summary: '고양이 / 강아지 데이터 수집 중',
                  details: const [
                    '고양이와 강아지 종류 데이터가 모이면 도감 기능이 추가 될 예정이에요.',
                    '성격 데이터도 추가될 예정이에요.',
                  ],
                  badgeText: '준비중',
                ),

                const SizedBox(height: 80),
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
                  '키퍼노트 가이드',
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

class _ExpandableGuideCard extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onTap;
  final String emoji;
  final String title;
  final String summary;
  final List<String> details;
  final String? badgeText;

  const _ExpandableGuideCard({
    required this.isExpanded,
    required this.onTap,
    required this.emoji,
    required this.title,
    required this.summary,
    required this.details,
    this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    final splash = const Color(0xFFFFD9D1).withOpacity(0.28);
    final highlight = const Color(0xFFFFEEE9).withOpacity(0.70);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isExpanded
              ? const Color(0xFFFFDCD3)
              : const Color(0xFFF2F3F5),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8E7C).withOpacity(isExpanded ? 0.10 : 0.06),
            blurRadius: isExpanded ? 22 : 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          splashColor: splash,
          highlightColor: highlight,
          overlayColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.pressed)) return splash;
            if (states.contains(MaterialState.hovered)) {
              return const Color(0xFFFFF4F0).withOpacity(0.40);
            }
            return null;
          }),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFFFF4EF),
                            Color(0xFFFFEAE4),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFFFE0D7),
                        ),
                      ),
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 22, height: 1),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 15.8,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF111827),
                                      height: 1.24,
                                      letterSpacing: -0.18,
                                    ),
                                  ),
                                ),
                                if (badgeText != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF4F1),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: const Color(0xFFFFE3DC),
                                      ),
                                    ),
                                    child: Text(
                                      badgeText!,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFFF8E7C),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              summary,
                              style: const TextStyle(
                                fontSize: 12.9,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280),
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8F5),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(0xFFFFE4DD),
                          ),
                        ),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: Color(0xFFFF8E7C),
                        ),
                      ),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Column(
                      children: details
                          .map(
                            (text) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                margin: const EdgeInsets.only(top: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF2ED),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  size: 13,
                                  color: Color(0xFFFF8E7C),
                                ),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  text,
                                  style: const TextStyle(
                                    fontSize: 13.1,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF4B5563),
                                    height: 1.52,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                          .toList(),
                    ),
                  ),
                  crossFadeState: isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 220),
                ),
              ],
            ),
          ),
        ),
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
      '오늘의 날씨 확인하고 채집하러 가기',
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
        children: List.generate(steps.length, (index) {
          final isLast = index == steps.length - 1;

          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFF9F8F),
                        Color(0xFFFF8E7C),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF8E7C).withOpacity(0.18),
                        blurRadius: 9,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 12.2,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFCFB),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFFFEAE4),
                      ),
                    ),
                    child: Text(
                      steps[index],
                      style: const TextStyle(
                        fontSize: 13.4,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF374151),
                        height: 1.42,
                        letterSpacing: -0.05,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFF1F3F5),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8E7C).withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1ED),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.sticky_note_2_rounded,
              size: 18,
              color: Color(0xFFFF8E7C),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4B5563),
                height: 1.5,
                letterSpacing: -0.03,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
