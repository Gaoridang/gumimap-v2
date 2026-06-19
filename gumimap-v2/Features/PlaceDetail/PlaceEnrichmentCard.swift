import SwiftUI

struct PlaceEnrichmentCard: View {
    let placeName: String
    let startedAt: Date?
    let isLoading: Bool
    let phases: [GrokEnrichmentPhase]
    let enrichment: PlaceEnrichment?
    let errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isLoading {
                loadingContent
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let enrichment {
                resultContent(enrichment)
            }
        }
        .frame(minHeight: isLoading || enrichment != nil || errorMessage != nil ? nil : 0)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .animation(nil, value: isLoading)
        .animation(nil, value: phases.count)
        .animation(nil, value: enrichment?.summary)
    }

    @ViewBuilder
    private var loadingContent: some View {
        if let startedAt {
            TimelineView(.periodic(from: startedAt, by: 1)) { context in
                HStack(spacing: 10) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text("\(placeName) 관련 정보 검색 중 · \(elapsedSeconds(since: startedAt, now: context.date))초")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }

        if phases.isEmpty {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("검색 준비 중")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(phases.enumerated()), id: \.element.id) { index, phase in
                    EnrichmentPhaseRow(
                        phase: phase,
                        showsConnector: index < phases.count - 1
                    )
                }
            }
        }
    }

    private func resultContent(_ enrichment: PlaceEnrichment) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(enrichment.summary)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !enrichment.highlights.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(enrichment.highlights, id: \.self) { highlight in
                        Text("• \(highlight)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            Text(enrichment.visitTip)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
    }

    private func elapsedSeconds(since start: Date, now: Date) -> Int {
        max(0, Int(now.timeIntervalSince(start)))
    }
}

private struct EnrichmentPhaseRow: View {
    let phase: GrokEnrichmentPhase
    let showsConnector: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            phaseIndicatorColumn

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(phase.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(phase.status == .inProgress ? .primary : .secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    trailingMetadata
                }

                if let detail = phase.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !phase.sourceHosts.isEmpty {
                    SourceBadgeStack(hosts: phase.sourceHosts)
                        .padding(.top, 2)
                }
            }
        }
        .padding(.bottom, showsConnector ? 14 : 0)
    }

    private var phaseIndicatorColumn: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(phase.status == .inProgress ? Color.primary.opacity(0.12) : Color.clear)
                    .frame(width: 28, height: 28)

                Group {
                    if phase.status == .inProgress {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if showsConnector {
                Rectangle()
                    .fill(Color.primary.opacity(0.12))
                    .frame(width: 1, height: 18)
                    .padding(.vertical, 4)
            }
        }
        .frame(width: 28)
    }

    @ViewBuilder
    private var trailingMetadata: some View {
        if phase.status == .inProgress {
            EmptyView()
        } else if let resultLabel = phase.resultLabel {
            Text(resultLabel)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

private struct SourceBadgeStack: View {
    let hosts: [String]

    var body: some View {
        HStack(spacing: -6) {
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
            .frame(width: 18, height: 18)
            .overlay {
                Circle()
                    .strokeBorder(Color(.secondarySystemGroupedBackground), lineWidth: 2)
            }
            .help(host)
    }

    private var badgeColor: Color {
        let palette: [Color] = [.orange, .green, .blue, .pink, .purple, .teal]
        return palette[abs(host.hashValue) % palette.count]
    }
}