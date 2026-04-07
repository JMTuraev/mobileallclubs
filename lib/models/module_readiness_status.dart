import 'package:flutter/material.dart';

enum ModuleReadinessStatus { auditBlocked, foundationReady, planned }

extension ModuleReadinessStatusX on ModuleReadinessStatus {
  String get label => switch (this) {
    ModuleReadinessStatus.auditBlocked => 'Tekshiruv kutilmoqda',
    ModuleReadinessStatus.foundationReady => 'Asos tayyor',
    ModuleReadinessStatus.planned => 'Rejada',
  };

  IconData get icon => switch (this) {
    ModuleReadinessStatus.auditBlocked => Icons.gpp_maybe_rounded,
    ModuleReadinessStatus.foundationReady => Icons.verified_rounded,
    ModuleReadinessStatus.planned => Icons.schedule_rounded,
  };
}
