enum SearchResultType {
  user('Users'),
  room('Rooms'),
  vibe('Vibes');

  const SearchResultType(this.label);

  final String label;
}

enum SearchResultCategory {
  all('All'),
  users('Users'),
  rooms('Rooms'),
  vibes('Vibes');

  const SearchResultCategory(this.label);

  final String label;
}
