import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:home_widget/home_widget.dart';
import 'services/home_widget_service.dart';

class WeatherAdminScreen extends StatefulWidget {
  const WeatherAdminScreen({super.key});

  @override
  State<WeatherAdminScreen> createState() => _WeatherAdminScreenState();
}

class _WeatherAdminScreenState extends State<WeatherAdminScreen> {
  static const String _baseUrl = 'https://api.keepers-note.o-r.kr';

  static const List<_WeatherOption> _weatherOptions = [
    _WeatherOption(label: '맑음', value: 'SUNNY', icon: Icons.wb_sunny_rounded),
    _WeatherOption(label: '흐림', value: 'CLOUDY', icon: Icons.cloud_rounded),
    _WeatherOption(label: '비', value: 'RAINY', icon: Icons.grain_rounded),
    _WeatherOption(label: '눈', value: 'SNOWY', icon: Icons.ac_unit_rounded),
    _WeatherOption(
        label: '무지개', value: 'RAINBOW', icon: Icons.auto_awesome_rounded),
  ];

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isSavingHourly = false;
  bool _isSavingDaily = false;
  bool _isUpdatingHourly = false;
  bool _isUpdatingDaily = false;
  bool _hasWeatherChanged = false;

  final Map<String, String> _editedHourlyWeather = {};
  final Map<String, String> _editedDailyWeather = {};

  String? _error;
  String? _serverUserId;

  List<dynamic> _hourlyItems = [];
  List<dynamic> _dailyItems = [];

  String? _nextHourlyTime;
  String? _nextDailyDate;

  String _selectedHourlyWeather = 'SUNNY';
  String _selectedDailyWeather = 'SUNNY';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      await _loadUserId(); // ✅ 변경
      await _refreshAll(showLoading: false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '날씨 데이터를 불러오지 못했어요.\n$e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshAll({bool showLoading = true}) async {
    if (_serverUserId == null || _serverUserId!.isEmpty) {
      debugPrint('❌ userId 없음 → 요청 차단');
      return;
    }
    
    try {
      if (showLoading && mounted) {
        setState(() {
          _isRefreshing = true;
        });
      }

      await Future.wait([
        _loadHourlyWeather(),
        _loadNextHourlySlot(),
        _loadDailyForecast(),
        _loadNextDailyDate(),
      ]);
    } finally {
      if (!mounted) return;
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  Future<void> _loadUserId() async {
    final user = await UserApi.instance.me();

    final response = await http.post(
      Uri.parse('$_baseUrl/api/user/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'provider': 'KAKAO',
        'providerUserId': user.id.toString(),
        'nickname': user.kakaoAccount?.profile?.nickname ?? '타운키퍼',
        'profileImageUrl': user.kakaoAccount?.profile?.profileImageUrl,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('userId 조회 실패');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));

    if (!mounted) return;

    setState(() {
      _serverUserId = data['id']?.toString();
    });
  }

  Future<void> _loadHourlyWeather() async {
    final uri = Uri.parse('$_baseUrl/api/admin/weather/hourly/current');

    final response = await http.get(
      uri,
      headers: _adminHeaders(withJson: false),
    );

    if (response.statusCode != 200) {
      throw Exception('시간대별 날씨 조회 실패: ${utf8.decode(response.bodyBytes)}');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) {
      throw Exception('시간대별 날씨 응답 형식이 올바르지 않아요.');
    }

    if (!mounted) return;
    setState(() {
      _hourlyItems = decoded;
    });
  }

  Future<void> _loadNextHourlySlot() async {
    final uri = Uri.parse('$_baseUrl/api/admin/weather/hourly/next-slot');

    final response = await http.get(
      uri,
      headers: _adminHeaders(withJson: false),
    );

    if (response.statusCode != 200) {
      throw Exception('다음 시간 슬롯 조회 실패: ${utf8.decode(response.bodyBytes)}');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (!mounted) return;
    setState(() {
      _nextHourlyTime = decoded['forecastTime']?.toString();
    });
  }

  Future<void> _loadDailyForecast() async {
    final uri = Uri.parse('$_baseUrl/api/admin/weather/daily/current');

    final response = await http.get(
      uri,
      headers: _adminHeaders(withJson: false),
    );

    if (response.statusCode != 200) {
      throw Exception('일별 날씨 조회 실패: ${utf8.decode(response.bodyBytes)}');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) {
      throw Exception('일별 날씨 응답 형식이 올바르지 않아요.');
    }

    if (!mounted) return;
    setState(() {
      _dailyItems = decoded;
    });
  }

  Future<void> _loadNextDailyDate() async {
    final uri = Uri.parse('$_baseUrl/api/admin/weather/daily/next-date');

    final response = await http.get(
      uri,
      headers: _adminHeaders(withJson: false),
    );

    if (response.statusCode != 200) {
      throw Exception('다음 날짜 조회 실패: ${utf8.decode(response.bodyBytes)}');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (!mounted) return;
    setState(() {
      _nextDailyDate = decoded['forecastDate']?.toString();
    });
  }

  Future<void> _saveHourlyWeather() async {
    if (_serverUserId == null || _serverUserId!.isEmpty) {
      _showSnack('ID를 불러오지 못했어요.');
      return;
    }
    if (_nextHourlyTime == null || _nextHourlyTime!.isEmpty) {
      _showSnack('다음 추가 가능 시간 정보를 불러오지 못했어요.');
      return;
    }

    try {
      setState(() {
        _isSavingHourly = true;
      });

      final response = await http.post(
        Uri.parse('$_baseUrl/api/admin/weather/hourly/append'),
        headers: _adminHeaders(),
        body: jsonEncode({
          'weatherType': _selectedHourlyWeather,
        }),
      );

      if (response.statusCode == 200) {
        _hasWeatherChanged = true;
        await _pushCurrentWeatherToWidget(_selectedHourlyWeather);
        _showSnack('시간대별 날씨가 추가됐어요.');
        await _refreshAll(showLoading: false);
      } else {
        _showSnack('저장 실패: ${utf8.decode(response.bodyBytes)}');
      }
    } catch (e) {
      _showSnack('저장 실패: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isSavingHourly = false;
      });
    }
  }

  Future<void> _saveDailyForecast() async {
    if (_serverUserId == null || _serverUserId!.isEmpty) {
      _showSnack('ID를 불러오지 못했어요.');
      return;
    }
    if (_nextDailyDate == null || _nextDailyDate!.isEmpty) {
      _showSnack('다음 추가 가능 날짜 정보를 불러오지 못했어요.');
      return;
    }

    try {
      setState(() {
        _isSavingDaily = true;
      });

      final response = await http.post(
        Uri.parse('$_baseUrl/api/admin/weather/daily/append'),
        headers: _adminHeaders(),
        body: jsonEncode({
          'weatherType': _selectedDailyWeather,
        }),
      );

      if (response.statusCode == 200) {
        _hasWeatherChanged = true;
        _showSnack('일별 날씨가 추가됐어요.');
        await _refreshAll(showLoading: false);
      } else {
        _showSnack('저장 실패: ${utf8.decode(response.bodyBytes)}');
      }
    } catch (e) {
      _showSnack('저장 실패: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isSavingDaily = false;
      });
    }
  }

  Future<void> _updateHourlyWeather({
    required String forecastTime,
    required String weatherType,
  }) async {
    if (_serverUserId == null || _serverUserId!.isEmpty) {
      _showSnack('ID를 불러오지 못했어요.');
      return;
    }

    try {
      setState(() {
        _isUpdatingHourly = true;
      });

      final response = await http.post(
        Uri.parse('$_baseUrl/api/admin/weather/hourly/update'),
        headers: _adminHeaders(),
        body: jsonEncode({
          'forecastTime': forecastTime,
          'weatherType': weatherType,
        }),
      );

      if (response.statusCode == 200) {
        _hasWeatherChanged = true;
        await _pushCurrentWeatherToWidget(weatherType);
        _showSnack('시간대별 날씨를 수정했어요.');
        await _refreshAll(showLoading: false);
      } else {
        _showSnack('수정 실패: ${utf8.decode(response.bodyBytes)}');
      }
    } catch (e) {
      _showSnack('수정 실패: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isUpdatingHourly = false;
      });
    }
  }

  Future<void> _updateDailyWeather({
    required String forecastDate,
    required String weatherType,
  }) async {
    if (_serverUserId == null || _serverUserId!.isEmpty) {
      _showSnack('ID를 불러오지 못했어요.');
      return;
    }

    try {
      setState(() {
        _isUpdatingDaily = true;
      });

      final response = await http.post(
        Uri.parse('$_baseUrl/api/admin/weather/daily/update'),
        headers: _adminHeaders(),
        body: jsonEncode({
          'forecastDate': forecastDate,
          'weatherType': weatherType,
        }),
      );

      if (response.statusCode == 200) {
        _hasWeatherChanged = true;
        _showSnack('일별 날씨를 수정했어요.');
        await _refreshAll(showLoading: false);
      } else {
        _showSnack('수정 실패: ${utf8.decode(response.bodyBytes)}');
      }
    } catch (e) {
      _showSnack('수정 실패: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isUpdatingDaily = false;
      });
    }
  }

  Map<String, String> _adminHeaders({bool withJson = true}) {
    return {
      if (withJson) 'Content-Type': 'application/json',
      if (_serverUserId != null && _serverUserId!.isNotEmpty)
        'X-USER-ID': _serverUserId!,
    };
  }

  void _showSnack(String text) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 110),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatDateDisplay(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day
        .toString().padLeft(2, '0')}';
  }

  String _formatTimeSlotDisplay(String isoString) {
    try {
      final date = DateTime.parse(isoString).toLocal();
      return '${_formatDateDisplay(date)} ${date.hour.toString().padLeft(
          2, '0')}:00';
    } catch (_) {
      return isoString;
    }
  }

  String _formatDateOnlyDisplay(String isoString) {
    try {
      final date = DateTime.parse('$isoString 00:00:00');
      return _formatDateDisplay(date);
    } catch (_) {
      return isoString;
    }
  }

  String _dayOfWeekKoFromDate(String isoString) {
    try {
      final date = DateTime.parse('$isoString 00:00:00');
      switch (date.weekday) {
        case DateTime.monday:
          return '월';
        case DateTime.tuesday:
          return '화';
        case DateTime.wednesday:
          return '수';
        case DateTime.thursday:
          return '목';
        case DateTime.friday:
          return '금';
        case DateTime.saturday:
          return '토';
        case DateTime.sunday:
          return '일';
        default:
          return '';
      }
    } catch (_) {
      return '';
    }
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFE2DB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF2D3436),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF7B8794),
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildWeatherDropdown({
    required String title,
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE2DB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              borderRadius: BorderRadius.circular(16),
              items: _weatherOptions
                  .map(
                    (e) =>
                    DropdownMenuItem<String>(
                      value: e.value,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            e.icon,
                            size: 18,
                            color: const Color(0xFFFF8E7C),
                          ),
                          const SizedBox(width: 8),
                          Text(e.label),
                        ],
                      ),
                    ),
              )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableItemRow({
    required String leading,
    required String value,
    required ValueChanged<String?>? onChanged,
    required VoidCallback? onApply,
    required bool isApplying,
    required bool isDirty,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE6DF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            leading,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: value,
                  isExpanded: true,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFFFE2DB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDirty
                            ? const Color(0xFFFFB4A6)
                            : const Color(0xFFFFE2DB),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFFFF8E7C),
                        width: 1.4,
                      ),
                    ),
                  ),
                  items: _weatherOptions.map((option) {
                    return DropdownMenuItem<String>(
                      value: option.value,
                      child: Row(
                        children: [
                          Icon(
                            option.icon,
                            size: 16,
                            color: const Color(0xFFFF8E7C),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              option.label,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 84,
                height: 46,
                child: ElevatedButton(
                  onPressed: (onApply != null && !isApplying && isDirty)
                      ? onApply
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8E7C),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFF3F4F6),
                    disabledForegroundColor: const Color(0xFF9CA3AF),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: isApplying
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    '수정',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _normalizeWidgetWeather(String raw) {
    switch (raw) {
      case 'SUNNY':
      case 'CLEAR':
      case '맑음':
        return '맑음';
      case 'CLOUDY':
      case 'OVERCAST':
      case '흐림':
        return '흐림';
      case 'RAIN':
      case 'RAINY':
      case '비':
        return '비';
      case 'SNOW':
      case 'SNOWY':
      case '눈':
        return '눈';
      case 'RAINBOW':
      case '무지개':
        return '무지개';
      default:
        return raw;
    }
  }

  Future<void> _pushCurrentWeatherToWidget(String weatherType) async {
    final normalized = _normalizeWidgetWeather(weatherType);

    await HomeWidget.saveWidgetData<String>('weather', normalized);
    await HomeWidget.updateWidget(
      androidName: 'TodayInfoWidgetProvider',
    );
  }

  Widget _buildAddBox({
    required String title,
    required String targetText,
    required String selectedValue,
    required ValueChanged<String?> onChanged,
    required VoidCallback onSave,
    required bool isSaving,
    required String buttonText,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFDFD7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFFFF8E7C),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            targetText,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2D3436),
            ),
          ),
          const SizedBox(height: 12),
          _buildWeatherDropdown(
            title: '날씨 선택',
            value: selectedValue,
            onChanged: onChanged,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isSaving ? null : onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8E7C),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: isSaving
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : Text(
                buttonText,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlySection() {
    return _buildSectionCard(
      title: '시간대별 날씨',
      subtitle: '6시간 단위 · 현재부터 5구간 표시 · 기존 항목 수정 가능',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '현재 표시 중',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF3C4856),
                ),
              ),
              if (_isUpdatingHourly) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          if (_hourlyItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '표시할 시간대별 날씨가 없어요.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF7B8794),
                ),
              ),
            )
          else
            ..._hourlyItems.map((item) {
              final forecastTime = item['forecastTime']?.toString() ?? '';
              final originalWeatherType =
                  item['weatherType']?.toString() ?? 'SUNNY';
              final currentValue =
                  _editedHourlyWeather[forecastTime] ?? originalWeatherType;
              final isDirty = currentValue != originalWeatherType;

              return _buildEditableItemRow(
                leading: _formatTimeSlotDisplay(forecastTime),
                value: currentValue,
                isApplying: _isUpdatingHourly,
                isDirty: isDirty,
                onChanged: _isUpdatingHourly
                    ? null
                    : (v) {
                  if (v == null) return;
                  setState(() {
                    _editedHourlyWeather[forecastTime] = v;
                  });
                },
                onApply: () async {
                  if (!isDirty) return;

                  await _updateHourlyWeather(
                    forecastTime: forecastTime,
                    weatherType: currentValue,
                  );

                  if (!mounted) return;
                  setState(() {
                    _editedHourlyWeather.remove(forecastTime);
                  });
                },
              );
            }),
          const SizedBox(height: 8),
          _buildAddBox(
            title: '다음 추가 가능',
            targetText: _nextHourlyTime == null
                ? '불러오는 중...'
                : _formatTimeSlotDisplay(_nextHourlyTime!),
            selectedValue: _selectedHourlyWeather,
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _selectedHourlyWeather = v;
              });
            },
            onSave: _saveHourlyWeather,
            isSaving: _isSavingHourly,
            buttonText: '시간대 추가',
          ),
        ],
      ),
    );
  }

  Widget _buildDailySection() {
    return _buildSectionCard(
      title: '8일 예보',
      subtitle: '게임 날짜 기준 · 현재부터 8일 표시 · 기존 항목 수정 가능',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '현재 표시 중',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF3C4856),
                ),
              ),
              if (_isUpdatingDaily) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          if (_dailyItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '표시할 일별 예보가 없어요.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF7B8794),
                ),
              ),
            )
          else
            ..._dailyItems.map((item) {
              final forecastDate = item['forecastDate']?.toString() ?? '';
              final originalWeatherType =
                  item['weatherType']?.toString() ?? 'SUNNY';
              final dayOfWeek = _dayOfWeekKoFromDate(forecastDate);
              final currentValue =
                  _editedDailyWeather[forecastDate] ?? originalWeatherType;
              final isDirty = currentValue != originalWeatherType;

              return _buildEditableItemRow(
                leading: '$dayOfWeek · ${_formatDateOnlyDisplay(forecastDate)}',
                value: currentValue,
                isApplying: _isUpdatingDaily,
                isDirty: isDirty,
                onChanged: _isUpdatingDaily
                    ? null
                    : (v) {
                  if (v == null) return;
                  setState(() {
                    _editedDailyWeather[forecastDate] = v;
                  });
                },
                onApply: () async {
                  if (!isDirty) return;

                  await _updateDailyWeather(
                    forecastDate: forecastDate,
                    weatherType: currentValue,
                  );

                  if (!mounted) return;
                  setState(() {
                    _editedDailyWeather.remove(forecastDate);
                  });
                },
              );
            }),
          const SizedBox(height: 8),
          _buildAddBox(
            title: '다음 추가 가능',
            targetText: _nextDailyDate == null
                ? '불러오는 중...'
                : '${_dayOfWeekKoFromDate(
                _nextDailyDate!)} · ${_formatDateOnlyDisplay(_nextDailyDate!)}',
            selectedValue: _selectedDailyWeather,
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _selectedDailyWeather = v;
              });
            },
            onSave: _saveDailyForecast,
            isSaving: _isSavingDaily,
            buttonText: '일별 추가',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _hasWeatherChanged);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFBF8),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () =>
                            Navigator.pop(context, _hasWeatherChanged),
                        icon: const Icon(Icons.arrow_back_ios_new),
                      ),
                    ),
                    const Text(
                      '날씨 관리',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: _isRefreshing ? null : () => _refreshAll(),
                        icon: _isRefreshing
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                            : const Icon(Icons.refresh_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(
                  child: CircularProgressIndicator(),
                )
                    : _error != null
                    ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ),
                )
                    : RefreshIndicator(
                  onRefresh: _refreshAll,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF5F1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFFFE3DC),
                          ),
                        ),
                        child: const Text(
                          '현재 보여주는 예보는 바로 수정할 수 있고, 맨 뒤에 들어갈 다음 1칸도 추가할 수 있어요.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF7B8794),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _buildHourlySection(),
                      const SizedBox(height: 18),
                      _buildDailySection(),
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
}

class _WeatherOption {
  final String label;
  final String value;
  final IconData icon;

  const _WeatherOption({
    required this.label,
    required this.value,
    required this.icon,
  });
}
