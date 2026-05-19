import 'package:flutter/foundation.dart';

import '../presentation/love_bonds/models/love_bond_models.dart';
import 'love_bond_api_service.dart';

enum LoveBondRequestStatus {
  pending,
  accepted,
  rejected,
}

class LoveBondPerson {
  const LoveBondPerson({
    required this.userId,
    required this.publicUserId,
    required this.displayName,
    this.gender,
    this.avatarUrl,
  });

  final String userId;
  final int publicUserId;
  final String displayName;
  final String? gender;
  final String? avatarUrl;

  String get avatarInitial {
    final trimmed = displayName.trim();
    return trimmed.isEmpty ? 'V' : trimmed[0].toUpperCase();
  }

  bool get isMale {
    final value = gender?.trim().toLowerCase();
    return value == 'male' || value == 'boy' || value == 'man';
  }

  bool get isFemale {
    final value = gender?.trim().toLowerCase();
    return value == 'female' || value == 'girl' || value == 'woman';
  }
}

class LoveBondRequest {
  const LoveBondRequest({
    required this.id,
    required this.cardType,
    required this.cardName,
    required this.sender,
    required this.receiver,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final LoveBondType cardType;
  final String cardName;
  final LoveBondPerson sender;
  final LoveBondPerson receiver;
  final LoveBondRequestStatus status;
  final DateTime createdAt;

  LoveBondRequest copyWith({
    LoveBondRequestStatus? status,
  }) {
    return LoveBondRequest(
      id: id,
      cardType: cardType,
      cardName: cardName,
      sender: sender,
      receiver: receiver,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }

  bool involvesPublicUserId(int publicUserId) {
    return sender.publicUserId == publicUserId || receiver.publicUserId == publicUserId;
  }

  LoveBondPerson? ownerFor(int publicUserId) {
    if (sender.publicUserId == publicUserId) return sender;
    if (receiver.publicUserId == publicUserId) return receiver;
    return null;
  }

  LoveBondPerson? partnerFor(int publicUserId) {
    if (sender.publicUserId == publicUserId) return receiver;
    if (receiver.publicUserId == publicUserId) return sender;
    return null;
  }

  String profileTitleFor(int profilePublicUserId) {
    if (cardType == LoveBondType.lover) return 'Lover';
    if (cardType == LoveBondType.bestie) return 'Bestie';

    final partner = partnerFor(profilePublicUserId);
    if (partner == null) return cardName;

    if (partner.isFemale) return 'Sister';
    if (partner.isMale) return 'Brother';

    return cardName.trim().isEmpty ? 'Sibling' : cardName;
  }
}

class LoveBondInventoryItem {
  const LoveBondInventoryItem({
    required this.cardType,
    required this.cardName,
    required this.quantity,
  });

  final LoveBondType cardType;
  final String cardName;
  final int quantity;

  LoveBondInventoryItem copyWith({
    int? quantity,
  }) {
    return LoveBondInventoryItem(
      cardType: cardType,
      cardName: cardName,
      quantity: quantity ?? this.quantity,
    );
  }
}

class LoveBondRealtimeService {
  const LoveBondRealtimeService._();

  static final ValueNotifier<List<LoveBondRequest>> requests =
      ValueNotifier(<LoveBondRequest>[]);

  static final ValueNotifier<Map<int, List<LoveBondInventoryItem>>> inventoryByPublicUserId =
      ValueNotifier(<int, List<LoveBondInventoryItem>>{});

  static final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);

  static List<LoveBondRequest> activeBondsFor(int publicUserId) {
    return requests.value
        .where((request) => request.status == LoveBondRequestStatus.accepted)
        .where((request) => request.involvesPublicUserId(publicUserId))
        .toList(growable: false);
  }

  static List<LoveBondRequest> pendingInboxRequestsFor(int publicUserId) {
    return requests.value
        .where((request) => request.status == LoveBondRequestStatus.pending)
        .where((request) => request.receiver.publicUserId == publicUserId)
        .toList(growable: false);
  }

  static Future<void> syncInventoryFromBackend({
    required int currentPublicUserId,
    LoveBondApiService apiService = const LoveBondApiService(),
  }) async {
    final items = await apiService.getInventory();
    final mapped = items
        .map((item) => LoveBondInventoryItem(
              cardType: _typeFromBackendCardType(item.cardType),
              cardName: item.cardName,
              quantity: item.availableQuantity,
            ))
        .toList(growable: false);

    final next = Map<int, List<LoveBondInventoryItem>>.from(inventoryByPublicUserId.value);
    next[currentPublicUserId] = mapped;
    inventoryByPublicUserId.value = next;
  }

  static Future<void> syncMyBondsFromBackend({
    required int currentUserId,
    required int currentPublicUserId,
    required String currentDisplayName,
    String? currentGender,
    String? currentAvatarUrl,
    LoveBondApiService apiService = const LoveBondApiService(),
  }) async {
    isSyncing.value = true;
    try {
      await syncInventoryFromBackend(
        currentPublicUserId: currentPublicUserId,
        apiService: apiService,
      );

      final bonds = await apiService.listMyBonds();
      final owner = LoveBondPerson(
        userId: currentUserId.toString(),
        publicUserId: currentPublicUserId,
        displayName: currentDisplayName,
        gender: currentGender,
        avatarUrl: currentAvatarUrl,
      );

      final mapped = bonds.map((bond) {
        return _acceptedRequestFromBondDto(
          bond: bond,
          profileOwner: owner,
        );
      }).toList(growable: false);

      _replaceAcceptedBondsForProfile(
        profilePublicUserId: currentPublicUserId,
        acceptedBonds: mapped,
      );
    } finally {
      isSyncing.value = false;
    }
  }

  static Future<void> syncPublicBondsFromBackend({
    required int profilePublicUserId,
    LoveBondApiService apiService = const LoveBondApiService(),
  }) async {
    isSyncing.value = true;
    try {
      final bonds = await apiService.listPublicBonds(profilePublicUserId);
      final profileOwner = LoveBondPerson(
        userId: profilePublicUserId.toString(),
        publicUserId: profilePublicUserId,
        displayName: 'Vibe User',
      );

      final mapped = bonds.map((bond) {
        return _acceptedRequestFromBondDto(
          bond: bond,
          profileOwner: profileOwner,
        );
      }).toList(growable: false);

      _replaceAcceptedBondsForProfile(
        profilePublicUserId: profilePublicUserId,
        acceptedBonds: mapped,
      );
    } finally {
      isSyncing.value = false;
    }
  }

  static void seedInventoryIfEmpty(int publicUserId) {
    if (inventoryByPublicUserId.value.containsKey(publicUserId)) return;

    final next = Map<int, List<LoveBondInventoryItem>>.from(inventoryByPublicUserId.value);
    next[publicUserId] = const <LoveBondInventoryItem>[];
    inventoryByPublicUserId.value = next;
  }

  static bool hasCard({
    required int ownerPublicUserId,
    required LoveBondType cardType,
  }) {
    seedInventoryIfEmpty(ownerPublicUserId);
    final normalizedCardType = _inventoryCardType(cardType);
    return inventoryByPublicUserId.value[ownerPublicUserId]
            ?.any((item) => _inventoryCardType(item.cardType) == normalizedCardType && item.quantity > 0) ??
        false;
  }

  static Future<LoveBondRequest> sendRequestToBackend({
    required LoveBondType cardType,
    required int receiverPublicUserId,
    LoveBondApiService apiService = const LoveBondApiService(),
  }) async {
    final dto = await apiService.sendRequest(
      receiverPublicUserId: receiverPublicUserId,
      cardType: _backendCardType(cardType),
    );

    final request = LoveBondRequest(
      id: dto.id,
      cardType: _typeFromBackendCardType(dto.cardType),
      cardName: dto.cardName,
      sender: LoveBondPerson(
        userId: dto.senderPublicUserId.toString(),
        publicUserId: dto.senderPublicUserId,
        displayName: dto.senderName,
      ),
      receiver: LoveBondPerson(
        userId: dto.receiverPublicUserId.toString(),
        publicUserId: dto.receiverPublicUserId,
        displayName: dto.receiverName,
      ),
      status: _statusFromBackend(dto.status),
      createdAt: DateTime.tryParse(dto.createdAt ?? '') ?? DateTime.now(),
    );

    _upsertRequest(request);
    await syncInventoryFromBackend(currentPublicUserId: dto.senderPublicUserId, apiService: apiService);
    return request;
  }

  static Future<void> acceptRequestOnBackend({
    required String requestId,
    required int receiverPublicUserId,
    LoveBondApiService apiService = const LoveBondApiService(),
  }) async {
    await apiService.acceptRequest(requestId);
    _setRequestStatus(requestId, LoveBondRequestStatus.accepted);
    await syncPublicBondsFromBackend(profilePublicUserId: receiverPublicUserId, apiService: apiService);
  }

  static Future<void> rejectRequestOnBackend({
    required String requestId,
    required int receiverPublicUserId,
    LoveBondApiService apiService = const LoveBondApiService(),
  }) async {
    final dto = await apiService.rejectRequest(requestId);
    _setRequestStatus(requestId, LoveBondRequestStatus.rejected);
    await syncInventoryFromBackend(currentPublicUserId: dto.senderPublicUserId, apiService: apiService);
    await syncPublicBondsFromBackend(profilePublicUserId: receiverPublicUserId, apiService: apiService);
  }

  static LoveBondRequest sendRequest({
    required LoveBondType cardType,
    required String cardName,
    required LoveBondPerson sender,
    required LoveBondPerson receiver,
  }) {
    seedInventoryIfEmpty(sender.publicUserId);

    final normalizedCardType = _inventoryCardType(cardType);
    if (!hasCard(ownerPublicUserId: sender.publicUserId, cardType: normalizedCardType)) {
      throw StateError('You do not own this relationship card.');
    }

    final existingPending = requests.value.where((request) {
      return request.status == LoveBondRequestStatus.pending &&
          _inventoryCardType(request.cardType) == normalizedCardType &&
          request.sender.publicUserId == sender.publicUserId &&
          request.receiver.publicUserId == receiver.publicUserId;
    }).isNotEmpty;

    if (existingPending) {
      throw StateError('Request already pending.');
    }

    _decreaseInventory(ownerPublicUserId: sender.publicUserId, cardType: normalizedCardType);

    final request = LoveBondRequest(
      id: 'love_bond_${DateTime.now().microsecondsSinceEpoch}',
      cardType: normalizedCardType,
      cardName: normalizedCardType == LoveBondType.brother ? 'Sibling' : cardName,
      sender: sender,
      receiver: receiver,
      status: LoveBondRequestStatus.pending,
      createdAt: DateTime.now(),
    );

    requests.value = [...requests.value, request];
    return request;
  }

  static void acceptRequest(String requestId) {
    _setRequestStatus(requestId, LoveBondRequestStatus.accepted);
  }

  static void rejectRequest(String requestId) {
    final request = requests.value.where((item) => item.id == requestId).firstOrNull;
    if (request == null || request.status != LoveBondRequestStatus.pending) return;

    _increaseInventory(
      ownerPublicUserId: request.sender.publicUserId,
      cardType: _inventoryCardType(request.cardType),
    );
    _setRequestStatus(requestId, LoveBondRequestStatus.rejected);
  }

  static LoveBondRequest _acceptedRequestFromBondDto({
    required LoveBondDto bond,
    required LoveBondPerson profileOwner,
  }) {
    final partner = LoveBondPerson(
      userId: bond.partnerPublicUserId.toString(),
      publicUserId: bond.partnerPublicUserId,
      displayName: bond.partnerName,
      gender: bond.partnerGender,
      avatarUrl: bond.partnerAvatarUrl,
    );

    return LoveBondRequest(
      id: bond.id,
      cardType: _typeFromBackendCardType(bond.cardType),
      cardName: bond.cardType == 'sibling' ? 'Sibling' : bond.cardType,
      sender: profileOwner,
      receiver: partner,
      status: LoveBondRequestStatus.accepted,
      createdAt: DateTime.tryParse(bond.startedAt ?? '') ?? DateTime.now(),
    );
  }

  static void _replaceAcceptedBondsForProfile({
    required int profilePublicUserId,
    required List<LoveBondRequest> acceptedBonds,
  }) {
    final current = requests.value.where((request) {
      final isAcceptedForProfile = request.status == LoveBondRequestStatus.accepted &&
          request.involvesPublicUserId(profilePublicUserId);
      return !isAcceptedForProfile;
    }).toList(growable: true);

    current.addAll(acceptedBonds);
    requests.value = current;
  }

  static void _upsertRequest(LoveBondRequest request) {
    final next = [...requests.value];
    final index = next.indexWhere((item) => item.id == request.id);
    if (index == -1) {
      next.insert(0, request);
    } else {
      next[index] = request;
    }
    requests.value = next;
  }

  static LoveBondType _inventoryCardType(LoveBondType type) {
    if (type == LoveBondType.sister) return LoveBondType.brother;
    return type;
  }

  static LoveBondType _typeFromBackendCardType(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'love' || normalized == 'lover') return LoveBondType.lover;
    if (normalized == 'bestie') return LoveBondType.bestie;
    if (normalized == 'sister') return LoveBondType.sister;
    return LoveBondType.brother;
  }

  static String _backendCardType(LoveBondType type) {
    return switch (_inventoryCardType(type)) {
      LoveBondType.lover => 'love',
      LoveBondType.bestie => 'bestie',
      LoveBondType.brother => 'sibling',
      LoveBondType.sister => 'sibling',
    };
  }

  static LoveBondRequestStatus _statusFromBackend(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'accepted') return LoveBondRequestStatus.accepted;
    if (normalized == 'rejected') return LoveBondRequestStatus.rejected;
    return LoveBondRequestStatus.pending;
  }

  static void _setRequestStatus(String requestId, LoveBondRequestStatus status) {
    requests.value = requests.value.map((request) {
      if (request.id != requestId) return request;
      return request.copyWith(status: status);
    }).toList(growable: false);
  }

  static void _decreaseInventory({
    required int ownerPublicUserId,
    required LoveBondType cardType,
  }) {
    final current = [...(inventoryByPublicUserId.value[ownerPublicUserId] ?? const <LoveBondInventoryItem>[])];
    final normalizedCardType = _inventoryCardType(cardType);

    final nextItems = current.map((item) {
      if (_inventoryCardType(item.cardType) != normalizedCardType) return item;
      return item.copyWith(quantity: (item.quantity - 1).clamp(0, 999999));
    }).toList(growable: false);

    final next = Map<int, List<LoveBondInventoryItem>>.from(inventoryByPublicUserId.value);
    next[ownerPublicUserId] = nextItems;
    inventoryByPublicUserId.value = next;
  }

  static void _increaseInventory({
    required int ownerPublicUserId,
    required LoveBondType cardType,
  }) {
    seedInventoryIfEmpty(ownerPublicUserId);
    final current = [...(inventoryByPublicUserId.value[ownerPublicUserId] ?? const <LoveBondInventoryItem>[])];
    final normalizedCardType = _inventoryCardType(cardType);
    var found = false;

    final nextItems = current.map((item) {
      if (_inventoryCardType(item.cardType) != normalizedCardType) return item;
      found = true;
      return item.copyWith(quantity: item.quantity + 1);
    }).toList(growable: false);

    final finalItems = found
        ? nextItems
        : [
            ...nextItems,
            LoveBondInventoryItem(
              cardType: normalizedCardType,
              cardName: normalizedCardType == LoveBondType.brother ? 'Sibling' : normalizedCardType.defaultTitle,
              quantity: 1,
            ),
          ];

    final next = Map<int, List<LoveBondInventoryItem>>.from(inventoryByPublicUserId.value);
    next[ownerPublicUserId] = finalItems;
    inventoryByPublicUserId.value = next;
  }
}
