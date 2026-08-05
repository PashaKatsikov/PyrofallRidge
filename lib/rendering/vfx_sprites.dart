/// Named (row, column) coordinates into the VFX atlas (5 rows x 12 columns,
/// 1-indexed), so the rest of the codebase never has raw magic numbers.
///
/// A small immutable record-like class instead of a `Record` alias keeps
/// this readable and self-documenting at call sites.
class VfxCoord {
  const VfxCoord(this.row, this.col);
  final int row;
  final int col;
}

class VfxSprites {
  VfxSprites._();

  // --- Falling object bodies (phase: falling) ---------------------------
  static const List<VfxCoord> rockfallBody = <VfxCoord>[
    VfxCoord(1, 1),
    VfxCoord(1, 4),
    VfxCoord(2, 3),
  ];
  static const List<VfxCoord> meteorBody = <VfxCoord>[
    VfxCoord(1, 3),
    VfxCoord(1, 6),
    VfxCoord(2, 2),
  ];

  // --- Telegraph (phase: warning) ----------------------------------------
  static const List<VfxCoord> telegraphRing = <VfxCoord>[
    VfxCoord(5, 1),
    VfxCoord(5, 10),
  ];
  static const VfxCoord telegraphAimDot = VfxCoord(4, 5);

  // --- Impact sequence (phase: impact), ~0.25-0.4s total -----------------
  static const List<VfxCoord> impactFlash = <VfxCoord>[
    VfxCoord(3, 4),
    VfxCoord(3, 8),
    VfxCoord(3, 9),
  ];
  static const List<VfxCoord> impactFireBurst = <VfxCoord>[
    VfxCoord(1, 9),
    VfxCoord(4, 7),
    VfxCoord(5, 3),
  ];
  static const List<VfxCoord> impactSmoke = <VfxCoord>[
    VfxCoord(1, 11),
    VfxCoord(3, 10),
    VfxCoord(4, 3),
  ];
  static const List<VfxCoord> meteorMoltenSplash = <VfxCoord>[
    VfxCoord(2, 8),
    VfxCoord(2, 9),
    VfxCoord(2, 10),
  ];
  static const List<VfxCoord> shockwave = <VfxCoord>[
    VfxCoord(5, 6),
    VfxCoord(5, 9),
  ];

  // --- Landed platform (phase: landed) ------------------------------------
  static const List<VfxCoord> platformCooled = <VfxCoord>[
    VfxCoord(2, 5),
    VfxCoord(3, 1),
    VfxCoord(4, 1),
    VfxCoord(2, 4),
  ];
  static const List<VfxCoord> platformSmoke = <VfxCoord>[
    VfxCoord(2, 11),
    VfxCoord(4, 8),
  ];

  // --- Ambient background atmosphere --------------------------------------
  static const List<VfxCoord> ambientSmoke = <VfxCoord>[
    VfxCoord(3, 11),
    VfxCoord(4, 10),
  ];
}
