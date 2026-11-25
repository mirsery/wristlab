import Foundation
import Testing
@testable import WristlabCore

struct PhoneCarePresentationTests {
    private let now = DemoData.previewDate

    @Test func readinessBoundariesAndRounding_TC_PTC_001() {
        for (value, title) in [(0.0, "较低"), (32, "较低"), (32.49, "较低"), (32.5, "接近个人常态"),
                               (33, "接近个人常态"), (66.49, "接近个人常态"), (66.5, "较高"), (67, "较高"), (100, "较高")] {
            let display = PhoneCarePresentation(kind: .readiness, estimate: MetricEstimate(value), at: now)
            #expect(display.title == title)
            #expect(display.isCurrent && display.energyFraction == nil)
            #expect(!display.symbol.isEmpty)
        }
    }

    @Test func pressureBoundariesAndContext_TC_PTC_001() {
        for (value, title) in [(0.0, "较低"), (19.49, "较低"), (19.5, "常态"), (20, "常态"),
                               (59.49, "常态"), (59.5, "偏高"), (60, "偏高"), (79.49, "偏高"),
                               (79.5, "较高"), (80, "较高"), (100, "较高")] {
            #expect(PhoneCarePresentation(kind: .stress, estimate: MetricEstimate(value), at: now).title == title)
        }
        let heartOnly = MetricEstimate(90, quality: .partial, reasons: ["hrOnly"], mode: "awake")
        let display = PhoneCarePresentation(kind: .stress, estimate: heartOnly, at: now)
        #expect(display.note.contains("仅心率估算"))
        #expect(display.note.contains("不代表心理状态"))
        var active = heartOnly
        active.mode = "activity"
        let activity = PhoneCarePresentation(kind: .stress, estimate: active, at: now)
        #expect(activity.title == "运动中" && activity.symbol == "figure.run")
        #expect(activity.note.contains("仅心率估算"))
        let partial = PhoneCarePresentation(kind: .readiness, estimate: MetricEstimate(40, quality: .partial), at: now)
        #expect(partial.note.contains("部分数据估算"))
    }

    @Test func energyZeroAndMissing_TC_PTC_002() {
        for value in [0.0, 1, 50, 100] {
            let display = PhoneCarePresentation(kind: .energy, estimate: MetricEstimate(value, mode: "energy"), at: now)
            #expect(display.isCurrent && display.energyFraction == value / 100)
            #expect(display.title == "身体电量估算")
            #expect(display.note.contains("实验估算"))
        }
        let missing = PhoneCarePresentation(kind: .energy, estimate: MetricEstimate(mode: "energy"), at: now)
        #expect(!missing.isCurrent && missing.energyFraction == nil)
        #expect(missing.title == "暂无可读取记录")
    }

    @Test func missingAndCalibrationReasons_TC_PTC_003() {
        let inputs: [MetricEstimate] = [
            MetricEstimate(), MetricEstimate(availability: .calibrating, baselineDays: 0),
            MetricEstimate(availability: .calibrating, baselineDays: 13, mode: "energy"),
            MetricEstimate(availability: .failed), MetricEstimate(availability: .unsupported)
        ] + ["missingHR", "missingCurrentHRV", "missingCurrentRHR", "missingPrimarySleep", "lowCoverage"].map {
            MetricEstimate(reasons: [$0], mode: "energy")
        } + [MetricEstimate(reasons: ["observationGap", "recalibrationRequired"], mode: "energy")]
        for estimate in inputs {
            let display = PhoneCarePresentation(kind: .energy, estimate: estimate, at: now)
            let explanation = MetricExplanation(estimate, at: now)
            #expect(display.title == explanation.summary)
            #expect(display.note == explanation.detail)
            #expect(!display.isCurrent && display.energyFraction == nil)
            #expect(!display.accessibilityLabel.contains("等待手机同步"))
        }
    }

    @Test func exactExpiryAndFutureObservation_TC_PTC_004() {
        for kind in ComplicationMetric.allCases {
            let estimate = MetricEstimate(70, effectiveAt: now.addingTimeInterval(-3601), validUntil: now)
            #expect(PhoneCarePresentation(kind: kind, estimate: estimate, at: now.addingTimeInterval(-1)).isCurrent)
            #expect(PhoneCarePresentation(kind: kind, estimate: estimate, at: now).isCurrent)
            let expired = PhoneCarePresentation(kind: kind, estimate: estimate, at: now.addingTimeInterval(1))
            #expect(!expired.isCurrent && expired.energyFraction == nil && expired.title == "数据已过期")
            var future = estimate
            future.effectiveAt = now.addingTimeInterval(1)
            #expect(PhoneCarePresentation(kind: kind, estimate: future, at: now).title == "数据已过期")
        }
    }

    @Test func noSnapshotTTLAndNoMutation_TC_PTC_004() {
        let estimate = MetricEstimate(50, effectiveAt: now.addingTimeInterval(-7200), validUntil: now.addingTimeInterval(3600))
        let before = estimate
        #expect(PhoneCarePresentation(kind: .readiness, estimate: estimate, at: now).isCurrent)
        #expect(estimate == before)
        #expect(PhoneCarePresentation(kind: .readiness, estimate: estimate, at: now.addingTimeInterval(3601)).title == "数据已过期")
    }

    @Test func scorelessAccessibility_TC_PTC_006() {
        for kind in ComplicationMetric.allCases {
            let display = PhoneCarePresentation(kind: kind, estimate: MetricEstimate(83), at: now)
            #expect(display.accessibilityLabel.contains(kind.title))
            #expect(display.accessibilityLabel.contains(display.title))
            #expect(display.accessibilityLabel.contains("查看详情"))
            #expect(!display.accessibilityLabel.contains("83") && !display.accessibilityLabel.contains("100"))
        }
    }

    @Test func clockRewindMakesObservationFuture_TC_PTC_004() {
        let estimate = MetricEstimate(50, effectiveAt: now.addingTimeInterval(-30), validUntil: now.addingTimeInterval(900))
        #expect(PhoneCarePresentation(kind: .readiness, estimate: estimate, at: now).isCurrent)
        #expect(!PhoneCarePresentation(kind: .readiness, estimate: estimate, at: now.addingTimeInterval(-31)).isCurrent)
        #expect(PhoneCarePresentation(kind: .readiness, estimate: estimate, at: now).isCurrent)
    }

    @Test func detailContributionsDisappearAfterExpiry_TC_PTC_004_005() {
        let contributions = ["hrv": 55.0, "baselineHRV": 50, "zHRV": 0.7, "rhr": 58, "baselineRHR": 60,
                             "zRHR": 0.5, "hr": 80, "baselineHR": 70, "zHR": 0.6]
        let estimate = MetricEstimate(50, contributions: contributions, effectiveAt: now.addingTimeInterval(-60), validUntil: now)
        for kind in [ComplicationMetric.readiness, .stress] {
            #expect(!MetricContributions.rows(for: kind, estimate: estimate, at: now).isEmpty)
            #expect(MetricContributions.rows(for: kind, estimate: estimate, at: now.addingTimeInterval(1)).isEmpty)
        }
    }
}
