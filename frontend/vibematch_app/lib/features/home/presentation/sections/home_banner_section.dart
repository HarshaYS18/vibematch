import 'package:flutter/material.dart';

import '../../models/home_banner.dart';

class HomeBannerSection extends StatelessWidget {
  const HomeBannerSection({
    super.key,
    required this.banners,
    required this.selectedIndex,
    required this.canManageHomeBanners,
    required this.onBannerChanged,
    required this.onBannerTap,
    required this.onManageTap,
  });

  final List<HomeBanner> banners;
  final int selectedIndex;
  final bool canManageHomeBanners;
  final ValueChanged<int> onBannerChanged;
  final ValueChanged<HomeBanner> onBannerTap;
  final VoidCallback onManageTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 4, 18, 16),
      height: 138,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: banners.length,
            onPageChanged: onBannerChanged,
            itemBuilder: (context, index) {
              final banner = banners[index];

              return GestureDetector(
                onTap: () => onBannerTap(banner),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: banner.fallbackGradient,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: banner.fallbackGradient.first.withValues(alpha: 0.18),
                          blurRadius: 18,
                          offset: const Offset(0, 9),
                        ),
                      ],
                    ),
                    child: banner.imageUrl == null
                        ? _BannerFallback(banner: banner)
                        : Image.network(
                            banner.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _BannerFallback(banner: banner),
                          ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            left: 14,
            bottom: 12,
            child: _BannerDots(
              length: banners.length,
              selectedIndex: selectedIndex,
            ),
          ),
          if (canManageHomeBanners)
            Positioned(
              right: 10,
              top: 10,
              child: GestureDetector(
                onTap: onManageTap,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
                  ),
                  child: const Icon(
                    Icons.add_photo_alternate_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BannerFallback extends StatelessWidget {
  const _BannerFallback({required this.banner});

  final HomeBanner banner;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          right: -18,
          bottom: -28,
          child: Icon(
            banner.fallbackIcon,
            size: 118,
            color: Colors.white.withValues(alpha: 0.13),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Text(
              banner.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.35,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BannerDots extends StatelessWidget {
  const _BannerDots({required this.length, required this.selectedIndex});

  final int length;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        length,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(right: 5),
          width: index == selectedIndex ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: index == selectedIndex ? 0.95 : 0.42),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}
