import 'package:flutter/widgets.dart';
import 'app_localizations.dart';
import '../data/listings.dart';

export 'app_localizations.dart';

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n {
    return Localizations.of<AppLocalizations>(this, AppLocalizations) ??
        lookupAppLocalizations(const Locale('ru'));
  }
}

extension PropertyKindL10n on PropertyKind {
  String labelL10n(BuildContext context) {
    switch (this) {
      case PropertyKind.house:
        return context.l10n.kindHouse;
      case PropertyKind.apartment:
        return context.l10n.kindApartment;
      case PropertyKind.plot:
        return context.l10n.kindPlot;
      case PropertyKind.newBuilding:
        return context.l10n.kindNewBuilding;
      case PropertyKind.room:
        return context.l10n.kindRoom;
      case PropertyKind.commercial:
        return context.l10n.kindCommercial;
    }
  }
}

extension SellerKindL10n on SellerKind {
  String labelL10n(BuildContext context) {
    switch (this) {
      case SellerKind.owner:
        return context.l10n.sellerOwner;
      case SellerKind.realtor:
        return context.l10n.sellerRealtor;
      case SellerKind.agency:
        return context.l10n.sellerAgency;
    }
  }
}
