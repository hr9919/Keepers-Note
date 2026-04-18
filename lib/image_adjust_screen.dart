import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

enum ImageAdjustShape {
  circle,
  roundedRect,
}

class ImageAdjustResult {
  final Uint8List bytes;
  final String extension;

  const ImageAdjustResult({
    required this.bytes,
    this.extension = 'png',
  });
}

class ImageAdjustScreen extends StatefulWidget {
  final String imagePath;
  final String title;
  final ImageAdjustShape shape;
  final double? viewportAspectRatio;
  final Color accentColor;
  final double borderRadius;

  const ImageAdjustScreen({
    super.key,
    required this.imagePath,
    required this.title,
    required this.shape,
    required this.viewportAspectRatio,
    this.accentColor = const Color(0xFFFF8E7C),
    this.borderRadius = 28,
  });

  @override
  State<ImageAdjustScreen> createState() => _ImageAdjustScreenState();
}

enum _CropHandle {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

class _ImageAdjustScreenState extends State<ImageAdjustScreen> {
  static const double _minCropWidth = 120;
  static const double _minCropHeight = 120;
  static const double _handleTouchSize = 36;
  static const double _canvasHorizontalPadding = 24;
  static const double _canvasVerticalPadding = 26;

  ui.Image? _decodedImage;
  Size? _rawImageSize;
  bool _isSaving = false;

  double _scale = 1.0;
  double _baseScale = 1.0;
  Offset _offset = Offset.zero;
  Offset _normalizedOffset = Offset.zero;

  double _gestureStartScale = 1.0;
  Offset _gestureStartOffset = Offset.zero;
  Offset _gestureFocalImagePoint = Offset.zero;

  Rect? _freeCropRect;
  Size? _lastCanvasSize;

  bool get _isFreeformCrop =>
      widget.shape == ImageAdjustShape.roundedRect &&
          widget.viewportAspectRatio == null;

  bool get _useSharpRect =>
      widget.shape == ImageAdjustShape.roundedRect &&
          widget.viewportAspectRatio == null;

  @override
  void initState() {
    super.initState();
    _loadImageInfo();
  }

  Future<void> _loadImageInfo() async {
    final bytes = await File(widget.imagePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    if (!mounted) return;
    setState(() {
      _decodedImage = image;
      _rawImageSize = Size(image.width.toDouble(), image.height.toDouble());
    });
  }

  Rect _cropBoundsFor(Size size) {
    return Rect.fromLTWH(
      _canvasHorizontalPadding,
      _canvasVerticalPadding,
      math.max(80, size.width - (_canvasHorizontalPadding * 2)),
      math.max(80, size.height - (_canvasVerticalPadding * 2)),
    );
  }

  Rect _defaultCropRectFor(Size size) {
    final bounds = _cropBoundsFor(size);

    if (_isFreeformCrop) {
      final width = bounds.width * 0.82;

      final imageRatio = _rawImageSize == null
          ? 1.0
          : _rawImageSize!.height / _rawImageSize!.width;

      double height = width * imageRatio;

      final minHeight = math.min(_minCropHeight, bounds.height);
      final maxHeight = bounds.height * 0.76;
      height = height.clamp(minHeight, maxHeight).toDouble();

      final resolvedWidth = width.clamp(
        math.min(_minCropWidth, bounds.width),
        bounds.width,
      ).toDouble();

      return Rect.fromCenter(
        center: bounds.center,
        width: resolvedWidth,
        height: height,
      );
    }

    final aspectRatio = widget.viewportAspectRatio ?? 1.0;

    double cropWidth = bounds.width;
    double cropHeight = cropWidth / aspectRatio;

    if (cropHeight > bounds.height) {
      cropHeight = bounds.height;
      cropWidth = cropHeight * aspectRatio;
    }

    return Rect.fromCenter(
      center: bounds.center,
      width: cropWidth,
      height: cropHeight,
    );
  }

  Rect _clampFreeCropRect(Rect rect, Size size) {
    final bounds = _cropBoundsFor(size);

    double left = rect.left;
    double top = rect.top;
    double right = rect.right;
    double bottom = rect.bottom;

    final maxWidth = bounds.width;
    final maxHeight = bounds.height;

    final minWidth = math.min(_minCropWidth, maxWidth);
    final minHeight = math.min(_minCropHeight, maxHeight);

    final width = (right - left).clamp(minWidth, maxWidth).toDouble();
    final height = (bottom - top).clamp(minHeight, maxHeight).toDouble();

    right = left + width;
    bottom = top + height;

    if (left < bounds.left) {
      right += bounds.left - left;
      left = bounds.left;
    }
    if (top < bounds.top) {
      bottom += bounds.top - top;
      top = bounds.top;
    }
    if (right > bounds.right) {
      left -= right - bounds.right;
      right = bounds.right;
    }
    if (bottom > bounds.bottom) {
      top -= bottom - bounds.bottom;
      bottom = bounds.bottom;
    }

    if (right - left < minWidth) {
      right = math.min(bounds.right, left + minWidth);
      left = math.max(bounds.left, right - minWidth);
    }

    if (bottom - top < minHeight) {
      bottom = math.min(bounds.bottom, top + minHeight);
      top = math.max(bounds.top, bottom - minHeight);
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }

  Rect _resolvedCropRect(Size size) {
    if (!_isFreeformCrop) {
      return _defaultCropRectFor(size);
    }

    final defaultRect = _defaultCropRectFor(size);

    if (_freeCropRect == null) {
      _freeCropRect = defaultRect;
      _lastCanvasSize = size;
      return _freeCropRect!;
    }

    if (_lastCanvasSize != size) {
      _freeCropRect = _clampFreeCropRect(_freeCropRect!, size);
      _lastCanvasSize = size;
    }

    return _freeCropRect!;
  }

  double get _effectiveScale => _baseScale * _scale;

  void _initTransformIfNeeded(Rect cropRect) {
    if (_rawImageSize == null) return;

    final imageW = _rawImageSize!.width;
    final imageH = _rawImageSize!.height;

    final scaleX = cropRect.width / imageW;
    final scaleY = cropRect.height / imageH;
    final nextBaseScale = math.max(scaleX, scaleY);

    final bool needsInit =
        _baseScale == 1.0 &&
            _offset == Offset.zero &&
            _normalizedOffset == Offset.zero;

    if (!needsInit) {
      // ✅ 자유 크롭에서는 cropRect가 작아질 때 baseScale를 다시 낮추지 않음
      // ✅ cropRect가 커져서 현재 배율로 못 덮는 경우만 보정은
      //    _ensureImageCoversCropRect()에서 처리
      _offset = _clampOffset(_offset, cropRect);
      _syncNormalizedOffset(cropRect);
      return;
    }

    _baseScale = nextBaseScale;
    _scale = 1.0;
    _normalizedOffset = Offset.zero;

    final displayW = imageW * _effectiveScale;
    final displayH = imageH * _effectiveScale;

    _offset = Offset(
      cropRect.center.dx - displayW / 2,
      cropRect.center.dy - displayH / 2,
    );

    _offset = _clampOffset(_offset, cropRect);
    _syncNormalizedOffset(cropRect);
  }

  Offset _clampOffset(Offset proposed, Rect cropRect) {
    if (_rawImageSize == null) return proposed;

    final displayW = _rawImageSize!.width * _effectiveScale;
    final displayH = _rawImageSize!.height * _effectiveScale;

    final rawMinDx = cropRect.right - displayW;
    final rawMaxDx = cropRect.left;
    final rawMinDy = cropRect.bottom - displayH;
    final rawMaxDy = cropRect.top;

    final minDx = math.min(rawMinDx, rawMaxDx);
    final maxDx = math.max(rawMinDx, rawMaxDx);
    final minDy = math.min(rawMinDy, rawMaxDy);
    final maxDy = math.max(rawMinDy, rawMaxDy);

    return Offset(
      proposed.dx.clamp(minDx, maxDx).toDouble(),
      proposed.dy.clamp(minDy, maxDy).toDouble(),
    );
  }

  void _ensureImageCoversCropRect(Rect cropRect) {
    if (_rawImageSize == null) return;

    final minEffectiveScale = math.max(
      cropRect.width / _rawImageSize!.width,
      cropRect.height / _rawImageSize!.height,
    );

    double nextBaseScale = _baseScale;
    double nextScale = _scale;

    if (_effectiveScale < minEffectiveScale) {
      nextScale = minEffectiveScale / nextBaseScale;

      if (nextScale > 2.6) {
        nextBaseScale = minEffectiveScale;
        nextScale = 1.0;
      }

      _baseScale = nextBaseScale;
      _scale = nextScale.clamp(1.0, 2.6).toDouble();
      _rebuildOffsetFromNormalized(cropRect);
    }

    _offset = _clampOffset(_offset, cropRect);
    _syncNormalizedOffset(cropRect);
  }

  void _syncNormalizedOffset(Rect cropRect) {
    if (_rawImageSize == null) return;

    final displayW = _rawImageSize!.width * _effectiveScale;
    final displayH = _rawImageSize!.height * _effectiveScale;

    final imageCenter = Offset(
      _offset.dx + displayW / 2,
      _offset.dy + displayH / 2,
    );

    _normalizedOffset = imageCenter - cropRect.center;
  }

  void _rebuildOffsetFromNormalized(Rect cropRect) {
    if (_rawImageSize == null) return;

    final displayW = _rawImageSize!.width * _effectiveScale;
    final displayH = _rawImageSize!.height * _effectiveScale;

    final center = cropRect.center + _normalizedOffset;
    _offset = Offset(
      center.dx - displayW / 2,
      center.dy - displayH / 2,
    );
  }

  void _resetTransform(Rect cropRect) {
    if (_rawImageSize == null) return;

    setState(() {
      _scale = 1.0;
      _normalizedOffset = Offset.zero;

      final displayW = _rawImageSize!.width * _effectiveScale;
      final displayH = _rawImageSize!.height * _effectiveScale;

      _offset = Offset(
        cropRect.center.dx - displayW / 2,
        cropRect.center.dy - displayH / 2,
      );
    });
  }

  void _updateFreeCropRect(
      _CropHandle handle,
      DragUpdateDetails details,
      Size canvasSize,
      ) {
    if (!_isFreeformCrop) return;

    final current = _freeCropRect ?? _defaultCropRectFor(canvasSize);
    final bounds = _cropBoundsFor(canvasSize);

    double left = current.left;
    double top = current.top;
    double right = current.right;
    double bottom = current.bottom;

    final dx = details.delta.dx;
    final dy = details.delta.dy;

    switch (handle) {
      case _CropHandle.topLeft:
        left += dx;
        top += dy;
        left = left.clamp(bounds.left, right - _minCropWidth).toDouble();
        top = top.clamp(bounds.top, bottom - _minCropHeight).toDouble();
        break;

      case _CropHandle.topRight:
        right += dx;
        top += dy;
        right = right.clamp(left + _minCropWidth, bounds.right).toDouble();
        top = top.clamp(bounds.top, bottom - _minCropHeight).toDouble();
        break;

      case _CropHandle.bottomLeft:
        left += dx;
        bottom += dy;
        left = left.clamp(bounds.left, right - _minCropWidth).toDouble();
        bottom = bottom.clamp(top + _minCropHeight, bounds.bottom).toDouble();
        break;

      case _CropHandle.bottomRight:
        right += dx;
        bottom += dy;
        right = right.clamp(left + _minCropWidth, bounds.right).toDouble();
        bottom = bottom.clamp(top + _minCropHeight, bounds.bottom).toDouble();
        break;
    }

    final nextRect = _clampFreeCropRect(
      Rect.fromLTRB(left, top, right, bottom),
      canvasSize,
    );

    setState(() {
      _freeCropRect = nextRect;
      _ensureImageCoversCropRect(nextRect);
    });
  }

  Future<void> _save(Rect cropRect) async {
    if (_isSaving || _decodedImage == null || _rawImageSize == null) return;

    try {
      setState(() => _isSaving = true);

      const outputScale = 3.0;
      final outputWidth = (cropRect.width * outputScale).round();
      final outputHeight = (cropRect.height * outputScale).round();

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, outputWidth.toDouble(), outputHeight.toDouble()),
      );

      final clipRect = Rect.fromLTWH(
        0,
        0,
        outputWidth.toDouble(),
        outputHeight.toDouble(),
      );

      if (widget.shape == ImageAdjustShape.circle) {
        canvas.clipPath(Path()..addOval(clipRect));
      } else if (_useSharpRect) {
        canvas.clipRect(clipRect);
      } else {
        canvas.clipRRect(
          RRect.fromRectAndRadius(
            clipRect,
            Radius.circular(widget.borderRadius * outputScale),
          ),
        );
      }

      final drawLeft = (_offset.dx - cropRect.left) * outputScale;
      final drawTop = (_offset.dy - cropRect.top) * outputScale;
      final drawWidth = _rawImageSize!.width * _effectiveScale * outputScale;
      final drawHeight = _rawImageSize!.height * _effectiveScale * outputScale;

      final dstRect = Rect.fromLTWH(drawLeft, drawTop, drawWidth, drawHeight);

      final paint = Paint()..isAntiAlias = true;

      canvas.drawImageRect(
        _decodedImage!,
        Rect.fromLTWH(
          0,
          0,
          _decodedImage!.width.toDouble(),
          _decodedImage!.height.toDouble(),
        ),
        dstRect,
        paint,
      );

      final picture = recorder.endRecording();
      final renderedImage = await picture.toImage(outputWidth, outputHeight);
      final bytes =
      await renderedImage.toByteData(format: ui.ImageByteFormat.png);

      if (!mounted || bytes == null) return;

      Navigator.pop(
        context,
        ImageAdjustResult(
          bytes: bytes.buffer.asUint8List(),
          extension: 'png',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지 적용 중 오류가 발생했어요.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildFreeCropHandle({
    required Rect cropRect,
    required _CropHandle handle,
    required Size canvasSize,
  }) {
    double left;
    double top;

    switch (handle) {
      case _CropHandle.topLeft:
        left = cropRect.left - (_handleTouchSize / 2);
        top = cropRect.top - (_handleTouchSize / 2);
        break;
      case _CropHandle.topRight:
        left = cropRect.right - (_handleTouchSize / 2);
        top = cropRect.top - (_handleTouchSize / 2);
        break;
      case _CropHandle.bottomLeft:
        left = cropRect.left - (_handleTouchSize / 2);
        top = cropRect.bottom - (_handleTouchSize / 2);
        break;
      case _CropHandle.bottomRight:
        left = cropRect.right - (_handleTouchSize / 2);
        top = cropRect.bottom - (_handleTouchSize / 2);
        break;
    }

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanUpdate: (details) =>
            _updateFreeCropRect(handle, details, canvasSize),
        child: SizedBox(
          width: _handleTouchSize,
          height: _handleTouchSize,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFAF8),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xFFFFFAF8),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2D3436)),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Color(0xFF2D3436),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final fullSize = Size(constraints.maxWidth, constraints.maxHeight);
          final cropRect = _resolvedCropRect(fullSize);

          if (_rawImageSize != null) {
            _initTransformIfNeeded(cropRect);
            _ensureImageCoversCropRect(cropRect);
          }

          return Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onScaleStart: (details) {
                          if (_rawImageSize == null) return;

                          _gestureStartScale = _scale;
                          _gestureStartOffset = _offset;

                          final startEffectiveScale =
                              _baseScale * _gestureStartScale;
                          final focal = details.localFocalPoint;

                          _gestureFocalImagePoint = Offset(
                            (focal.dx - _gestureStartOffset.dx) /
                                startEffectiveScale,
                            (focal.dy - _gestureStartOffset.dy) /
                                startEffectiveScale,
                          );
                        },
                        onScaleUpdate: (details) {
                          if (_rawImageSize == null) return;

                          final focal = details.localFocalPoint;

                          final adjustedScaleDelta =
                              1 + ((details.scale - 1) * 0.08);
                          final newScale = (_gestureStartScale * adjustedScaleDelta)
                              .clamp(1.0, 2.6)
                              .toDouble();
                          final nextEffectiveScale = _baseScale * newScale;

                          final nextOffset = Offset(
                            focal.dx -
                                _gestureFocalImagePoint.dx * nextEffectiveScale,
                            focal.dy -
                                _gestureFocalImagePoint.dy * nextEffectiveScale,
                          );

                          setState(() {
                            _scale = newScale;
                            _offset = _clampOffset(nextOffset, cropRect);
                            _syncNormalizedOffset(cropRect);
                          });
                        },
                        child: Container(
                          width: double.infinity,
                          height: double.infinity,
                          color: const Color(0xFFFFFAF8),
                          child: _rawImageSize == null
                              ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFF8E7C),
                            ),
                          )
                              : Stack(
                            children: [
                              Positioned(
                                left: _offset.dx,
                                top: _offset.dy,
                                child: SizedBox(
                                  width: _rawImageSize!.width *
                                      _effectiveScale,
                                  height: _rawImageSize!.height *
                                      _effectiveScale,
                                  child: Image.file(
                                    File(widget.imagePath),
                                    fit: BoxFit.fill,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _CropOverlayPainter(
                            cropRect: cropRect,
                            shape: widget.shape,
                            accent: accent,
                            borderRadius: widget.borderRadius,
                            useSharpRect: _useSharpRect,
                          ),
                        ),
                      ),
                    ),
                    if (_isFreeformCrop) ...[
                      _buildFreeCropHandle(
                        cropRect: cropRect,
                        handle: _CropHandle.topLeft,
                        canvasSize: fullSize,
                      ),
                      _buildFreeCropHandle(
                        cropRect: cropRect,
                        handle: _CropHandle.topRight,
                        canvasSize: fullSize,
                      ),
                      _buildFreeCropHandle(
                        cropRect: cropRect,
                        handle: _CropHandle.bottomLeft,
                        canvasSize: fullSize,
                      ),
                      _buildFreeCropHandle(
                        cropRect: cropRect,
                        handle: _CropHandle.bottomRight,
                        canvasSize: fullSize,
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.96),
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
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.zoom_out_rounded,
                            color: Color(0xFF9AA4B2),
                            size: 20,
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 4,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 9,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 18,
                                ),
                                activeTrackColor: accent,
                                thumbColor: accent,
                                overlayColor: accent.withOpacity(0.14),
                                inactiveTrackColor: const Color(0xFFF3D8D1),
                              ),
                              child: Slider(
                                min: 1.0,
                                max: 2.6,
                                value: _scale.clamp(1.0, 2.6),
                                onChanged: _rawImageSize == null
                                    ? null
                                    : (value) {
                                  setState(() {
                                    _scale = value;
                                    _rebuildOffsetFromNormalized(cropRect);
                                    _ensureImageCoversCropRect(cropRect);
                                  });
                                },
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.zoom_in_rounded,
                            color: Color(0xFF9AA4B2),
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _rawImageSize == null
                                  ? null
                                  : () => _resetTransform(cropRect),
                              icon: const Icon(
                                Icons.refresh_rounded,
                                size: 18,
                              ),
                              label: const Text('초기화'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                side: const BorderSide(
                                  color: Color(0xFFFFDDD4),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                foregroundColor: const Color(0xFF7B8794),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed:
                              _isSaving ? null : () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                side: const BorderSide(
                                  color: Color(0xFFFFDDD4),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                foregroundColor: const Color(0xFF7B8794),
                              ),
                              child: const Text(
                                '취소',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: (_isSaving ||
                                  _rawImageSize == null ||
                                  _decodedImage == null)
                                  ? null
                                  : () => _save(cropRect),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(48),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                                  : const Text(
                                '적용',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
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
            ],
          );
        },
      ),
    );
  }
}

class _CropOverlayPainter extends CustomPainter {
  final Rect cropRect;
  final ImageAdjustShape shape;
  final Color accent;
  final double borderRadius;
  final bool useSharpRect;

  _CropOverlayPainter({
    required this.cropRect,
    required this.shape,
    required this.accent,
    required this.borderRadius,
    required this.useSharpRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.34);
    final clearPaint = Paint()..blendMode = BlendMode.clear;

    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, overlayPaint);

    if (shape == ImageAdjustShape.circle) {
      canvas.drawOval(cropRect, clearPaint);

      final borderPaint = Paint()
        ..color = accent.withOpacity(0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawOval(cropRect, borderPaint);
    } else if (useSharpRect) {
      canvas.drawRect(cropRect, clearPaint);

      final dotPaint = Paint()
        ..color = accent
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;

      const dotRadius = 5.0;

      canvas.drawCircle(cropRect.topLeft, dotRadius, dotPaint);
      canvas.drawCircle(cropRect.topRight, dotRadius, dotPaint);
      canvas.drawCircle(cropRect.bottomLeft, dotRadius, dotPaint);
      canvas.drawCircle(cropRect.bottomRight, dotRadius, dotPaint);
    } else {
      final rrect = RRect.fromRectAndRadius(
        cropRect,
        Radius.circular(borderRadius),
      );
      final borderPaint = Paint()
        ..color = accent.withOpacity(0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawRRect(rrect, clearPaint);
      canvas.drawRRect(rrect, borderPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) {
    return cropRect != oldDelegate.cropRect ||
        shape != oldDelegate.shape ||
        accent != oldDelegate.accent ||
        borderRadius != oldDelegate.borderRadius ||
        useSharpRect != oldDelegate.useSharpRect;
  }
}