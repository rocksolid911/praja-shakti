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
