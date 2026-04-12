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
  final double viewportAspectRatio;
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

class _ImageAdjustScreenState extends State<ImageAdjustScreen> {
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

  Rect _cropRectFor(Size size) {
    const horizontalPadding = 24.0;
    final maxWidth = size.width - horizontalPadding * 2;

    double cropWidth = maxWidth;
    double cropHeight = cropWidth / widget.viewportAspectRatio;

    final maxHeight = size.height * 0.58;
    if (cropHeight > maxHeight) {
      cropHeight = maxHeight;
      cropWidth = cropHeight * widget.viewportAspectRatio;
    }

    final left = (size.width - cropWidth) / 2;
    final top = (size.height - cropHeight) / 2 - 18;

    return Rect.fromLTWH(left, top, cropWidth, cropHeight);
  }

  double get _effectiveScale => _baseScale * _scale;

  void _initTransformIfNeeded(Rect cropRect) {
    if (_rawImageSize == null) return;
    if (_baseScale != 1.0 || _offset != Offset.zero) return;

    final imageW = _rawImageSize!.width;
    final imageH = _rawImageSize!.height;

    final scaleX = cropRect.width / imageW;
    final scaleY = cropRect.height / imageH;
    _baseScale = math.max(scaleX, scaleY);
    _scale = 1.0;
    _normalizedOffset = Offset.zero;

    final displayW = imageW * _effectiveScale;
    final displayH = imageH * _effectiveScale;

    _offset = Offset(
      cropRect.center.dx - displayW / 2,
      cropRect.center.dy - displayH / 2,
    );
  }

  Offset _clampOffset(Offset proposed, Rect cropRect) {
    if (_rawImageSize == null) return proposed;

    final displayW = _rawImageSize!.width * _effectiveScale;
    final displayH = _rawImageSize!.height * _effectiveScale;

    final minDx = cropRect.right - displayW;
    final maxDx = cropRect.left;
    final minDy = cropRect.bottom - displayH;
    final maxDy = cropRect.top;

    return Offset(
      proposed.dx.clamp(minDx, maxDx),
      proposed.dy.clamp(minDy, maxDy),
    );
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

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFAF8),
      appBar: AppBar(
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
          final cropRect = _cropRectFor(fullSize);

          if (_rawImageSize != null) {
            _initTransformIfNeeded(cropRect);
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
                          final newScale =
                          (_gestureStartScale * adjustedScaleDelta)
                              .clamp(1.0, 2.6);
                          final nextEffectiveScale = _baseScale * newScale;

                          final nextOffset = Offset(
                            focal.dx -
                                _gestureFocalImagePoint.dx *
                                    nextEffectiveScale,
                            focal.dy -
                                _gestureFocalImagePoint.dy *
                                    nextEffectiveScale,
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
                          ),
                        ),
                      ),
                    ),
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
                      Text(
                        widget.shape == ImageAdjustShape.circle
                            ? '원형 프레임에 맞게 드래그하고 확대해보세요'
                            : '배경 프레임 안에서 위치와 확대를 조정해보세요',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7B8794),
                        ),
                      ),
                      const SizedBox(height: 14),
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
                                inactiveTrackColor:
                                const Color(0xFFF3D8D1),
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
                                    _rebuildOffsetFromNormalized(
                                      cropRect,
                                    );
                                    _offset = _clampOffset(
                                      _offset,
                                      cropRect,
                                    );
                                    _syncNormalizedOffset(cropRect);
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
                                foregroundColor:
                                const Color(0xFF7B8794),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isSaving
                                  ? null
                                  : () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                side: const BorderSide(
                                  color: Color(0xFFFFDDD4),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                foregroundColor:
                                const Color(0xFF7B8794),
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
                                child:
                                CircularProgressIndicator(
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

  _CropOverlayPainter({
    required this.cropRect,
    required this.shape,
    required this.accent,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.34);
    final clearPaint = Paint()..blendMode = BlendMode.clear;
    final borderPaint = Paint()
      ..color = accent.withOpacity(0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, overlayPaint);

    if (shape == ImageAdjustShape.circle) {
      canvas.drawOval(cropRect, clearPaint);
      canvas.drawOval(cropRect, borderPaint);
    } else {
      final rrect = RRect.fromRectAndRadius(
        cropRect,
        Radius.circular(borderRadius),
      );
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
        borderRadius != oldDelegate.borderRadius;
  }
}