import Testing
@testable import WristlabCore

@Test func trendsSectionsKeepMetricsAndPeriodsSeparate_TC_TRENDUI_001() {
    var state = TrendsNavigationState()
    #expect(state.selected == .health)
    #expect(TrendsSection.health.metrics == [.readiness, .sleep, .nightHRV, .restingHeartRate])
    #expect(TrendsSection.movement.metrics == [.load])
    #expect(TrendsSection.weight.metrics.isEmpty)
    state.selectHealthMetric(.nightHRV)
    state.setLength(30, for: .health)
    state.selected = .movement
    #expect(state.metric(for: .movement) == .load)
    #expect(state.length(for: .movement) == 7)
    #expect(state.metric(for: .health) == .nightHRV)
    #expect(state.length(for: .weight) == nil)
}

@Test func trendsSwitchingPreservesIndependentPositions_TC_TRENDUI_002() {
    var state = TrendsNavigationState()
    state.rememberPosition("review", for: .health)
    state.selected = .movement
    state.rememberPosition("movement-review", for: .movement)
    state.setLength(30, for: .movement)
    state.selected = .health
    #expect(state.position(for: .health) == "review")
    #expect(state.position(for: .movement) == "movement-review")
    #expect(state.length(for: .health) == 7)
    #expect(state.length(for: .movement) == 30)
}

@Test func trendsLocalSectionsDoNotRequireHealthReport_TC_TRENDUI_003() {
    #expect(!TrendsSection.weight.requiresHealthReport)
    #expect(!TrendsSection.movement.requiresHealthReport)
    #expect(TrendsSection.health.requiresHealthReport)
    #expect(TrendsSection.weight.periodExplanation.contains("周"))
    #expect(TrendsSection.movement.periodExplanation.contains("7/30"))
}

@Test func trendsSourceResetDropsAnchorsButKeepsPreferences_TC_TRENDUI_004() {
    var state = TrendsNavigationState()
    state.selected = .weight
    state.selectHealthMetric(.restingHeartRate)
    state.setLength(30, for: .health)
    state.rememberPosition("weight-progress", for: .weight)
    state.rememberPosition("history", for: .health)
    state.resetContentPositions()
    #expect(state.selected == .weight)
    #expect(state.position(for: .weight) == nil)
    #expect(state.position(for: .health) == nil)
    #expect(state.metric(for: .health) == .restingHeartRate)
    #expect(state.length(for: .health) == 30)
}

@Test func trendsRejectInvalidFiltersAndKeepWeightFixed_TC_TRENDUI_001() {
    var state = TrendsNavigationState()
    state.selectHealthMetric(.load)
    state.setLength(42, for: .health)
    state.setLength(30, for: .weight)
    #expect(state.metric(for: .health) == .readiness)
    #expect(state.length(for: .health) == 7)
    #expect(state.length(for: .weight) == nil)
}
