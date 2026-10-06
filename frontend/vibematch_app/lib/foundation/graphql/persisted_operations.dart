/// Immutable Chunk 36 persisted operation IDs.
///
/// These SHA-256 IDs must match apps/graphql-bff/operations.py. Flutter ships
/// IDs and variables only; query text is never constructed by feature code.
abstract final class PersistedGraphqlOperations {
  static const String homeComposite =
      '49caa7816c5a823071f7b812cfcc35b6ee996fe337da55dce98f121c776c16f6';
  static const String profileComposite =
      '84f74379f8353663a757b7d3550e710a352e4a2d6b6b3e9ee1f15cb6681927bf';
  static const String discoveryComposite =
      'f6c1566209c436ef1d2739366111c9b3ca251fb3bb4ed29195fb038c8be0766e';
  static const String creatorAdminDashboard =
      'f54ff76c9aa11351397d600ebf1d9a3faa17e071d4735bcc2604b678b6329f84';
}
