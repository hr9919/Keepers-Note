import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'setting_screen.dart';
import 'map_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback? openDrawer;
  final VoidCallback? openEndDrawer;
  final List<Map<String, dynamic>> todoList;
  final Function(int)? onTodoToggle;

  const HomeScreen({
    super.key,
    this.openDrawer,
    this.openEndDrawer,
    this.todoList = const [],
    this.onTodoToggle,
  });

  static const List<BoxShadow> _kCommonShadow = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 20, offset: Offset(0, 0), spreadRadius: 1),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
          image: DecorationImage(image: AssetImage('assets/images/bg_gradient.png'), fit: BoxFit.cover)
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildCustomAppBar(context),
            _buildSearchBar(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildSectionTitle('날씨 정보'),
                    const SizedBox(height: 8),
                    _buildWeatherCard(),
                    const SizedBox(height: 32),
                    _buildTodoSection(),
                    const SizedBox(height: 32),
                    _buildMapSection(context),
                    const SizedBox(height: 32),
                    // ★ 여기 context를 빠뜨리면 에러가 납니다!
                    _buildEventSection(context),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 1. 날씨 카드 ---
  Widget _buildWeatherCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      width: double.infinity, height: 120,
      decoration: ShapeDecoration(color: Colors.white.withOpacity(0.9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), shadows: _kCommonShadow),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Align(alignment: Alignment.centerLeft, child: _buildWeatherTimeline()), const Center(child: Text('현재 날씨에는 특별한 이벤트가 없습니다.', style: TextStyle(fontSize: 11, fontFamily: 'SF Pro')))])),
          const SizedBox(width: 20), _buildWeeklyColumn(),
        ],
      ),
    );
  }

  Widget _buildWeatherTimeline() {
    return SingleChildScrollView(scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), child: Row(children: [_buildTimeItem('현재 (아침)', true), _buildTimeItem('낮', false), _buildTimeItem('밤', false), _buildTimeItem('내일 새벽', false), _buildTimeItem('내일 아침', false)]));
  }

  Widget _buildTimeItem(String label, bool isCurrent) {
    return Container(width: 50, margin: const EdgeInsets.only(right: 6), child: Column(children: [Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400, fontFamily: 'SF Pro')), const SizedBox(height: 6), Container(width: 26, height: 26, decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.wb_sunny_rounded, size: 16, color: Colors.orange))]));
  }

  Widget _buildWeeklyColumn() {
    final days = [{'day': '수 (내일)', 'icon': true}, {'day': '목', 'icon': true}, {'day': '금', 'icon': true}, {'day': '토', 'icon': true}, {'day': '일', 'icon': false}];
    return Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: days.map((data) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(mainAxisSize: MainAxisSize.min, children: [Text(data['day'] as String, style: const TextStyle(fontSize: 9, fontFamily: 'SF Pro')), const SizedBox(width: 6), Icon(Icons.circle, size: 8, color: (data['icon'] as bool) ? Colors.black26 : Colors.transparent)]))).toList());
  }

  // --- 2. 오늘의 할 일 섹션 ---
  Widget _buildTodoSection() {
    int displayLimit = 6;
    int displayCount = todoList.length > displayLimit ? displayLimit : todoList.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('오늘의 할 일'),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GestureDetector(
            onTap: openEndDrawer,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.fromLTRB(25, 20, 15, 20),
              decoration: ShapeDecoration(color: Colors.white.withOpacity(0.85), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), shadows: _kCommonShadow),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 30),
                    child: todoList.isEmpty
                        ? const Text("오늘의 할 일을 등록해보세요! 🌿", style: TextStyle(color: Colors.grey, fontSize: 14))
                        : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...List.generate(displayCount, (index) {
                          final todo = todoList[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: _buildTodoItemSummary(
                              todo['taskName'],
                              todo['completed'],
                                  () => onTodoToggle?.call(index),
                            ),
                          );
                        }),
                        if (todoList.length > displayLimit)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text("+ ${todoList.length - displayLimit}개 더보기", style: const TextStyle(fontSize: 11, color: Color(0xFFFF8E7C), fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                  ),
                  const Positioned(
                    top: 0, right: 0,
                    child: Icon(Icons.chevron_right, size: 20, color: Colors.black26),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTodoItemSummary(String task, bool isDone, VoidCallback onToggle) {
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Container(width: 16, height: 16, decoration: BoxDecoration(color: isDone ? const Color(0x2890CDFF) : Colors.transparent, borderRadius: BorderRadius.circular(4), border: Border.all(width: 1, color: const Color(0xFF90CDFF))), child: isDone ? const Icon(Icons.check, size: 10, color: Color(0xFF90CDFF)) : null),
          const SizedBox(width: 10),
          Expanded(
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: IntrinsicWidth(
                      child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Text(task, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontFamily: 'SF Pro', color: isDone ? Colors.grey : Colors.black87)),
                            if (isDone) Positioned(left: 0, right: 0, child: Container(height: 1.2, color: Colors.grey.withOpacity(0.6)))
                          ]
                      )
                  )
              )
          ),
        ],
      ),
    );
  }

  // --- 3. 지도 섹션 ---
  Widget _buildMapSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('지도'),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const MapScreen()));
            },
            child: Container(
              width: double.infinity,
              height: 227,
              decoration: ShapeDecoration(
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                shadows: _kCommonShadow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    Positioned.fill(
                        child: Image.asset(
                            'assets/images/map_preview.png',
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Container(color: Colors.grey[200], child: const Icon(Icons.map_outlined, color: Colors.grey))
                        )
                    ),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Image.asset('assets/icons/ic_maximize.png', width: 54, height: 54),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- 4. 이벤트 섹션 ---
  // --- 4. 이벤트 섹션 (네트워크 이미지 적용) ---
  Widget _buildEventSection(BuildContext context) {
    // 화면 전체 너비에서 좌우 패딩(16*2)과 아이템 사이 간격(12*2)을 뺍니다.
    double screenWidth = MediaQuery.of(context).size.width;
    double itemWidth = (screenWidth - (16 * 2) - (12 * 2)) / 3;

    // ★ 페이스북에서 가져온 실제 이미지 주소 (유효기간 주의)
    const String facebookImageUrl =
        'https://scontent-icn2-1.xx.fbcdn.net/v/t39.30808-6/653560105_122127351237021391_2534542623193999458_n.jpg?_nc_cat=110&ccb=1-7&_nc_sid=13d280&_nc_ohc=GJ6gMkapj0EQ7kNvwGe2VZj&_nc_oc=AdoiTg1t670K8-kTotsOj-LbC134Aq6plrE5HNZuqP7TmI07StiCU9mt_MJCAlh2YlE&_nc_zt=23&_nc_ht=scontent-icn2-1.xx&_nc_gid=cd7roSdfW4Yhunct6S5Ghg&_nc_ss=7a32e&oh=00_AfwXPj2QZt7wKp-poD2VpNQkENY9kC40PFj5WJa_DwUSZA&oe=69CE102B';

    // ★ 클릭 시 이동할 페이스북 포스트 원본 링크
    const String facebookPostUrl =
        'https://www.facebook.com/HeartopiaKR/photos/122127351225021391/';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('진행중인 이벤트'),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 첫 번째 카드를 페이스북 이미지와 링크로 변경
              _buildEventCard(
                context,
                facebookImageUrl, // 이제 로컬 에셋 경로가 아닌 URL을 넘깁니다.
                itemWidth,
                facebookPostUrl,
                isNetworkImage: true, // ★ 네트워크 이미지임을 표시하는 플래그 추가
              ),
              // 나머지는 일단 기존 유지 (나중에 지우거나 변경)
              _buildEventCard(context, 'assets/images/event_2.png', itemWidth, 'https://www.leagueoflegends.com'),
              _buildEventCard(context, 'assets/images/event_3.png', itemWidth, 'https://github.com'),
            ],
          ),
        ),
      ],
    );
  }

// ★ 파라미터에 isNetworkImage 추가
  Widget _buildEventCard(BuildContext context, String imagePathOrUrl, double width, String url, {bool isNetworkImage = false}) {
    return GestureDetector(
      onTap: () async {
        final Uri uri = Uri.parse(url);
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          debugPrint('Could not launch $url');
        }
      },
      child: Container(
        width: width,
        height: width, // 1:1 정사각형
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 15,
              offset: Offset(0, 0),
              spreadRadius: 1,
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: isNetworkImage
              ? Image.network( // ★ 네트워크 이미지일 때
            imagePathOrUrl,
            fit: BoxFit.cover,
            // 로딩 중 표시 (선택 사항)
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.grey[200],
              child: const Icon(Icons.broken_image, color: Colors.grey),
            ),
          )
              : Image.asset( // ★ 기존 로컬 에셋 이미지일 때
            imagePathOrUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.grey[200],
              child: const Icon(Icons.image, color: Colors.grey),
            ),
          ),
        ),
      ),
    );
  }

  // --- 앱바 & 기타 공통 위젯 ---
  Widget _buildCustomAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(onPressed: openDrawer, icon: SvgPicture.asset('assets/icons/ic_menu.svg', width: 24, height: 24)),
          const Text("Keeper's Note", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, fontFamily: 'SF Pro')),
          IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())), icon: SvgPicture.asset('assets/icons/ic_settings.svg', width: 24, height: 24)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 40,
        decoration: ShapeDecoration(color: const Color(0xFFFFFDFD), shape: RoundedRectangleBorder(side: const BorderSide(width: 1, color: Color(0x30FF7A65)), borderRadius: BorderRadius.circular(36)), shadows: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]),
        child: TextField(
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            isDense: true, border: InputBorder.none,
            prefixIcon: Padding(padding: const EdgeInsets.all(10.0), child: SvgPicture.asset('assets/icons/ic_search.svg', colorFilter: const ColorFilter.mode(Color(0xFF898989), BlendMode.srcIn))),
            hintText: '아이템을 검색해보세요.', hintStyle: const TextStyle(color: Color(0xFF898989), fontSize: 14, fontFamily: 'SF Pro'),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text(title, style: const TextStyle(color: Colors.black, fontSize: 16, fontFamily: 'SF Pro', fontWeight: FontWeight.w600, height: 1.0)));
  }
} // ★ 클래스의 마지막 닫는 괄호