import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

class SignatureImageService {
  const SignatureImageService._();

  static Uint8List normalize(
    Uint8List source, {
    bool blackInk = false,
  }) {
    final decoded = img.decodeImage(source);
    if (decoded == null) return source;

    var minX = decoded.width;
    var minY = decoded.height;
    var maxX = -1;
    var maxY = -1;

    for (final pixel in decoded) {
      final alpha = pixel.a.toInt();
      final lightestInk = math.min(
        pixel.r.toInt(),
        math.min(pixel.g.toInt(), pixel.b.toInt()),
      );
      if (alpha > 18 && lightestInk < 245) {
        minX = math.min(minX, pixel.x);
        minY = math.min(minY, pixel.y);
        maxX = math.max(maxX, pixel.x);
        maxY = math.max(maxY, pixel.y);
      }
    }

    if (maxX < minX || maxY < minY) return source;
    final inkWidth = maxX - minX + 1;
    final inkHeight = maxY - minY + 1;
    final padding = math.max(3, (math.max(inkWidth, inkHeight) * .025).round());
    final x = math.max(0, minX - padding);
    final y = math.max(0, minY - padding);
    final right = math.min(decoded.width - 1, maxX + padding);
    final bottom = math.min(decoded.height - 1, maxY + padding);
    var cropped = img.copyCrop(
      decoded,
      x: x,
      y: y,
      width: right - x + 1,
      height: bottom - y + 1,
    );

    if (cropped.width < 900) {
      cropped = img.copyResize(
        cropped,
        width: 900,
        interpolation: img.Interpolation.cubic,
      );
    }

    for (final pixel in cropped) {
      final originalAlpha = pixel.a.toInt();
      final lightestInk = math.min(
        pixel.r.toInt(),
        math.min(pixel.g.toInt(), pixel.b.toInt()),
      );
      final ink = (255 - lightestInk).clamp(0, 255);
      final alpha = (originalAlpha * ink / 255).round().clamp(0, 255);
      pixel.setRgba(
        18,
        blackInk ? 18 : 57,
        blackInk ? 18 : 158,
        alpha,
      );
    }

    return Uint8List.fromList(img.encodePng(cropped, level: 6));
  }
}
