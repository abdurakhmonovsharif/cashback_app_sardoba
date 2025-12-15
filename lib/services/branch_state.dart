import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

import '../app_language.dart';
import '../models/branch.dart';

class BranchState extends ChangeNotifier {
  BranchState._()
      : _branches = [
          Branch(
            id: 'sardoba-geofizika',
            storeId: 139235,
            name: 'Sardoba (Geofizika)',
            address: 'ул. Дехмирзайон, 12',
            localizedAddresses: const {
              AppLocale.uz: "Dehmirzayon ko'chasi, 12",
              AppLocale.ru: 'ул. Дехмирзайон, 12',
            },
            point: const Point(latitude: 39.740148, longitude: 64.494980),
          ),
          Branch(
            id: 'sardoba-gijdivon',
            storeId: 157757,
            name: 'Sardoba (Gʻijdivon)',
            address: 'Гиждуванский район, Бухарская область',
            localizedAddresses: const {
              AppLocale.uz: 'Gʻijdivon tumani, Buxoro viloyati',
              AppLocale.ru: 'Гиждуванский район, Бухарская область',
            },
            point: const Point(latitude: 40.084355, longitude: 64.684085),
          ),
          Branch(
            id: 'sardoba-severniy',
            storeId: 139350,
            name: 'Sardoba (Severniy)',
            address: 'ул. Дилькушо 2Б, 200100, Бухара, Республика Узбекистан',
            localizedAddresses: const {
              AppLocale.ru:
                  'ул. Дилькушо 2Б, 200100, Бухара, Республика Узбекистан',
              AppLocale.uz:
                  "Dilqusho ko'chasi 2B, 200100, Buxoro, Oʻzbekiston Respublikasi",
            },
            point: const Point(latitude: 39.781381, longitude: 64.435121),
          ),
          Branch(
            id: 'sardoba-mk5',
            storeId: 139458,
            name: 'Sardoba (MK-5)',
            address: 'ул. Пири Дастгир, 10/2',
            localizedAddresses: const {
              AppLocale.uz: "Piri Dastgir ko'chasi, 10/2",
              AppLocale.ru: 'ул. Пири Дастгир, 10/2',
            },
            point: const Point(latitude: 39.748616, longitude: 64.422795),
          ),
        ] {
    _activeBranch = _branches.first;
  }

  static final BranchState instance = BranchState._();

  final List<Branch> _branches;
  late Branch _activeBranch;

  UnmodifiableListView<Branch> get branches =>
      UnmodifiableListView<Branch>(_branches);

  Branch get activeBranch => _activeBranch;

  void selectBranch(Branch branch) {
    if (_activeBranch.id == branch.id) return;
    _activeBranch = branch;
    notifyListeners();
  }

  void selectBranchById(String id) {
    final match = _branches.where((branch) => branch.id == id);
    if (match.isEmpty) return;
    selectBranch(match.first);
  }
}
