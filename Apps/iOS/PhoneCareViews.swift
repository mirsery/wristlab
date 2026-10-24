import SwiftUI
import WristlabCore

struct PhoneCareClock<Content: View>: View {
    let demoDate: Date?
    @ViewBuilder let content: (Date) -> Content
    @Environment(\.scenePhase) private var scenePhase
    @State private var resumedAt = Date()

    var body: some View {
        TimelineView(.periodic(from: resumedAt, by: 30)) { _ in
            content(demoDate ?? Date())
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { resumedAt = Date() }
        }
    }
}

struct PhoneCareSection: View {
    let report: HealthReport?
    let demo: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        PhoneCareClock(demoDate: demo ? (report?.asOf ?? DemoData.previewDate) : nil) { now in
            PhoneCareCard(kind: .readiness, estimate: report?.readiness ?? MetricEstimate(), now: now)
                .id("readiness")
            let energy = PhoneCareCard(kind: .energy, estimate: report?.energy.estimate ?? MetricEstimate(), now: now)
            let stress = PhoneCareCard(kind: .stress, estimate: report?.stress ?? MetricEstimate(), now: now)
            Group {
                if typeSize.isAccessibilitySize {
                    VStack(spacing: 12) { energy; stress }
                } else {
                    // Cards of different text length share one row height instead of centring vertically.
                    HStack(alignment: .top, spacing: 12) { energy; stress }
                        .fixedSize(horizontal: false, vertical: true)
                }
            }.id("metrics")
        }
    }
}

private struct PhoneCareCard: View {
    let kind: ComplicationMetric
    let estimate: MetricEstimate
    let now: Date

    private var color: Color {
        switch kind { case .readiness: wristMint; case .energy: .cyan; case .stress: .orange }
    }

    var body: some View {
        let display = PhoneCarePresentation(kind: kind, estimate: estimate, at: now)
        NavigationLink(value: kind) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Text(kind.title).font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Image(systemName: display.symbol).font(.title2).foregroundStyle(color)
                        .accessibilityHidden(true)
                }
                Text(display.title).font(.system(.title3, design: .rounded, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                if let fraction = display.energyFraction {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(color.opacity(0.15))
                            Capsule().fill(color.gradient).frame(width: geometry.size.width * fraction)
                        }
                    }.frame(height: 12).accessibilityHidden(true)
                }
                Text(display.note).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Label("查看详情", systemImage: "arrow.up.right").font(.caption).foregroundStyle(color)
                    .frame(maxHeight: .infinity, alignment: .bottomLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(20)
            .background(wristCard, in: RoundedRectangle(cornerRadius: 24))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(color.opacity(0.6)).frame(width: 3).padding(.vertical, 24)
                    .accessibilityHidden(true)
            }
            .contentShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(display.accessibilityLabel)
        .accessibilityIdentifier("care.\(kind.rawValue)")
    }
}
