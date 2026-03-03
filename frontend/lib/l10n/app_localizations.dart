import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';
import 'app_localizations_gu.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_kn.dart';
import 'app_localizations_ml.dart';
import 'app_localizations_mr.dart';
import 'app_localizations_or.dart';
import 'app_localizations_pa.dart';
import 'app_localizations_ta.dart';
import 'app_localizations_te.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en'),
    Locale('gu'),
    Locale('hi'),
    Locale('kn'),
    Locale('ml'),
    Locale('mr'),
    Locale('or'),
    Locale('pa'),
    Locale('ta'),
    Locale('te')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'PrajaShakti AI'**
  String get appTitle;

  /// No description provided for @mapLayers.
  ///
  /// In en, this message translates to:
  /// **'Map Layers'**
  String get mapLayers;

  /// No description provided for @layerReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get layerReports;

  /// No description provided for @layerSatellite.
  ///
  /// In en, this message translates to:
  /// **'Satellite'**
  String get layerSatellite;

  /// No description provided for @layerInfra.
  ///
  /// In en, this message translates to:
  /// **'Infra'**
  String get layerInfra;

  /// No description provided for @layerHeatmap.
  ///
  /// In en, this message translates to:
  /// **'Heatmap'**
  String get layerHeatmap;

  /// No description provided for @layerProjects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get layerProjects;

  /// No description provided for @layerFunds.
  ///
  /// In en, this message translates to:
  /// **'Funds'**
  String get layerFunds;

  /// No description provided for @layerPeople.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get layerPeople;

  /// No description provided for @priority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get priority;

  /// No description provided for @fundsAvailable.
  ///
  /// In en, this message translates to:
  /// **'available'**
  String get fundsAvailable;

  /// No description provided for @demographics.
  ///
  /// In en, this message translates to:
  /// **'Demographics'**
  String get demographics;

  /// No description provided for @population.
  ///
  /// In en, this message translates to:
  /// **'Population'**
  String get population;

  /// No description provided for @households.
  ///
  /// In en, this message translates to:
  /// **'Households'**
  String get households;

  /// No description provided for @agriHouseholds.
  ///
  /// In en, this message translates to:
  /// **'Agri HH'**
  String get agriHouseholds;

  /// No description provided for @groundwater.
  ///
  /// In en, this message translates to:
  /// **'Groundwater'**
  String get groundwater;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @panchayat.
  ///
  /// In en, this message translates to:
  /// **'Panchayat'**
  String get panchayat;

  /// No description provided for @ward.
  ///
  /// In en, this message translates to:
  /// **'Ward'**
  String get ward;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @leaderDashboard.
  ///
  /// In en, this message translates to:
  /// **'Leader Dashboard'**
  String get leaderDashboard;

  /// No description provided for @openLeaderDashboard.
  ///
  /// In en, this message translates to:
  /// **'Open Leader Dashboard'**
  String get openLeaderDashboard;

  /// No description provided for @villageIntelligenceMap.
  ///
  /// In en, this message translates to:
  /// **'Village Intelligence Map'**
  String get villageIntelligenceMap;

  /// No description provided for @coordinates.
  ///
  /// In en, this message translates to:
  /// **'Coordinates'**
  String get coordinates;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @infraSchool.
  ///
  /// In en, this message translates to:
  /// **'School'**
  String get infraSchool;

  /// No description provided for @infraHospital.
  ///
  /// In en, this message translates to:
  /// **'Hospital / Health Centre'**
  String get infraHospital;

  /// No description provided for @infraMarket.
  ///
  /// In en, this message translates to:
  /// **'Market / Haat'**
  String get infraMarket;

  /// No description provided for @infraWaterSource.
  ///
  /// In en, this message translates to:
  /// **'Water Source'**
  String get infraWaterSource;

  /// No description provided for @infraRoad.
  ///
  /// In en, this message translates to:
  /// **'Road'**
  String get infraRoad;

  /// No description provided for @changeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Change Language'**
  String get changeLanguage;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @profileNotFound.
  ///
  /// In en, this message translates to:
  /// **'Profile not found'**
  String get profileNotFound;

  /// No description provided for @citizen.
  ///
  /// In en, this message translates to:
  /// **'CITIZEN'**
  String get citizen;

  /// No description provided for @leader.
  ///
  /// In en, this message translates to:
  /// **'LEADER'**
  String get leader;

  /// No description provided for @reportIssue.
  ///
  /// In en, this message translates to:
  /// **'Report Issue'**
  String get reportIssue;

  /// No description provided for @gramSabha.
  ///
  /// In en, this message translates to:
  /// **'Gram Sabha'**
  String get gramSabha;

  /// No description provided for @schemes.
  ///
  /// In en, this message translates to:
  /// **'Schemes'**
  String get schemes;

  /// No description provided for @communityFeed.
  ///
  /// In en, this message translates to:
  /// **'Community Feed'**
  String get communityFeed;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @sendOtp.
  ///
  /// In en, this message translates to:
  /// **'Send OTP'**
  String get sendOtp;

  /// No description provided for @verifyOtp.
  ///
  /// In en, this message translates to:
  /// **'Verify OTP'**
  String get verifyOtp;

  /// No description provided for @enterPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter phone number'**
  String get enterPhone;

  /// No description provided for @enterOtp.
  ///
  /// In en, this message translates to:
  /// **'Enter OTP'**
  String get enterOtp;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get error;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @vote.
  ///
  /// In en, this message translates to:
  /// **'Vote'**
  String get vote;

  /// No description provided for @votes.
  ///
  /// In en, this message translates to:
  /// **'votes'**
  String get votes;

  /// No description provided for @reported.
  ///
  /// In en, this message translates to:
  /// **'Reported'**
  String get reported;

  /// No description provided for @adopted.
  ///
  /// In en, this message translates to:
  /// **'Adopted'**
  String get adopted;

  /// No description provided for @inProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get inProgress;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @delayed.
  ///
  /// In en, this message translates to:
  /// **'Delayed'**
  String get delayed;

  /// No description provided for @water.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get water;

  /// No description provided for @road.
  ///
  /// In en, this message translates to:
  /// **'Road'**
  String get road;

  /// No description provided for @health.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get health;

  /// No description provided for @education.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get education;

  /// No description provided for @electricity.
  ///
  /// In en, this message translates to:
  /// **'Electricity'**
  String get electricity;

  /// No description provided for @sanitation.
  ///
  /// In en, this message translates to:
  /// **'Sanitation'**
  String get sanitation;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @score.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get score;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @projects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get projects;

  /// No description provided for @noReports.
  ///
  /// In en, this message translates to:
  /// **'No reports yet'**
  String get noReports;

  /// No description provided for @noProjects.
  ///
  /// In en, this message translates to:
  /// **'No projects yet'**
  String get noProjects;

  /// No description provided for @navMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get navMap;

  /// No description provided for @navReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get navReport;

  /// No description provided for @navFeed.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get navFeed;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navGovDashboard.
  ///
  /// In en, this message translates to:
  /// **'Gov Dashboard'**
  String get navGovDashboard;

  /// No description provided for @navGramSabha.
  ///
  /// In en, this message translates to:
  /// **'Gram Sabha'**
  String get navGramSabha;

  /// No description provided for @navProjects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get navProjects;

  /// No description provided for @navSchemes.
  ///
  /// In en, this message translates to:
  /// **'Schemes'**
  String get navSchemes;

  /// No description provided for @navManageUsers.
  ///
  /// In en, this message translates to:
  /// **'Manage Users'**
  String get navManageUsers;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @reportDetails.
  ///
  /// In en, this message translates to:
  /// **'Report Details'**
  String get reportDetails;

  /// No description provided for @projectDetails.
  ///
  /// In en, this message translates to:
  /// **'Project Details'**
  String get projectDetails;

  /// No description provided for @otpVerification.
  ///
  /// In en, this message translates to:
  /// **'OTP Verification'**
  String get otpVerification;

  /// No description provided for @newGramSabha.
  ///
  /// In en, this message translates to:
  /// **'New Gram Sabha'**
  String get newGramSabha;

  /// No description provided for @raiseIssue.
  ///
  /// In en, this message translates to:
  /// **'Raise Issue'**
  String get raiseIssue;

  /// No description provided for @adoptProject.
  ///
  /// In en, this message translates to:
  /// **'Adopt Project'**
  String get adoptProject;

  /// No description provided for @schemeAdvisor.
  ///
  /// In en, this message translates to:
  /// **'Scheme Advisor'**
  String get schemeAdvisor;

  /// No description provided for @aiPoweredSchemeAdvisor.
  ///
  /// In en, this message translates to:
  /// **'AI-powered scheme advisor'**
  String get aiPoweredSchemeAdvisor;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @issueType.
  ///
  /// In en, this message translates to:
  /// **'Type of Issue'**
  String get issueType;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @urgencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Urgency'**
  String get urgencyLabel;

  /// No description provided for @wardNumberOptional.
  ///
  /// In en, this message translates to:
  /// **'Ward Number (Optional)'**
  String get wardNumberOptional;

  /// No description provided for @submitReport.
  ///
  /// In en, this message translates to:
  /// **'Submit Report'**
  String get submitReport;

  /// No description provided for @locationFound.
  ///
  /// In en, this message translates to:
  /// **'Location found'**
  String get locationFound;

  /// No description provided for @locationNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Location not available — report will be submitted without GPS'**
  String get locationNotAvailable;

  /// No description provided for @enterDescription.
  ///
  /// In en, this message translates to:
  /// **'Please enter a description'**
  String get enterDescription;

  /// No description provided for @noReportsFound.
  ///
  /// In en, this message translates to:
  /// **'No reports found'**
  String get noReportsFound;

  /// No description provided for @newMeeting.
  ///
  /// In en, this message translates to:
  /// **'New Meeting'**
  String get newMeeting;

  /// No description provided for @createMeeting.
  ///
  /// In en, this message translates to:
  /// **'Create Meeting'**
  String get createMeeting;

  /// No description provided for @noGramSabhaYet.
  ///
  /// In en, this message translates to:
  /// **'No Gram Sabha yet'**
  String get noGramSabhaYet;

  /// No description provided for @createNewMeeting.
  ///
  /// In en, this message translates to:
  /// **'Create a new meeting'**
  String get createNewMeeting;

  /// No description provided for @issuesLabel.
  ///
  /// In en, this message translates to:
  /// **'Issues:'**
  String get issuesLabel;

  /// No description provided for @noIssuesYet.
  ///
  /// In en, this message translates to:
  /// **'No issues yet — raise the first one!'**
  String get noIssuesYet;

  /// No description provided for @meetingTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Meeting title'**
  String get meetingTitleHint;

  /// No description provided for @issueDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Describe the issue...'**
  String get issueDescriptionHint;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @aiSummary.
  ///
  /// In en, this message translates to:
  /// **'AI Summary'**
  String get aiSummary;

  /// No description provided for @scheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get scheduled;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get live;

  /// No description provided for @urgencyLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get urgencyLow;

  /// No description provided for @urgencyMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get urgencyMedium;

  /// No description provided for @urgencyHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get urgencyHigh;

  /// No description provided for @urgencyCritical.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get urgencyCritical;

  /// No description provided for @aiConfidence.
  ///
  /// In en, this message translates to:
  /// **'AI confidence'**
  String get aiConfidence;

  /// No description provided for @reportedBy.
  ///
  /// In en, this message translates to:
  /// **'Reported by'**
  String get reportedBy;

  /// No description provided for @villageLabel.
  ///
  /// In en, this message translates to:
  /// **'Village'**
  String get villageLabel;

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get dateLabel;

  /// No description provided for @locationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get locationLabel;

  /// No description provided for @beneficiaries.
  ///
  /// In en, this message translates to:
  /// **'beneficiaries'**
  String get beneficiaries;

  /// No description provided for @costLabel.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get costLabel;

  /// No description provided for @timeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get timeline;

  /// No description provided for @fundPlan.
  ///
  /// In en, this message translates to:
  /// **'Fund Plan'**
  String get fundPlan;

  /// No description provided for @viewFullDetails.
  ///
  /// In en, this message translates to:
  /// **'View Full Details'**
  String get viewFullDetails;

  /// No description provided for @noProjectsFound.
  ///
  /// In en, this message translates to:
  /// **'No projects found'**
  String get noProjectsFound;

  /// No description provided for @aiRecommended.
  ///
  /// In en, this message translates to:
  /// **'AI Recommended'**
  String get aiRecommended;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @projectStatus.
  ///
  /// In en, this message translates to:
  /// **'Project Status'**
  String get projectStatus;

  /// No description provided for @expectedImpact.
  ///
  /// In en, this message translates to:
  /// **'Expected Impact'**
  String get expectedImpact;

  /// No description provided for @subsidySavings.
  ///
  /// In en, this message translates to:
  /// **'% subsidy savings'**
  String get subsidySavings;

  /// No description provided for @citizenRating.
  ///
  /// In en, this message translates to:
  /// **'Citizen Rating'**
  String get citizenRating;

  /// No description provided for @giveYourRating.
  ///
  /// In en, this message translates to:
  /// **'Give your rating:'**
  String get giveYourRating;

  /// No description provided for @writeReviewHint.
  ///
  /// In en, this message translates to:
  /// **'Write review (optional)...'**
  String get writeReviewHint;

  /// No description provided for @ratingSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Rating submitted! Thank you'**
  String get ratingSubmitted;

  /// No description provided for @submitRating.
  ///
  /// In en, this message translates to:
  /// **'Submit Rating'**
  String get submitRating;

  /// No description provided for @activeProjects.
  ///
  /// In en, this message translates to:
  /// **'Active Projects'**
  String get activeProjects;

  /// No description provided for @priorities.
  ///
  /// In en, this message translates to:
  /// **'Priorities'**
  String get priorities;

  /// No description provided for @aiPriorityRanking.
  ///
  /// In en, this message translates to:
  /// **'AI Priority Ranking'**
  String get aiPriorityRanking;

  /// No description provided for @issuesNeedingAttention.
  ///
  /// In en, this message translates to:
  /// **'Issues needing immediate attention'**
  String get issuesNeedingAttention;

  /// No description provided for @currentlyInProgress.
  ///
  /// In en, this message translates to:
  /// **'Currently in progress'**
  String get currentlyInProgress;

  /// No description provided for @fundUtilization.
  ///
  /// In en, this message translates to:
  /// **'Fund Utilization'**
  String get fundUtilization;

  /// No description provided for @budgetTracking.
  ///
  /// In en, this message translates to:
  /// **'Budget tracking by category'**
  String get budgetTracking;

  /// No description provided for @proposalReady.
  ///
  /// In en, this message translates to:
  /// **'Proposal Ready!'**
  String get proposalReady;

  /// No description provided for @totalCost.
  ///
  /// In en, this message translates to:
  /// **'Total Cost'**
  String get totalCost;

  /// No description provided for @subsidyLabel.
  ///
  /// In en, this message translates to:
  /// **'Subsidy'**
  String get subsidyLabel;

  /// No description provided for @pdfProposalReady.
  ///
  /// In en, this message translates to:
  /// **'PDF proposal generated and ready to download.'**
  String get pdfProposalReady;

  /// No description provided for @generatingProposal.
  ///
  /// In en, this message translates to:
  /// **'Proposal is being generated...'**
  String get generatingProposal;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @downloadPdf.
  ///
  /// In en, this message translates to:
  /// **'Download PDF'**
  String get downloadPdf;

  /// No description provided for @categoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryLabel;

  /// No description provided for @aiProposalNote.
  ///
  /// In en, this message translates to:
  /// **'AI-generated proposal will be created automatically.'**
  String get aiProposalNote;

  /// No description provided for @projectAdoptedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Project adopted! Proposal is being prepared...'**
  String get projectAdoptedSnackbar;

  /// No description provided for @adopt.
  ///
  /// In en, this message translates to:
  /// **'Adopt'**
  String get adopt;

  /// No description provided for @schemeWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Government Scheme Advisor'**
  String get schemeWelcomeTitle;

  /// No description provided for @schemeWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Ask about schemes like PM-KUSUM, MGNREGA, Jal Jeevan Mission. AI will tell you eligibility based on your village.'**
  String get schemeWelcomeBody;

  /// No description provided for @frequentlyAsked.
  ///
  /// In en, this message translates to:
  /// **'Frequently asked questions:'**
  String get frequentlyAsked;

  /// No description provided for @askAboutScheme.
  ///
  /// In en, this message translates to:
  /// **'Ask about a scheme...'**
  String get askAboutScheme;

  /// No description provided for @clearChat.
  ///
  /// In en, this message translates to:
  /// **'Clear chat'**
  String get clearChat;

  /// No description provided for @quickQuery1.
  ///
  /// In en, this message translates to:
  /// **'What is eligibility for PM-KUSUM?'**
  String get quickQuery1;

  /// No description provided for @quickQuery2.
  ///
  /// In en, this message translates to:
  /// **'How many days work in MGNREGA?'**
  String get quickQuery2;

  /// No description provided for @quickQuery3.
  ///
  /// In en, this message translates to:
  /// **'What is Jal Jeevan Mission?'**
  String get quickQuery3;

  /// No description provided for @quickQuery4.
  ///
  /// In en, this message translates to:
  /// **'How to apply for PMAY-G?'**
  String get quickQuery4;

  /// No description provided for @quickQuery5.
  ///
  /// In en, this message translates to:
  /// **'How to get Kisan Credit Card?'**
  String get quickQuery5;

  /// No description provided for @reportSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Report submitted! ID: WTR-{id}'**
  String reportSubmitted(int id);

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @voiceOfRuralDev.
  ///
  /// In en, this message translates to:
  /// **'Voice of Rural Development'**
  String get voiceOfRuralDev;

  /// No description provided for @enterMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter your mobile number'**
  String get enterMobileNumber;

  /// No description provided for @loginWithOtp.
  ///
  /// In en, this message translates to:
  /// **'Login with OTP — no password needed'**
  String get loginWithOtp;

  /// No description provided for @mobileRequired.
  ///
  /// In en, this message translates to:
  /// **'Mobile number is required'**
  String get mobileRequired;

  /// No description provided for @enterTenDigits.
  ///
  /// In en, this message translates to:
  /// **'Enter a 10-digit number'**
  String get enterTenDigits;

  /// No description provided for @forRegisteredCitizens.
  ///
  /// In en, this message translates to:
  /// **'For registered citizens'**
  String get forRegisteredCitizens;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get lastName;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @mobileNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Mobile Number'**
  String get mobileNumberLabel;

  /// No description provided for @yourLocation.
  ///
  /// In en, this message translates to:
  /// **'Your Location'**
  String get yourLocation;

  /// No description provided for @registerGetOtp.
  ///
  /// In en, this message translates to:
  /// **'Register & Get OTP'**
  String get registerGetOtp;

  /// No description provided for @stateLabel.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get stateLabel;

  /// No description provided for @districtLabel.
  ///
  /// In en, this message translates to:
  /// **'District'**
  String get districtLabel;

  /// No description provided for @gramPanchayatLabel.
  ///
  /// In en, this message translates to:
  /// **'Gram Panchayat'**
  String get gramPanchayatLabel;

  /// No description provided for @selectItem.
  ///
  /// In en, this message translates to:
  /// **'Select {item}'**
  String selectItem(String item);

  /// No description provided for @pleaseSelectLocation.
  ///
  /// In en, this message translates to:
  /// **'Please select your location'**
  String get pleaseSelectLocation;

  /// No description provided for @noDataForDistrict.
  ///
  /// In en, this message translates to:
  /// **'No data for {district} — please enter names'**
  String noDataForDistrict(String district);

  /// No description provided for @gramPanchayatName.
  ///
  /// In en, this message translates to:
  /// **'Gram Panchayat name'**
  String get gramPanchayatName;

  /// No description provided for @villageName.
  ///
  /// In en, this message translates to:
  /// **'Village name'**
  String get villageName;

  /// No description provided for @choosePreferredLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred language'**
  String get choosePreferredLanguage;

  /// No description provided for @landingNavFeatures.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get landingNavFeatures;

  /// No description provided for @landingNavHowItWorks.
  ///
  /// In en, this message translates to:
  /// **'How it Works'**
  String get landingNavHowItWorks;

  /// No description provided for @landingNavImpact.
  ///
  /// In en, this message translates to:
  /// **'Impact'**
  String get landingNavImpact;

  /// No description provided for @landingNavGramPanchayat.
  ///
  /// In en, this message translates to:
  /// **'Gram Panchayat'**
  String get landingNavGramPanchayat;

  /// No description provided for @landingOpenApp.
  ///
  /// In en, this message translates to:
  /// **'Open App'**
  String get landingOpenApp;

  /// No description provided for @landingHeroBadge.
  ///
  /// In en, this message translates to:
  /// **'Village Development AI Platform'**
  String get landingHeroBadge;

  /// No description provided for @landingHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Village\'s Voice,\nReaching the Government'**
  String get landingHeroTitle;

  /// No description provided for @landingHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Report village problems via voice or photo — AI matches them to government schemes, satellite data validates, and panchayats act.'**
  String get landingHeroSubtitle;

  /// No description provided for @landingBadgeGovt.
  ///
  /// In en, this message translates to:
  /// **'Govt. Supported'**
  String get landingBadgeGovt;

  /// No description provided for @landingBadgeAi.
  ///
  /// In en, this message translates to:
  /// **'AI-Powered'**
  String get landingBadgeAi;

  /// No description provided for @landingBadgePanchayats.
  ///
  /// In en, this message translates to:
  /// **'2.5 Lakh+ Panchayats'**
  String get landingBadgePanchayats;

  /// No description provided for @landingGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started Now'**
  String get landingGetStarted;

  /// No description provided for @landingWatchDemo.
  ///
  /// In en, this message translates to:
  /// **'Watch Live Demo'**
  String get landingWatchDemo;

  /// No description provided for @landingLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get landingLive;

  /// No description provided for @landingFeaturesLabel.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get landingFeaturesLabel;

  /// No description provided for @landingFeaturesTitle.
  ///
  /// In en, this message translates to:
  /// **'Built for Villages,\nPowered by People'**
  String get landingFeaturesTitle;

  /// No description provided for @featurePhotoReportingTitle.
  ///
  /// In en, this message translates to:
  /// **'Photo Reporting'**
  String get featurePhotoReportingTitle;

  /// No description provided for @featurePhotoReportingDesc.
  ///
  /// In en, this message translates to:
  /// **'Report issues via photo, voice note, or text in seconds.'**
  String get featurePhotoReportingDesc;

  /// No description provided for @featureLiveTrackingTitle.
  ///
  /// In en, this message translates to:
  /// **'Live Tracking'**
  String get featureLiveTrackingTitle;

  /// No description provided for @featureLiveTrackingDesc.
  ///
  /// In en, this message translates to:
  /// **'Track issue status in real-time on an interactive village map.'**
  String get featureLiveTrackingDesc;

  /// No description provided for @featureCommunityUpvotesTitle.
  ///
  /// In en, this message translates to:
  /// **'Community Upvotes'**
  String get featureCommunityUpvotesTitle;

  /// No description provided for @featureCommunityUpvotesDesc.
  ///
  /// In en, this message translates to:
  /// **'Villagers vote together to prioritize the most critical issues.'**
  String get featureCommunityUpvotesDesc;

  /// No description provided for @featureOfflineSupportTitle.
  ///
  /// In en, this message translates to:
  /// **'Offline Support'**
  String get featureOfflineSupportTitle;

  /// No description provided for @featureOfflineSupportDesc.
  ///
  /// In en, this message translates to:
  /// **'Report problems even without an internet connection.'**
  String get featureOfflineSupportDesc;

  /// No description provided for @featureMultiLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Multi-Language'**
  String get featureMultiLanguageTitle;

  /// No description provided for @featureMultiLanguageDesc.
  ///
  /// In en, this message translates to:
  /// **'Supports English, Hindi, Odia, Telugu and 8 more languages.'**
  String get featureMultiLanguageDesc;

  /// No description provided for @featureWhatsappAlertsTitle.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp Alerts'**
  String get featureWhatsappAlertsTitle;

  /// No description provided for @featureWhatsappAlertsDesc.
  ///
  /// In en, this message translates to:
  /// **'Get instant WhatsApp notifications on every status update.'**
  String get featureWhatsappAlertsDesc;

  /// No description provided for @landingProcessLabel.
  ///
  /// In en, this message translates to:
  /// **'Process'**
  String get landingProcessLabel;

  /// No description provided for @landingProcessTitle.
  ///
  /// In en, this message translates to:
  /// **'Simple 3-Step Process'**
  String get landingProcessTitle;

  /// No description provided for @stepReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get stepReportTitle;

  /// No description provided for @stepReportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Submit your grievance'**
  String get stepReportSubtitle;

  /// No description provided for @stepReportDesc.
  ///
  /// In en, this message translates to:
  /// **'Use voice note, photo or text. AI understands your language and logs it instantly.'**
  String get stepReportDesc;

  /// No description provided for @stepRouteTitle.
  ///
  /// In en, this message translates to:
  /// **'Route to Panchayat'**
  String get stepRouteTitle;

  /// No description provided for @stepRouteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'AI matches the right scheme'**
  String get stepRouteSubtitle;

  /// No description provided for @stepRouteDesc.
  ///
  /// In en, this message translates to:
  /// **'AI categorizes the issue, validates with satellite data, and matches the best government scheme.'**
  String get stepRouteDesc;

  /// No description provided for @stepResolveTitle.
  ///
  /// In en, this message translates to:
  /// **'Resolve & Verify'**
  String get stepResolveTitle;

  /// No description provided for @stepResolveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track until completion'**
  String get stepResolveSubtitle;

  /// No description provided for @stepResolveDesc.
  ///
  /// In en, this message translates to:
  /// **'Panchayat adopts the project. Citizens track progress, upload photos, and rate the outcome.'**
  String get stepResolveDesc;

  /// No description provided for @statsTitle.
  ///
  /// In en, this message translates to:
  /// **'Real Villages. Real Impact'**
  String get statsTitle;

  /// No description provided for @statsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A Story of Real Change'**
  String get statsSubtitle;

  /// No description provided for @statVillagesConnected.
  ///
  /// In en, this message translates to:
  /// **'Villages Connected'**
  String get statVillagesConnected;

  /// No description provided for @statGrievancesFiled.
  ///
  /// In en, this message translates to:
  /// **'Grievances Filed'**
  String get statGrievancesFiled;

  /// No description provided for @statIssuesResolved.
  ///
  /// In en, this message translates to:
  /// **'Issues Resolved'**
  String get statIssuesResolved;

  /// No description provided for @statAvgResolution.
  ///
  /// In en, this message translates to:
  /// **'Avg Resolution'**
  String get statAvgResolution;

  /// No description provided for @landingPanchayatLabel.
  ///
  /// In en, this message translates to:
  /// **'Panchayat'**
  String get landingPanchayatLabel;

  /// No description provided for @landingPanchayatTitle.
  ///
  /// In en, this message translates to:
  /// **'Strengthening Grassroots\nGovernance'**
  String get landingPanchayatTitle;

  /// No description provided for @benefitDigitalGramTitle.
  ///
  /// In en, this message translates to:
  /// **'Digital Gram Panchayat'**
  String get benefitDigitalGramTitle;

  /// No description provided for @benefitDigitalGramDesc.
  ///
  /// In en, this message translates to:
  /// **'AI-powered dashboard for leaders to manage issues, funds, and projects.'**
  String get benefitDigitalGramDesc;

  /// No description provided for @benefitGovtPartnershipTitle.
  ///
  /// In en, this message translates to:
  /// **'Government Partnership'**
  String get benefitGovtPartnershipTitle;

  /// No description provided for @benefitGovtPartnershipDesc.
  ///
  /// In en, this message translates to:
  /// **'Direct integration with eGramSwaraj, DISHA, and 12+ central schemes.'**
  String get benefitGovtPartnershipDesc;

  /// No description provided for @benefitDataDrivenTitle.
  ///
  /// In en, this message translates to:
  /// **'Data-Driven Decisions'**
  String get benefitDataDrivenTitle;

  /// No description provided for @benefitDataDrivenDesc.
  ///
  /// In en, this message translates to:
  /// **'Satellite + census + community data for unbiased AI prioritization.'**
  String get benefitDataDrivenDesc;

  /// No description provided for @benefitGramSabhaTitle.
  ///
  /// In en, this message translates to:
  /// **'Gram Sabha Empowerment'**
  String get benefitGramSabhaTitle;

  /// No description provided for @benefitGramSabhaDesc.
  ///
  /// In en, this message translates to:
  /// **'Digital Gram Sabha with live voting, AI transcription, and auto minutes.'**
  String get benefitGramSabhaDesc;

  /// No description provided for @footerEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Transform Your Village'**
  String get footerEyebrow;

  /// No description provided for @footerTitle.
  ///
  /// In en, this message translates to:
  /// **'Transform Your Village Today'**
  String get footerTitle;

  /// No description provided for @footerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Thousands of villages are already using PrajaShakti AI to drive real, measurable change.'**
  String get footerSubtitle;

  /// No description provided for @footerOpenAppNow.
  ///
  /// In en, this message translates to:
  /// **'Open App Now'**
  String get footerOpenAppNow;

  /// No description provided for @footerCopyright.
  ///
  /// In en, this message translates to:
  /// **'© 2026 PrajaShakti. Jai Hind.'**
  String get footerCopyright;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'bn',
        'en',
        'gu',
        'hi',
        'kn',
        'ml',
        'mr',
        'or',
        'pa',
        'ta',
        'te'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
    case 'gu':
      return AppLocalizationsGu();
    case 'hi':
      return AppLocalizationsHi();
    case 'kn':
      return AppLocalizationsKn();
    case 'ml':
      return AppLocalizationsMl();
    case 'mr':
      return AppLocalizationsMr();
    case 'or':
      return AppLocalizationsOr();
    case 'pa':
      return AppLocalizationsPa();
    case 'ta':
      return AppLocalizationsTa();
    case 'te':
      return AppLocalizationsTe();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
