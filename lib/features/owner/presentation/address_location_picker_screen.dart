import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gmm_amap_flutter_base/gmm_amap_flutter_base.dart';
import 'package:gmm_amap_flutter_map/gmm_amap_flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:pets/core/config/amap_config.dart';

class AddressLocationPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;

  const AddressLocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<AddressLocationPickerScreen> createState() =>
      _AddressLocationPickerScreenState();
}

class _AddressLocationPickerScreenState
    extends State<AddressLocationPickerScreen> {
  static const _amapApiKey = AMapApiKey(androidKey: AmapConfig.androidKey);
  static const _defaultCenter = LatLng(39.909187, 116.397451);
  static const _restKey = AmapConfig.restKey;

  AMapController? _mapController;
  LatLng? _selected;
  bool _isResolving = false;
  bool _isLocating = false;
  bool _isMoving = false;
  String? _errorMessage;
  _ResolvedAddress? _resolvedAddress;

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selected = LatLng(widget.initialLatitude!, widget.initialLongitude!);
      _resolveAddress(_selected!);
    }
  }

  /// 校验定位服务与权限，OK 返回 true（失败时给出提示并复位 loading）。
  Future<bool> _ensureLocationReady() async {
    bool serviceEnabled;
    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return false;
    }
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('请先开启设备定位服务')));
      }
      return false;
    }

    LocationPermission permission;
    try {
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
    } catch (_) {
      return false;
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('定位权限未授权，请在设置中开启')));
      }
      return false;
    }
    return true;
  }

  /// 把 WGS-84 坐标转成高德 GCJ-02 后移动相机到该位置。
  Future<void> _moveCameraToWgs(double wgsLat, double wgsLng) async {
    final (gcjLat, gcjLng) = _wgs84ToGcj02(wgsLat, wgsLng);
    await _mapController?.moveCamera(
      CameraUpdate.newLatLngZoom(LatLng(gcjLat, gcjLng), 16),
      animated: true,
    );
  }

  Future<void> _locateMe() async {
    setState(() => _isLocating = true);

    if (!await _ensureLocationReady()) {
      if (mounted) setState(() => _isLocating = false);
      return;
    }

    // 1) 先用系统缓存的“最近一次定位”立即移动相机，做到秒开。
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && mounted) {
        await _moveCameraToWgs(last.latitude, last.longitude);
      }
    } catch (_) {
      // 没有缓存就忽略，等下面的实时定位
    }

    // 2) 再用较低精度 + 较短超时快速获取实时位置并刷新（精度足够选址用）。
    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } on TimeoutException {
      // 超时就维持缓存位置，不再阻塞
    } catch (_) {
      // 忽略，维持当前相机位置
    }

    if (!mounted) {
      return;
    }
    setState(() => _isLocating = false);

    if (pos != null) {
      // 实时位置与缓存位置不同则刷新；相机停止后 onCameraMoveEnd 自动反查地址。
      await _moveCameraToWgs(pos.latitude, pos.longitude);
    }
  }

  /// WGS-84 → GCJ-02 近似转换（与编辑档案页 GCJ-02→WGS-84 互为逆操作）。
  static (double lat, double lng) _wgs84ToGcj02(double wgsLat, double wgsLng) {
    const a = 6378245.0;
    const ee = 0.00669342162296594323;

    double transformLat(double x, double y) {
      var ret =
          -100.0 +
          2.0 * x +
          3.0 * y +
          0.2 * y * y +
          0.1 * x * y +
          0.2 * sqrt(x.abs());
      ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0;
      ret += (20.0 * sin(y * pi) + 40.0 * sin(y / 3.0 * pi)) * 2.0 / 3.0;
      ret +=
          (160.0 * sin(y / 12.0 * pi) + 320.0 * sin(y * pi / 30.0)) * 2.0 / 3.0;
      return ret;
    }

    double transformLng(double x, double y) {
      var ret =
          300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(x.abs());
      ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0;
      ret += (20.0 * sin(x * pi) + 40.0 * sin(x / 3.0 * pi)) * 2.0 / 3.0;
      ret +=
          (150.0 * sin(x / 12.0 * pi) + 300.0 * sin(x / 30.0 * pi)) * 2.0 / 3.0;
      return ret;
    }

    final dLat = transformLat(wgsLng - 105.0, wgsLat - 35.0);
    final dLng = transformLng(wgsLng - 105.0, wgsLat - 35.0);
    final radLat = wgsLat / 180.0 * pi;
    final magic = sin(radLat);
    final sqrtMagic = sqrt(1 - ee * magic * magic);
    final finalDLat =
        (dLat * 180.0) /
        ((a * (1 - ee)) / (sqrtMagic * sqrtMagic * sqrtMagic) * pi);
    final finalDLng = (dLng * 180.0) / (a / sqrtMagic * cos(radLat) * pi);
    // WGS-84 → GCJ-02：加偏移（与 GCJ-02→WGS-84 的减偏移相反）
    return (wgsLat + finalDLat, wgsLng + finalDLng);
  }

  Future<void> _resolveAddress(LatLng position) async {
    setState(() {
      _isResolving = true;
      _errorMessage = null;
    });

    try {
      final uri = Uri.https('restapi.amap.com', '/v3/geocode/regeo', {
        'key': _restKey,
        'location': '${position.longitude},${position.latitude}',
        'extensions': 'base',
      });
      final response = await http.get(uri);
      if (!mounted) return;
      if (response.statusCode != 200) {
        setState(() {
          _errorMessage = '地址解析失败';
          _isResolving = false;
        });
        return;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final regeocode = json['regeocode'] as Map<String, dynamic>?;
      final addressComponent =
          regeocode?['addressComponent'] as Map<String, dynamic>?;
      final formattedAddress = _asString(regeocode?['formatted_address']);
      final province = _asString(addressComponent?['province']);
      // 高德对直辖市等空值会返回空数组 [] 而非字符串，需归一化为 ''
      final city = _normalizeCity(
        province,
        _asString(addressComponent?['city']),
      );
      final district = _asString(addressComponent?['district']);
      final street = addressComponent?['streetNumber'] is Map
          ? _asString((addressComponent?['streetNumber'] as Map)['street'])
          : '';
      final township = _asString(addressComponent?['township']);
      final detail = _buildDetailAddress(
        formattedAddress,
        province,
        city,
        district,
        street,
        township,
      );

      setState(() {
        _resolvedAddress = _ResolvedAddress(
          province: province,
          city: city,
          district: district,
          detailAddress: detail,
        );
        _isResolving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '地址解析失败';
        _isResolving = false;
      });
    }
  }

  /// 高德 regeo 字段在为空时可能返回空数组 []（而非 ""），
  /// 这里统一归一化：List 一律按空字符串处理，避免渲染出 "[]"。
  static String _asString(dynamic value) {
    if (value == null) return '';
    if (value is List) return '';
    return value.toString();
  }

  static String _normalizeCity(String province, String city) {
    final normalizedProvince = province.trim();
    final normalizedCity = city.trim();
    if (normalizedCity.isNotEmpty) {
      return normalizedCity;
    }

    const municipalities = {'北京', '北京市', '上海', '上海市', '天津', '天津市', '重庆', '重庆市'};
    if (municipalities.contains(normalizedProvince)) {
      return normalizedProvince;
    }
    return normalizedCity;
  }

  String _buildDetailAddress(
    String formatted,
    String province,
    String city,
    String district,
    String street,
    String township,
  ) {
    final rest = formatted
        .replaceFirst(province, '')
        .replaceFirst(city, '')
        .replaceFirst(district, '')
        .replaceFirst(township, '');
    if (street.isNotEmpty) {
      return street + rest;
    }
    return rest.isNotEmpty ? rest : formatted;
  }

  @override
  Widget build(BuildContext context) {
    final center = _selected ?? _defaultCenter;

    return Scaffold(
      appBar: AppBar(title: const Text('选择地图位置'), centerTitle: true),
      // 地图 + 顶部信息卡片在 Stack 里，底部按钮在 Stack 之外
      // 这样地图区域完全不被 Flutter 层覆盖，PlatformView 触摸事件不受干扰
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                AMapWidget(
                  apiKey: _amapApiKey,
                  privacyStatement: const AMapPrivacyStatement(
                    hasContains: true,
                    hasShow: true,
                    hasAgree: true,
                  ),
                  initialCameraPosition: CameraPosition(
                    target: center,
                    zoom: 16,
                  ),
                  // 关闭 POI 点击拦截：否则点到 POI 会走 onPoiTouched 而不触发选点
                  touchPoiEnabled: false,
                  // 让地图立即赢得手势竞技场，消除拖动/缩放的触摸延迟
                  gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                    Factory<OneSequenceGestureRecognizer>(
                      () => EagerGestureRecognizer(),
                    ),
                  },
                  onMapCreated: (controller) {
                    _mapController = controller;
                    // 未传入初始坐标时，默认定位到用户当前位置
                    if (_selected == null) {
                      _locateMe();
                    }
                  },
                  // 中心大头针模式：拖动地图，针固定在屏幕中心，
                  // 相机停止后用中心点反查地址，彻底避开点击延迟。
                  onCameraMove: (_) {
                    if (!_isMoving) {
                      setState(() => _isMoving = true);
                    }
                  },
                  onCameraMoveEnd: (position) {
                    setState(() {
                      _selected = position.target;
                      _isMoving = false;
                    });
                    _resolveAddress(position.target);
                  },
                ),
                // 固定在地图中心的大头针，不拦截触摸（IgnorePointer）
                const Positioned.fill(
                  child: IgnorePointer(child: _CenterPin()),
                ),
                // 仅保留信息卡片叠在地图上，不影响触摸事件
                Positioned(
                  left: 16,
                  right: 16,
                  top: 16,
                  child: _buildInfoCard(),
                ),
              ],
            ),
          ),
          // 底部按钮区域移出 Stack，彻底避免遮挡地图触摸区域
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  // 定位到当前位置
                  GestureDetector(
                    onTap: _isLocating ? null : _locateMe,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE0EAE6)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _isLocating
                          ? const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF004D36),
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.my_location_rounded,
                              color: Color(0xFF004D36),
                              size: 22,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 确认位置
                  Expanded(
                    child: FilledButton(
                      onPressed:
                          _selected == null ||
                              _resolvedAddress == null ||
                              _isResolving ||
                              _isMoving
                          ? null
                          : () {
                              Navigator.pop(context, {
                                'latitude': _selected!.latitude,
                                'longitude': _selected!.longitude,
                                'province': _resolvedAddress!.province,
                                'city': _resolvedAddress!.city,
                                'district': _resolvedAddress!.district,
                                'detailAddress':
                                    _resolvedAddress!.detailAddress,
                              });
                            },
                      child: Text(
                        _isMoving
                            ? '移动中...'
                            : (_isResolving ? '解析中...' : '确认位置'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        _errorMessage ??
            (_isMoving
                ? '移动地图，将中心对准目标位置'
                : (_resolvedAddress == null
                      ? '拖动地图，中心的图钉即为所选位置，系统会自动反查地址'
                      : '${_resolvedAddress!.province}${_resolvedAddress!.city}${_resolvedAddress!.district}${_resolvedAddress!.detailAddress}')),
      ),
    );
  }
}

/// 固定在地图中心的大头针（针尖对准屏幕中心）。
class _CenterPin extends StatelessWidget {
  const _CenterPin();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.location_on, size: 44, color: Color(0xFF004D36)),
          // 等高占位，使图钉针尖正好落在屏幕中心。
          SizedBox(height: 44),
        ],
      ),
    );
  }
}

class _ResolvedAddress {
  final String province;
  final String city;
  final String district;
  final String detailAddress;

  const _ResolvedAddress({
    required this.province,
    required this.city,
    required this.district,
    required this.detailAddress,
  });
}
