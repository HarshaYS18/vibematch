import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  LoveBondRequest copyWith({LoveBondRequestStatus? status}) {
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
    return sender.publicUserId == publicUserId ||
        receiver.publicUserId == publicUserId;
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

  LoveBondInventoryItem copyWith({int? quantity}) {
    return LoveBondInventoryItem(
      cardType: cardType,
      cardName: cardName,
      quantity: quantity ?? this.quantity,
    );
  }
}

/// Immutable session-wide client projection of Love Bond backend state.
///
/// Backend APIs remain authoritative. This state only caches the current
/// session's fetched requests/inventory plus synchronization status.
class LoveBondRealtimeState {
  const LoveBondRealtimeState({
    this.requests = const <LoveBondRequest>[],
    this.inventoryByPublicUserId =
        const <int, List<LoveBondInventoryItem>>{},
    this.isSyncing = false,
  });

  final List<LoveBondRequest> requests;
  final Map<int, List<LoveBondInventoryItem>> inventoryByPublicUserId;
  final bool isSyncing;

  LoveBondRealtimeState copyWith({
    List<LoveBondRequest>? requests,
    Map<int, List<LoveBondInventoryItem>>? inventoryByPublicUserId,
    bool? isSyncing,
  }) {
    return LoveBondRealtimeState(
      requests: requests ?? this.requests,
      inventoryByPublicUserId:
          inventoryByPublicUserId ?? this.inventoryByPublicUserId,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }
}

/// Riverpod owner for Love Bond request/inventory synchronization.
///
/// Lifecycle: app/session scoped (non-auto-dispose) because profile surfaces,
/// inbox-style request UI and public-profile panels may observe the same
/// backend projection. No static mutable notifier or feature event bus exists.
class LoveBondRealtimeController extends Notifier<LoveBondRealtimeState> {
  @override
  LoveBondRealtimeState build() => const LoveBondRealtimeState();

  List<LoveBondRequest> activeBondsFor(int publicUserId) {
    return state.requests
        .where((request) => request.status == LoveBondRequestStatus.accepted)
        .where((request) => request.involvesPublicUserId(publicUserId))
        .toList(growable: false);
  }

  List<LoveBondRequest> pendingInboxRequestsFor(int publicUserId) {
    return state.requests
        .where((request) => request.status == LoveBondRequestStatus.pending)
        .where((request) => request.receiver.publicUserId == publicUserId)
        .toList(growable: false);
  }

  Future<void> syncInventoryFromBackend({
    required int currentPublicUserId,
    LoveBondApiService apiService = const LoveBondApiService(),
  }) async {
    final items = await apiService.getInventory();
    final mapped = items
        .map(
          (item) => LoveBondInventoryItem(
            cardType: _typeFromBackendCardType(item.cardType),
            cardName: item.cardName,
            quantity: item.availableQuantity,
          ),
        )
        .toList(growable: false);

    final next = Map<int, List<LoveBondInventoryItem>>.from(
      state.inventoryByPublicUserId,
    );
    next[currentPublicUserId] = mapped;
    state = state.copyWith(inventoryByPublicUserId: next);
  }

  Future<void> syncMyBondsFromBackend({
    required int currentUserId,
    required int currentPublicUserId,
    required String currentDisplayName,
    String? currentGender,
    String? currentAvatarUrl,
    LoveBondApiService apiService = const LoveBondApiService(),
  }) async {
    state = state.copyWith(isSyncing: true);
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
      final mapped = bonds
          .map((bond) => _acceptedRequestFromBondDto(
                bond: bond,
                profileOwner: owner,
              ))
          .toList(growable: false);
      _replaceAcceptedBondsForProfile(
        profilePublicUserId: currentPublicUserId,
        acceptedBonds: mapped,
      );
    } finally {
      state = state.copyWith(isSyncing: false);
    }
  }

  Future<void> syncPublicBondsFromBackend({
    required int profilePublicUserId,
    LoveBondApiService apiService = const LoveBondApiService(),
  }) async {
    state = state.copyWith(isSyncing: true);
    try {
      final bonds = await apiService.listPublicBonds(profilePublicUserId);
      final profileOwner = LoveBondPerson(
        userId: profilePublicUserId.toString(),
        publicUserId: profilePublicUserId,
        displayName: 'Vibe User',
      );
      final mapped = bonds
          .map((bond) => _acceptedRequestFromBondDto(
                bond: bond,
                profileOwner: profileOwner,
              ))
          .toList(growable: false);
      _replaceAcceptedBondsForProfile(
        profilePublicUserId: profilePublicUserId,
        acceptedBonds: mapped,
      );
    } finally {
      state = state.copyWith(isSyncing: false);
    }
  }

  void seedInventoryIfEmpty(int publicUserId) {
    if (state.inventoryByPublicUserId.containsKey(publicUserId)) return;
    final next = Map<int, List<LoveBondInventoryItem>>.from(
      state.inventoryByPublicUserId,
    );
    next[publicUserId] = const <LoveBondInventoryItem>[];
    state = state.copyWith(inventoryByPublicUserId: next);
  }

  bool hasCard({
    required int ownerPublicUserId,
    required LoveBondType cardType,
  }) {
    seedInventoryIfEmpty(ownerPublicUserId);
    final normalizedCardType = _inventoryCardType(cardType);
    return state.inventoryByPublicUserId[ownerPublicUserId]?.any(
              (item) =>
                  _inventoryCardType(item.cardType) == normalizedCardType &&
                  item.quantity > 0,
            ) ??
        false;
  }

  Future<LoveBondRequest> sendRequestToBackend({
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
    await syncInventoryFromBackend(
      currentPublicUserId: dto.senderPublicUserId,
      apiService: apiService,
    );
    return request;
  }

  Future<void> acceptRequestOnBackend({
    required String requestId,
    required int receiverPublicUserId,
    LoveBondApiService apiService = const LoveBondApiService(),
  }) async {
    await apiService.acceptRequest(requestId);
    _setRequestStatus(requestId, LoveBondRequestStatus.accepted);
    await syncPublicBondsFromBackend(
      profilePublicUserId: receiverPublicUserId,
      apiService: apiService,
    );
  }

  Future<void> rejectRequestOnBackend({
    required String requestId,
    required int receiverPublicUserId,
    LoveBondApiService apiService = const LoveBondApiService(),
  }) async {
    final dto = await apiService.rejectRequest(requestId);
    _setRequestStatus(requestId, LoveBondRequestStatus.rejected);
    await syncInventoryFromBackend(
      currentPublicUserId: dto.senderPublicUserId,
      apiService: apiService,
    );
    await syncPublicBondsFromBackend(
      profilePublicUserId: receiverPublicUserId,
      apiService: apiService,
    );
  }

  LoveBondRequest sendRequest({
    required LoveBondType cardType,
    required String cardName,
    required LoveBondPerson sender,
    required LoveBondPerson receiver,
  }) {
    seedInventoryIfEmpty(sender.publicUserId);
    final normalizedCardType = _inventoryCardType(cardType);
    if (!hasCard(
      ownerPublicUserId: sender.publicUserId,
      cardType: normalizedCardType,
    )) {
      throw StateError('You do not own this relationship card.');
    }

    final existingPending = state.requests.any((request) =>
        request.status == LoveBondRequestStatus.pending &&
        _inventoryCardType(request.cardType) == normalizedCardType &&
        request.sender.publicUserId == sender.publicUserId &&
        request.receiver.publicUserId == receiver.publicUserId);
    if (existingPending) throw StateError('Request already pending.');

    _decreaseInventory(
      ownerPublicUserId: sender.publicUserId,
      cardType: normalizedCardType,
    );
    final request = LoveBondRequest(
      id: 'love_bond_${DateTime.now().microsecondsSinceEpoch}',
      cardType: normalizedCardType,
      cardName:
          normalizedCardType == LoveBondType.brother ? 'Sibling' : cardName,
      sender: sender,
      receiver: receiver,
      status: LoveBondRequestStatus.pending,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(requests: [...state.requests, request]);
    return request;
  }

  void acceptRequest(String requestId) {
    _setRequestStatus(requestId, LoveBondRequestStatus.accepted);
  }

  void rejectRequest(String requestId) {
    final request = state.requests.where((item) => item.id == requestId).firstOrNull;
    if (request == null || request.status != LoveBondRequestStatus.pending) {
      return;
    }
    _increaseInventory(
      ownerPublicUserId: request.sender.publicUserId,
      cardType: _inventoryCardType(request.cardType),
    );
    _setRequestStatus(requestId, LoveBondRequestStatus.rejected);
  }

  LoveBondRequest _acceptedRequestFromBondDto({
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

  void _replaceAcceptedBondsForProfile({
    required int profilePublicUserId,
    required List<LoveBondRequest> acceptedBonds,
  }) {
    final current = state.requests.where((request) {
      final isAcceptedForProfile =
          request.status == LoveBondRequestStatus.accepted &&
          request.involvesPublicUserId(profilePublicUserId);
      return !isAcceptedForProfile;
    }).toList(growable: true)
      ..addAll(acceptedBonds);
    state = state.copyWith(requests: current);
  }

  void _upsertRequest(LoveBondRequest request) {
    final next = [...state.requests];
    final index = next.indexWhere((item) => item.id == request.id);
    if (index == -1) {
      next.insert(0, request);
    } else {
      next[index] = request;
    }
    state = state.copyWith(requests: next);
  }

  static LoveBondType _inventoryCardType(LoveBondType type) {
    return type == LoveBondType.sister ? LoveBondType.brother : type;
  }

  static LoveBondType _typeFromBackendCardType(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'love' || normalized == 'lover') {
      return LoveBondType.lover;
    }
    if (normalized == 'bestie') return LoveBondType.bestie;
    if (normalized == 'sister') return LoveBondType.sister;
    return LoveBondType.brother;
  }

  static String _backendCardType(LoveBondType type) {
    return switch (_inventoryCardType(type)) {
      LoveBondType.lover => 'love',
      LoveBondType.bestie => 'bestie',
      LoveBondType.brother || LoveBondType.sister => 'sibling',
    };
  }

  static LoveBondRequestStatus _statusFromBackend(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'accepted') return LoveBondRequestStatus.accepted;
    if (normalized == 'rejected') return LoveBondRequestStatus.rejected;
    return LoveBondRequestStatus.pending;
  }

  void _setRequestStatus(String requestId, LoveBondRequestStatus status) {
    state = state.copyWith(
      requests: state.requests
          .map((request) =>
              request.id == requestId ? request.copyWith(status: status) : request)
          .toList(growable: false),
    );
  }

  void _decreaseInventory({
    required int ownerPublicUserId,
    required LoveBondType cardType,
  }) {
    final current = [
      ...(state.inventoryByPublicUserId[ownerPublicUserId] ??
          const <LoveBondInventoryItem>[]),
    ];
    final normalizedCardType = _inventoryCardType(cardType);
    final nextItems = current
        .map((item) => _inventoryCardType(item.cardType) != normalizedCardType
            ? item
            : item.copyWith(quantity: (item.quantity - 1).clamp(0, 999999)))
        .toList(growable: false);
    final next = Map<int, List<LoveBondInventoryItem>>.from(
      state.inventoryByPublicUserId,
    );
    next[ownerPublicUserId] = nextItems;
    state = state.copyWith(inventoryByPublicUserId: next);
  }

  void _increaseInventory({
    required int ownerPublicUserId,
    required LoveBondType cardType,
  }) {
    seedInventoryIfEmpty(ownerPublicUserId);
    final current = [
      ...(state.inventoryByPublicUserId[ownerPublicUserId] ??
          const <LoveBondInventoryItem>[]),
    ];
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
              cardName: normalizedCardType == LoveBondType.brother
                  ? 'Sibling'
                  : normalizedCardType.defaultTitle,
              quantity: 1,
            ),
          ];
    final next = Map<int, List<LoveBondInventoryItem>>.from(
      state.inventoryByPublicUserId,
    );
    next[ownerPublicUserId] = finalItems;
    state = state.copyWith(inventoryByPublicUserId: next);
  }
}

/// Session-scoped Love Bond provider shared by profile/inbox presentation.
final loveBondRealtimeProvider =
    NotifierProvider<LoveBondRealtimeController, LoveBondRealtimeState>(
      LoveBondRealtimeController.new,
    );
