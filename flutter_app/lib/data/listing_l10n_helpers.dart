import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

String localizedRoomName(AppLocalizations l10n, String roomName) {
  final normalized = roomName.toLowerCase().trim();
  switch (normalized) {
    case 'гостиная':
    case 'гостинная':
      return l10n.addListingRoomLiving;
    case 'кухня':
      return l10n.addListingRoomKitchen;
    case 'спальная':
    case 'спальня':
      return l10n.addListingRoomBedroom;
    case 'балкон':
      return l10n.addListingRoomBalcony;
    case 'сан.узел':
    case 'санузел':
      return l10n.addListingRoomBathroom;
    case 'холл':
      return l10n.addListingRoomHall;
    case 'гардеробная':
      return l10n.addListingRoomWardrobe;
    case 'терраса':
      return l10n.addListingRoomTerrace;
    case 'детская':
      return 'Балдар бөлмөсү'; // Needs to be added to ARB
    default:
      return roomName;
  }
}
