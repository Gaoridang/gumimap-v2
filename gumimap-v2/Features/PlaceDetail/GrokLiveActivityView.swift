import SwiftUI

struct GrokLiveActivityView: View {
    let placeName: String
    let startedAt: Date
    let steps: [GrokSearchStep]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            TimelineView(.periodic(from: startedAt, by: 1)) { context in
                HStack(spacing: 10) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text("\(placeName) 관련 정보 검색 중 · \(elapsedSeconds(since: startedAt, now: context.date))s")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            VStack(alignment: .leading, spacing: 20) {
                ForEach(steps) { step in
                    GrokSearchStepRow(step: step)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(nil, value: steps.count)
    }

    private func elapsedSeconds(since start: Date, now: Date) -> Int {
        max(0, Int(now.timeIntervalSince(start)))
    }
}

private struct GrokSearchStepRow: View {
    let step: GrokSearchStep

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            stepIcon

            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)

                if let subtitle = step.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailingContent
        }
    }

    private var stepIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.tertiarySystemFill))
                .frame(width: 34, height: 34)

            Image(systemName: step.kind == .webSearch ? "magnifyingglass" : "doc.text.magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var trailingContent: some View {
        if step.isInProgress {
            ProgressView()
                .controlSize(.small)
                .padding(.top, 4)
        } else if let resultLabel = step.resultLabel {
            HStack(spacing: 8) {
                Text(resultLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !step.sourceHosts.isEmpty {
                    SourceBadgeStack(hosts: step.sourceHosts)
                }
            }
            .padding(.top, 2)
        }
    }
}

private struct SourceBadgeStack: View {
    let hosts: [String]

    var body: some View {
        HStack(spacing: -7) {
            ForEach(Array(hosts.prefix(3).enumerated()), id: \.offset) { index, host in
                SourceBadge(host: host)
                    .zIndex(Double(3 - index))
            }
        }
    }
}

private struct SourceBadge: View {
    let host: String

    var body: some View {
        Circle()
            .fill(badgeColor)
            .frame(width: 20, height: 20)
            .overlay {
                Circle()
                    .strokeBorder(Color(.systemGroupedBackground), lineWidth: 2)
            }
    }

    private var badgeColor: Color {
        let palette: [Color] = [
            .orange,
            .green,
            .blue,
            .pink,
            .purple,
            .teal,
        ]
        let index = abs(host.hashValue) % palette.count
        return palette[index]
    }
}