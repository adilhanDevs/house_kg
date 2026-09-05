import 'package:flutter/foundation.dart';

import 'package:flutter/widgets.dart';
import '../l10n/l10n.dart';

extension TariffFeatureL10n on TariffFeature {
  String localizedTitle(BuildContext context) {
    final l10n = context.l10n;
    switch (icon) {
      case TariffFeatureIcon.promotion:
        return l10n.tariffPromoPosts(this.value);
      case TariffFeatureIcon.posts:
        return l10n.tariffMaxPosts(this.value);
      case TariffFeatureIcon.reels:
        return l10n.tariffReels(this.value);
      case TariffFeatureIcon.bricks:
        return l10n.tariffBricks;
      case TariffFeatureIcon.catalog:
        return l10n.tariffCatalog;
      case TariffFeatureIcon.whatsapp:
        return l10n.tariffWhatsapp;
    }
  }
}


enum TariffFeatureIcon {
  promotion,
  posts,
  reels,
  bricks,
  catalog,
  whatsapp,
}

@immutable
class TariffFeature {
  const TariffFeature({
    required this.title,
    required this.icon,
    this.value = 0,
  });

  final String title;
  final TariffFeatureIcon icon;
  final int value;
}

@immutable
class TariffPlan {
  const TariffPlan({
    required this.code,
    required this.name,
    required this.priceSom,
    this.priceBricks,
    required this.maxPromoPosts,
    required this.maxPosts,
    this.maxReels = 0,
    this.hasBricksAccumulation = false,
    this.hasCatalogCreation = false,
    this.hasWhatsappAccess = false,
    required this.features,
    this.illustrationAsset,
  });

  final String code;
  final String name;
  final int priceSom;
  final int? priceBricks;
  final int maxPromoPosts;
  final int maxPosts;
  final int maxReels;
  final bool hasBricksAccumulation;
  final bool hasCatalogCreation;
  final bool hasWhatsappAccess;
  final List<TariffFeature> features;
  final String? illustrationAsset;

  bool get isFree => priceSom == 0;
  bool get canPayWithBricks => priceBricks != null && priceBricks! > 0;

  factory TariffPlan.fromJson(Map<String, dynamic> json) {
    final code = json['code'] as String? ?? 'owner';
    final name = json['name'] as String? ?? 'Тариф';
    final priceSom = json['price_som'] as int? ?? json['price'] as int? ?? 0;
    final priceBricks = json['price_bricks'] as int? ?? json['price_bricks_per_month'] as int?;
    final listingsLimit = json['listings_limit'] as int? ?? 5;

    final defaultPlan = kDefaultTariffPlans.firstWhere(
      (p) => p.code == code,
      orElse: () => kDefaultTariffPlans.first,
    );

    return TariffPlan(
      code: code,
      name: name.isNotEmpty ? name : defaultPlan.name,
      priceSom: priceSom > 0 ? priceSom : defaultPlan.priceSom,
      priceBricks: priceBricks ?? defaultPlan.priceBricks,
      maxPromoPosts: defaultPlan.maxPromoPosts,
      maxPosts: listingsLimit > 0 ? listingsLimit : defaultPlan.maxPosts,
      maxReels: defaultPlan.maxReels,
      hasBricksAccumulation: defaultPlan.hasBricksAccumulation,
      hasCatalogCreation: defaultPlan.hasCatalogCreation,
      hasWhatsappAccess: defaultPlan.hasWhatsappAccess,
      features: defaultPlan.features,
      illustrationAsset: defaultPlan.illustrationAsset,
    );
  }
}

/// 4 тарифа строго по макету дизайна
const List<TariffPlan> kDefaultTariffPlans = [
  TariffPlan(
    code: 'owner',
    name: 'Собственник',
    priceSom: 0,
    priceBricks: null,
    maxPromoPosts: 3,
    maxPosts: 5,
    features: [
      TariffFeature(title: 'Продвижение на\nмаксимуме 3 постов', icon: TariffFeatureIcon.promotion, value: 3),
      TariffFeature(title: 'Выкладка до 5 постов', icon: TariffFeatureIcon.posts, value: 5),
    ],
  ),
  TariffPlan(
    code: 'top',
    name: 'TOP',
    priceSom: 1,
    priceBricks: 1,
    maxPromoPosts: 5,
    maxPosts: 15,
    maxReels: 3,
    hasBricksAccumulation: true,
    hasCatalogCreation: true,
    features: [
      TariffFeature(title: 'Продвижение на\nмаксимуме 5 постов', icon: TariffFeatureIcon.promotion, value: 5),
      TariffFeature(title: 'Доступ\n3 видео REELS', icon: TariffFeatureIcon.reels, value: 3),
      TariffFeature(title: 'Накопление\nкирпичей', icon: TariffFeatureIcon.bricks),
      TariffFeature(title: 'Создание каталога', icon: TariffFeatureIcon.catalog),
      TariffFeature(title: 'Выкладка\nдо 15 постов', icon: TariffFeatureIcon.posts, value: 15),
    ],
  ),
  TariffPlan(
    code: 'vip',
    name: 'VIP',
    priceSom: 1,
    priceBricks: 1,
    maxPromoPosts: 15,
    maxPosts: 20,
    maxReels: 3,
    hasBricksAccumulation: true,
    hasCatalogCreation: true,
    hasWhatsappAccess: true,
    features: [
      TariffFeature(title: 'Продвижение на\nмаксимуме 15 постов', icon: TariffFeatureIcon.promotion, value: 15),
      TariffFeature(title: 'Накопление\nкирпичей', icon: TariffFeatureIcon.bricks),
      TariffFeature(title: 'Создание каталога', icon: TariffFeatureIcon.catalog),
      TariffFeature(title: 'Выкладка\nдо 20 постов', icon: TariffFeatureIcon.posts, value: 20),
      TariffFeature(title: 'Доступ к\nWhatsapp', icon: TariffFeatureIcon.whatsapp),
      TariffFeature(title: 'Доступ\n3 видео REELS', icon: TariffFeatureIcon.reels, value: 3),
    ],
  ),
  TariffPlan(
    code: 'premium',
    name: 'Premium',
    priceSom: 1,
    priceBricks: 1,
    maxPromoPosts: 15,
    maxPosts: 20,
    maxReels: 15,
    hasBricksAccumulation: true,
    hasCatalogCreation: true,
    hasWhatsappAccess: true,
    features: [
      TariffFeature(title: 'Продвижение на\nмаксимуме 15 постов', icon: TariffFeatureIcon.promotion, value: 15),
      TariffFeature(title: 'Накопление\nкирпичей', icon: TariffFeatureIcon.bricks),
      TariffFeature(title: 'Создание каталога', icon: TariffFeatureIcon.catalog),
      TariffFeature(title: 'Выкладка\nдо 20 постов', icon: TariffFeatureIcon.posts, value: 20),
      TariffFeature(title: 'Доступ к\nWhatsapp', icon: TariffFeatureIcon.whatsapp),
      TariffFeature(title: 'Доступ\n15 видео REELS', icon: TariffFeatureIcon.reels, value: 15),
    ],
  ),
];
