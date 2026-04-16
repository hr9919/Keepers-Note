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
  bool _isGridView = false;
  String _selectedTag = '전체';
  CommunitySortType _sortType = CommunitySortType.latest;
  final Set<String> _likedPostIds = <String>{'post_1', 'post_3'};

  late final List<CommunityPost> _posts = const <CommunityPost>[
    CommunityPost(
      id: 'post_1',
      author: '해리',
      uid: 'UID 7H2K9',
      title: '올블랙 고양이랑 어울리는 거실 톤 정리했어요',
      body:
      '화이트 패브릭이랑 우드 가구 위주로 맞췄더니 검은 털이 더 또렷하게 보여요. 조명은 너무 노랗지 않게 맞추는 게 사진 찍을 때 훨씬 예뻤어요.',
      imageUrls: <String>[
        'https://images.unsplash.com/photo-1511044568932-338cba0ad803?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1574158622682-e40e69881006?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1543852786-1cf6624b9987?auto=format&fit=crop&w=1200&q=80',
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
      body:
      '침대 헤드 쪽은 색을 많이 쓰지 않고, 쿠션만 포인트로 잡으니까 훨씬 덜 복잡해 보여요. 벽지 톤이 연하면 소품이 잘 살아납니다.',
      imageUrls: <String>[
        'https://images.unsplash.com/photo-1505693416388-ac5ce068fe85?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1484154218962-a197022b5858?auto=format&fit=crop&w=1200&q=80',
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
      body:
      '직접 그린 과일 가판대 도안이에요. 색상 수를 너무 늘리지 않고 4~5개 톤으로만 잡으면 게임 안에서도 더 깔끔하게 보여요.',
      imageUrls: <String>[
        'https://images.unsplash.com/photo-1513364776144-60967b0f800f?auto=format&fit=crop&w=1200&q=80',
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
      body:
      '처음 꾸밀 때 입구, 메인 포토존, 작업 구역 세 개만 나눠도 배치가 훨씬 쉬워져요. 영상은 관리자 추천 자료라 상세에서 바로 볼 수 있게 넣으면 좋겠어요.',
      imageUrls: <String>[
        'https://images.unsplash.com/photo-1493666438817-866a91353ca9?auto=format&fit=crop&w=1200&q=80',
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
      body:
      '전체를 우드로 채우기보다 손잡이, 식탁 소품만 포인트로 두니까 훨씬 가볍고 깔끔하게 보여요.',
      imageUrls: <String>[
        'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1505693416388-ac5ce068fe85?auto=format&fit=crop&w=1200&q=80',
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
      body:
      '배경천은 채도를 너무 높이지 않는 게 좋아요. 크림색이나 톤다운 핑크가 털색이랑 잘 어울립니다.',
      imageUrls: <String>[
        'https://images.unsplash.com/photo-1517849845537-4d257902454a?auto=format&fit=crop&w=1200&q=80',
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

  List<CommunityPost> _filteredPosts() {
    List<CommunityPost> result = List<CommunityPost>.from(_posts);

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

  void _openFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext bottomSheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBFA).withOpacity(0.98),
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(
              color: const Color(0xFFFFE4DC),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFFFF8E7C).withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 42,
                    height: 4.5,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD7CF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const Text(
                  '정렬',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF6E625D),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _buildFilterChip(
                      '최신순',
                      _sortType == CommunitySortType.latest,
                          () {
                        setState(() {
                          _sortType = CommunitySortType.latest;
                        });
                      },
                    ),
                    _buildFilterChip(
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
                const SizedBox(height: 18),
                const Text(
                  '카테고리',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF6E625D),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _fixedTags.map<Widget>((String tag) {
                    final bool selected = _selectedTag == tag;
                    return _buildFilterChip(
                      tag,
                      selected,
                          () {
                        setState(() {
                          _selectedTag = tag;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(bottomSheetContext),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: const Color(0xFFFF8E7C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      '적용',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String text, bool selected, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFFFF1EC)
                : Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? const Color(0xFFFFD8CF)
                  : const Color(0xFFF6E4DE),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFFFF8E7C).withOpacity(selected ? 0.07 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.3,
              fontWeight: FontWeight.w800,
              color: selected
                  ? const Color(0xFFFF8E7C)
                  : const Color(0xFFB18579),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;
    const double appBarBodyHeight = 78;
    const double appBarBottomGap = 2;
    final double refreshTop = topPadding + appBarBodyHeight + appBarBottomGap;
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
              top: refreshTop,
              child: RefreshIndicator(
                color: const Color(0xFFFF8E7C),
                backgroundColor: Colors.white,
                edgeOffset: 8,
                displacement: 26,
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
                content: Text('UID 승인 사용자만 게시글을 작성할 수 있어요.'),
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
                        onTap: _openFilterSheet,
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
  }) {
    return Material(
      color: isAccent
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
              color: isAccent
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
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
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
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 120),
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
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 120),
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
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFFFF8E7C).withOpacity(0.08),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {},
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: _PostImageCarousel(post: post),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
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
                                Row(
                                  children: <Widget>[
                                    Flexible(
                                      child: Text(
                                        post.author,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF2D3436),
                                        ),
                                      ),
                                    ),
                                    if (post.isAdminPick) ...<Widget>[
                                      const SizedBox(width: 6),
                                      _buildTinyBadge('추천'),
                                    ],
                                  ],
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
                          _buildLikeButton(
                            liked: liked,
                            count: post.likeCount + (liked ? 1 : 0),
                            onTap: () => _toggleLike(post.id),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        post.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.28,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF443834),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        post.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.55,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8E7770),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children:
                        post.tags.map<Widget>((String tag) => _buildHashTag(tag)).toList(),
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

  Widget _buildGridCard(CommunityPost post, int index) {
    final bool liked = _likedPostIds.contains(post.id);
    final double aspectRatio = _gridAspectRatioForIndex(index, post);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFFFE5DE),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFFFF8E7C).withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: <Widget>[
                    AspectRatio(
                      aspectRatio: aspectRatio,
                      child: _buildNetworkImage(post.imageUrls.first),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _buildGridLikeButton(
                        liked: liked,
                        onTap: () => _toggleLike(post.id),
                      ),
                    ),
                    if (post.tags.isNotEmpty)
                      Positioned(
                        left: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.84),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFFFFE2DA),
                            ),
                          ),
                          child: Text(
                            '#${post.tags.first}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFFEA7F6B),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    if (post.isAdminPick)
                      Positioned(
                        left: 10,
                        top: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1EC).withOpacity(0.92),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFFFFD9D0),
                            ),
                          ),
                          child: const Text(
                            '추천',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFFF8E7C),
                            ),
                          ),
                        ),
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

  Widget _buildGridLikeButton({
    required bool liked,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.90),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFFFE5DE),
            ),
          ),
          child: Icon(
            liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 18,
            color: liked
                ? const Color(0xFFFF8E7C)
                : const Color(0xFFD0A49A),
          ),
        ),
      ),
    );
  }

  Widget _buildHashTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFFE1D9),
        ),
      ),
      child: Text(
        '#$text',
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFFEA7F6B),
        ),
      ),
    );
  }

  Widget _buildTinyBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEE9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFFD8CF)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: Color(0xFFFF8E7C),
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

  Widget _buildNetworkImage(String url) {
    return Image.network(
      url,
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
      loadingBuilder: (BuildContext context, Widget child,
          ImageChunkEvent? progress) {
        if (progress == null) return child;
        return Container(
          color: const Color(0xFFFFF8F5),
          alignment: Alignment.center,
          child: const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: Color(0xFFFF8E7C),
            ),
          ),
        );
      },
    );
  }
}

class _PostImageCarousel extends StatefulWidget {
  final CommunityPost post;

  const _PostImageCarousel({required this.post});

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

  Widget _buildNetworkImage(String url) {
    return Image.network(
      url,
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
      loadingBuilder: (BuildContext context, Widget child,
          ImageChunkEvent? progress) {
        if (progress == null) return child;
        return Container(
          color: const Color(0xFFFFF8F5),
          alignment: Alignment.center,
          child: const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: Color(0xFFFF8E7C),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> images = widget.post.imageUrls;

    return AspectRatio(
      aspectRatio: 16 / 10,
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
                _buildNetworkImage(images[index]),
          ),
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.88),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: const Color(0xFFFFE2DA),
                ),
              ),
              child: Text(
                widget.post.tags.first,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFB18579),
                ),
              ),
            ),
          ),
          if (images.length > 1)
            Positioned(
              top: 14,
              right: 14,
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
          if (images.length > 1)
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
