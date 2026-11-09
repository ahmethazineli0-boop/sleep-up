import 'package:flutter/material.dart';

import '../theme.dart';

/// Kilit katmanı olmayan derlemelerde (ör. ücretsiz Apple hesabıyla yüklenen
/// iOS deneme sürümü) gösterilen bilgi kartı.
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1E36),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: SU.lavender.withValues(alpha: 0.4)),
        ),
        child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.science_outlined, color: SU.lavender, size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Deneme sürümü: ekranları gezebilir ve programını ayarlayabilirsin, '
              'ama bu kurulumda uygulama kilidi çalışmaz. iPhone\'da kilit için '
              'Apple Developer üyeliği gerekir.',
              style: TextStyle(fontSize: 13, height: 1.45, color: SU.text),
            ),
          ),
        ]),
      );
}
