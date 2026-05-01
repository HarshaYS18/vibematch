class HomeAccessController {
  const HomeAccessController({required this.activeUser});

  final Object? activeUser;

  bool get canManageHighlights {
    try {
      final dynamic user = activeUser;
      final primaryRole = user?.primaryRole?.toString().toLowerCase();
      final roles = user?.roles;

      if (primaryRole == 'founder_owner' ||
          primaryRole == 'super_owner' ||
          primaryRole == 'owner') {
        return true;
      }

      if (roles is Iterable) {
        return roles.any((role) {
          final normalized = role.toString().toLowerCase();
          return normalized == 'founder_owner' ||
              normalized == 'super_owner' ||
              normalized == 'owner';
        });
      }
    } catch (_) {
      return false;
    }

    return false;
  }
}
