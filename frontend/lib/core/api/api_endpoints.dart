class ApiEndpoints {
  // Auth
  static const String register = '/auth/register/';
  static const String login = '/auth/login/';
  static const String refresh = '/auth/refresh/';
  static const String profile = '/auth/profile/';
  static const String otpSend = '/auth/otp/send/';

  // Reports
  static const String reports = '/reports/';
  static String reportDetail(int id) => '/reports/$id/';
  static String reportVote(int id) => '/reports/$id/vote/';
  static const String reportClusters = '/reports/clusters/';

  // Map
  static const String mapLayers = '/map/layers/';
  static String villageBoundary(int id) => '/map/village/$id/boundary/';
  static const String infrastructure = '/map/infrastructure/';

  // AI
  static const String transcribe = '/ai/transcribe/';
  static String transcribeStatus(int id) => '/ai/transcribe/$id/';
  static const String priorities = '/ai/priorities/';
  static const String recommendations = '/ai/recommendations/';
  static String scoreDetail(int id) => '/ai/score/$id/';
  static const String schemeQuery = '/ai/scheme-query/';

  // Projects
  static const String projects = '/projects/';
  static String projectDetail(int id) => '/projects/$id/';
  static String projectPhotos(int id) => '/projects/$id/photos/';
  static String projectRating(int id) => '/projects/$id/rating/';
  static const String projectAdopt = '/projects/adopt/';
  static String projectStatus(int id) => '/projects/$id/update_status/';

  // Dashboard
  static const String dashboardSummary = '/dashboard/summary/';
  static const String dashboardFundStatus = '/dashboard/fund-status/';

  // Schemes
  static const String schemes = '/schemes/';

  // Villages
  static const String villages = '/villages/';

  // Gram Sabha
  static const String gramSabha = '/gramsabha/';
  static const String gramSabhaIssues = '/gramsabha-issues/';
}
