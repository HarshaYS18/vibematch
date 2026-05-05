import '../models/love_bond_models.dart';

LoveBondCardData get loverBond => mockLoveBondCards.firstWhere(
      (bond) => bond.type == LoveBondType.lover,
    );

List<LoveBondTaskData> get loverBondTasks => tasksForBondType(LoveBondType.lover);
