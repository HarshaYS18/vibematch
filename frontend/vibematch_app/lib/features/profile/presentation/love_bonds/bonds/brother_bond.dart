import '../models/love_bond_models.dart';

LoveBondCardData get brotherBond => mockLoveBondCards.firstWhere(
      (bond) => bond.type == LoveBondType.brother,
    );

List<LoveBondTaskData> get brotherBondTasks => tasksForBondType(LoveBondType.brother);
