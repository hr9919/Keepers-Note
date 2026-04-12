import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';

class WeatherAdminScreen extends StatefulWidget {
  const WeatherAdminScreen({super.key});

  @override
  State<WeatherAdminScreen> createState() => _WeatherAdminScreenState();
}

class _WeatherAdminScreenState extends State<WeatherAdminScreen> {
  static const String _baseUrl = 'http://161.33.30.40:8080';

  static const List<_WeatherOption> _weatherOptions = [
    _WeatherOption(label: '맑음', value: 'SUNNY'),
    _WeatherOption(label: '흐림', value: 'CLOUDY'),
    _WeatherOption(label: '비', value: 'RAINY'),
    _WeatherOption(label: '눈', value: 'SNOWY'),
    _WeatherOption(label: '무지개', value: 'RAINBOW'),
  ];

  bool _isLoading = true;
  bool _isSavingDaily = false;
  bool _isSavingWeekly = false;
  String? _error;
  int? _kakaoId;

  DateTime _selectedGameDate = DateTime.now();
  DateTime _selectedMonday = _resolveMonday(DateTime.now());

  String _daily06 = 'SUNNY';
  String _daily12 = 'SUNNY';
  String _daily18 = 'SUNNY';
  String _daily00 = 'SUNNY';
  String _dailyNext06 = 'SUNNY';

  String _weekMon = 'SUNNY';
  String _weekTue = 'SUNNY';
  String _weekWed = 'SUNNY';
  String _weekThu = 'SUNNY';
  String _weekFri = 'SUNNY';
  String _weekSat = 'SUNNY';
  String _weekSun = 'SUNNY';
  String _weekNextMon = 'SUNNY';

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

      await _loadKakaoId();
      await Future.wait([
        _loadDailyWeather(),
        _loadWeeklyWeather(),
      ]);
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

  Future<void> _loadKakaoId() async {
    final user = await UserApi.instance.me();
    _kakaoId = user.id?.toInt();
  }

  Future<void> _pickGameDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedGameDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      locale: const Locale('ko'),
    );

    if (picked == null) return;

    setState(() {
      _selectedGameDate = picked;
    });

    await _loadDailyWeather();
  }

  Future<void> _pickMondayDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonday,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      locale: const Locale('ko'),
    );

    if (picked == null) return;

    setState(() {
      _selectedMonday = _resolveMonday(picked);
    });

    await _loadWeeklyWeather();
  }

  Future<void> _loadDailyWeather() async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/api/admin/weather/daily?gameDate=${_formatDate(_selectedGameDate)}',
      );

      final response = await http.get(
        uri,
        headers: _adminHeaders(withJson: false),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (!mounted) return;
        setState(() {
          _daily06 = (data['weather06'] ?? 'SUNNY').toString();
          _daily12 = (data['weather12'] ?? 'SUNNY').toString();
          _daily18 = (data['weather18'] ?? 'SUNNY').toString();
          _daily00 = (data['weather00'] ?? 'SUNNY').toString();
          _dailyNext06 = (data['nextDay06'] ?? 'SUNNY').toString();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadWeeklyWeather() async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/api/admin/weather/weekly?mondayDate=${_formatDate(_selectedMonday)}',
      );

      final response = await http.get(
        uri,
        headers: _adminHeaders(withJson: false),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (!mounted) return;
        setState(() {
          _weekMon = (data['monday'] ?? 'SUNNY').toString();
          _weekTue = (data['tuesday'] ?? 'SUNNY').toString();
          _weekWed = (data['wednesday'] ?? 'SUNNY').toString();
          _weekThu = (data['thursday'] ?? 'SUNNY').toString();
          _weekFri = (data['friday'] ?? 'SUNNY').toString();
          _weekSat = (data['saturday'] ?? 'SUNNY').toString();
          _weekSun = (data['sunday'] ?? 'SUNNY').toString();
          _weekNextMon = (data['nextMonday'] ?? 'SUNNY').toString();
        });
      }
    } catch (_) {}
  }

  Future<void> _saveDailyWeather() async {
    if (_kakaoId == null) {
      _showSnack('카카오 ID를 불러오지 못했어요.');
      return;
    }

    try {
      setState(() => _isSavingDaily = true);

      final response = await http.post(
        Uri.parse('$_baseUrl/api/admin/weather/daily'),
        headers: _adminHeaders(),
        body: jsonEncode({
          'gameDate': _formatDate(_selectedGameDate),
          'weather06': _daily06,
          'weather12': _daily12,
          'weather18': _daily18,
          'weather00': _daily00,
          'nextDay06': _dailyNext06,
        }),
      );

      if (response.statusCode == 200) {
        _showSnack('일별 날씨 저장 완료');
        return;
      }

      _showSnack('저장 실패: ${utf8.decode(response.bodyBytes)}');
    } catch (e) {
      _showSnack('저장 실패: $e');
    } finally {
      if (!mounted) return;
      setState(() => _isSavingDaily = false);
    }
  }

  Future<void> _saveWeeklyWeather() async {
    if (_kakaoId == null) {
      _showSnack('카카오 ID를 불러오지 못했어요.');
      return;
    }

    try {
      setState(() => _isSavingWeekly = true);

      final response = await http.post(
        Uri.parse('$_baseUrl/api/admin/weather/weekly'),
        headers: _adminHeaders(),
        body: jsonEncode({
          'mondayDate': _formatDate(_selectedMonday),
          'monday': _weekMon,
          'tuesday': _weekTue,
          'wednesday': _weekWed,
          'thursday': _weekThu,
          'friday': _weekFri,
          'saturday': _weekSat,
          'sunday': _weekSun,
          'nextMonday': _weekNextMon,
        }),
      );

      if (response.statusCode == 200) {
        _showSnack('주간 날씨 저장 완료');
        return;
      }

      _showSnack('저장 실패: ${utf8.decode(response.bodyBytes)}');
    } catch (e) {
      _showSnack('저장 실패: $e');
    } finally {
      if (!mounted) return;
      setState(() => _isSavingWeekly = false);
    }
  }

  Map<String, String> _adminHeaders({bool withJson = true}) {
    return {
      if (withJson) 'Content-Type': 'application/json',
      if (_kakaoId != null) 'X-KAKAO-ID': _kakaoId.toString(),
    };
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  static DateTime _resolveMonday(DateTime date) {
    final weekday = date.weekday;
    return DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: weekday - DateTime.monday));
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _displayDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  Widget _buildWeatherDropdown({
    required String title,
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFE2DB),
        ),
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
                    (e) => DropdownMenuItem<String>(
                  value: e.value,
                  child: Text(e.label),
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

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Widget child,
    required VoidCallback onSave,
    required bool isSaving,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFFE2DB),
        ),
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
          const SizedBox(height: 16),
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
                  : const Text(
                '저장',
                style: TextStyle(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      onPressed: () => Navigator.pop(context),
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
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
                  : RefreshIndicator(
                onRefresh: _init,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    _buildSectionCard(
                      title: '일별 시간대 날씨',
                      subtitle: '06시 / 12시 / 18시 / 00시 / 다음 06시',
                      onSave: _saveDailyWeather,
                      isSaving: _isSavingDaily,
                      child: Column(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: _pickGameDate,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF8F5),
                                borderRadius:
                                BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFFFE0D8),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_month_rounded,
                                    color: Color(0xFFFF8E7C),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '게임 날짜 ${_displayDate(_selectedGameDate)}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildWeatherDropdown(
                            title: '06시',
                            value: _daily06,
                            onChanged: (v) =>
                                setState(() => _daily06 = v!),
                          ),
                          const SizedBox(height: 10),
                          _buildWeatherDropdown(
                            title: '12시',
                            value: _daily12,
                            onChanged: (v) =>
                                setState(() => _daily12 = v!),
                          ),
                          const SizedBox(height: 10),
                          _buildWeatherDropdown(
                            title: '18시',
                            value: _daily18,
                            onChanged: (v) =>
                                setState(() => _daily18 = v!),
                          ),
                          const SizedBox(height: 10),
                          _buildWeatherDropdown(
                            title: '00시',
                            value: _daily00,
                            onChanged: (v) =>
                                setState(() => _daily00 = v!),
                          ),
                          const SizedBox(height: 10),
                          _buildWeatherDropdown(
                            title: '다음날 06시',
                            value: _dailyNext06,
                            onChanged: (v) =>
                                setState(() => _dailyNext06 = v!),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildSectionCard(
                      title: '주간 날씨',
                      subtitle: '월요일 기준 월~일 + 다음주 월요일',
                      onSave: _saveWeeklyWeather,
                      isSaving: _isSavingWeekly,
                      child: Column(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: _pickMondayDate,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF8F5),
                                borderRadius:
                                BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFFFE0D8),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.date_range_rounded,
                                    color: Color(0xFFFF8E7C),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '기준 월요일 ${_displayDate(_selectedMonday)}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildWeatherDropdown(
                            title: '월요일',
                            value: _weekMon,
                            onChanged: (v) =>
                                setState(() => _weekMon = v!),
                          ),
                          const SizedBox(height: 10),
                          _buildWeatherDropdown(
                            title: '화요일',
                            value: _weekTue,
                            onChanged: (v) =>
                                setState(() => _weekTue = v!),
                          ),
                          const SizedBox(height: 10),
                          _buildWeatherDropdown(
                            title: '수요일',
                            value: _weekWed,
                            onChanged: (v) =>
                                setState(() => _weekWed = v!),
                          ),
                          const SizedBox(height: 10),
                          _buildWeatherDropdown(
                            title: '목요일',
                            value: _weekThu,
                            onChanged: (v) =>
                                setState(() => _weekThu = v!),
                          ),
                          const SizedBox(height: 10),
                          _buildWeatherDropdown(
                            title: '금요일',
                            value: _weekFri,
                            onChanged: (v) =>
                                setState(() => _weekFri = v!),
                          ),
                          const SizedBox(height: 10),
                          _buildWeatherDropdown(
                            title: '토요일',
                            value: _weekSat,
                            onChanged: (v) =>
                                setState(() => _weekSat = v!),
                          ),
                          const SizedBox(height: 10),
                          _buildWeatherDropdown(
                            title: '일요일',
                            value: _weekSun,
                            onChanged: (v) =>
                                setState(() => _weekSun = v!),
                          ),
                          const SizedBox(height: 10),
                          _buildWeatherDropdown(
                            title: '다음주 월요일',
                            value: _weekNextMon,
                            onChanged: (v) =>
                                setState(() => _weekNextMon = v!),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeatherOption {
  final String label;
  final String value;

  const _WeatherOption({
    required this.label,
    required this.value,
  });
}