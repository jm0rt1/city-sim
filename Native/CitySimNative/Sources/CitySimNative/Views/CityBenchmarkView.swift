import SwiftUI

struct CityBenchmarkView: View {
    let session: CityBenchmarkSessionPresentation
    let runAction: () -> Void
    let cancelRunAction: () -> Void
    let exportAction: () -> Void
    let backAction: () -> Void
    let doneAction: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 700
            ZStack {
                Color.black.opacity(0.76).ignoresSafeArea()
                VStack(spacing: compact ? 14 : 18) {
                    header(compact: compact)
                    content(compact: compact)
                    actionBar
                }
                .padding(compact ? 22 : 28)
                .frame(width: min(850, max(720, proxy.size.width - 40)))
                .cityPanelBackground(
                    .regular,
                    in: RoundedRectangle(cornerRadius: 26, style: .continuous)
                )
                .overlay(RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.15)))
                .shadow(color: .black.opacity(0.45), radius: 36, y: 18)
            }
        }
        .accessibilityIdentifier("benchmark.blocking-modal")
    }

    private func header(compact: Bool) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(GameTheme.information.opacity(0.16))
                    .frame(width: compact ? 58 : 68, height: compact ? 58 : 68)
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .font(.system(size: compact ? 28 : 34, weight: .semibold))
                    .foregroundStyle(GameTheme.information.gradient)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("Native Performance Benchmark")
                    .font(.system(size: compact ? 25 : 29, weight: .heavy, design: .rounded))
                Text(session.definition.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            phaseBadge
        }
    }

    @ViewBuilder
    private func content(compact: Bool) -> some View {
        switch session.phase {
        case .ready:
            readyContent(compact: compact)
        case .running:
            runningContent
        case .complete:
            if let result = session.result {
                resultContent(result, compact: compact)
            }
        case .canceled, .failed:
            stoppedContent
        }
    }

    private func readyContent(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 12 : 16) {
            Text(session.definition.detail)
                .font(.title3)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                factCard("Pulses", session.definition.pulseCount.formatted(), "waveform.path.ecg")
                factCard("City", session.definition.citySize, "square.grid.3x3.fill")
                factCard("Seed", String(session.definition.seed), "number")
            }
            safetyNotice
        }
    }

    private var runningContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Running the known city workload…")
                .font(.title3.weight(.semibold))
            ProgressView(value: session.progress)
                .progressViewStyle(.linear)
                .tint(GameTheme.information)
                .accessibilityLabel("Benchmark progress")
                .accessibilityValue("\(Int((session.progress * 100).rounded())) percent")
            HStack {
                Text("Pulse \(session.completedPulses) of \(session.definition.pulseCount)")
                    .monospacedDigit()
                Spacer()
                Text("Temporary city · no autosave")
            }
            .font(.callout.weight(.semibold))
            .foregroundStyle(.secondary)
            safetyNotice
        }
    }

    private func resultContent(_ result: CityBenchmarkResult, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 12 : 16) {
            HStack {
                Label(
                    result.assessment,
                    systemImage: result.withinProvisionalBudget && result.fingerprintVerified
                        ? "checkmark.seal.fill"
                        : "exclamationmark.triangle.fill"
                )
                .font(.headline)
                .foregroundStyle(
                    result.withinProvisionalBudget && result.fingerprintVerified
                        ? GameTheme.accent
                        : GameTheme.warning
                )
                Spacer()
                Text("LOCAL RESULT")
                    .font(.caption.weight(.black))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                metricCard("Average", result.averagePulseMilliseconds.millisecondsText, "timer")
                metricCard("95th percentile", result.p95PulseMilliseconds.millisecondsText, "chart.line.uptrend.xyaxis")
                metricCard("Throughput", "\(Int(result.pulsesPerSecond.rounded())) pulses/s", "speedometer")
            }
            HStack(spacing: 10) {
                factCard("Logical ticks", result.logicalTicks.formatted(), "clock.arrow.2.circlepath")
                factCard("Developed tiles", result.developedTiles.formatted(), "building.2.fill")
                factCard("Final state", result.shortFingerprint, "number.square.fill")
            }
            if let reportURL = session.reportURL {
                Label("Report saved · \(reportURL.lastPathComponent)", systemImage: "doc.badge.checkmark.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GameTheme.accent)
            } else if let message = session.message {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GameTheme.warning)
            }
            Text(session.definition.qualification)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var stoppedContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(
                session.phase == .canceled ? "Benchmark canceled" : "Benchmark could not finish",
                systemImage: session.phase == .canceled ? "stop.circle.fill" : "exclamationmark.triangle.fill"
            )
            .font(.title3.weight(.bold))
            .foregroundStyle(session.phase == .canceled ? .secondary : GameTheme.warning)
            Text(session.message ?? "Your current city was not changed. You can run the workload again or return to the mode chooser.")
                .foregroundStyle(.secondary)
            safetyNotice
        }
    }

    private var safetyNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Your current city remains paused and unchanged.", systemImage: "lock.shield.fill")
                .font(.callout.weight(.semibold))
                .foregroundStyle(GameTheme.accent)
            Text(session.definition.qualification)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
    }

    private func factCard(_ label: String, _ value: String, _ symbol: String) -> some View {
        metricCard(label, value, symbol)
    }

    private func metricCard(_ label: String, _ value: String, _ symbol: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .foregroundStyle(GameTheme.information)
            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline.monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private var phaseBadge: some View {
        Text(phaseTitle)
            .font(.caption.weight(.black))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(GameTheme.information.opacity(0.15), in: Capsule())
            .foregroundStyle(GameTheme.information)
    }

    private var phaseTitle: String {
        switch session.phase {
        case .ready: "READY"
        case .running: "RUNNING"
        case .complete: "COMPLETE"
        case .canceled: "CANCELED"
        case .failed: "INCOMPLETE"
        }
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button("Mode Chooser", action: backAction)
                .buttonStyle(.bordered)
                .disabled(session.phase == .running)
            Spacer()
            switch session.phase {
            case .ready, .canceled, .failed:
                Button("Done", action: doneAction)
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                Button("Run Benchmark", action: runAction)
                    .buttonStyle(.borderedProminent)
                    .tint(GameTheme.information)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("benchmark.run")
            case .running:
                Button("Cancel Run", action: cancelRunAction)
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("benchmark.cancel")
            case .complete:
                Button("Run Again", action: runAction)
                    .buttonStyle(.bordered)
                Button("Export Report", action: exportAction)
                    .buttonStyle(.borderedProminent)
                    .tint(GameTheme.information)
                    .accessibilityIdentifier("benchmark.export")
                Button("Done", action: doneAction)
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
            }
        }
    }
}

private extension Double {
    var millisecondsText: String {
        if self < 1 { return String(format: "%.3f ms", self) }
        return String(format: "%.2f ms", self)
    }
}
