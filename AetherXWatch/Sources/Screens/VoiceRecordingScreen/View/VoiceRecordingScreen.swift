//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

struct VoiceRecordingScreen: View {
    @Bindable var context: VoiceRecordingScreenViewModel.Context

    private var viewState: VoiceRecordingScreenViewState {
        context.viewState
    }

    private var isShowingError: Binding<Bool> {
        Binding(get: { context.viewState.bindings.errorMessage != nil },
                set: { if !$0 { context.errorMessage = nil } })
    }

    var body: some View {
        content
            .navigationTitle(WatchStrings.voiceMessage)
            .onAppear { context.send(viewAction: .appear) }
            // Back, ✕ and the sheet closing all end here; after a send or a delete it's a no-op.
            .onDisappear { context.send(viewAction: .dismiss) }
            .alert(viewState.bindings.errorMessage ?? "", isPresented: isShowingError) {
                if viewState.bindings.canRetrySend {
                    Button(WatchStrings.tryAgain) { context.send(viewAction: .retrySend) }
                    Button(WatchStrings.cancel, role: .cancel) { }
                } else {
                    Button(WatchStrings.ok) { context.send(viewAction: .delete) }
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewState.step {
        case .starting:
            ProgressView()
        case .permissionDenied:
            ScrollView {
                Text(WatchStrings.microphoneAccessOff)
                    .font(.footnote)
                    .foregroundStyle(Color.compound.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case let .recording(elapsed, level, isNearLimit):
            recording(elapsed: elapsed, level: level, isNearLimit: isNearLimit)
        case .preparing:
            progress(WatchStrings.preparing)
        case let .review(message, waveform):
            review(message: message, waveform: waveform)
        case .sending:
            progress(WatchStrings.sending)
        }
    }

    private func recording(elapsed: TimeInterval, level: Float, isNearLimit: Bool) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                RecordingDot(level: level)
                Text(elapsed.formattedMinutesSeconds())
                    .font(.title2.monospacedDigit())
                    .foregroundStyle(isNearLimit ? Color.compound.textWarningPrimary : Color.compound.textPrimary)
            }
            LevelMeter(level: level)
                .frame(height: 6)
                .padding(.horizontal, 24)
            Button { context.send(viewAction: .stop) } label: {
                Image(compound: \.stopSolid)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(CircleGlassButtonStyle(size: 64, iconColor: Color.compound.iconCriticalPrimary))
            .accessibilityLabel(WatchStrings.stop)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func review(message: EncodedVoiceMessage, waveform: [Float]) -> some View {
        ScrollView {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Button { context.send(viewAction: .togglePlayback) } label: {
                        if viewState.isStartingPlayback {
                            ProgressView()
                        } else {
                            Image(compound: viewState.isPlaying ? \.pauseSolid : \.playSolid)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                        }
                    }
                    .buttonStyle(CircleGlassButtonStyle(size: 36))
                    .accessibilityLabel(viewState.isPlaying ? WatchStrings.pause : WatchStrings.play)
                    WaveformView(waveform: waveform, progress: viewState.playbackProgress)
                        .frame(height: 28)
                }
                Text((viewState.remainingPlaybackTime ?? message.duration).formattedMinutesSeconds(roundingUp: true))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Color.compound.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Button(WatchStrings.send) { context.send(viewAction: .send) }
                    .buttonStyle(.fullWidthProminent)
                Button { context.send(viewAction: .delete) } label: {
                    Text(WatchStrings.delete).foregroundStyle(Color.compound.textCriticalPrimary)
                }
                .buttonStyle(.fullWidth)
            }
        }
    }

    private func progress(_ title: String) -> some View {
        VStack(spacing: 4) {
            ProgressView()
            Text(title)
                .font(.footnote)
                .foregroundStyle(Color.compound.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A red dot that pulses, growing with the input level.
private struct RecordingDot: View {
    let level: Float
    @State private var isDimmed = false

    var body: some View {
        Circle()
            .fill(Color.compound.iconCriticalPrimary)
            .frame(width: 12, height: 12)
            .scaleEffect(1 + CGFloat(level) * 0.5)
            .animation(.easeOut(duration: 0.1), value: level)
            .opacity(isDimmed ? 0.4 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever()) { isDimmed = true }
            }
    }
}

private struct LevelMeter: View {
    let level: Float

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.compound.bgSubtleSecondary)
                Capsule()
                    .fill(Color.compound.iconAccentPrimary)
                    .frame(width: geometry.size.width * CGFloat(min(max(level, 0), 1)))
                    .animation(.easeOut(duration: 0.1), value: level)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Previews

struct VoiceRecordingScreen_Previews: PreviewProvider {
    static let message = EncodedVoiceMessage(fileURL: URL(filePath: "/tmp/preview.ogg"), duration: 12.4, size: 20000)
    static let waveform: [Float] = (0..<100).map { index in Float(abs(sin(Double(index) / 5))) * 0.8 + 0.1 }

    // Kept alive by the previews: a context only weakly references its view model.
    static let starting = makeViewModel(recorderState: .idle, start: .none)
    static let recording = makeViewModel(recorderState: .recording(elapsed: 12, level: 0.6, isNearLimit: false))
    static let nearLimit = makeViewModel(recorderState: .recording(elapsed: 275, level: 0.3, isNearLimit: true))
    static let permissionDenied = makeViewModel(recorderState: .idle, start: .failure(.permissionDenied))
    static let preparing = makeViewModel(recorderState: .stopped(recorded), encodes: false)
    static let review = makeViewModel(recorderState: .stopped(recorded))
    static let playing = makeViewModel(recorderState: .stopped(recorded), playerState: .playing(progress: 0.4))
    static let decoding = makeDecodingViewModel()
    static let sending = makeSendingViewModel(sends: nil)
    static let sendFailed = makeSendingViewModel(sends: .failure(.sdkError("offline")))

    static var recorded: RecordedVoiceMessage {
        RecordedVoiceMessage(pcmURL: URL(filePath: "/tmp/preview.caf"), duration: 12.4, waveform: waveform)
    }

    static var previews: some View {
        screen(starting)
            .previewDisplayName("Starting")
        screen(recording)
            .previewDisplayName("Recording")
        screen(nearLimit)
            .previewDisplayName("Recording near the limit")
        screen(permissionDenied)
            .previewDisplayName("Permission denied")
        screen(preparing)
            .previewDisplayName("Preparing")
        screen(review)
            .previewDisplayName("Review")
        screen(decoding)
            .previewDisplayName("Review decoding")
        screen(playing)
            .previewDisplayName("Review playing")
        screen(sending)
            .previewDisplayName("Sending")
        screen(sendFailed)
            .previewDisplayName("Send failed")
    }

    static func screen(_ viewModel: VoiceRecordingScreenViewModel) -> some View {
        NavigationStack { VoiceRecordingScreen(context: viewModel.context) }
    }

    /// - Parameters:
    ///   - start: The recorder's start result, or `nil` to never finish starting.
    ///   - sends: The send result, or `nil` to never finish sending.
    ///   - plays: Whether a play finishes decoding.
    static func makeViewModel(recorderState: VoiceRecorderState,
                              start: Result<Void, VoiceRecorderError>? = .success(()),
                              encodes: Bool = true,
                              sends: Result<Void, TimelineProxyError>? = .success(()),
                              plays: Bool = true,
                              playerState: VoiceMessagePreviewPlayerState = .stopped) -> VoiceRecordingScreenViewModel {
        let recorder = VoiceMessageRecorderMock()
        recorder.state = recorderState
        recorder.statePublisher = Just(recorderState).eraseToAnyPublisher()
        recorder.startClosure = {
            guard let start else { return await never(.success(())) }
            return start
        }

        let player = VoiceMessagePreviewPlayerMock()
        player.statePublisher = Just(playerState).eraseToAnyPublisher()
        player.playFileURLClosure = { _ in plays ? .success(()) : await never(.success(())) }

        return VoiceRecordingScreenViewModel(recorder: recorder,
                                             encode: { _ in encodes ? .success(message) : await never(.failure(.encodingFailed)) },
                                             send: { _, _ in
                                                 guard let sends else { return await never(.success(())) }
                                                 return sends
                                             },
                                             previewPlayer: player)
    }

    /// Taps Send once the review is up.
    static func makeSendingViewModel(sends: Result<Void, TimelineProxyError>?) -> VoiceRecordingScreenViewModel {
        let viewModel = makeViewModel(recorderState: .stopped(recorded), sends: sends)
        Task {
            await Task.yield()
            viewModel.context.send(viewAction: .send)
        }
        return viewModel
    }

    /// Taps ▶︎ once the review is up, and the first play never finishes decoding.
    static func makeDecodingViewModel() -> VoiceRecordingScreenViewModel {
        let viewModel = makeViewModel(recorderState: .stopped(recorded), plays: false)
        Task {
            await Task.yield()
            viewModel.context.send(viewAction: .togglePlayback)
        }
        return viewModel
    }

    private static func never<T>(_ value: T) async -> T {
        try? await Task.sleep(for: .seconds(999))
        return value
    }
}
