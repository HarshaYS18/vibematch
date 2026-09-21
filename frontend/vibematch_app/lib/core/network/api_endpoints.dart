class ApiEndpoints {
  const ApiEndpoints._();

  static const String localBaseUrl = 'http://127.0.0.1:8000';

  static const String roomsTrending = '/rooms/trending';
  static const String roomsFollowing = '/rooms/following';
  static const String myCreatedRoom = '/rooms/my-created-room';

  static const String homeBanners = '/home-banners';
  static const String homeBannersManage = '/admin/media/banners';
}
