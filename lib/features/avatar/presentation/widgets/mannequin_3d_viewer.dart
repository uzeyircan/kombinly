import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

/// Gerçek GLB 3D manken görüntüleyici.
///
/// [model_viewer_plus] paketi üzerinden Google Model Viewer'ı kullanır.
/// Orbit (yaw) ve zoom değerleri `cameraOrbit` parametresine dönüştürülür.
/// [onModelLoaded] callback'i model hazır olduğunda tetiklenir.
class Mannequin3DViewer extends StatelessWidget {
  /// Asset yolu veya HTTP URL'i — örnek: 'assets/mannequin/standard_female_v1.glb'
  final String modelSrc;

  /// Yatay orbit açısı (-1.0 .. 1.0). 0 = ön, negatif = sola, pozitif = sağa.
  final double yaw;

  /// Dikey bakış açısı derece olarak. Negatif değer biraz yukarıdan bakmayı sağlar.
  final double pitch;

  /// Zoom çarpanı (0.7 .. 1.5).
  final double zoom;

  const Mannequin3DViewer({
    super.key,
    required this.modelSrc,
    this.yaw = 0.0,
    this.pitch = -5.0,
    this.zoom = 1.0,
  });

  /// yaw (-1..1) → derece (−90..90 aralığında yumuşatılmış)
  String _buildCameraOrbit() {
    final yawDeg = yaw * 90.0;
    // pitch sabit tutulur, zoom radius'a çevrilir (küçük = yakın)
    final radius = (3.5 / zoom).clamp(2.0, 5.5);
    final pitchDeg = pitch.clamp(-30.0, 10.0);
    return '${yawDeg.toStringAsFixed(1)}deg ${(90.0 + pitchDeg).toStringAsFixed(1)}deg ${radius.toStringAsFixed(2)}m';
  }

  /// yaw değerine göre arka plan rengi — çok hafif bir ambient sıcaklık değişimi
  Color _ambientColor() {
    final t = (yaw.abs() * 0.12).clamp(0.0, 0.12);
    return Color.lerp(
      const Color(0xFF0D0D14),
      const Color(0xFF141020),
      t,
    )!;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: ColoredBox(
        color: _ambientColor(),
        child: ModelViewer(
          src: modelSrc,
          alt: 'Premium Kombinly Mannequin',
          ar: false,
          autoRotate: false,
          cameraControls: true,
          cameraOrbit: _buildCameraOrbit(),
          shadowIntensity: 0.9,
          shadowSoftness: 0.6,
          exposure: 1.1,
          backgroundColor: Colors.transparent,
        ),
      ),
    );
  }
}

/// Fallback widget: GLB yokken veya platform desteklemiyorken gösterilir.
class Mannequin3DFallbackWidget extends StatelessWidget {
  final String message;

  const Mannequin3DFallbackWidget({
    super.key,
    this.message = 'Premium 3D model yükleniyor…',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0D0D14), Color(0xFF1A1A2E)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.view_in_ar_outlined,
              size: 52,
              color: Color(0xFF8B7CF8),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                color: Color(0xFFCCCCDD),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
