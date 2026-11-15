import '../../../projects/domain/models/daily_progress_entry.dart';
import '../../../projects/domain/models/project_compliance_record.dart';
import '../../../projects/domain/models/site_project.dart';
import '../models/project_incentive_record.dart';
import '../models/project_incentive_settings.dart';

class ProjectIncentiveCalculator {
  /// Computes the comprehensive incentive record for a project based on:
  /// 1. Daily Progress (Approved volume done vs target)
  /// 2. Timely Bill Submission (Bonus on-time vs penalty for delayed/missing)
  /// 3. Payment Collection (Pro-rata release factor based on client payment)
  /// 4. Incident Disqualification (Automatically forfeits incentive to ₹0 if any incident is logged)
  /// 5. Dedicated Restoration Cost Tracking (Tracked separately in damage ledger)
  static ProjectIncentiveRecord calculate({
    required SiteProject project,
    required List<DailyProgressEntry> dailyProgressEntries,
    required List<IncidentLogEntry> incidents,
    ProjectIncentiveSettings settings = const ProjectIncentiveSettings(),
    DateTime? billSubmissionDate,
    DateTime? calculationDate,
  }) {
    final now = calculationDate ?? DateTime.now();

    // ── 1. Daily Progress Calculation ──
    final approvedEntries = dailyProgressEntries
        .where((e) => e.approvalStatus.toLowerCase() == 'approved')
        .toList();

    final approvedQuantityDone = approvedEntries.fold<double>(
      0.0,
      (sum, e) => sum + e.quantityDone,
    );

    // Target quantity: either from daily progress entries, breakdown or default
    final totalQuantityTarget = approvedEntries.isNotEmpty &&
            approvedEntries.first.totalQuantity > 0
        ? approvedEntries.first.totalQuantity
        : (dailyProgressEntries.isNotEmpty &&
                dailyProgressEntries.first.totalQuantity > 0
            ? dailyProgressEntries.first.totalQuantity
            : (approvedQuantityDone > 0 ? approvedQuantityDone : 100.0));

    final unit = approvedEntries.isNotEmpty
        ? approvedEntries.first.unit
        : (dailyProgressEntries.isNotEmpty
            ? dailyProgressEntries.first.unit
            : 'metres');

    final progressPct = totalQuantityTarget > 0
        ? (approvedQuantityDone / totalQuantityTarget * 100.0).clamp(0.0, 100.0)
        : 0.0;

    final baseProgressIncentive = approvedQuantityDone * settings.baseRatePerUnit;

    // ── 2. Timely Bill Submission Consideration ──
    // A bill is considered submitted if billing documents are uploaded or flow of bills status is progressing
    final hasBillingDocs = project.billingDetailsDocuments.isNotEmpty;
    final hasFlowStatus = project.flowOfBillsStatus.isNotEmpty;
    final isBillSubmitted = hasBillingDocs || hasFlowStatus || billSubmissionDate != null;

    final billTargetDate = project.revisedCompletionDate ??
        project.targetCompletionDate ??
        project.actualCompletionDate;

    // Timely bill determination:
    // If target date is defined and submission date is available: compare dates.
    // If billing docs uploaded before or on target date -> on-time.
    bool isBillTimely = false;
    double billMultiplier = 1.0;
    double timelyBillAdjustment = 0.0;

    if (isBillSubmitted) {
      if (billTargetDate != null) {
        final effectiveSubmission = billSubmissionDate ??
            (project.billingDetailsDocuments.isNotEmpty
                ? project.billingDetailsDocuments.first.uploadedAt
                : now);
        isBillTimely = !effectiveSubmission.isAfter(billTargetDate);
      } else {
        // If no explicit deadline set, having submitted bills confers timely status
        isBillTimely = true;
      }

      if (isBillTimely) {
        billMultiplier = 1.0 + (settings.timelyBillBonusPercentage / 100.0);
        timelyBillAdjustment =
            baseProgressIncentive * (settings.timelyBillBonusPercentage / 100.0);
      } else {
        billMultiplier = 1.0 - (settings.delayedBillPenaltyPercentage / 100.0);
        timelyBillAdjustment =
            -(baseProgressIncentive * (settings.delayedBillPenaltyPercentage / 100.0));
      }
    } else {
      // Bill not yet submitted
      if (billTargetDate != null && now.isAfter(billTargetDate)) {
        // Overdue submission
        billMultiplier = 1.0 - (settings.delayedBillPenaltyPercentage / 100.0);
        timelyBillAdjustment =
            -(baseProgressIncentive * (settings.delayedBillPenaltyPercentage / 100.0));
      }
    }

    // ── 3. Payment Collection Consideration ──
    final contractVal = project.contractValue > 0
        ? project.contractValue
        : (project.tenderAmount > 0 ? project.tenderAmount : 0.0);

    final paymentCollected = project.paymentAmount;
    final collectionPct = contractVal > 0
        ? (paymentCollected / contractVal * 100.0).clamp(0.0, 100.0)
        : (paymentCollected > 0 ? 100.0 : 0.0);

    // Collection Factor:
    // If collection >= minCollectionThresholdPct -> full 1.0 factor
    // If collection < threshold -> pro-rated payout ratio
    double collectionFactor = 1.0;
    if (contractVal > 0) {
      if (collectionPct >= settings.minCollectionThresholdPct) {
        collectionFactor = 1.0;
      } else {
        collectionFactor = (collectionPct / settings.minCollectionThresholdPct)
            .clamp(0.0, 1.0);
      }
    }

    final preCollectionAmount = baseProgressIncentive + timelyBillAdjustment;
    final grossEarnedIncentive = (preCollectionAmount * collectionFactor)
        .clamp(0.0, double.infinity);
    final collectionAdjustment = grossEarnedIncentive - preCollectionAmount;

    // ── 4. Incident Disqualification Engine ──
    // Automatically disqualify incentive when any incident is recorded
    final hasIncidents = incidents.isNotEmpty;
    final isDisqualified = hasIncidents && settings.autoDisqualifyOnIncident;

    String disqualificationReason = '';
    DateTime? disqualificationDate;

    if (isDisqualified) {
      disqualificationReason =
          'Automatically disqualified: ${incidents.length} incident(s) logged on site '
          '(utility damage / safety incident). Zero tolerance incentive forfeiture.';
      disqualificationDate = incidents.first.incidentDate;
    }

    // ── 5. Track Restoration Costs Separately ──
    final totalRestorationCost = incidents.fold<double>(
      0.0,
      (sum, inc) => sum + inc.restorationCost,
    );

    final restorationIncidents = incidents
        .map((inc) => RestorationIncidentItem(
              incidentId: inc.id,
              incidentDate: inc.incidentDate,
              remarks: inc.remarks,
              restorationCost: inc.restorationCost,
              photoUrls: inc.photoUrls.isNotEmpty
                  ? inc.photoUrls
                  : (inc.photoUrl.isNotEmpty ? [inc.photoUrl] : const []),
            ))
        .toList();

    // ── 6. Final Payable Summary ──
    final netPayableIncentive = isDisqualified ? 0.0 : grossEarnedIncentive;
    final status = isDisqualified
        ? 'DISQUALIFIED'
        : (!isBillSubmitted && billTargetDate != null && now.isAfter(billTargetDate)
            ? 'ON_HOLD'
            : 'ELIGIBLE');

    return ProjectIncentiveRecord(
      id: 'inc_${project.id.isNotEmpty ? project.id : project.projectCode}',
      projectId: project.id,
      projectCode: project.projectCode,
      projectName: project.generalCode.isNotEmpty
          ? project.generalCode
          : (project.clientName.isNotEmpty ? project.clientName : project.projectCode),
      clientName: project.clientName,
      assignedEmployeeNames: project.assignedToEmployeeNames,
      assignedEmployeeIds: project.assignedToEmployeeIds,
      division: project.division,
      contractValue: contractVal,
      // 1. Daily Progress
      totalQuantityTarget: totalQuantityTarget,
      approvedQuantityDone: approvedQuantityDone,
      unit: unit,
      approvedEntriesCount: approvedEntries.length,
      baseProgressIncentive: baseProgressIncentive,
      progressCompletionPercentage: progressPct,
      // 2. Timely Bill Submission
      isBillSubmitted: isBillSubmitted,
      flowOfBillsStatus: project.flowOfBillsStatus,
      billTargetDate: billTargetDate,
      billSubmissionDate: billSubmissionDate,
      isBillTimely: isBillTimely,
      billTimelinessMultiplier: billMultiplier,
      timelyBillAdjustmentAmount: timelyBillAdjustment,
      // 3. Payment Collection
      paymentCollectedAmount: paymentCollected,
      paymentCollectionPercentage: collectionPct,
      paymentCollectionFactor: collectionFactor,
      paymentCollectionAdjustmentAmount: collectionAdjustment,
      // 4. Incident Disqualification
      incidentCount: incidents.length,
      isDisqualified: isDisqualified,
      disqualificationReason: disqualificationReason,
      disqualificationDate: disqualificationDate,
      // 5. Separate Restoration Costs
      totalRestorationCost: totalRestorationCost,
      restorationIncidents: restorationIncidents,
      // 6. Final Amounts
      grossEarnedIncentive: grossEarnedIncentive,
      netPayableIncentive: netPayableIncentive,
      status: status,
      calculatedAt: now,
      remarks: isDisqualified
          ? 'Incentive disqualified due to recorded site incident. Restoration costs tracked separately in damage audit ledger.'
          : 'Incentive calculated and verified against daily progress, timely billing, and payment collection.',
    );
  }
}
