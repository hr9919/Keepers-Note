import 'dart:ui';

import 'package:flutter/material.dart';

class CommunityScreen extends StatefulWidget {
  final VoidCallback? openDrawer;

  const CommunityScreen({
    super.key,
    this.openDrawer,
  });

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

enum CommunitySortType { latest, popular }

class CommunityPost {
  final String id;
  final String author;
  final String uid;
  final String title;
  final String body;
  final List<String> imageUrls;
  final List<String> tags;
  final int likeCount;
  final String createdLabel;
  final bool isAdminPick;
  final bool hasYoutube;
  final bool hasSourceLink;

  const CommunityPost({
    required this.id,
    required this.author,
    required this.uid,
    required this.title,
    required this.body,
    required this.imageUrls,
    required this.tags,
    required this.likeCount,
    required this.createdLabel,
    this.isAdminPick = false,
    this.hasYoutube = false,
    this.hasSourceLink = false,
  });
}

class _CommunityScreenState extends State<CommunityScreen> {
  static const List<String> _fixedTags = <String>[
    '전체',
    '인테리어',
    '익스테리어',
    '코디',
    '반려동물',
    '도트 도안',
    '꿀팁 영상',
  ];

  final ScrollController _scrollController = ScrollController();

  bool _showTopButton = false;
  bool _isGridView = true;
  bool _isFilterPanelOpen = false;
  String _selectedTag = '전체';
  bool _showLikedOnly = false;
  CommunitySortType _sortType = CommunitySortType.latest;
  final Set<String> _likedPostIds = <String>{'post_1', 'post_3'};

  _TagChipStyle _tagChipStyle(String text) {
    switch (text) {
      case '인테리어':
        return const _TagChipStyle(
          background: Color(0xFFFFF4EF),
          border: Color(0xFFF7D8CC),
          text: Color(0xFFD97A5D),
          selectedBackground: Color(0xFFFFE8DF),
          selectedBorder: Color(0xFFF1BEAA),
          selectedText: Color(0xFFC96547),
        );
      case '익스테리어':
        return const _TagChipStyle(
          background: Color(0xFFF3FAF6),
          border: Color(0xFFD8EEDD),
          text: Color(0xFF5E9D74),
          selectedBackground: Color(0xFFE5F5EB),
          selectedBorder: Color(0xFFBFE2CB),
          selectedText: Color(0xFF43885B),
        );
      case '코디':
        return const _TagChipStyle(
          background: Color(0xFFFFF4FA),
          border: Color(0xFFF1D7E8),
          text: Color(0xFFC56C9D),
          selectedBackground: Color(0xFFFFE8F4),
          selectedBorder: Color(0xFFEAB8D6),
          selectedText: Color(0xFFB75689),
        );
      case '반려동물':
        return const _TagChipStyle(
          background: Color(0xFFF8F3FF),
          border: Color(0xFFE2D8F5),
          text: Color(0xFF8B73C7),
          selectedBackground: Color(0xFFEEE7FF),
          selectedBorder: Color(0xFFD1C2F0),
          selectedText: Color(0xFF775BB8),
        );
      case '도트 도안':
        return const _TagChipStyle(
          background: Color(0xFFFFF9EE),
          border: Color(0xFFF2E4BE),
          text: Color(0xFFC59A34),
          selectedBackground: Color(0xFFFFF2D9),
          selectedBorder: Color(0xFFEBCF8D),
          selectedText: Color(0xFFB78718),
        );
      case '꿀팁 영상':
        return const _TagChipStyle(
          background: Color(0xFFEFF8FF),
          border: Color(0xFFD2E8F8),
          text: Color(0xFF5B95BA),
          selectedBackground: Color(0xFFE1F1FC),
          selectedBorder: Color(0xFFB6DBF2),
          selectedText: Color(0xFF427FA7),
        );
      case '전체':
      default:
        return const _TagChipStyle(
          background: Color(0xFFFBF8F6),
          border: Color(0xFFECE3DD),
          text: Color(0xFF9A8C82),
          selectedBackground: Color(0xFFF4EEEA),
          selectedBorder: Color(0xFFE2D5CC),
          selectedText: Color(0xFF7B6D64),
        );
    }
  }

  late final List<CommunityPost> _posts = const <CommunityPost>[
    CommunityPost(
      id: 'post_1',
      author: '해리',
      uid: 'UID 7H2K9',
      title: '올블랙 고양이랑 어울리는 거실 톤 정리했어요',
      body: '',
      imageUrls: <String>[
        'assets/images/sample_1.jpeg',
        'assets/images/sample_2.jpeg',
        'assets/images/sample_3.jpeg',
      ],
      tags: <String>['반려동물', '인테리어'],
      likeCount: 128,
      createdLabel: '오늘',
      isAdminPick: true,
    ),
    CommunityPost(
      id: 'post_2',
      author: '모나',
      uid: 'UID A0P3D',
      title: '핑크 톤 침실 코디 + 쿠션 배치 팁',
      body: '',
      imageUrls: <String>[
        'assets/images/sample_4.jpeg',
        'assets/images/sample_5.jpeg',
      ],
      tags: <String>['코디', '인테리어'],
      likeCount: 73,
      createdLabel: '1일 전',
    ),
    CommunityPost(
      id: 'post_3',
      author: '페퍼',
      uid: 'UID N8M1Q',
      title: '도트 도안 정리본 올려요',
      body: '',
      imageUrls: <String>[
        'assets/images/sample_6.png',
      ],
      tags: <String>['도트 도안'],
      likeCount: 211,
      createdLabel: '2일 전',
      hasSourceLink: true,
    ),
    CommunityPost(
      id: 'post_4',
      author: '쿠키',
      uid: 'UID R2T8W',
      title: '초보용 집 꾸미기 동선 정리 영상',
      body: '',
      imageUrls: <String>[
        'assets/images/sample_7.png',
      ],
      tags: <String>['꿀팁 영상', '익스테리어'],
      likeCount: 94,
      createdLabel: '3일 전',
      isAdminPick: true,
      hasYoutube: true,
    ),
    CommunityPost(
      id: 'post_5',
      author: '라라',
      uid: 'UID K2M7L',
      title: '화이트 톤 주방에 우드 소품 살짝만 넣은 조합',
      body: '',
      imageUrls: <String>[
        'assets/images/sample_8.png',
        'assets/images/sample_9.png',
      ],
      tags: <String>['인테리어'],
      likeCount: 56,
      createdLabel: '4일 전',
    ),
    CommunityPost(
      id: 'post_6',
      author: '보리',
      uid: 'UID Z8T1Q',
      title: '강아지 포토존 만들 때 배경천 색 고르는 법',
      body: '',
      imageUrls: <String>[
        'assets/images/sample_10.png',
      ],
      tags: <String>['반려동물', '코디'],
      likeCount: 89,
      createdLabel: '5일 전',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final bool show = _scrollController.offset > 160;
    if (show != _showTopButton) {
      setState(() {
        _showTopButton = show;
      });
    }
  }

  Future<void> _onRefresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
  }

  void _toggleLike(String postId) {
    setState(() {
      if (_likedPostIds.contains(postId)) {
        _likedPostIds.remove(postId);
      } else {
        _likedPostIds.add(postId);
      }
    });
  }

  void _toggleViewMode() {
    setState(() {
      _isGridView = !_isGridView;
    });
  }

  void _toggleFilterPanel() {
    setState(() {
      _isFilterPanelOpen = !_isFilterPanelOpen;
    });
  }

  void _closeFilterPanel() {
    if (_isFilterPanelOpen) {
      setState(() {
        _isFilterPanelOpen = false;
      });
    }
  }

  List<CommunityPost> _filteredPosts() {
    List<CommunityPost> result = List<CommunityPost>.from(_posts);

    if (_showLikedOnly) {
      result = result
          .where((CommunityPost post) => _likedPostIds.contains(post.id))
          .toList();
    }

    if (_selectedTag != '전체') {
      result = result
          .where((CommunityPost post) => post.tags.contains(_selectedTag))
          .toList();
    }

    result.sort((CommunityPost a, CommunityPost b) {
      if (_sortType == CommunitySortType.popular) {
        final int likeCompare = b.likeCount.compareTo(a.likeCount);
        if (likeCompare != 0) return likeCompare;
      }
      return a.id.compareTo(b.id) * -1;
    });

    result.sort((CommunityPost a, CommunityPost b) {
      if (a.isAdminPick == b.isAdminPick) return 0;
      return a.isAdminPick ? -1 : 1;
    });

    return result;
  }

  Widget _buildFilterChip(
      String text,
      bool selected,
      VoidCallback onTap, {
        bool isHashTag = false,
      }) {
    final String label = isHashTag && text != '전체' ? '#$text' : text;
    final _TagChipStyle style = _tagChipStyle(text);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? style.selectedBackground : style.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? style.selectedBorder : style.border,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: (selected ? style.selectedText : style.text)
                    .withOpacity(selected ? 0.08 : 0.035),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            maxLines: 1,
            textAlign: TextAlign.center,
            strutStyle: const StrutStyle(
              fontSize: 11.6,
              height: 1.0,
              forceStrutHeight: true,
            ),
            style: TextStyle(
              fontSize: 11.6,
              height: 1.0,
              leadingDistribution: TextLeadingDistribution.even,
              fontWeight: FontWeight.w800,
              color: selected ? style.selectedText : style.text,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final double topPadding = media.padding.top;

    const double appBarContentHeight = 34;
    const double appBarBottomPadding = 14;
    final double appBarTotalHeight =
        topPadding + 10 + appBarContentHeight + appBarBottomPadding;

    final List<CommunityPost> posts = _filteredPosts();

    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F6),
      body: SafeArea(
        top: false,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Image.asset(
                'assets/images/bg_gradient.png',
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              top: appBarTotalHeight,
              child: RefreshIndicator(
                color: const Color(0xFFFF8E7C),
                backgroundColor: Colors.white,
                edgeOffset: 6,
                displacement: 24,
                onRefresh: _onRefresh,
                child: _isGridView
                    ? _buildPinterestFeed(posts)
                    : _buildListFeed(posts),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildCustomAppBar(context, topPadding),
            ),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_isFilterPanelOpen,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  opacity: _isFilterPanelOpen ? 1 : 0,
                  child: GestureDetector(
                    onTap: _closeFilterPanel,
                    child: Container(
                      color: Colors.black.withOpacity(0.18),
                    ),
                  ),
                ),
              ),
            ),
            _buildFilterSidePanel(topPadding),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              right: 20,
              bottom: _showTopButton ? 104 : 78,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _showTopButton ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !_showTopButton,
                  child: _buildScrollToTopButton(),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: FloatingActionButton.extended(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('현재는 사진과 해시태그 중심으로 업로드하는 구조예요.'),
              ),
            );
          },
          backgroundColor: const Color(0xFFFF8E7C),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
          label: const Text(
            '글쓰기',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSidePanel(double topPadding) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 380),
      curve: _isFilterPanelOpen
          ? Curves.easeOutQuad
          : Curves.easeInCubic,
      top: topPadding + 118,
      right: _isFilterPanelOpen ? 12 : -340,
      child: IgnorePointer(
        ignoring: !_isFilterPanelOpen,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          opacity: _isFilterPanelOpen ? 1 : 0.85,
          child: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: 272,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.992),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFF0E3DC),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withOpacity(0.09),
                      blurRadius: 22,
                      offset: const Offset(-4, 10),
                    ),
                    BoxShadow(
                      color: const Color(0xFFFF8E7C).withOpacity(0.045),
                      blurRadius: 14,
                      offset: const Offset(-2, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Expanded(
                          child: Text(
                            '정렬 및 필터',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF443834),
                            ),
                          ),
                        ),
                        _buildPanelIconButton(
                          icon: Icons.close_rounded,
                          onTap: _closeFilterPanel,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '정렬',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF6E625D),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        _buildSortChip(
                          '최신순',
                          _sortType == CommunitySortType.latest,
                              () {
                            setState(() {
                              _sortType = CommunitySortType.latest;
                            });
                          },
                        ),
                        _buildSortChip(
                          '인기순',
                          _sortType == CommunitySortType.popular,
                              () {
                            setState(() {
                              _sortType = CommunitySortType.popular;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '필터',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF6E625D),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        _buildFilterChip(
                          '전체',
                          _selectedTag == '전체',
                              () {
                            setState(() {
                              _selectedTag = '전체';
                            });
                          },
                          isHashTag: true,
                        ),
                        _buildLikedFilterChip(),
                        _buildFilterChip(
                          '인테리어',
                          _selectedTag == '인테리어',
                              () {
                            setState(() {
                              _selectedTag = '인테리어';
                            });
                          },
                          isHashTag: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        _buildFilterChip(
                          '코디',
                          _selectedTag == '코디',
                              () {
                            setState(() {
                              _selectedTag = '코디';
                            });
                          },
                          isHashTag: true,
                        ),
                        _buildFilterChip(
                          '익스테리어',
                          _selectedTag == '익스테리어',
                              () {
                            setState(() {
                              _selectedTag = '익스테리어';
                            });
                          },
                          isHashTag: true,
                        ),
                        _buildFilterChip(
                          '반려동물',
                          _selectedTag == '반려동물',
                              () {
                            setState(() {
                              _selectedTag = '반려동물';
                            });
                          },
                          isHashTag: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        _buildFilterChip(
                          '도트 도안',
                          _selectedTag == '도트 도안',
                              () {
                            setState(() {
                              _selectedTag = '도트 도안';
                            });
                          },
                          isHashTag: true,
                        ),
                        _buildFilterChip(
                          '꿀팁 영상',
                          _selectedTag == '꿀팁 영상',
                              () {
                            setState(() {
                              _selectedTag = '꿀팁 영상';
                            });
                          },
                          isHashTag: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: const Color(0xFFE7DBD3),
                              ),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.025),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(15),
                                onTap: () {
                                  setState(() {
                                    _sortType = CommunitySortType.latest;
                                    _selectedTag = '전체';
                                    _showLikedOnly = false;
                                  });
                                },
                                child: const Center(
                                  child: Text(
                                    '초기화',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5,
                                      color: Color(0xFF8A7B71),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFF9C88),
                                  Color(0xFFFF8E7C),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: const Color(0xFFFF8E7C).withOpacity(0.22),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(15),
                                onTap: _closeFilterPanel,
                                child: const Center(
                                  child: Text(
                                    '적용',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12.5,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLikedFilterChip() {
    final bool selected = _showLikedOnly;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _showLikedOnly = !_showLikedOnly;
          });
        },
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFFFEEF1)
                : const Color(0xFFFFF7F8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? const Color(0xFFFFC6CF)
                  : const Color(0xFFF3D8DE),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFFFF6F8F).withOpacity(
                  selected ? 0.12 : 0.05,
                ),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                selected
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: 13,
                color: selected
                    ? const Color(0xFFFF5E7E)
                    : const Color(0xFFD98A9D),
              ),
              const SizedBox(width: 5),
              Text(
                '좋아요',
                strutStyle: const StrutStyle(
                  fontSize: 11.6,
                  height: 1.0,
                  forceStrutHeight: true,
                ),
                style: TextStyle(
                  fontSize: 11.6,
                  height: 1.0,
                  leadingDistribution: TextLeadingDistribution.even,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? const Color(0xFFE25476)
                      : const Color(0xFFBF7A8E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortChip(
      String text,
      bool selected,
      VoidCallback onTap,
      ) {
    final Color bg = selected
        ? const Color(0xFFFFF1CC)
        : const Color(0xFFFFFBF2);
    final Color border = selected
        ? const Color(0xFFF2D48B)
        : const Color(0xFFF1E4BF);
    final Color textColor = selected
        ? const Color(0xFF9C6B00)
        : const Color(0xFFB08A3C);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: textColor.withOpacity(selected ? 0.10 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            text,
            maxLines: 1,
            strutStyle: const StrutStyle(
              fontSize: 11.6,
              height: 1.0,
              forceStrutHeight: true,
            ),
            style: TextStyle(
              fontSize: 11.6,
              height: 1.0,
              leadingDistribution: TextLeadingDistribution.even,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanelIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFFFF8F5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFF2E3DC),
            ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: const Color(0xFFFF8E7C),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAppBar(BuildContext context, double topPadding) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.88),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFFF8E7C).withOpacity(0.08),
            width: 1,
          ),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFF8E7C).withOpacity(0.03),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
            ),
            child: Stack(
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.fromLTRB(16, topPadding + 10, 16, 14),
                  child: Row(
                    children: <Widget>[
                      _buildIconAppBarButton(
                        icon: _isGridView
                            ? Icons.view_stream_rounded
                            : Icons.grid_view_rounded,
                        onTap: _toggleViewMode,
                        isAccent: true,
                      ),
                      const Spacer(),
                      _buildAppTitle(),
                      const Spacer(),
                      _buildIconAppBarButton(
                        icon: Icons.tune_rounded,
                        onTap: _toggleFilterPanel,
                        isActive: _isFilterPanelOpen,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 18,
                  right: 18,
                  child: IgnorePointer(
                    child: Container(
                      height: 2.5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF8E7C).withOpacity(0.62),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppTitle() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text(
          "Keeper's Feed",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF2D3436),
            letterSpacing: -0.3,
            fontFamily: 'SF Pro',
          ),
        ),
        const SizedBox(height: 3),
        Container(
          width: 12,
          height: 3,
          decoration: BoxDecoration(
            color: const Color(0xFFFF8E7C).withOpacity(0.78),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ],
    );
  }

  Widget _buildIconAppBarButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isAccent = false,
    bool isActive = false,
  }) {
    return Material(
      color: isAccent || isActive
          ? const Color(0xFFFFF3F0)
          : const Color(0xFFFFFBFA),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isAccent || isActive
                  ? const Color(0xFFFFE2DB)
                  : const Color(0xFFF2E3DE),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 19,
            color: const Color(0xFFFF8E7C),
          ),
        ),
      ),
    );
  }

  Widget _buildListFeed(List<CommunityPost> posts) {
    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 132),
      children: <Widget>[
        if (posts.isEmpty)
          _buildEmptyState()
        else
          ...posts.map<Widget>((CommunityPost post) => _buildPostCard(post)),
      ],
    );
  }

  Widget _buildPinterestFeed(List<CommunityPost> posts) {
    if (posts.isEmpty) {
      return ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 132),
        children: <Widget>[
          _buildEmptyState(),
        ],
      );
    }

    final List<CommunityPost> leftColumn = <CommunityPost>[];
    final List<CommunityPost> rightColumn = <CommunityPost>[];
    double leftScore = 0;
    double rightScore = 0;

    for (int i = 0; i < posts.length; i++) {
      final CommunityPost post = posts[i];
      final double score = _estimatedGridHeightScore(post, i);
      if (leftScore <= rightScore) {
        leftColumn.add(post);
        leftScore += score;
      } else {
        rightColumn.add(post);
        rightScore += score;
      }
    }

    return SingleChildScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 132),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              children: leftColumn
                  .asMap()
                  .entries
                  .map<Widget>(
                    (MapEntry<int, CommunityPost> entry) =>
                    _buildGridCard(entry.value, entry.key),
              )
                  .toList(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              children: rightColumn
                  .asMap()
                  .entries
                  .map<Widget>(
                    (MapEntry<int, CommunityPost> entry) =>
                    _buildGridCard(entry.value, entry.key + 1),
              )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  double _estimatedGridHeightScore(CommunityPost post, int index) {
    final int imageCount = post.imageUrls.length;
    return 1.0 + (index % 3) * 0.16 + imageCount * 0.10;
  }

  double _gridAspectRatioForIndex(int index, CommunityPost post) {
    if (post.hasYoutube) return 0.82;
    switch (index % 4) {
      case 0:
        return 1.02;
      case 1:
        return 0.90;
      case 2:
        return 1.12;
      default:
        return 0.96;
    }
  }

  Widget _buildPostCard(CommunityPost post) {
    final bool liked = _likedPostIds.contains(post.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.white.withOpacity(0.97),
            const Color(0xFFFFFCFB).withOpacity(0.95),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFFFE7E0),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFFFF8E7C).withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: _PostImageCarousel(
                      post: post,
                      aspectRatio: 1,
                      showBottomIndicator: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFFFFF2EE),
                        child: Text(
                          post.author.characters.first,
                          style: const TextStyle(
                            color: Color(0xFFFF8E7C),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              post.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2D3436),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${post.uid} · ${post.createdLabel}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFC19C92),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildLikeButton(
                        liked: liked,
                        count: post.likeCount + (liked ? 1 : 0),
                        onTap: () => _toggleLike(post.id),
                      ),
                    ],
                  ),
                  if (post.tags.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: post.tags
                          .map<Widget>((String tag) => _buildHashTag(tag))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGridCard(CommunityPost post, int index) {
    final bool liked = _likedPostIds.contains(post.id);
    final double aspectRatio = _gridAspectRatioForIndex(index, post);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.96, end: 1),
      duration: Duration(milliseconds: 240 + (index % 6) * 40),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: scale.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.94),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFFFE7E0),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0xFFFF8E7C).withOpacity(0.07),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.035),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: AspectRatio(
                    aspectRatio: aspectRatio,
                    child: _AnimatedGridImageCarousel(
                      post: post,
                      liked: liked,
                      onLikeTap: () => _toggleLike(post.id),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLikeButton({
    required bool liked,
    required int count,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: liked
              ? const Color(0xFFFFF2EF)
              : Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(
            color: liked
                ? const Color(0xFFFFD7CF)
                : const Color(0xFFF2E3DE),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 18,
              color: liked
                  ? const Color(0xFFFF8E7C)
                  : const Color(0xFFD0A49A),
            ),
            const SizedBox(width: 5),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: liked
                    ? const Color(0xFFFF8E7C)
                    : const Color(0xFFC19C92),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHashTag(String text) {
    final _TagChipStyle style = _tagChipStyle(text);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: style.border,
        ),
      ),
      child: Text(
        '#$text',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: style.text,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0E2DD)),
      ),
      child: const Column(
        children: <Widget>[
          Icon(
            Icons.forum_outlined,
            size: 34,
            color: Color(0xFFFF8E7C),
          ),
          SizedBox(height: 12),
          Text(
            '조건에 맞는 게시글이 없어요.',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2D3436),
            ),
          ),
          SizedBox(height: 6),
          Text(
            '필터를 바꿔서 다시 찾아보세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: Color(0xFFC19C92),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollToTopButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          );
        },
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF0E1DB)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFFFF8E7C).withOpacity(0.08),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.keyboard_arrow_up_rounded,
            size: 28,
            color: Color(0xFFFF8E7C),
          ),
        ),
      ),
    );
  }
}

class _PostImageCarousel extends StatefulWidget {
  final CommunityPost post;
  final double aspectRatio;
  final bool showBottomIndicator;

  const _PostImageCarousel({
    required this.post,
    this.aspectRatio = 16 / 10,
    this.showBottomIndicator = true,
  });

  @override
  State<_PostImageCarousel> createState() => _PostImageCarouselState();
}

class _PostImageCarouselState extends State<_PostImageCarousel> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildAssetImage(String path) {
    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFFFFF6F2),
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_not_supported_outlined,
          size: 32,
          color: Color(0xFFE1B3A8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> images = widget.post.imageUrls;

    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: Stack(
        children: <Widget>[
          PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            onPageChanged: (int index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (BuildContext context, int index) =>
                _buildAssetImage(images[index]),
          ),
          if (widget.post.isAdminPick)
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFC8A7),
                      Color(0xFFFF8E7C),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.92),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF8E7C).withOpacity(0.30),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.star_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          if (images.length > 1)
            Positioned(
              right: 14,
              bottom: widget.showBottomIndicator ? 28 : 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.78),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0xFFFFE2DA),
                  ),
                ),
                child: Text(
                  '${_currentIndex + 1}/${images.length}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFEA7F6B),
                  ),
                ),
              ),
            ),
          if (widget.showBottomIndicator && images.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 14,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(images.length, (int index) {
                  final bool selected = index == _currentIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: selected ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFFF8E7C)
                          : Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _AnimatedGridImageCarousel extends StatefulWidget {
  final CommunityPost post;
  final bool liked;
  final VoidCallback onLikeTap;

  const _AnimatedGridImageCarousel({
    required this.post,
    required this.liked,
    required this.onLikeTap,
  });

  @override
  State<_AnimatedGridImageCarousel> createState() =>
      _AnimatedGridImageCarouselState();
}

class _AnimatedGridImageCarouselState
    extends State<_AnimatedGridImageCarousel> {
  late final PageController _pageController;
  int _currentIndex = 0;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildImage(String path) {
    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFFFFF6F2),
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_not_supported_outlined,
          size: 30,
          color: Color(0xFFE1B3A8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.post.imageUrls;

    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _pressed = true;
        });
      },
      onTapCancel: () {
        setState(() {
          _pressed = false;
        });
      },
      onTapUp: (_) {
        setState(() {
          _pressed = false;
        });
      },
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            PageView.builder(
              controller: _pageController,
              itemCount: images.length,
              onPageChanged: (int index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (BuildContext context, int index) {
                return _buildImage(images[index]);
              },
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.08),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withOpacity(0.16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (widget.post.tags.isNotEmpty)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.88),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xFFFFE2DA),
                    ),
                  ),
                  child: Text(
                    '#${widget.post.tags.first}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFFEA7F6B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 8,
              right: 8,
              child: _AnimatedLikeBubble(
                liked: widget.liked,
                onTap: widget.onLikeTap,
                size: 32,
                iconSize: 16,
              ),
            ),
            if (widget.post.isAdminPick)
              Positioned(
                left: 8,
                bottom: images.length > 1 ? 22 : 8,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFFC8A7),
                        Color(0xFFFF8E7C),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.92),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF8E7C).withOpacity(0.22),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                ),
              ),
            if (images.length > 1)
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List<Widget>.generate(images.length, (i) {
                        final bool selected = i == _currentIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.symmetric(horizontal: 2.5),
                          width: selected ? 14 : 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFFF8E7C)
                                : Colors.white.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedLikeBubble extends StatefulWidget {
  final bool liked;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  const _AnimatedLikeBubble({
    required this.liked,
    required this.onTap,
    this.size = 36,
    this.iconSize = 18,
  });

  @override
  State<_AnimatedLikeBubble> createState() => _AnimatedLikeBubbleState();
}

class _AnimatedLikeBubbleState extends State<_AnimatedLikeBubble> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _pressed = true;
        });
      },
      onTapCancel: () {
        setState(() {
          _pressed = false;
        });
      },
      onTapUp: (_) {
        setState(() {
          _pressed = false;
        });
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.liked
                  ? const Color(0xFFFFD8D0)
                  : const Color(0xFFFFE5DE),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) {
              return ScaleTransition(
                scale: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutBack,
                ),
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
            child: Icon(
              widget.liked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              key: ValueKey<bool>(widget.liked),
              size: widget.iconSize,
              color: widget.liked
                  ? const Color(0xFFFF8E7C)
                  : const Color(0xFFD0A49A),
            ),
          ),
        ),
      ),
    );
  }
}

class _TagChipStyle {
  final Color background;
  final Color border;
  final Color text;
  final Color selectedBackground;
  final Color selectedBorder;
  final Color selectedText;

  const _TagChipStyle({
    required this.background,
    required this.border,
    required this.text,
    required this.selectedBackground,
    required this.selectedBorder,
    required this.selectedText,
  });
}