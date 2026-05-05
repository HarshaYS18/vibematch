import '../models/love_bond_models.dart';

LoveBondCardData get bestieBond => mockLoveBondCards.firstWhere(
      (bond) => bond.type == LoveBondType.bestie,
    );

List<LoveBondTaskData> get bestieBondTasks => tasksForBondType(LoveBondType.bestie);
