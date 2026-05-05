import '../models/love_bond_models.dart';

LoveBondCardData get sisterBond => mockLoveBondCards.firstWhere(
      (bond) => bond.type == LoveBondType.sister,
    );

List<LoveBondTaskData> get sisterBondTasks => tasksForBondType(LoveBondType.sister);
