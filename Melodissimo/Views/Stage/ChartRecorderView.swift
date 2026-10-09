//
//  ChartRecorderView.swift
//  Melodissimo
//

#if DEBUG
import SwiftUI
import AudioToolbox

/// DEBUG-only tool for authoring rhythm charts by playing along: pick a song and a tempo, play the
/// melody on the keyboard to a metronome, and the recording is quantized into `chart_<slug>.json`.
/// Reached by long-pressing the title on Home. (English only: it is a developer tool.)
struct ChartRecorderView: View {
    @EnvironmentObject private var router: AppRouter
    @StateObject private var model = ChartRecorderViewModel(song: SongLibrary.all[0])

    @State private var savedURL: URL?
    @State private var message: String?
    @State private var lastTickBeat = -1

    private let ticker = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.softBlue.ignoresSafeArea()

            VStack(spacing: 12) {
                topBar
                switch model.phase {
                case .setup: setupPanel
                case .recording: recordingPanel
                case .finished: finishedPanel
                }
                Spacer(minLength: 0)
                if model.phase == .recording {
                    PianoKeyboard(metrics: .stage,
                                  showLabels: true,
                                  highlights: model.wrongKeyId.map { [$0: Color.red] } ?? [:],
                                  onNoteOn: { model.keyDown($0, now: CACurrentMediaTime()) })
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .onReceive(ticker) { _ in tickMetronome() }
        .onChange(of: model.phase) { phase in
            if phase == .finished { saveOutputs() }
        }
        .onChange(of: model.wrongKeyId) { id in
            guard id != nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { model.clearWrongKey() }
        }
    }

    // MARK: Panels

    private var topBar: some View {
        HStack {
            Button { router.pop() } label: {
                Text("< Back")
                    .frame(width: 120, height: 64)
                    .background(Color.darkGreen)
                    .foregroundColor(.white)
                    .cornerRadius(20)
                    .font(Font.headline)
            }
            Spacer()
            Text("Chart Recorder (DEBUG)")
                .font(.custom("BalooDa-Regular", size: 32))
                .foregroundColor(Color.darkGreen)
            Spacer()
            Color.clear.frame(width: 120, height: 64)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    private var setupPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Song").font(.headline)
                Picker("Song", selection: $model.song) {
                    ForEach(SongLibrary.all) { song in
                        Text(song.title).tag(song)
                    }
                }
                .pickerStyle(.menu)
                Text("\(model.song.keyIds.count) notes")
                    .foregroundColor(Color.darkGreen.opacity(0.7))
            }

            HStack(spacing: 16) {
                Text("BPM").font(.headline)
                Slider(value: $model.bpm, in: 60...160, step: 1)
                    .frame(maxWidth: 420)
                Text("\(Int(model.bpm))")
                    .font(.custom("BalooDa-Regular", size: 32))
                    .frame(width: 60)
            }

            HStack(spacing: 16) {
                Text("Grid").font(.headline)
                Picker("Grid", selection: $model.grid) {
                    Text("1/2 beat").tag(0.5)
                    Text("1/4 beat").tag(0.25)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 300)
            }

            Text("Press Start, count along with the four metronome beats, then play the melody. A wrong key flashes red and is ignored.")
                .font(.footnote)
                .foregroundColor(Color.darkGreen.opacity(0.8))

            Button { model.start(now: CACurrentMediaTime()) } label: {
                Text("Start")
                    .frame(width: 220, height: 64)
                    .background(Color.darkGreen)
                    .foregroundColor(.white)
                    .cornerRadius(20)
                    .font(Font.headline)
            }
        }
        .foregroundColor(Color.darkGreen)
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var recordingPanel: some View {
        TimelineView(.animation) { timeline in
            let _ = timeline.date
            let now = CACurrentMediaTime()
            let counting = model.isCountingIn(now: now)
            HStack(spacing: 40) {
                Circle()
                    .fill(counting ? Color.red : Color.darkGreen)
                    .opacity(1 - 0.8 * model.beatProgress(now: now))
                    .frame(width: 70, height: 70)

                VStack(spacing: 2) {
                    Text(counting ? "Count-in \(model.metronomeBeat(now: now) + 1)" : "Play")
                        .font(.headline)
                    Text(expectedLabel)
                        .font(.custom("BalooDa-Regular", size: 130))
                    Text("\(model.recordedCount) / \(model.song.keyIds.count)")
                        .font(.custom("BalooDa-Regular", size: 28))
                }
                .foregroundColor(Color.darkGreen)

                Button { model.stop() } label: {
                    Text("Stop")
                        .frame(width: 140, height: 64)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                        .font(Font.headline)
                }
            }
        }
    }

    private var expectedLabel: String {
        model.expectedKeyId.map { NoteCatalog.note($0).label } ?? "✓"
    }

    private var finishedPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let chart = model.chart {
                Text("\(chart.notes.count) notes recorded at \(Int(chart.bpm)) bpm")
                    .font(.custom("BalooDa-Regular", size: 30))
                Text("JSON printed to the console and copied to the clipboard.")
                if let savedURL {
                    Text("Saved to:").font(.headline)
                    Text(savedURL.path)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                    Text("Simulator: xcrun simctl get_app_container booted com.balqishafiraini.Melodissimo data, then Documents/")
                        .font(.footnote)
                        .foregroundColor(Color.darkGreen.opacity(0.7))
                }
                if !model.chart!.matchesMelody(of: model.song) {
                    Text("Warning: the recorded keys differ from the song's melody.").foregroundColor(Color.red)
                }
                HStack(spacing: 16) {
                    Button { router.push(.chartPreview(chart)) } label: {
                        buttonLabel("Preview (Listen)", filled: true)
                    }
                    Button { model.reset() } label: {
                        buttonLabel("Record again", filled: false)
                    }
                }
            } else {
                Text("Nothing was recorded.").font(.headline)
                Button { model.reset() } label: { buttonLabel("Record again", filled: false) }
            }
            if let message {
                Text(message).foregroundColor(Color.red)
            }
        }
        .foregroundColor(Color.darkGreen)
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func buttonLabel(_ title: String, filled: Bool) -> some View {
        Text(title)
            .frame(width: 240, height: 64)
            .background(filled ? Color.darkGreen : Color.yellow)
            .foregroundColor(filled ? .white : Color.darkGreen)
            .cornerRadius(20)
            .font(Font.headline)
    }

    // MARK: Actions

    /// An audible tick on each metronome beat while recording.
    private func tickMetronome() {
        guard model.phase == .recording else {
            lastTickBeat = -1
            return
        }
        let beat = model.metronomeBeat(now: CACurrentMediaTime())
        if beat != lastTickBeat {
            lastTickBeat = beat
            AudioServicesPlaySystemSound(1104)
        }
    }

    /// Prints the JSON, copies it, and writes `Documents/chart_<slug>.json`.
    private func saveOutputs() {
        guard let chart = model.chart else { return }
        do {
            let json = try ChartQuantizer.json(for: chart)
            print("--- chart_\(model.song.id).json ---\n\(json)\n--- end ---")
            UIPasteboard.general.string = json
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            savedURL = try ChartQuantizer.write(chart, for: model.song, to: documents)
            message = nil
        } catch {
            message = "Could not save: \(error.localizedDescription)"
        }
    }
}
#endif
