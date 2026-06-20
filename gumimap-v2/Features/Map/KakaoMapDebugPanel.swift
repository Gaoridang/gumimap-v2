import SwiftUI

struct KakaoMapDebugPanel: View {
    let snapshot: KakaoMapDebugSnapshot
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if isExpanded {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        section("상태") {
                            row("phase", snapshot.phaseLabel)
                            row("lastEvent", snapshot.lastEvent)
                            row("updated", snapshot.updatedAt.formatted(date: .omitted, time: .standard))
                        }

                        section("앱 / 키") {
                            row("bundleID", snapshot.bundleID)
                            row("nativeKey", snapshot.nativeKeyMasked)
                            row("sdkPhase", snapshot.sdkPhase)
                        }

                        section("엔진") {
                            boolRow("mapTabActive", snapshot.isMapTabActive)
                            boolRow("enginePrepared", snapshot.isEnginePrepared)
                            boolRow("engineActive", snapshot.isEngineActive)
                            boolRow("authenticated", snapshot.didAuthenticate)
                            boolRow("mapReady", snapshot.isMapReady)
                            boolRow("hasMapView", snapshot.hasMapView)
                            boolRow("viewRectApplied", snapshot.viewRectApplied)
                            boolRow("cameraSet", snapshot.cameraSet)
                        }

                        section("레이아웃") {
                            row("container", snapshot.containerSize)
                            row("pending", snapshot.pendingSize)
                            row("viewRect", snapshot.appliedViewRectSize)
                            row("addView", snapshot.addViewSize)
                        }

                        section("데이터") {
                            row("pins", "\(snapshot.pinCount)")
                        }

                        if let authError = snapshot.authError {
                            section("인증 오류") {
                                Text(authError)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.red)
                                    .textSelection(.enabled)
                            }
                        }

                        section("SDK state") {
                            Text(snapshot.engineStateMessage)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(12)
                }
                .frame(maxHeight: 280)
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.orange.opacity(0.5), lineWidth: 1)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private var header: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "ladybug.fill")
                    .foregroundStyle(.orange)

                Text("Kakao Map Debug")
                    .font(.caption.weight(.semibold))

                Spacer()

                statusChip

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    private var statusChip: some View {
        Text(snapshot.phaseLabel)
            .font(.caption2.weight(.semibold).monospaced())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(chipColor.opacity(0.15), in: Capsule())
            .foregroundStyle(chipColor)
    }

    private var chipColor: Color {
        switch snapshot.phaseLabel {
        case "ready":
            .green
        case "authFailed", "addViewFailed":
            .red
        default:
            .orange
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)

            content()
        }
    }

    private func row(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(key)
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
                .frame(width: 92, alignment: .leading)

            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func boolRow(_ key: String, _ value: Bool) -> some View {
        row(key, value ? "true" : "false")
    }
}

#Preview {
    KakaoMapDebugPanel(
        snapshot: KakaoMapDebugSnapshot(phaseLabel: "loading", lastEvent: "prepareEngine"),
        isExpanded: .constant(true)
    )
}