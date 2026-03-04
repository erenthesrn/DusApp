// lib/screens/achievements_screen.dart
import 'package:flutter/material.dart';
import '../services/achievement_service.dart';
import '../models/achievement_model.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  String _selectedFilter = 'Tümü';

  static const _filters = ['Tümü', 'Kazanılan', 'Kilitli', 'Branş', 'Özel'];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _controller.forward();
    AchievementService.instance.refreshFromFirebase();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Achievement> _filtered(List<Achievement> all) {
    switch (_selectedFilter) {
      case 'Kazanılan':
        return all.where((a) => a.isUnlocked).toList();
      case 'Kilitli':
        return all.where((a) => !a.isUnlocked).toList();
      case 'Branş':
        return all.where((a) => a.groupId != null).toList();
      case 'Özel':
        return all.where((a) => a.groupId == null).toList();
      default:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFE6EDF3) : const Color(0xFF1E293B);

    return AnimatedBuilder(
      animation: AchievementService.instance,
      builder: (context, _) {
        final all = AchievementService.instance.achievements;
        final unlockedCount = all.where((a) => a.isUnlocked).length;
        final filtered = _filtered(all);

        return Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF0A0E14) : const Color(0xFFF0F4FF),
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            cacheExtent: 800,
            slivers: [
              // ── APP BAR ──
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor:
                    isDark ? const Color(0xFF0A0E14) : const Color(0xFFF0F4FF),
                elevation: 0,
                iconTheme: IconThemeData(color: textColor),
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.pin,
                  background: _HeroHeader(
                    unlockedCount: unlockedCount,
                    totalCount: all.length,
                    isDark: isDark,
                    controller: _controller,
                  ),
                ),
                title: Text(
                  'Kupa Dolabı',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                centerTitle: true,
              ),

              // ── FİLTRE ÇUBUĞU ──
              SliverPersistentHeader(
                pinned: true,
                delegate: _FilterBarDelegate(
                  filters: _filters,
                  selected: _selectedFilter,
                  isDark: isDark,
                  onSelect: (f) => setState(() {
                    _selectedFilter = f;
                    _controller
                      ..reset()
                      ..forward();
                  }),
                ),
              ),

              // ── ROZET IZGARASI ──
              filtered.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded,
                                size: 64,
                                color: isDark
                                    ? Colors.white24
                                    : Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'Bu kategoride başarım yok',
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.72,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final anim = Tween<double>(begin: 0.0, end: 1.0)
                                .animate(CurvedAnimation(
                              parent: _controller,
                              curve: Interval(
                                (index / filtered.length).clamp(0.0, 0.85),
                                1.0,
                                curve: Curves.easeOutBack,
                              ),
                            ));
                            return AnimatedBuilder(
                              animation: anim,
                              builder: (_, child) => Transform.translate(
                                offset: Offset(0, 50 * (1 - anim.value)),
                                child: Opacity(
                                  opacity: anim.value.clamp(0.0, 1.0),
                                  child: child,
                                ),
                              ),
                              child: RepaintBoundary(
                                child: _AchievementCard(
                                  item: filtered[index],
                                  isDark: isDark,
                                  isLocked: AchievementService.instance
                                      .isLocked(filtered[index]),
                                ),
                              ),
                            );
                          },
                          childCount: filtered.length,
                          addAutomaticKeepAlives: false,
                          addRepaintBoundaries: false,
                        ),
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────
//  HERO HEADER
// ─────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final int unlockedCount;
  final int totalCount;
  final bool isDark;
  final AnimationController controller;

  const _HeroHeader({
    required this.unlockedCount,
    required this.totalCount,
    required this.isDark,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalCount > 0 ? unlockedCount / totalCount : 0.0;

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 56, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0D1B4B), const Color(0xFF0A0E14)]
              : [const Color(0xFF1565C0), const Color(0xFF42A5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            children: [
              // Trophy animasyonu
              SlideTransition(
                position: Tween<Offset>(
                        begin: const Offset(-0.3, 0), end: Offset.zero)
                    .animate(CurvedAnimation(
                        parent: controller, curve: Curves.easeOutBack)),
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFFFFD700).withOpacity(0.5),
                          blurRadius: 16,
                          spreadRadius: 2)
                    ],
                  ),
                  child: const Icon(Icons.emoji_events_rounded,
                      color: Colors.white, size: 34),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Kupa Dolabı',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    FadeTransition(
                      opacity: controller,
                      child: RichText(
                        text: TextSpan(children: [
                          TextSpan(
                              text: '$unlockedCount',
                              style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1)),
                          TextSpan(
                              text: ' / $totalCount başarım',
                              style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.white60,
                                  fontWeight: FontWeight.w500)),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: Colors.white24,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${(progress * 100).toStringAsFixed(0)}% tamamlandı',
                style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  FİLTRE ÇUBUĞU DELEGESİ
// ─────────────────────────────────────────

class _FilterBarDelegate extends SliverPersistentHeaderDelegate {
  final List<String> filters;
  final String selected;
  final bool isDark;
  final ValueChanged<String> onSelect;

  _FilterBarDelegate({
    required this.filters,
    required this.selected,
    required this.isDark,
    required this.onSelect,
  });

  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: isDark ? const Color(0xFF0A0E14) : const Color(0xFFF0F4FF),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = filters[i];
          final isActive = f == selected;
          return GestureDetector(
            onTap: () => onSelect(f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                gradient: isActive
                    ? const LinearGradient(
                        colors: [Color(0xFF2962FF), Color(0xFF42A5F5)])
                    : null,
                color: isActive
                    ? null
                    : (isDark
                        ? const Color(0xFF1C2333)
                        : Colors.white),
                borderRadius: BorderRadius.circular(20),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                            color: const Color(0xFF2962FF).withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 3))
                      ]
                    : null,
              ),
              child: Text(
                f,
                style: TextStyle(
                  color: isActive
                      ? Colors.white
                      : (isDark ? Colors.white54 : Colors.grey.shade600),
                  fontSize: 13,
                  fontWeight:
                      isActive ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  bool shouldRebuild(_FilterBarDelegate old) =>
      old.selected != selected || old.isDark != isDark;
}

// ─────────────────────────────────────────
//  BAŞARIM KARTI
// ─────────────────────────────────────────

class _AchievementCard extends StatelessWidget {
  final Achievement item;
  final bool isDark;
  final bool isLocked;

  const _AchievementCard({
    required this.item,
    required this.isDark,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    final tier = item.tier;
    final unlocked = item.isUnlocked;
    final fullyLocked = isLocked && !unlocked;

    // Renk teması
    final tierColor = tier?.color ?? const Color(0xFF448AFF);
    final tierGradient = tier?.gradient ??
        [const Color(0xFF2962FF), const Color(0xFF1565C0)];
    final tierGlow = tier?.glowColor ?? const Color(0xFF448AFF);

    final cardBg = isDark
        ? (unlocked ? const Color(0xFF1A2035) : const Color(0xFF111722))
        : (unlocked ? Colors.white : const Color(0xFFF5F7FF));

    final border = unlocked
        ? Border.all(color: tierColor.withOpacity(0.6), width: 1.5)
        : Border.all(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
            width: 1.2);

    final shadows = unlocked
        ? [
            BoxShadow(
              color: tierGlow.withOpacity(isDark ? 0.25 : 0.2),
              blurRadius: 16,
              offset: const Offset(0, 6),
            )
          ]
        : [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ];

    final titleColor =
        isDark ? const Color(0xFFE6EDF3) : const Color(0xFF1E293B);
    final descColor = isDark ? Colors.white60 : Colors.grey.shade600;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: border,
        boxShadow: shadows,
      ),
      child: Column(
        children: [
          // ── ÜST BÖLÜM ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 18, 12, 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // İkon
                  _TierIcon(
                    item: item,
                    tier: tier,
                    unlocked: unlocked,
                    fullyLocked: fullyLocked,
                    isDark: isDark,
                    tierColor: tierColor,
                  ),
                  const SizedBox(height: 12),

                  // Tier rozeti (bronz/gümüş/altın)
                  if (tier != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: unlocked
                            ? LinearGradient(colors: tierGradient)
                            : null,
                        color: unlocked
                            ? null
                            : (isDark ? Colors.white10 : Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(tier.tierIcon,
                              size: 11,
                              color:
                                  unlocked ? Colors.white : Colors.grey),
                          const SizedBox(width: 3),
                          Text(
                            tier.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color:
                                  unlocked ? Colors.white : Colors.grey,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (tier != null) const SizedBox(height: 8),

                  // Başlık
                  Text(
                    item.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      height: 1.2,
                      color: unlocked
                          ? titleColor
                          : titleColor.withOpacity(0.4),
                    ),
                  ),

                  const SizedBox(height: 5),

                  // Açıklama
                  Text(
                    fullyLocked
                        ? 'Önceki kademeyi kazan!'
                        : item.description,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: fullyLocked
                          ? (isDark ? Colors.white24 : Colors.grey.shade400)
                          : descColor,
                      height: 1.3,
                      fontStyle: fullyLocked
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── ALT BÖLÜM ──
          if (unlocked)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: tierGradient),
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(22)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: Colors.white.withOpacity(0.9), size: 13),
                  const SizedBox(width: 5),
                  const Text(
                    'KAZANILDI',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: fullyLocked ? 0.0 : item.progressPercentage,
                      backgroundColor: isDark
                          ? Colors.white10
                          : Colors.grey.shade200,
                      color: fullyLocked
                          ? Colors.grey.withOpacity(0.3)
                          : tierColor,
                      minHeight: 5,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    fullyLocked
                        ? '🔒 Kilitli'
                        : '${item.currentValue} / ${item.targetValue}',
                    style: TextStyle(
                      fontSize: 10,
                      color: fullyLocked
                          ? (isDark ? Colors.white24 : Colors.grey.shade400)
                          : descColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  TİER İKON
// ─────────────────────────────────────────

class _TierIcon extends StatelessWidget {
  final Achievement item;
  final AchievementTier? tier;
  final bool unlocked;
  final bool fullyLocked;
  final bool isDark;
  final Color tierColor;

  const _TierIcon({
    required this.item,
    required this.tier,
    required this.unlocked,
    required this.fullyLocked,
    required this.isDark,
    required this.tierColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow efekti (sadece kazanıldıysa)
        if (unlocked)
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: tierColor.withOpacity(0.4),
                  blurRadius: 18,
                  spreadRadius: 3,
                )
              ],
            ),
          ),
        // İkon çemberi
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: unlocked
                ? LinearGradient(
                    colors: [
                      tierColor.withOpacity(0.25),
                      tierColor.withOpacity(0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: unlocked
                ? null
                : (isDark
                    ? Colors.white.withOpacity(0.04)
                    : Colors.grey.withOpacity(0.08)),
            border: unlocked
                ? Border.all(color: tierColor.withOpacity(0.5), width: 1.5)
                : Border.all(
                    color: isDark ? Colors.white12 : Colors.grey.shade300,
                    width: 1),
          ),
          child: Icon(
            item.iconData,
            size: 28,
            color: unlocked
                ? tierColor
                : (isDark ? Colors.white24 : Colors.grey.shade400),
          ),
        ),
        // Kilit ikonu (tamamen kilitliyse)
        if (fullyLocked)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C2333) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                    color: isDark ? Colors.white12 : Colors.grey.shade300),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 3)
                ],
              ),
              child: Icon(Icons.lock_rounded,
                  size: 11,
                  color: isDark ? Colors.white38 : Colors.grey.shade500),
            ),
          ),
      ],
    );
  }
}
