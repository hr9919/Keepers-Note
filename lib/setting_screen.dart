import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 스위치 상태 관리 변수
  bool _isPushEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 내 정보 섹션
              _buildSectionTitle('내 정보'),
              _buildInfoCard(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 6),
                      child: Row(
                        children: [
                          const Text(
                            'UID: 0000000',
                            style: TextStyle(color: Color(0xFF636363), fontSize: 16, fontWeight: FontWeight.w500, fontFamily: 'SF Pro'),
                          ),
                          const Spacer(),
                          _buildActionIcon('assets/icons/ic_copy.png'),
                          const SizedBox(width: 8),
                          _buildActionIcon('assets/icons/ic_edit.png'),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFEEEEEE), indent: 20, endIndent: 20),

                    _buildRowItem(
                      label: '푸시 알림 받기',
                      trailing: _buildCustomSwitch(_isPushEnabled),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 2. 공식 커뮤니티 링크 섹션
              _buildSectionTitle('공식 커뮤니티 링크'),
              _buildInfoCard(
                child: Column(
                  children: [
                    // 네이버 카페 아이콘 반영
                    _buildLinkItem(
                      '두근두근 타운 네이버 공식 카페',
                      'assets/icons/ic_naver_cafe.png', // 수정된 파일명
                    ),
                    const Divider(height: 1, color: Color(0xFFEEEEEE), indent: 20, endIndent: 20),

                    // 유튜브 아이콘 반영
                    _buildLinkItem(
                      '두근두근 타운 한국 공식 유튜브',
                      'assets/icons/ic_youtube.png', // 수정된 파일명
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 3. 이용 안내 섹션
              _buildSectionTitle('이용 안내'),
              _buildInfoCard(
                child: Column(
                  children: [
                    _buildRowItem(label: '앱 버전', trailingText: '1.0.0'),
                    const Divider(height: 1, color: Color(0xFFEEEEEE), indent: 20, endIndent: 20),

                    // --- ★ [복구] 메일 아이콘 + 메일 주소 + 화살표 배치 ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          const Text(
                            '버그 리포트',
                            style: TextStyle(
                                color: Color(0xFF636363),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'SF Pro'
                            ),
                          ),
                          const Spacer(),
                          // 사라졌던 메일 아이콘 복구!
                          Image.asset(
                              'assets/icons/ic_mail_send.png',
                              width: 18,
                              height: 18,
                          ),
                          const SizedBox(width: 6),
                          // 메일 주소
                          const Text(
                            'mintblue1078@gmail.com',
                            style: TextStyle(
                                color: Color(0xFFA4A4A4),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'SF Pro'
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 오른쪽 화살표
                          const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFFA4A4A4)),
                        ],
                      ),
                    ),

                    const Divider(height: 1, color: Color(0xFFEEEEEE), indent: 20, endIndent: 20),
                    _buildRowItem(label: '저작권 안내', isTitleOnly: true),

                    const SizedBox(height: 6),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        '''키퍼노트는 XD와 공식적인 관계가 없는
팬 메이드 비영리 가이드 앱이며, 게임사의 지적 재산권을 존중합니다.

본 앱에 사용된 모든 게임 이미지, 데이터 등의 저작권은
모두 XD Interactive Entertainment Co., Ltd.에 있습니다.

사용된 이미지 및 데이터는 오직 유저 가이드 목적으로만 사용되며,
상업적으로 이용되지 않습니다.''',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFF8C8C8C),
                          fontSize: 10,
                          fontFamily: 'SF Pro',
                          fontWeight: FontWeight.w400,
                          height: 1.60,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  // --- 헬퍼 위젯: 섹션 타이틀 ---
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black, fontFamily: 'SF Pro')),
    );
  }

  // --- 헬퍼 위젯: 카드 배경 ---
  Widget _buildInfoCard({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: ShapeDecoration(
        color: Colors.white.withOpacity(0.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        shadows: const [
          BoxShadow(color: Color(0x0C000000), blurRadius: 4, offset: Offset(4, 4))
        ],
      ),
      child: child,
    );
  }

  // --- 배경 포함된 PNG 아이콘용 함수 ---
  Widget _buildActionIcon(String iconPath) {
    return SizedBox(
      width: 50,
      height: 50,
      child: Image.asset(iconPath, fit: BoxFit.contain),
    );
  }

  // --- [수정 완료] 에러를 일으킨 파라미터를 추가했습니다! ---
  Widget _buildRowItem({
    required String label,
    String? trailingText,
    Widget? trailing,
    bool isTitleOnly = false, // ★ 여기에 추가!
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF636363), fontSize: 16, fontWeight: FontWeight.w500, fontFamily: 'SF Pro')),
          const Spacer(),
          if (!isTitleOnly && trailingText != null)
            Text(trailingText, style: const TextStyle(color: Color(0xFFA4A4A4), fontSize: 16, fontWeight: FontWeight.w500, fontFamily: 'SF Pro')),
          if (!isTitleOnly && trailing != null) trailing,
        ],
      ),
    );
  }

  // --- 헬퍼 위젯: 커뮤니티 링크 항목 ---
  // --- 헬퍼 위젯: 커뮤니티 링크 항목 (아이콘 잘림 방지 버전) ---
  // --- 헬퍼 위젯: 커뮤니티 링크 항목 (이미지 원본 비율 유지) ---
  Widget _buildLinkItem(String title, String imagePath) {
    return Padding(
      // 카드 테두리에 붙지 않게 전체 마진 유지
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // ★ 기존에 잡아둔 50x40 틀은 유지합니다.
          SizedBox(
            width: 50,
            height: 40,
            child: Image.asset(
              imagePath,
              fit: BoxFit.contain, // ★ 중요: 틀 안에서 원본 비율 유지 (잘림 방지)
              errorBuilder: (c, e, s) => const Icon(Icons.link, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 12), // 이미지와 텍스트 사이 간격
          Expanded(
            child: Text(
                title,
                style: const TextStyle(
                    color: Color(0xFF636363),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'SF Pro'
                )
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFFA4A4A4)),
        ],
      ),
    );
  }

  // --- 실제로 작동하는 커스텀 스위치 ---
  Widget _buildCustomSwitch(bool isActive) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isPushEnabled = !_isPushEnabled;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 53, height: 30,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFFF8E7C).withOpacity(0.56) : const Color(0xFFD9D9D9),
          borderRadius: BorderRadius.circular(99),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: isActive ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.5),
            child: Container(
              width: 25, height: 25,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 2))],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- 앱바 ---
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20), onPressed: () => Navigator.pop(context)),
      title: const Text('설정', style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'SF Pro')),
      centerTitle: true,
      bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Divider(height: 1, color: Colors.black.withOpacity(0.16))),
    );
  }
}