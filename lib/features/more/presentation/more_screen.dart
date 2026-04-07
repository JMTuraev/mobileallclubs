import 'package:flutter/material.dart';

import '../../../core/widgets/foundation_page.dart';
import '../../../core/widgets/module_status_card.dart';
import '../../../core/widgets/section_title.dart';
import '../../../models/module_readiness_status.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FoundationPage(
      eyebrow: 'Qo\'shimcha bo\'limlar',
      title: 'Keyin ulanadigan bo\'limlar',
      subtitle:
          'Moliya, analitika, xodimlar, sozlamalar, billing va POS qismlari hozircha kutishda. Real tizim tasdiqlangach ulanadi.',
      children: [
        SectionTitle(
          title: 'Keyingi bosqichlar',
          subtitle: 'Bu bo\'limlar reja ichida bor, lekin hali faol emas.',
        ),
        ModuleStatusCard(
          title: 'Moliya va analitika',
          description:
              'Bu bo\'limlar aniq backend ma\'lumotlariga tayanadi. Shuning uchun hozircha faqat joyi ajratilgan.',
          status: ModuleReadinessStatus.auditBlocked,
          highlights: [
            'Hisob-kitob telefonda qayta yozilmaydi.',
            'Analitika taxminiy hisoblanmaydi.',
            'Real ma\'lumot keyin backenddan olinadi.',
          ],
        ),
        ModuleStatusCard(
          title: 'Xodimlar va sozlamalar',
          description:
              'Xodimlar ko\'rinishi va ruxsatlar keyinchalik aniq qoidalarga qarab ulanadi.',
          status: ModuleReadinessStatus.planned,
          highlights: [
            'Rolga qarab menu tuzilmasi saqlangan.',
            'Nozik sozlamalar hozircha yopiq.',
            'Ruxsatlar aniq bo\'lgach qo\'shiladi.',
          ],
        ),
        ModuleStatusCard(
          title: 'Billing va POS',
          description:
              'To\'lov va savdo jarayonlari alohida qoidalar bilan ishlaydi. Shu sabab hozircha bu qism ochilmagan.',
          status: ModuleReadinessStatus.auditBlocked,
          highlights: [
            'Do\'kon to\'lovi avtomatik huquq bermaydi.',
            'Ichki savdo va ilova billing\'i alohida yuradi.',
            'POS funksiyasi keyin tekshirib ulanadi.',
          ],
        ),
      ],
    );
  }
}
