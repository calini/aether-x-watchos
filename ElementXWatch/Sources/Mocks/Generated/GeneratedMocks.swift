// Generated using Sourcery 2.3.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

// swiftlint:disable all
@preconcurrency import Combine
@preconcurrency import SwiftUI

@preconcurrency import MatrixRustSDK

import Foundation

nonisolated class AudioPlaybackBackendMock: AudioPlaybackBackend, @unchecked Sendable {
    var duration: TimeInterval {
        get { return underlyingDuration }
        set(value) { underlyingDuration = value }
    }
    nonisolated(unsafe) var underlyingDuration: TimeInterval!
    var currentTime: TimeInterval {
        get { return underlyingCurrentTime }
        set(value) { underlyingCurrentTime = value }
    }
    nonisolated(unsafe) var underlyingCurrentTime: TimeInterval!
    nonisolated(unsafe) var finishHandler: (() -> Void)?

    //MARK: - play

    private let playCallsCountLock = NSLock()
    private nonisolated(unsafe) var playUnderlyingCallsCount = 0
    var playCallsCount: Int {
        get { playCallsCountLock.withLock { playUnderlyingCallsCount } }
        set { playCallsCountLock.withLock { playUnderlyingCallsCount = newValue } }
    }
    var playCalled: Bool {
        return playCallsCount > 0
    }

    private let playReturnValueLock = NSLock()
    private nonisolated(unsafe) var playUnderlyingReturnValue: Bool!
    var playReturnValue: Bool! {
        get { playReturnValueLock.withLock { playUnderlyingReturnValue } }
        set { playReturnValueLock.withLock { playUnderlyingReturnValue = newValue } }
    }
    nonisolated(unsafe) var playClosure: (() -> Bool)?

    func play() -> Bool {
        playCallsCountLock.withLock { playUnderlyingCallsCount += 1 }
        if let playClosure = playClosure {
            return playClosure()
        } else {
            return playReturnValue
        }
    }
    //MARK: - pause

    private let pauseCallsCountLock = NSLock()
    private nonisolated(unsafe) var pauseUnderlyingCallsCount = 0
    var pauseCallsCount: Int {
        get { pauseCallsCountLock.withLock { pauseUnderlyingCallsCount } }
        set { pauseCallsCountLock.withLock { pauseUnderlyingCallsCount = newValue } }
    }
    var pauseCalled: Bool {
        return pauseCallsCount > 0
    }
    nonisolated(unsafe) var pauseClosure: (() -> Void)?

    func pause() {
        pauseCallsCountLock.withLock { pauseUnderlyingCallsCount += 1 }
        pauseClosure?()
    }
    //MARK: - stop

    private let stopCallsCountLock = NSLock()
    private nonisolated(unsafe) var stopUnderlyingCallsCount = 0
    var stopCallsCount: Int {
        get { stopCallsCountLock.withLock { stopUnderlyingCallsCount } }
        set { stopCallsCountLock.withLock { stopUnderlyingCallsCount = newValue } }
    }
    var stopCalled: Bool {
        return stopCallsCount > 0
    }
    nonisolated(unsafe) var stopClosure: (() -> Void)?

    func stop() {
        stopCallsCountLock.withLock { stopUnderlyingCallsCount += 1 }
        stopClosure?()
    }
}
nonisolated class AudioRecorderBackendMock: AudioRecorderBackend, @unchecked Sendable {
    var currentTime: TimeInterval {
        get { return underlyingCurrentTime }
        set(value) { underlyingCurrentTime = value }
    }
    nonisolated(unsafe) var underlyingCurrentTime: TimeInterval!
    var interruptions: AnyPublisher<Void, Never> {
        get { return underlyingInterruptions }
        set(value) { underlyingInterruptions = value }
    }
    nonisolated(unsafe) var underlyingInterruptions: AnyPublisher<Void, Never>!

    //MARK: - start

    nonisolated(unsafe) var startUrlThrowableError: Error?
    private let startUrlCallsCountLock = NSLock()
    private nonisolated(unsafe) var startUrlUnderlyingCallsCount = 0
    var startUrlCallsCount: Int {
        get { startUrlCallsCountLock.withLock { startUrlUnderlyingCallsCount } }
        set { startUrlCallsCountLock.withLock { startUrlUnderlyingCallsCount = newValue } }
    }
    var startUrlCalled: Bool {
        return startUrlCallsCount > 0
    }
    private let startUrlReceivedUrlLock = NSLock()
    private nonisolated(unsafe) var startUrlUnderlyingReceivedUrl: URL?
    var startUrlReceivedUrl: URL? {
        get { startUrlReceivedUrlLock.withLock { startUrlUnderlyingReceivedUrl } }
        set { startUrlReceivedUrlLock.withLock { startUrlUnderlyingReceivedUrl = newValue } }
    }
    private let startUrlReceivedInvocationsLock = NSLock()
    private nonisolated(unsafe) var startUrlUnderlyingReceivedInvocations: [URL] = []
    var startUrlReceivedInvocations: [URL] {
        get { startUrlReceivedInvocationsLock.withLock { startUrlUnderlyingReceivedInvocations } }
        set { startUrlReceivedInvocationsLock.withLock { startUrlUnderlyingReceivedInvocations = newValue } }
    }
    nonisolated(unsafe) var startUrlClosure: ((URL) throws -> Void)?

    func start(url: URL) throws {
        if let error = startUrlThrowableError {
            throw error
        }
        startUrlCallsCountLock.withLock { startUrlUnderlyingCallsCount += 1 }
        startUrlReceivedUrl = url
        startUrlReceivedInvocationsLock.withLock { startUrlUnderlyingReceivedInvocations.append(url) }
        try startUrlClosure?(url)
    }
    //MARK: - stop

    private let stopCallsCountLock = NSLock()
    private nonisolated(unsafe) var stopUnderlyingCallsCount = 0
    var stopCallsCount: Int {
        get { stopCallsCountLock.withLock { stopUnderlyingCallsCount } }
        set { stopCallsCountLock.withLock { stopUnderlyingCallsCount = newValue } }
    }
    var stopCalled: Bool {
        return stopCallsCount > 0
    }
    nonisolated(unsafe) var stopClosure: (() -> Void)?

    func stop() {
        stopCallsCountLock.withLock { stopUnderlyingCallsCount += 1 }
        stopClosure?()
    }
    //MARK: - averagePower

    private let averagePowerCallsCountLock = NSLock()
    private nonisolated(unsafe) var averagePowerUnderlyingCallsCount = 0
    var averagePowerCallsCount: Int {
        get { averagePowerCallsCountLock.withLock { averagePowerUnderlyingCallsCount } }
        set { averagePowerCallsCountLock.withLock { averagePowerUnderlyingCallsCount = newValue } }
    }
    var averagePowerCalled: Bool {
        return averagePowerCallsCount > 0
    }

    private let averagePowerReturnValueLock = NSLock()
    private nonisolated(unsafe) var averagePowerUnderlyingReturnValue: Float!
    var averagePowerReturnValue: Float! {
        get { averagePowerReturnValueLock.withLock { averagePowerUnderlyingReturnValue } }
        set { averagePowerReturnValueLock.withLock { averagePowerUnderlyingReturnValue = newValue } }
    }
    nonisolated(unsafe) var averagePowerClosure: (() -> Float)?

    func averagePower() -> Float {
        averagePowerCallsCountLock.withLock { averagePowerUnderlyingCallsCount += 1 }
        if let averagePowerClosure = averagePowerClosure {
            return averagePowerClosure()
        } else {
            return averagePowerReturnValue
        }
    }
}
nonisolated class AudioSessionProxyMock: AudioSessionProxyProtocol, @unchecked Sendable {
    var recordPermission: MicrophonePermission {
        get { return underlyingRecordPermission }
        set(value) { underlyingRecordPermission = value }
    }
    nonisolated(unsafe) var underlyingRecordPermission: MicrophonePermission!

    //MARK: - requestRecordPermission

    private let requestRecordPermissionCallsCountLock = NSLock()
    private nonisolated(unsafe) var requestRecordPermissionUnderlyingCallsCount = 0
    var requestRecordPermissionCallsCount: Int {
        get { requestRecordPermissionCallsCountLock.withLock { requestRecordPermissionUnderlyingCallsCount } }
        set { requestRecordPermissionCallsCountLock.withLock { requestRecordPermissionUnderlyingCallsCount = newValue } }
    }
    var requestRecordPermissionCalled: Bool {
        return requestRecordPermissionCallsCount > 0
    }

    private let requestRecordPermissionReturnValueLock = NSLock()
    private nonisolated(unsafe) var requestRecordPermissionUnderlyingReturnValue: Bool!
    var requestRecordPermissionReturnValue: Bool! {
        get { requestRecordPermissionReturnValueLock.withLock { requestRecordPermissionUnderlyingReturnValue } }
        set { requestRecordPermissionReturnValueLock.withLock { requestRecordPermissionUnderlyingReturnValue = newValue } }
    }
    nonisolated(unsafe) var requestRecordPermissionClosure: (() async -> Bool)?

    @concurrent func requestRecordPermission() async -> Bool {
        requestRecordPermissionCallsCountLock.withLock { requestRecordPermissionUnderlyingCallsCount += 1 }
        if let requestRecordPermissionClosure = requestRecordPermissionClosure {
            return await requestRecordPermissionClosure()
        } else {
            return requestRecordPermissionReturnValue
        }
    }
    //MARK: - activateForRecording

    nonisolated(unsafe) var activateForRecordingThrowableError: Error?
    private let activateForRecordingCallsCountLock = NSLock()
    private nonisolated(unsafe) var activateForRecordingUnderlyingCallsCount = 0
    var activateForRecordingCallsCount: Int {
        get { activateForRecordingCallsCountLock.withLock { activateForRecordingUnderlyingCallsCount } }
        set { activateForRecordingCallsCountLock.withLock { activateForRecordingUnderlyingCallsCount = newValue } }
    }
    var activateForRecordingCalled: Bool {
        return activateForRecordingCallsCount > 0
    }
    nonisolated(unsafe) var activateForRecordingClosure: (() throws -> Void)?

    func activateForRecording() throws {
        if let error = activateForRecordingThrowableError {
            throw error
        }
        activateForRecordingCallsCountLock.withLock { activateForRecordingUnderlyingCallsCount += 1 }
        try activateForRecordingClosure?()
    }
    //MARK: - activateForPlayback

    nonisolated(unsafe) var activateForPlaybackThrowableError: Error?
    private let activateForPlaybackCallsCountLock = NSLock()
    private nonisolated(unsafe) var activateForPlaybackUnderlyingCallsCount = 0
    var activateForPlaybackCallsCount: Int {
        get { activateForPlaybackCallsCountLock.withLock { activateForPlaybackUnderlyingCallsCount } }
        set { activateForPlaybackCallsCountLock.withLock { activateForPlaybackUnderlyingCallsCount = newValue } }
    }
    var activateForPlaybackCalled: Bool {
        return activateForPlaybackCallsCount > 0
    }
    nonisolated(unsafe) var activateForPlaybackClosure: (() throws -> Void)?

    func activateForPlayback() throws {
        if let error = activateForPlaybackThrowableError {
            throw error
        }
        activateForPlaybackCallsCountLock.withLock { activateForPlaybackUnderlyingCallsCount += 1 }
        try activateForPlaybackClosure?()
    }
    //MARK: - deactivate

    private let deactivateCallsCountLock = NSLock()
    private nonisolated(unsafe) var deactivateUnderlyingCallsCount = 0
    var deactivateCallsCount: Int {
        get { deactivateCallsCountLock.withLock { deactivateUnderlyingCallsCount } }
        set { deactivateCallsCountLock.withLock { deactivateUnderlyingCallsCount = newValue } }
    }
    var deactivateCalled: Bool {
        return deactivateCallsCount > 0
    }
    nonisolated(unsafe) var deactivateClosure: (() -> Void)?

    func deactivate() {
        deactivateCallsCountLock.withLock { deactivateUnderlyingCallsCount += 1 }
        deactivateClosure?()
    }
}
nonisolated class AuthenticationServiceMock: AuthenticationServiceProtocol, @unchecked Sendable {

    //MARK: - configure

    private let configureServerCallsCountLock = NSLock()
    private nonisolated(unsafe) var configureServerUnderlyingCallsCount = 0
    var configureServerCallsCount: Int {
        get { configureServerCallsCountLock.withLock { configureServerUnderlyingCallsCount } }
        set { configureServerCallsCountLock.withLock { configureServerUnderlyingCallsCount = newValue } }
    }
    var configureServerCalled: Bool {
        return configureServerCallsCount > 0
    }
    private let configureServerReceivedServerLock = NSLock()
    private nonisolated(unsafe) var configureServerUnderlyingReceivedServer: String?
    var configureServerReceivedServer: String? {
        get { configureServerReceivedServerLock.withLock { configureServerUnderlyingReceivedServer } }
        set { configureServerReceivedServerLock.withLock { configureServerUnderlyingReceivedServer = newValue } }
    }
    private let configureServerReceivedInvocationsLock = NSLock()
    private nonisolated(unsafe) var configureServerUnderlyingReceivedInvocations: [String] = []
    var configureServerReceivedInvocations: [String] {
        get { configureServerReceivedInvocationsLock.withLock { configureServerUnderlyingReceivedInvocations } }
        set { configureServerReceivedInvocationsLock.withLock { configureServerUnderlyingReceivedInvocations = newValue } }
    }

    private let configureServerReturnValueLock = NSLock()
    private nonisolated(unsafe) var configureServerUnderlyingReturnValue: Result<LoginOptions, AuthenticationError>!
    var configureServerReturnValue: Result<LoginOptions, AuthenticationError>! {
        get { configureServerReturnValueLock.withLock { configureServerUnderlyingReturnValue } }
        set { configureServerReturnValueLock.withLock { configureServerUnderlyingReturnValue = newValue } }
    }
    nonisolated(unsafe) var configureServerClosure: ((String) async -> Result<LoginOptions, AuthenticationError>)?

    @concurrent func configure(server: String) async -> Result<LoginOptions, AuthenticationError> {
        configureServerCallsCountLock.withLock { configureServerUnderlyingCallsCount += 1 }
        configureServerReceivedServer = server
        configureServerReceivedInvocationsLock.withLock { configureServerUnderlyingReceivedInvocations.append(server) }
        if let configureServerClosure = configureServerClosure {
            return await configureServerClosure(server)
        } else {
            return configureServerReturnValue
        }
    }
    //MARK: - login

    private let loginUsernamePasswordCallsCountLock = NSLock()
    private nonisolated(unsafe) var loginUsernamePasswordUnderlyingCallsCount = 0
    var loginUsernamePasswordCallsCount: Int {
        get { loginUsernamePasswordCallsCountLock.withLock { loginUsernamePasswordUnderlyingCallsCount } }
        set { loginUsernamePasswordCallsCountLock.withLock { loginUsernamePasswordUnderlyingCallsCount = newValue } }
    }
    var loginUsernamePasswordCalled: Bool {
        return loginUsernamePasswordCallsCount > 0
    }
    private let loginUsernamePasswordReceivedArgumentsLock = NSLock()
    private nonisolated(unsafe) var loginUsernamePasswordUnderlyingReceivedArguments: (username: String, password: String)?
    var loginUsernamePasswordReceivedArguments: (username: String, password: String)? {
        get { loginUsernamePasswordReceivedArgumentsLock.withLock { loginUsernamePasswordUnderlyingReceivedArguments } }
        set { loginUsernamePasswordReceivedArgumentsLock.withLock { loginUsernamePasswordUnderlyingReceivedArguments = newValue } }
    }
    private let loginUsernamePasswordReceivedInvocationsLock = NSLock()
    private nonisolated(unsafe) var loginUsernamePasswordUnderlyingReceivedInvocations: [(username: String, password: String)] = []
    var loginUsernamePasswordReceivedInvocations: [(username: String, password: String)] {
        get { loginUsernamePasswordReceivedInvocationsLock.withLock { loginUsernamePasswordUnderlyingReceivedInvocations } }
        set { loginUsernamePasswordReceivedInvocationsLock.withLock { loginUsernamePasswordUnderlyingReceivedInvocations = newValue } }
    }

    private let loginUsernamePasswordReturnValueLock = NSLock()
    private nonisolated(unsafe) var loginUsernamePasswordUnderlyingReturnValue: Result<ClientProxyProtocol, AuthenticationError>!
    var loginUsernamePasswordReturnValue: Result<ClientProxyProtocol, AuthenticationError>! {
        get { loginUsernamePasswordReturnValueLock.withLock { loginUsernamePasswordUnderlyingReturnValue } }
        set { loginUsernamePasswordReturnValueLock.withLock { loginUsernamePasswordUnderlyingReturnValue = newValue } }
    }
    nonisolated(unsafe) var loginUsernamePasswordClosure: ((String, String) async -> Result<ClientProxyProtocol, AuthenticationError>)?

    @concurrent func login(username: String, password: String) async -> Result<ClientProxyProtocol, AuthenticationError> {
        loginUsernamePasswordCallsCountLock.withLock { loginUsernamePasswordUnderlyingCallsCount += 1 }
        loginUsernamePasswordReceivedArguments = (username: username, password: password)
        loginUsernamePasswordReceivedInvocationsLock.withLock { loginUsernamePasswordUnderlyingReceivedInvocations.append((username: username, password: password)) }
        if let loginUsernamePasswordClosure = loginUsernamePasswordClosure {
            return await loginUsernamePasswordClosure(username, password)
        } else {
            return loginUsernamePasswordReturnValue
        }
    }
    //MARK: - reset

    private let resetCallsCountLock = NSLock()
    private nonisolated(unsafe) var resetUnderlyingCallsCount = 0
    var resetCallsCount: Int {
        get { resetCallsCountLock.withLock { resetUnderlyingCallsCount } }
        set { resetCallsCountLock.withLock { resetUnderlyingCallsCount = newValue } }
    }
    var resetCalled: Bool {
        return resetCallsCount > 0
    }
    nonisolated(unsafe) var resetClosure: (() -> Void)?

    func reset() {
        resetCallsCountLock.withLock { resetUnderlyingCallsCount += 1 }
        resetClosure?()
    }
}
nonisolated class ClientFactoryMock: ClientFactoryProtocol, @unchecked Sendable {

    //MARK: - makeLoginClient

    nonisolated(unsafe) var makeLoginClientServerNameDirectoriesPassphraseThrowableError: Error?
    private let makeLoginClientServerNameDirectoriesPassphraseCallsCountLock = NSLock()
    private nonisolated(unsafe) var makeLoginClientServerNameDirectoriesPassphraseUnderlyingCallsCount = 0
    var makeLoginClientServerNameDirectoriesPassphraseCallsCount: Int {
        get { makeLoginClientServerNameDirectoriesPassphraseCallsCountLock.withLock { makeLoginClientServerNameDirectoriesPassphraseUnderlyingCallsCount } }
        set { makeLoginClientServerNameDirectoriesPassphraseCallsCountLock.withLock { makeLoginClientServerNameDirectoriesPassphraseUnderlyingCallsCount = newValue } }
    }
    var makeLoginClientServerNameDirectoriesPassphraseCalled: Bool {
        return makeLoginClientServerNameDirectoriesPassphraseCallsCount > 0
    }
    private let makeLoginClientServerNameDirectoriesPassphraseReceivedArgumentsLock = NSLock()
    private nonisolated(unsafe) var makeLoginClientServerNameDirectoriesPassphraseUnderlyingReceivedArguments: (serverName: String, directories: SessionDirectories, passphrase: Data)?
    var makeLoginClientServerNameDirectoriesPassphraseReceivedArguments: (serverName: String, directories: SessionDirectories, passphrase: Data)? {
        get { makeLoginClientServerNameDirectoriesPassphraseReceivedArgumentsLock.withLock { makeLoginClientServerNameDirectoriesPassphraseUnderlyingReceivedArguments } }
        set { makeLoginClientServerNameDirectoriesPassphraseReceivedArgumentsLock.withLock { makeLoginClientServerNameDirectoriesPassphraseUnderlyingReceivedArguments = newValue } }
    }
    private let makeLoginClientServerNameDirectoriesPassphraseReceivedInvocationsLock = NSLock()
    private nonisolated(unsafe) var makeLoginClientServerNameDirectoriesPassphraseUnderlyingReceivedInvocations: [(serverName: String, directories: SessionDirectories, passphrase: Data)] = []
    var makeLoginClientServerNameDirectoriesPassphraseReceivedInvocations: [(serverName: String, directories: SessionDirectories, passphrase: Data)] {
        get { makeLoginClientServerNameDirectoriesPassphraseReceivedInvocationsLock.withLock { makeLoginClientServerNameDirectoriesPassphraseUnderlyingReceivedInvocations } }
        set { makeLoginClientServerNameDirectoriesPassphraseReceivedInvocationsLock.withLock { makeLoginClientServerNameDirectoriesPassphraseUnderlyingReceivedInvocations = newValue } }
    }

    private let makeLoginClientServerNameDirectoriesPassphraseReturnValueLock = NSLock()
    private nonisolated(unsafe) var makeLoginClientServerNameDirectoriesPassphraseUnderlyingReturnValue: Client!
    var makeLoginClientServerNameDirectoriesPassphraseReturnValue: Client! {
        get { makeLoginClientServerNameDirectoriesPassphraseReturnValueLock.withLock { makeLoginClientServerNameDirectoriesPassphraseUnderlyingReturnValue } }
        set { makeLoginClientServerNameDirectoriesPassphraseReturnValueLock.withLock { makeLoginClientServerNameDirectoriesPassphraseUnderlyingReturnValue = newValue } }
    }
    nonisolated(unsafe) var makeLoginClientServerNameDirectoriesPassphraseClosure: ((String, SessionDirectories, Data) async throws -> Client)?

    @concurrent func makeLoginClient(serverName: String, directories: SessionDirectories, passphrase: Data) async throws -> Client {
        if let error = makeLoginClientServerNameDirectoriesPassphraseThrowableError {
            throw error
        }
        makeLoginClientServerNameDirectoriesPassphraseCallsCountLock.withLock { makeLoginClientServerNameDirectoriesPassphraseUnderlyingCallsCount += 1 }
        makeLoginClientServerNameDirectoriesPassphraseReceivedArguments = (serverName: serverName, directories: directories, passphrase: passphrase)
        makeLoginClientServerNameDirectoriesPassphraseReceivedInvocationsLock.withLock { makeLoginClientServerNameDirectoriesPassphraseUnderlyingReceivedInvocations.append((serverName: serverName, directories: directories, passphrase: passphrase)) }
        if let makeLoginClientServerNameDirectoriesPassphraseClosure = makeLoginClientServerNameDirectoriesPassphraseClosure {
            return try await makeLoginClientServerNameDirectoriesPassphraseClosure(serverName, directories, passphrase)
        } else {
            return makeLoginClientServerNameDirectoriesPassphraseReturnValue
        }
    }
    //MARK: - makeRestoredClient

    nonisolated(unsafe) var makeRestoredClientTokenThrowableError: Error?
    private let makeRestoredClientTokenCallsCountLock = NSLock()
    private nonisolated(unsafe) var makeRestoredClientTokenUnderlyingCallsCount = 0
    var makeRestoredClientTokenCallsCount: Int {
        get { makeRestoredClientTokenCallsCountLock.withLock { makeRestoredClientTokenUnderlyingCallsCount } }
        set { makeRestoredClientTokenCallsCountLock.withLock { makeRestoredClientTokenUnderlyingCallsCount = newValue } }
    }
    var makeRestoredClientTokenCalled: Bool {
        return makeRestoredClientTokenCallsCount > 0
    }
    private let makeRestoredClientTokenReceivedTokenLock = NSLock()
    private nonisolated(unsafe) var makeRestoredClientTokenUnderlyingReceivedToken: RestorationToken?
    var makeRestoredClientTokenReceivedToken: RestorationToken? {
        get { makeRestoredClientTokenReceivedTokenLock.withLock { makeRestoredClientTokenUnderlyingReceivedToken } }
        set { makeRestoredClientTokenReceivedTokenLock.withLock { makeRestoredClientTokenUnderlyingReceivedToken = newValue } }
    }
    private let makeRestoredClientTokenReceivedInvocationsLock = NSLock()
    private nonisolated(unsafe) var makeRestoredClientTokenUnderlyingReceivedInvocations: [RestorationToken] = []
    var makeRestoredClientTokenReceivedInvocations: [RestorationToken] {
        get { makeRestoredClientTokenReceivedInvocationsLock.withLock { makeRestoredClientTokenUnderlyingReceivedInvocations } }
        set { makeRestoredClientTokenReceivedInvocationsLock.withLock { makeRestoredClientTokenUnderlyingReceivedInvocations = newValue } }
    }

    private let makeRestoredClientTokenReturnValueLock = NSLock()
    private nonisolated(unsafe) var makeRestoredClientTokenUnderlyingReturnValue: Client!
    var makeRestoredClientTokenReturnValue: Client! {
        get { makeRestoredClientTokenReturnValueLock.withLock { makeRestoredClientTokenUnderlyingReturnValue } }
        set { makeRestoredClientTokenReturnValueLock.withLock { makeRestoredClientTokenUnderlyingReturnValue = newValue } }
    }
    nonisolated(unsafe) var makeRestoredClientTokenClosure: ((RestorationToken) async throws -> Client)?

    @concurrent func makeRestoredClient(token: RestorationToken) async throws -> Client {
        if let error = makeRestoredClientTokenThrowableError {
            throw error
        }
        makeRestoredClientTokenCallsCountLock.withLock { makeRestoredClientTokenUnderlyingCallsCount += 1 }
        makeRestoredClientTokenReceivedToken = token
        makeRestoredClientTokenReceivedInvocationsLock.withLock { makeRestoredClientTokenUnderlyingReceivedInvocations.append(token) }
        if let makeRestoredClientTokenClosure = makeRestoredClientTokenClosure {
            return try await makeRestoredClientTokenClosure(token)
        } else {
            return makeRestoredClientTokenReturnValue
        }
    }
}
nonisolated class ClientProxyMock: ClientProxyProtocol, @unchecked Sendable {
    var userID: String {
        get { return underlyingUserID }
        set(value) { underlyingUserID = value }
    }
    nonisolated(unsafe) var underlyingUserID: String!
    nonisolated(unsafe) var deviceID: String?
    var homeserver: String {
        get { return underlyingHomeserver }
        set(value) { underlyingHomeserver = value }
    }
    nonisolated(unsafe) var underlyingHomeserver: String!
    var syncStatePublisher: AnyPublisher<SyncState, Never> {
        get { return underlyingSyncStatePublisher }
        set(value) { underlyingSyncStatePublisher = value }
    }
    nonisolated(unsafe) var underlyingSyncStatePublisher: AnyPublisher<SyncState, Never>!
    var verificationStatePublisher: AnyPublisher<SessionVerification, Never> {
        get { return underlyingVerificationStatePublisher }
        set(value) { underlyingVerificationStatePublisher = value }
    }
    nonisolated(unsafe) var underlyingVerificationStatePublisher: AnyPublisher<SessionVerification, Never>!
    var actionsPublisher: AnyPublisher<ClientProxyAction, Never> {
        get { return underlyingActionsPublisher }
        set(value) { underlyingActionsPublisher = value }
    }
    nonisolated(unsafe) var underlyingActionsPublisher: AnyPublisher<ClientProxyAction, Never>!
    var roomSummaryProvider: RoomSummaryProviderProtocol {
        get { return underlyingRoomSummaryProvider }
        set(value) { underlyingRoomSummaryProvider = value }
    }
    nonisolated(unsafe) var underlyingRoomSummaryProvider: RoomSummaryProviderProtocol!
    var ownBeaconInfoPublisher: AnyPublisher<OwnBeaconInfo, Never> {
        get { return underlyingOwnBeaconInfoPublisher }
        set(value) { underlyingOwnBeaconInfoPublisher = value }
    }
    nonisolated(unsafe) var underlyingOwnBeaconInfoPublisher: AnyPublisher<OwnBeaconInfo, Never>!

    //MARK: - startSync

    private let startSyncCallsCountLock = NSLock()
    private nonisolated(unsafe) var startSyncUnderlyingCallsCount = 0
    var startSyncCallsCount: Int {
        get { startSyncCallsCountLock.withLock { startSyncUnderlyingCallsCount } }
        set { startSyncCallsCountLock.withLock { startSyncUnderlyingCallsCount = newValue } }
    }
    var startSyncCalled: Bool {
        return startSyncCallsCount > 0
    }
    nonisolated(unsafe) var startSyncClosure: (() async -> Void)?

    @concurrent func startSync() async {
        startSyncCallsCountLock.withLock { startSyncUnderlyingCallsCount += 1 }
        await startSyncClosure?()
    }
    //MARK: - stopSync

    private let stopSyncCallsCountLock = NSLock()
    private nonisolated(unsafe) var stopSyncUnderlyingCallsCount = 0
    var stopSyncCallsCount: Int {
        get { stopSyncCallsCountLock.withLock { stopSyncUnderlyingCallsCount } }
        set { stopSyncCallsCountLock.withLock { stopSyncUnderlyingCallsCount = newValue } }
    }
    var stopSyncCalled: Bool {
        return stopSyncCallsCount > 0
    }
    nonisolated(unsafe) var stopSyncClosure: (() async -> Void)?

    @concurrent func stopSync() async {
        stopSyncCallsCountLock.withLock { stopSyncUnderlyingCallsCount += 1 }
        await stopSyncClosure?()
    }
    //MARK: - loadDisplayName

    private let loadDisplayNameCallsCountLock = NSLock()
    private nonisolated(unsafe) var loadDisplayNameUnderlyingCallsCount = 0
    var loadDisplayNameCallsCount: Int {
        get { loadDisplayNameCallsCountLock.withLock { loadDisplayNameUnderlyingCallsCount } }
        set { loadDisplayNameCallsCountLock.withLock { loadDisplayNameUnderlyingCallsCount = newValue } }
    }
    var loadDisplayNameCalled: Bool {
        return loadDisplayNameCallsCount > 0
    }

    private let loadDisplayNameReturnValueLock = NSLock()
    private nonisolated(unsafe) var loadDisplayNameUnderlyingReturnValue: String?
    var loadDisplayNameReturnValue: String? {
        get { loadDisplayNameReturnValueLock.withLock { loadDisplayNameUnderlyingReturnValue } }
        set { loadDisplayNameReturnValueLock.withLock { loadDisplayNameUnderlyingReturnValue = newValue } }
    }
    nonisolated(unsafe) var loadDisplayNameClosure: (() async -> String?)?

    @concurrent func loadDisplayName() async -> String? {
        loadDisplayNameCallsCountLock.withLock { loadDisplayNameUnderlyingCallsCount += 1 }
        if let loadDisplayNameClosure = loadDisplayNameClosure {
            return await loadDisplayNameClosure()
        } else {
            return loadDisplayNameReturnValue
        }
    }
    //MARK: - loadThumbnail

    private let loadThumbnailForWidthHeightCallsCountLock = NSLock()
    private nonisolated(unsafe) var loadThumbnailForWidthHeightUnderlyingCallsCount = 0
    var loadThumbnailForWidthHeightCallsCount: Int {
        get { loadThumbnailForWidthHeightCallsCountLock.withLock { loadThumbnailForWidthHeightUnderlyingCallsCount } }
        set { loadThumbnailForWidthHeightCallsCountLock.withLock { loadThumbnailForWidthHeightUnderlyingCallsCount = newValue } }
    }
    var loadThumbnailForWidthHeightCalled: Bool {
        return loadThumbnailForWidthHeightCallsCount > 0
    }
    private let loadThumbnailForWidthHeightReceivedArgumentsLock = NSLock()
    private nonisolated(unsafe) var loadThumbnailForWidthHeightUnderlyingReceivedArguments: (source: MediaSourceProxy, width: Int, height: Int)?
    var loadThumbnailForWidthHeightReceivedArguments: (source: MediaSourceProxy, width: Int, height: Int)? {
        get { loadThumbnailForWidthHeightReceivedArgumentsLock.withLock { loadThumbnailForWidthHeightUnderlyingReceivedArguments } }
        set { loadThumbnailForWidthHeightReceivedArgumentsLock.withLock { loadThumbnailForWidthHeightUnderlyingReceivedArguments = newValue } }
    }
    private let loadThumbnailForWidthHeightReceivedInvocationsLock = NSLock()
    private nonisolated(unsafe) var loadThumbnailForWidthHeightUnderlyingReceivedInvocations: [(source: MediaSourceProxy, width: Int, height: Int)] = []
    var loadThumbnailForWidthHeightReceivedInvocations: [(source: MediaSourceProxy, width: Int, height: Int)] {
        get { loadThumbnailForWidthHeightReceivedInvocationsLock.withLock { loadThumbnailForWidthHeightUnderlyingReceivedInvocations } }
        set { loadThumbnailForWidthHeightReceivedInvocationsLock.withLock { loadThumbnailForWidthHeightUnderlyingReceivedInvocations = newValue } }
    }

    private let loadThumbnailForWidthHeightReturnValueLock = NSLock()
    private nonisolated(unsafe) var loadThumbnailForWidthHeightUnderlyingReturnValue: Data?
    var loadThumbnailForWidthHeightReturnValue: Data? {
        get { loadThumbnailForWidthHeightReturnValueLock.withLock { loadThumbnailForWidthHeightUnderlyingReturnValue } }
        set { loadThumbnailForWidthHeightReturnValueLock.withLock { loadThumbnailForWidthHeightUnderlyingReturnValue = newValue } }
    }
    nonisolated(unsafe) var loadThumbnailForWidthHeightClosure: ((MediaSourceProxy, Int, Int) async -> Data?)?

    @concurrent func loadThumbnail(for source: MediaSourceProxy, width: Int, height: Int) async -> Data? {
        loadThumbnailForWidthHeightCallsCountLock.withLock { loadThumbnailForWidthHeightUnderlyingCallsCount += 1 }
        loadThumbnailForWidthHeightReceivedArguments = (source: source, width: width, height: height)
        loadThumbnailForWidthHeightReceivedInvocationsLock.withLock { loadThumbnailForWidthHeightUnderlyingReceivedInvocations.append((source: source, width: width, height: height)) }
        if let loadThumbnailForWidthHeightClosure = loadThumbnailForWidthHeightClosure {
            return await loadThumbnailForWidthHeightClosure(source, width, height)
        } else {
            return loadThumbnailForWidthHeightReturnValue
        }
    }
    //MARK: - loadMediaContent

    private let loadMediaContentForCallsCountLock = NSLock()
    private nonisolated(unsafe) var loadMediaContentForUnderlyingCallsCount = 0
    var loadMediaContentForCallsCount: Int {
        get { loadMediaContentForCallsCountLock.withLock { loadMediaContentForUnderlyingCallsCount } }
        set { loadMediaContentForCallsCountLock.withLock { loadMediaContentForUnderlyingCallsCount = newValue } }
    }
    var loadMediaContentForCalled: Bool {
        return loadMediaContentForCallsCount > 0
    }
    private let loadMediaContentForReceivedSourceLock = NSLock()
    private nonisolated(unsafe) var loadMediaContentForUnderlyingReceivedSource: MediaSourceProxy?
    var loadMediaContentForReceivedSource: MediaSourceProxy? {
        get { loadMediaContentForReceivedSourceLock.withLock { loadMediaContentForUnderlyingReceivedSource } }
        set { loadMediaContentForReceivedSourceLock.withLock { loadMediaContentForUnderlyingReceivedSource = newValue } }
    }
    private let loadMediaContentForReceivedInvocationsLock = NSLock()
    private nonisolated(unsafe) var loadMediaContentForUnderlyingReceivedInvocations: [MediaSourceProxy] = []
    var loadMediaContentForReceivedInvocations: [MediaSourceProxy] {
        get { loadMediaContentForReceivedInvocationsLock.withLock { loadMediaContentForUnderlyingReceivedInvocations } }
        set { loadMediaContentForReceivedInvocationsLock.withLock { loadMediaContentForUnderlyingReceivedInvocations = newValue } }
    }

    private let loadMediaContentForReturnValueLock = NSLock()
    private nonisolated(unsafe) var loadMediaContentForUnderlyingReturnValue: Data?
    var loadMediaContentForReturnValue: Data? {
        get { loadMediaContentForReturnValueLock.withLock { loadMediaContentForUnderlyingReturnValue } }
        set { loadMediaContentForReturnValueLock.withLock { loadMediaContentForUnderlyingReturnValue = newValue } }
    }
    nonisolated(unsafe) var loadMediaContentForClosure: ((MediaSourceProxy) async -> Data?)?

    @concurrent func loadMediaContent(for source: MediaSourceProxy) async -> Data? {
        loadMediaContentForCallsCountLock.withLock { loadMediaContentForUnderlyingCallsCount += 1 }
        loadMediaContentForReceivedSource = source
        loadMediaContentForReceivedInvocationsLock.withLock { loadMediaContentForUnderlyingReceivedInvocations.append(source) }
        if let loadMediaContentForClosure = loadMediaContentForClosure {
            return await loadMediaContentForClosure(source)
        } else {
            return loadMediaContentForReturnValue
        }
    }
    //MARK: - timelineProxy

    private let timelineProxyForCallsCountLock = NSLock()
    private nonisolated(unsafe) var timelineProxyForUnderlyingCallsCount = 0
    var timelineProxyForCallsCount: Int {
        get { timelineProxyForCallsCountLock.withLock { timelineProxyForUnderlyingCallsCount } }
        set { timelineProxyForCallsCountLock.withLock { timelineProxyForUnderlyingCallsCount = newValue } }
    }
    var timelineProxyForCalled: Bool {
        return timelineProxyForCallsCount > 0
    }
    private let timelineProxyForReceivedRoomIDLock = NSLock()
    private nonisolated(unsafe) var timelineProxyForUnderlyingReceivedRoomID: String?
    var timelineProxyForReceivedRoomID: String? {
        get { timelineProxyForReceivedRoomIDLock.withLock { timelineProxyForUnderlyingReceivedRoomID } }
        set { timelineProxyForReceivedRoomIDLock.withLock { timelineProxyForUnderlyingReceivedRoomID = newValue } }
    }
    private let timelineProxyForReceivedInvocationsLock = NSLock()
    private nonisolated(unsafe) var timelineProxyForUnderlyingReceivedInvocations: [String] = []
    var timelineProxyForReceivedInvocations: [String] {
        get { timelineProxyForReceivedInvocationsLock.withLock { timelineProxyForUnderlyingReceivedInvocations } }
        set { timelineProxyForReceivedInvocationsLock.withLock { timelineProxyForUnderlyingReceivedInvocations = newValue } }
    }

    private let timelineProxyForReturnValueLock = NSLock()
    private nonisolated(unsafe) var timelineProxyForUnderlyingReturnValue: TimelineProxyProtocol?
    var timelineProxyForReturnValue: TimelineProxyProtocol? {
        get { timelineProxyForReturnValueLock.withLock { timelineProxyForUnderlyingReturnValue } }
        set { timelineProxyForReturnValueLock.withLock { timelineProxyForUnderlyingReturnValue = newValue } }
    }
    nonisolated(unsafe) var timelineProxyForClosure: ((String) async -> TimelineProxyProtocol?)?

    @concurrent func timelineProxy(for roomID: String) async -> TimelineProxyProtocol? {
        timelineProxyForCallsCountLock.withLock { timelineProxyForUnderlyingCallsCount += 1 }
        timelineProxyForReceivedRoomID = roomID
        timelineProxyForReceivedInvocationsLock.withLock { timelineProxyForUnderlyingReceivedInvocations.append(roomID) }
        if let timelineProxyForClosure = timelineProxyForClosure {
            return await timelineProxyForClosure(roomID)
        } else {
            return timelineProxyForReturnValue
        }
    }
    //MARK: - roomLocationProxy

    private let roomLocationProxyForCallsCountLock = NSLock()
    private nonisolated(unsafe) var roomLocationProxyForUnderlyingCallsCount = 0
    var roomLocationProxyForCallsCount: Int {
        get { roomLocationProxyForCallsCountLock.withLock { roomLocationProxyForUnderlyingCallsCount } }
        set { roomLocationProxyForCallsCountLock.withLock { roomLocationProxyForUnderlyingCallsCount = newValue } }
    }
    var roomLocationProxyForCalled: Bool {
        return roomLocationProxyForCallsCount > 0
    }
    private let roomLocationProxyForReceivedRoomIDLock = NSLock()
    private nonisolated(unsafe) var roomLocationProxyForUnderlyingReceivedRoomID: String?
    var roomLocationProxyForReceivedRoomID: String? {
        get { roomLocationProxyForReceivedRoomIDLock.withLock { roomLocationProxyForUnderlyingReceivedRoomID } }
        set { roomLocationProxyForReceivedRoomIDLock.withLock { roomLocationProxyForUnderlyingReceivedRoomID = newValue } }
    }
    private let roomLocationProxyForReceivedInvocationsLock = NSLock()
    private nonisolated(unsafe) var roomLocationProxyForUnderlyingReceivedInvocations: [String] = []
    var roomLocationProxyForReceivedInvocations: [String] {
        get { roomLocationProxyForReceivedInvocationsLock.withLock { roomLocationProxyForUnderlyingReceivedInvocations } }
        set { roomLocationProxyForReceivedInvocationsLock.withLock { roomLocationProxyForUnderlyingReceivedInvocations = newValue } }
    }

    private let roomLocationProxyForReturnValueLock = NSLock()
    private nonisolated(unsafe) var roomLocationProxyForUnderlyingReturnValue: RoomLocationProxyProtocol?
    var roomLocationProxyForReturnValue: RoomLocationProxyProtocol? {
        get { roomLocationProxyForReturnValueLock.withLock { roomLocationProxyForUnderlyingReturnValue } }
        set { roomLocationProxyForReturnValueLock.withLock { roomLocationProxyForUnderlyingReturnValue = newValue } }
    }
    nonisolated(unsafe) var roomLocationProxyForClosure: ((String) async -> RoomLocationProxyProtocol?)?

    @concurrent func roomLocationProxy(for roomID: String) async -> RoomLocationProxyProtocol? {
        roomLocationProxyForCallsCountLock.withLock { roomLocationProxyForUnderlyingCallsCount += 1 }
        roomLocationProxyForReceivedRoomID = roomID
        roomLocationProxyForReceivedInvocationsLock.withLock { roomLocationProxyForUnderlyingReceivedInvocations.append(roomID) }
        if let roomLocationProxyForClosure = roomLocationProxyForClosure {
            return await roomLocationProxyForClosure(roomID)
        } else {
            return roomLocationProxyForReturnValue
        }
    }
    //MARK: - logout

    private let logoutCallsCountLock = NSLock()
    private nonisolated(unsafe) var logoutUnderlyingCallsCount = 0
    var logoutCallsCount: Int {
        get { logoutCallsCountLock.withLock { logoutUnderlyingCallsCount } }
        set { logoutCallsCountLock.withLock { logoutUnderlyingCallsCount = newValue } }
    }
    var logoutCalled: Bool {
        return logoutCallsCount > 0
    }
    nonisolated(unsafe) var logoutClosure: (() async -> Void)?

    @concurrent func logout() async {
        logoutCallsCountLock.withLock { logoutUnderlyingCallsCount += 1 }
        await logoutClosure?()
    }
    //MARK: - sessionVerificationController

    private let sessionVerificationControllerCallsCountLock = NSLock()
    private nonisolated(unsafe) var sessionVerificationControllerUnderlyingCallsCount = 0
    var sessionVerificationControllerCallsCount: Int {
        get { sessionVerificationControllerCallsCountLock.withLock { sessionVerificationControllerUnderlyingCallsCount } }
        set { sessionVerificationControllerCallsCountLock.withLock { sessionVerificationControllerUnderlyingCallsCount = newValue } }
    }
    var sessionVerificationControllerCalled: Bool {
        return sessionVerificationControllerCallsCount > 0
    }

    private let sessionVerificationControllerReturnValueLock = NSLock()
    private nonisolated(unsafe) var sessionVerificationControllerUnderlyingReturnValue: SessionVerificationControllerProxyProtocol?
    var sessionVerificationControllerReturnValue: SessionVerificationControllerProxyProtocol? {
        get { sessionVerificationControllerReturnValueLock.withLock { sessionVerificationControllerUnderlyingReturnValue } }
        set { sessionVerificationControllerReturnValueLock.withLock { sessionVerificationControllerUnderlyingReturnValue = newValue } }
    }
    nonisolated(unsafe) var sessionVerificationControllerClosure: (() async -> SessionVerificationControllerProxyProtocol?)?

    @concurrent func sessionVerificationController() async -> SessionVerificationControllerProxyProtocol? {
        sessionVerificationControllerCallsCountLock.withLock { sessionVerificationControllerUnderlyingCallsCount += 1 }
        if let sessionVerificationControllerClosure = sessionVerificationControllerClosure {
            return await sessionVerificationControllerClosure()
        } else {
            return sessionVerificationControllerReturnValue
        }
    }
}
nonisolated class KeychainStoreMock: KeychainStoreProtocol, @unchecked Sendable {

    //MARK: - restorationToken

    private let restorationTokenCallsCountLock = NSLock()
    private nonisolated(unsafe) var restorationTokenUnderlyingCallsCount = 0
    var restorationTokenCallsCount: Int {
        get { restorationTokenCallsCountLock.withLock { restorationTokenUnderlyingCallsCount } }
        set { restorationTokenCallsCountLock.withLock { restorationTokenUnderlyingCallsCount = newValue } }
    }
    var restorationTokenCalled: Bool {
        return restorationTokenCallsCount > 0
    }

    private let restorationTokenReturnValueLock = NSLock()
    private nonisolated(unsafe) var restorationTokenUnderlyingReturnValue: RestorationToken?
    var restorationTokenReturnValue: RestorationToken? {
        get { restorationTokenReturnValueLock.withLock { restorationTokenUnderlyingReturnValue } }
        set { restorationTokenReturnValueLock.withLock { restorationTokenUnderlyingReturnValue = newValue } }
    }
    nonisolated(unsafe) var restorationTokenClosure: (() -> RestorationToken?)?

    func restorationToken() -> RestorationToken? {
        restorationTokenCallsCountLock.withLock { restorationTokenUnderlyingCallsCount += 1 }
        if let restorationTokenClosure = restorationTokenClosure {
            return restorationTokenClosure()
        } else {
            return restorationTokenReturnValue
        }
    }
    //MARK: - setRestorationToken

    private let setRestorationTokenCallsCountLock = NSLock()
    private nonisolated(unsafe) var setRestorationTokenUnderlyingCallsCount = 0
    var setRestorationTokenCallsCount: Int {
        get { setRestorationTokenCallsCountLock.withLock { setRestorationTokenUnderlyingCallsCount } }
        set { setRestorationTokenCallsCountLock.withLock { setRestorationTokenUnderlyingCallsCount = newValue } }
    }
    var setRestorationTokenCalled: Bool {
        return setRestorationTokenCallsCount > 0
    }
    private let setRestorationTokenReceivedTokenLock = NSLock()
    private nonisolated(unsafe) var setRestorationTokenUnderlyingReceivedToken: RestorationToken?
    var setRestorationTokenReceivedToken: RestorationToken? {
        get { setRestorationTokenReceivedTokenLock.withLock { setRestorationTokenUnderlyingReceivedToken } }
        set { setRestorationTokenReceivedTokenLock.withLock { setRestorationTokenUnderlyingReceivedToken = newValue } }
    }
    private let setRestorationTokenReceivedInvocationsLock = NSLock()
    private nonisolated(unsafe) var setRestorationTokenUnderlyingReceivedInvocations: [RestorationToken] = []
    var setRestorationTokenReceivedInvocations: [RestorationToken] {
        get { setRestorationTokenReceivedInvocationsLock.withLock { setRestorationTokenUnderlyingReceivedInvocations } }
        set { setRestorationTokenReceivedInvocationsLock.withLock { setRestorationTokenUnderlyingReceivedInvocations = newValue } }
    }
    nonisolated(unsafe) var setRestorationTokenClosure: ((RestorationToken) -> Void)?

    func setRestorationToken(_ token: RestorationToken) {
        setRestorationTokenCallsCountLock.withLock { setRestorationTokenUnderlyingCallsCount += 1 }
        setRestorationTokenReceivedToken = token
        setRestorationTokenReceivedInvocationsLock.withLock { setRestorationTokenUnderlyingReceivedInvocations.append(token) }
        setRestorationTokenClosure?(token)
    }
    //MARK: - removeRestorationToken

    private let removeRestorationTokenCallsCountLock = NSLock()
    private nonisolated(unsafe) var removeRestorationTokenUnderlyingCallsCount = 0
    var removeRestorationTokenCallsCount: Int {
        get { removeRestorationTokenCallsCountLock.withLock { removeRestorationTokenUnderlyingCallsCount } }
        set { removeRestorationTokenCallsCountLock.withLock { removeRestorationTokenUnderlyingCallsCount = newValue } }
    }
    var removeRestorationTokenCalled: Bool {
        return removeRestorationTokenCallsCount > 0
    }
    nonisolated(unsafe) var removeRestorationTokenClosure: (() -> Void)?

    func removeRestorationToken() {
        removeRestorationTokenCallsCountLock.withLock { removeRestorationTokenUnderlyingCallsCount += 1 }
        removeRestorationTokenClosure?()
    }
}
nonisolated class LiveLocationServiceMock: LiveLocationServiceProtocol, @unchecked Sendable {
    var state: LiveLocationState {
        get { return underlyingState }
        set(value) { underlyingState = value }
    }
    nonisolated(unsafe) var underlyingState: LiveLocationState!
    var statePublisher: AnyPublisher<LiveLocationState, Never> {
        get { return underlyingStatePublisher }
        set(value) { underlyingStatePublisher = value }
    }
    nonisolated(unsafe) var underlyingStatePublisher: AnyPublisher<LiveLocationState, Never>!

    //MARK: - restore

    private let restoreCallsCountLock = NSLock()
    private nonisolated(unsafe) var restoreUnderlyingCallsCount = 0
    var restoreCallsCount: Int {
        get { restoreCallsCountLock.withLock { restoreUnderlyingCallsCount } }
        set { restoreCallsCountLock.withLock { restoreUnderlyingCallsCount = newValue } }
    }
    var restoreCalled: Bool {
        return restoreCallsCount > 0
    }
    nonisolated(unsafe) var restoreClosure: (() async -> Void)?

    @concurrent func restore() async {
        restoreCallsCountLock.withLock { restoreUnderlyingCallsCount += 1 }
        await restoreClosure?()
    }
    //MARK: - start

    private let startRoomIDDurationCallsCountLock = NSLock()
    private nonisolated(unsafe) var startRoomIDDurationUnderlyingCallsCount = 0
    var startRoomIDDurationCallsCount: Int {
        get { startRoomIDDurationCallsCountLock.withLock { startRoomIDDurationUnderlyingCallsCount } }
        set { startRoomIDDurationCallsCountLock.withLock { startRoomIDDurationUnderlyingCallsCount = newValue } }
    }
    var startRoomIDDurationCalled: Bool {
        return startRoomIDDurationCallsCount > 0
    }
    private let startRoomIDDurationReceivedArgumentsLock = NSLock()
    private nonisolated(unsafe) var startRoomIDDurationUnderlyingReceivedArguments: (roomID: String, duration: Duration)?
    var startRoomIDDurationReceivedArguments: (roomID: String, duration: Duration)? {
        get { startRoomIDDurationReceivedArgumentsLock.withLock { startRoomIDDurationUnderlyingReceivedArguments } }
        set { startRoomIDDurationReceivedArgumentsLock.withLock { startRoomIDDurationUnderlyingReceivedArguments = newValue } }
    }
    private let startRoomIDDurationReceivedInvocationsLock = NSLock()
    private nonisolated(unsafe) var startRoomIDDurationUnderlyingReceivedInvocations: [(roomID: String, duration: Duration)] = []
    var startRoomIDDurationReceivedInvocations: [(roomID: String, duration: Duration)] {
        get { startRoomIDDurationReceivedInvocationsLock.withLock { startRoomIDDurationUnderlyingReceivedInvocations } }
        set { startRoomIDDurationReceivedInvocationsLock.withLock { startRoomIDDurationUnderlyingReceivedInvocations = newValue } }
    }

    private let startRoomIDDurationReturnValueLock = NSLock()
    private nonisolated(unsafe) var startRoomIDDurationUnderlyingReturnValue: Result<Void, LiveLocationServiceError>!
    var startRoomIDDurationReturnValue: Result<Void, LiveLocationServiceError>! {
        get { startRoomIDDurationReturnValueLock.withLock { startRoomIDDurationUnderlyingReturnValue } }
        set { startRoomIDDurationReturnValueLock.withLock { startRoomIDDurationUnderlyingReturnValue = newValue } }
    }
    nonisolated(unsafe) var startRoomIDDurationClosure: ((String, Duration) async -> Result<Void, LiveLocationServiceError>)?

    @concurrent func start(roomID: String, duration: Duration) async -> Result<Void, LiveLocationServiceError> {
        startRoomIDDurationCallsCountLock.withLock { startRoomIDDurationUnderlyingCallsCount += 1 }
        startRoomIDDurationReceivedArguments = (roomID: roomID, duration: duration)
        startRoomIDDurationReceivedInvocationsLock.withLock { startRoomIDDurationUnderlyingReceivedInvocations.append((roomID: roomID, duration: duration)) }
        if let startRoomIDDurationClosure = startRoomIDDurationClosure {
            return await startRoomIDDurationClosure(roomID, duration)
        } else {
            return startRoomIDDurationReturnValue
        }
    }
    //MARK: - stop

    private let stopCallsCountLock = NSLock()
    private nonisolated(unsafe) var stopUnderlyingCallsCount = 0
    var stopCallsCount: Int {
        get { stopCallsCountLock.withLock { stopUnderlyingCallsCount } }
        set { stopCallsCountLock.withLock { stopUnderlyingCallsCount = newValue } }
    }
    var stopCalled: Bool {
        return stopCallsCount > 0
    }
    nonisolated(unsafe) var stopClosure: (() async -> Void)?

    @concurrent func stop() async {
        stopCallsCountLock.withLock { stopUnderlyingCallsCount += 1 }
        await stopClosure?()
    }
}
nonisolated class LocationProviderMock: LocationProviderProtocol, @unchecked Sendable {
    var authorization: LocationAuthorization {
        get { return underlyingAuthorization }
        set(value) { underlyingAuthorization = value }
    }
    nonisolated(unsafe) var underlyingAuthorization: LocationAuthorization!
    var authorizationPublisher: AnyPublisher<LocationAuthorization, Never> {
        get { return underlyingAuthorizationPublisher }
        set(value) { underlyingAuthorizationPublisher = value }
    }
    nonisolated(unsafe) var underlyingAuthorizationPublisher: AnyPublisher<LocationAuthorization, Never>!
    var updatesPublisher: AnyPublisher<GeoURI, Never> {
        get { return underlyingUpdatesPublisher }
        set(value) { underlyingUpdatesPublisher = value }
    }
    nonisolated(unsafe) var underlyingUpdatesPublisher: AnyPublisher<GeoURI, Never>!

    //MARK: - requestAuthorization

    private let requestAuthorizationCallsCountLock = NSLock()
    private nonisolated(unsafe) var requestAuthorizationUnderlyingCallsCount = 0
    var requestAuthorizationCallsCount: Int {
        get { requestAuthorizationCallsCountLock.withLock { requestAuthorizationUnderlyingCallsCount } }
        set { requestAuthorizationCallsCountLock.withLock { requestAuthorizationUnderlyingCallsCount = newValue } }
    }
    var requestAuthorizationCalled: Bool {
        return requestAuthorizationCallsCount > 0
    }
    nonisolated(unsafe) var requestAuthorizationClosure: (() -> Void)?

    func requestAuthorization() {
        requestAuthorizationCallsCountLock.withLock { requestAuthorizationUnderlyingCallsCount += 1 }
        requestAuthorizationClosure?()
    }
    //MARK: - currentLocation

    private let currentLocationTimeoutCallsCountLock = NSLock()
    private nonisolated(unsafe) var currentLocationTimeoutUnderlyingCallsCount = 0
    var currentLocationTimeoutCallsCount: Int {
        get { currentLocationTimeoutCallsCountLock.withLock { currentLocationTimeoutUnderlyingCallsCount } }
        set { currentLocationTimeoutCallsCountLock.withLock { currentLocationTimeoutUnderlyingCallsCount = newValue } }
    }
    var currentLocationTimeoutCalled: Bool {
        return currentLocationTimeoutCallsCount > 0
    }
    private let currentLocationTimeoutReceivedTimeoutLock = NSLock()
    private nonisolated(unsafe) var currentLocationTimeoutUnderlyingReceivedTimeout: Duration?
    var currentLocationTimeoutReceivedTimeout: Duration? {
        get { currentLocationTimeoutReceivedTimeoutLock.withLock { currentLocationTimeoutUnderlyingReceivedTimeout } }
        set { currentLocationTimeoutReceivedTimeoutLock.withLock { currentLocationTimeoutUnderlyingReceivedTimeout = newValue } }
    }
    private let currentLocationTimeoutReceivedInvocationsLock = NSLock()
    private nonisolated(unsafe) var currentLocationTimeoutUnderlyingReceivedInvocations: [Duration] = []
    var currentLocationTimeoutReceivedInvocations: [Duration] {
        get { currentLocationTimeoutReceivedInvocationsLock.withLock { currentLocationTimeoutUnderlyingReceivedInvocations } }
        set { currentLocationTimeoutReceivedInvocationsLock.withLock { currentLocationTimeoutUnderlyingReceivedInvocations = newValue } }
    }

    private let currentLocationTimeoutReturnValueLock = NSLock()
    private nonisolated(unsafe) var currentLocationTimeoutUnderlyingReturnValue: Result<GeoURI, LocationError>!
    var currentLocationTimeoutReturnValue: Result<GeoURI, LocationError>! {
        get { currentLocationTimeoutReturnValueLock.withLock { currentLocationTimeoutUnderlyingReturnValue } }
        set { currentLocationTimeoutReturnValueLock.withLock { currentLocationTimeoutUnderlyingReturnValue = newValue } }
    }
    nonisolated(unsafe) var currentLocationTimeoutClosure: ((Duration) async -> Result<GeoURI, LocationError>)?

    @concurrent func currentLocation(timeout: Duration) async -> Result<GeoURI, LocationError> {
        currentLocationTimeoutCallsCountLock.withLock { currentLocationTimeoutUnderlyingCallsCount += 1 }
        currentLocationTimeoutReceivedTimeout = timeout
        currentLocationTimeoutReceivedInvocationsLock.withLock { currentLocationTimeoutUnderlyingReceivedInvocations.append(timeout) }
        if let currentLocationTimeoutClosure = currentLocationTimeoutClosure {
            return await currentLocationTimeoutClosure(timeout)
        } else {
            return currentLocationTimeoutReturnValue
        }
    }
    //MARK: - startUpdates

    private let startUpdatesCallsCountLock = NSLock()
    private nonisolated(unsafe) var startUpdatesUnderlyingCallsCount = 0
    var startUpdatesCallsCount: Int {
        get { startUpdatesCallsCountLock.withLock { startUpdatesUnderlyingCallsCount } }
        set { startUpdatesCallsCountLock.withLock { startUpdatesUnderlyingCallsCount = newValue } }
    }
    var startUpdatesCalled: Bool {
        return startUpdatesCallsCount > 0
    }
    nonisolated(unsafe) var startUpdatesClosure: (() -> Void)?

    func startUpdates() {
        startUpdatesCallsCountLock.withLock { startUpdatesUnderlyingCallsCount += 1 }
        startUpdatesClosure?()
    }
    //MARK: - stopUpdates

    private let stopUpdatesCallsCountLock = NSLock()
    private nonisolated(unsafe) var stopUpdatesUnderlyingCallsCount = 0
    var stopUpdatesCallsCount: Int {
        get { stopUpdatesCallsCountLock.withLock { stopUpdatesUnderlyingCallsCount } }
        set { stopUpdatesCallsCountLock.withLock { stopUpdatesUnderlyingCallsCount = newValue } }
    }
    var stopUpdatesCalled: Bool {
        return stopUpdatesCallsCount > 0
    }
    nonisolated(unsafe) var stopUpdatesClosure: (() -> Void)?

    func stopUpdates() {
        stopUpdatesCallsCountLock.withLock { stopUpdatesUnderlyingCallsCount += 1 }
        stopUpdatesClosure?()
    }
}
nonisolated class MapSnapshotLoaderMock: MapSnapshotLoaderProtocol, @unchecked Sendable {

    //MARK: - snapshot

    private let snapshotOfSizeCallsCountLock = NSLock()
    private nonisolated(unsafe) var snapshotOfSizeUnderlyingCallsCount = 0
    var snapshotOfSizeCallsCount: Int {
        get { snapshotOfSizeCallsCountLock.withLock { snapshotOfSizeUnderlyingCallsCount } }
        set { snapshotOfSizeCallsCountLock.withLock { snapshotOfSizeUnderlyingCallsCount = newValue } }
    }
    var snapshotOfSizeCalled: Bool {
        return snapshotOfSizeCallsCount > 0
    }
    private let snapshotOfSizeReceivedArgumentsLock = NSLock()
    private nonisolated(unsafe) var snapshotOfSizeUnderlyingReceivedArguments: (geoURI: GeoURI, size: CGSize)?
    var snapshotOfSizeReceivedArguments: (geoURI: GeoURI, size: CGSize)? {
        get { snapshotOfSizeReceivedArgumentsLock.withLock { snapshotOfSizeUnderlyingReceivedArguments } }
        set { snapshotOfSizeReceivedArgumentsLock.withLock { snapshotOfSizeUnderlyingReceivedArguments = newValue } }
    }
    private let snapshotOfSizeReceivedInvocationsLock = NSLock()
    private nonisolated(unsafe) var snapshotOfSizeUnderlyingReceivedInvocations: [(geoURI: GeoURI, size: CGSize)] = []
    var snapshotOfSizeReceivedInvocations: [(geoURI: GeoURI, size: CGSize)] {
        get { snapshotOfSizeReceivedInvocationsLock.withLock { snapshotOfSizeUnderlyingReceivedInvocations } }
        set { snapshotOfSizeReceivedInvocationsLock.withLock { snapshotOfSizeUnderlyingReceivedInvocations = newValue } }
    }

    private let snapshotOfSizeReturnValueLock = NSLock()
    private nonisolated(unsafe) var snapshotOfSizeUnderlyingReturnValue: UIImage?
    var snapshotOfSizeReturnValue: UIImage? {
        get { snapshotOfSizeReturnValueLock.withLock { snapshotOfSizeUnderlyingReturnValue } }
        set { snapshotOfSizeReturnValueLock.withLock { snapshotOfSizeUnderlyingReturnValue = newValue } }
    }
    nonisolated(unsafe) var snapshotOfSizeClosure: ((GeoURI, CGSize) async -> UIImage?)?

    @concurrent func snapshot(of geoURI: GeoURI, size: CGSize) async -> UIImage? {
        snapshotOfSizeCallsCountLock.withLock { snapshotOfSizeUnderlyingCallsCount += 1 }
        snapshotOfSizeReceivedArguments = (geoURI: geoURI, size: size)
        snapshotOfSizeReceivedInvocationsLock.withLock { snapshotOfSizeUnderlyingReceivedInvocations.append((geoURI: geoURI, size: size)) }
        if let snapshotOfSizeClosure = snapshotOfSizeClosure {
            return await snapshotOfSizeClosure(geoURI, size)
        } else {
            return snapshotOfSizeReturnValue
        }
    }
}
nonisolated class QRLoginServiceMock: QRLoginServiceProtocol, @unchecked Sendable {

    //MARK: - loginWithGeneratedQRCode

    private let loginWithGeneratedQRCodeOnProgressCallsCountLock = NSLock()
    private nonisolated(unsafe) var loginWithGeneratedQRCodeOnProgressUnderlyingCallsCount = 0
    var loginWithGeneratedQRCodeOnProgressCallsCount: Int {
        get { loginWithGeneratedQRCodeOnProgressCallsCountLock.withLock { loginWithGeneratedQRCodeOnProgressUnderlyingCallsCount } }
        set { loginWithGeneratedQRCodeOnProgressCallsCountLock.withLock { loginWithGeneratedQRCodeOnProgressUnderlyingCallsCount = newValue } }
    }
    var loginWithGeneratedQRCodeOnProgressCalled: Bool {
        return loginWithGeneratedQRCodeOnProgressCallsCount > 0
    }
    private let loginWithGeneratedQRCodeOnProgressReceivedOnProgressLock = NSLock()
    private nonisolated(unsafe) var loginWithGeneratedQRCodeOnProgressUnderlyingReceivedOnProgress: (@MainActor (QRLoginProgress) -> Void)?
    var loginWithGeneratedQRCodeOnProgressReceivedOnProgress: (@MainActor (QRLoginProgress) -> Void)? {
        get { loginWithGeneratedQRCodeOnProgressReceivedOnProgressLock.withLock { loginWithGeneratedQRCodeOnProgressUnderlyingReceivedOnProgress } }
        set { loginWithGeneratedQRCodeOnProgressReceivedOnProgressLock.withLock { loginWithGeneratedQRCodeOnProgressUnderlyingReceivedOnProgress = newValue } }
    }
    private let loginWithGeneratedQRCodeOnProgressReceivedInvocationsLock = NSLock()
    private nonisolated(unsafe) var loginWithGeneratedQRCodeOnProgressUnderlyingReceivedInvocations: [(@MainActor (QRLoginProgress) -> Void)] = []
    var loginWithGeneratedQRCodeOnProgressReceivedInvocations: [(@MainActor (QRLoginProgress) -> Void)] {
        get { loginWithGeneratedQRCodeOnProgressReceivedInvocationsLock.withLock { loginWithGeneratedQRCodeOnProgressUnderlyingReceivedInvocations } }
        set { loginWithGeneratedQRCodeOnProgressReceivedInvocationsLock.withLock { loginWithGeneratedQRCodeOnProgressUnderlyingReceivedInvocations = newValue } }
    }

    private let loginWithGeneratedQRCodeOnProgressReturnValueLock = NSLock()
    private nonisolated(unsafe) var loginWithGeneratedQRCodeOnProgressUnderlyingReturnValue: Result<ClientProxyProtocol, QRLoginError>!
    var loginWithGeneratedQRCodeOnProgressReturnValue: Result<ClientProxyProtocol, QRLoginError>! {
        get { loginWithGeneratedQRCodeOnProgressReturnValueLock.withLock { loginWithGeneratedQRCodeOnProgressUnderlyingReturnValue } }
        set { loginWithGeneratedQRCodeOnProgressReturnValueLock.withLock { loginWithGeneratedQRCodeOnProgressUnderlyingReturnValue = newValue } }
    }
    nonisolated(unsafe) var loginWithGeneratedQRCodeOnProgressClosure: ((@MainActor @escaping (QRLoginProgress) -> Void) async -> Result<ClientProxyProtocol, QRLoginError>)?

    @concurrent func loginWithGeneratedQRCode(onProgress: @MainActor @escaping (QRLoginProgress) -> Void) async -> Result<ClientProxyProtocol, QRLoginError> {
        loginWithGeneratedQRCodeOnProgressCallsCountLock.withLock { loginWithGeneratedQRCodeOnProgressUnderlyingCallsCount += 1 }
        loginWithGeneratedQRCodeOnProgressReceivedOnProgress = onProgress
        loginWithGeneratedQRCodeOnProgressReceivedInvocationsLock.withLock { loginWithGeneratedQRCodeOnProgressUnderlyingReceivedInvocations.append(onProgress) }
        if let loginWithGeneratedQRCodeOnProgressClosure = loginWithGeneratedQRCodeOnProgressClosure {
            return await loginWithGeneratedQRCodeOnProgressClosure(onProgress)
        } else {
            return loginWithGeneratedQRCodeOnProgressReturnValue
        }
    }
}
nonisolated class RoomLocationProxyMock: RoomLocationProxyProtocol, @unchecked Sendable {
    var roomID: String {
        get { return underlyingRoomID }
        set(value) { underlyingRoomID = value }
    }
    nonisolated(unsafe) var underlyingRoomID: String!
    var liveLocationsPublisher: AnyPublisher<[LiveLocationSummary], Never> {
        get { return underlyingLiveLocationsPublisher }
        set(value) { underlyingLiveLocationsPublisher = value }
    }
    nonisolated(unsafe) var underlyingLiveLocationsPublisher: AnyPublisher<[LiveLocationSummary], Never>!

    //MARK: - startLiveLocationShare

    private let startLiveLocationShareDurationCallsCountLock = NSLock()
    private nonisolated(unsafe) var startLiveLocationShareDurationUnderlyingCallsCount = 0
    var startLiveLocationShareDurationCallsCount: Int {
        get { startLiveLocationShareDurationCallsCountLock.withLock { startLiveLocationShareDurationUnderlyingCallsCount } }
        set { startLiveLocationShareDurationCallsCountLock.withLock { startLiveLocationShareDurationUnderlyingCallsCount = newValue } }
    }
    var startLiveLocationShareDurationCalled: Bool {
        return startLiveLocationShareDurationCallsCount > 0
    }
    private let startLiveLocationShareDurationReceivedDurationLock = NSLock()
    private nonisolated(unsafe) var startLiveLocationShareDurationUnderlyingReceivedDuration: Duration?
    var startLiveLocationShareDurationReceivedDuration: Duration? {
        get { startLiveLocationShareDurationReceivedDurationLock.withLock { startLiveLocationShareDurationUnderlyingReceivedDuration } }
        set { startLiveLocationShareDurationReceivedDurationLock.withLock { startLiveLocationShareDurationUnderlyingReceivedDuration = newValue } }
    }
    private let startLiveLocationShareDurationReceivedInvocationsLock = NSLock()
    private nonisolated(unsafe) var startLiveLocationShareDurationUnderlyingReceivedInvocations: [Duration] = []
    var startLiveLocationShareDurationReceivedInvocations: [Duration] {
        get { startLiveLocationShareDurationReceivedInvocationsLock.withLock { startLiveLocationShareDurationUnderlyingReceivedInvocations } }
        set { startLiveLocationShareDurationReceivedInvocationsLock.withLock { startLiveLocationShareDurationUnderlyingReceivedInvocations = newValue } }
    }

    private let startLiveLocationShareDurationReturnValueLock = NSLock()
    private nonisolated(unsafe) var startLiveLocationShareDurationUnderlyingReturnValue: Result<String, LocationProxyError>!
    var startLiveLocationShareDurationReturnValue: Result<String, LocationProxyError>! {
        get { startLiveLocationShareDurationReturnValueLock.withLock { startLiveLocationShareDurationUnderlyingReturnValue } }
        set { startLiveLocationShareDurationReturnValueLock.withLock { startLiveLocationShareDurationUnderlyingReturnValue = newValue } }
    }
    nonisolated(unsafe) var startLiveLocationShareDurationClosure: ((Duration) async -> Result<String, LocationProxyError>)?

    @concurrent func startLiveLocationShare(duration: Duration) async -> Result<String, LocationProxyError> {
        startLiveLocationShareDurationCallsCountLock.withLock { startLiveLocationShareDurationUnderlyingCallsCount += 1 }
        startLiveLocationShareDurationReceivedDuration = duration
        startLiveLocationShareDurationReceivedInvocationsLock.withLock { startLiveLocationShareDurationUnderlyingReceivedInvocations.append(duration) }
        if let startLiveLocationShareDurationClosure = startLiveLocationShareDurationClosure {
            return await startLiveLocationShareDurationClosure(duration)
        } else {
            return startLiveLocationShareDurationReturnValue
        }
    }
    //MARK: - sendLiveLocation

    private let sendLiveLocationCallsCountLock = NSLock()
    private nonisolated(unsafe) var sendLiveLocationUnderlyingCallsCount = 0
    var sendLiveLocationCallsCount: Int {
        get { sendLiveLocationCallsCountLock.withLock { sendLiveLocationUnderlyingCallsCount } }
        set { sendLiveLocationCallsCountLock.withLock { sendLiveLocationUnderlyingCallsCount = newValue } }
    }
    var sendLiveLocationCalled: Bool {
        return sendLiveLocationCallsCount > 0
    }
    private let sendLiveLocationReceivedGeoURILock = NSLock()
    private nonisolated(unsafe) var sendLiveLocationUnderlyingReceivedGeoURI: GeoURI?
    var sendLiveLocationReceivedGeoURI: GeoURI? {
        get { sendLiveLocationReceivedGeoURILock.withLock { sendLiveLocationUnderlyingReceivedGeoURI } }
        set { sendLiveLocationReceivedGeoURILock.withLock { sendLiveLocationUnderlyingReceivedGeoURI = newValue } }
    }
    private let sendLiveLocationReceivedInvocationsLock = NSLock()
    private nonisolated(unsafe) var sendLiveLocationUnderlyingReceivedInvocations: [GeoURI] = []
    var sendLiveLocationReceivedInvocations: [GeoURI] {
        get { sendLiveLocationReceivedInvocationsLock.withLock { sendLiveLocationUnderlyingReceivedInvocations } }
        set { sendLiveLocationReceivedInvocationsLock.withLock { sendLiveLocationUnderlyingReceivedInvocations = newValue } }
    }

    private let sendLiveLocationReturnValueLock = NSLock()
    private nonisolated(unsafe) var sendLiveLocationUnderlyingReturnValue: Result<Void, LocationProxyError>!
    var sendLiveLocationReturnValue: Result<Void, LocationProxyError>! {
        get { sendLiveLocationReturnValueLock.withLock { sendLiveLocationUnderlyingReturnValue } }
        set { sendLiveLocationReturnValueLock.withLock { sendLiveLocationUnderlyingReturnValue = newValue } }
    }
    nonisolated(unsafe) var sendLiveLocationClosure: ((GeoURI) async -> Result<Void, LocationProxyError>)?

    @concurrent func sendLiveLocation(_ geoURI: GeoURI) async -> Result<Void, LocationProxyError> {
        sendLiveLocationCallsCountLock.withLock { sendLiveLocationUnderlyingCallsCount += 1 }
        sendLiveLocationReceivedGeoURI = geoURI
        sendLiveLocationReceivedInvocationsLock.withLock { sendLiveLocationUnderlyingReceivedInvocations.append(geoURI) }
        if let sendLiveLocationClosure = sendLiveLocationClosure {
            return await sendLiveLocationClosure(geoURI)
        } else {
            return sendLiveLocationReturnValue
        }
    }
    //MARK: - stopLiveLocationShare

    private let stopLiveLocationShareCallsCountLock = NSLock()
    private nonisolated(unsafe) var stopLiveLocationShareUnderlyingCallsCount = 0
    var stopLiveLocationShareCallsCount: Int {
        get { stopLiveLocationShareCallsCountLock.withLock { stopLiveLocationShareUnderlyingCallsCount } }
        set { stopLiveLocationShareCallsCountLock.withLock { stopLiveLocationShareUnderlyingCallsCount = newValue } }
    }
    var stopLiveLocationShareCalled: Bool {
        return stopLiveLocationShareCallsCount > 0
    }

    private let stopLiveLocationShareReturnValueLock = NSLock()
    private nonisolated(unsafe) var stopLiveLocationShareUnderlyingReturnValue: Result<Void, LocationProxyError>!
    var stopLiveLocationShareReturnValue: Result<Void, LocationProxyError>! {
        get { stopLiveLocationShareReturnValueLock.withLock { stopLiveLocationShareUnderlyingReturnValue } }
        set { stopLiveLocationShareReturnValueLock.withLock { stopLiveLocationShareUnderlyingReturnValue = newValue } }
    }
    nonisolated(unsafe) var stopLiveLocationShareClosure: (() async -> Result<Void, LocationProxyError>)?

    @concurrent func stopLiveLocationShare() async -> Result<Void, LocationProxyError> {
        stopLiveLocationShareCallsCountLock.withLock { stopLiveLocationShareUnderlyingCallsCount += 1 }
        if let stopLiveLocationShareClosure = stopLiveLocationShareClosure {
            return await stopLiveLocationShareClosure()
        } else {
            return stopLiveLocationShareReturnValue
        }
    }
}
nonisolated class RoomSummaryProviderMock: RoomSummaryProviderProtocol, @unchecked Sendable {
    var roomsPublisher: AnyPublisher<[RoomSummary], Never> {
        get { return underlyingRoomsPublisher }
        set(value) { underlyingRoomsPublisher = value }
    }
    nonisolated(unsafe) var underlyingRoomsPublisher: AnyPublisher<[RoomSummary], Never>!

    //MARK: - start

    private let startCallsCountLock = NSLock()
    private nonisolated(unsafe) var startUnderlyingCallsCount = 0
    var startCallsCount: Int {
        get { startCallsCountLock.withLock { startUnderlyingCallsCount } }
        set { startCallsCountLock.withLock { startUnderlyingCallsCount = newValue } }
    }
    var startCalled: Bool {
        return startCallsCount > 0
    }
    nonisolated(unsafe) var startClosure: (() async -> Void)?

    @concurrent func start() async {
        startCallsCountLock.withLock { startUnderlyingCallsCount += 1 }
        await startClosure?()
    }
}
nonisolated class SessionStoreMock: SessionStoreProtocol, @unchecked Sendable {
    var hasSession: Bool {
        get { return underlyingHasSession }
        set(value) { underlyingHasSession = value }
    }
    nonisolated(unsafe) var underlyingHasSession: Bool!

    //MARK: - restorationToken

    private let restorationTokenCallsCountLock = NSLock()
    private nonisolated(unsafe) var restorationTokenUnderlyingCallsCount = 0
    var restorationTokenCallsCount: Int {
        get { restorationTokenCallsCountLock.withLock { restorationTokenUnderlyingCallsCount } }
        set { restorationTokenCallsCountLock.withLock { restorationTokenUnderlyingCallsCount = newValue } }
    }
    var restorationTokenCalled: Bool {
        return restorationTokenCallsCount > 0
    }

    private let restorationTokenReturnValueLock = NSLock()
    private nonisolated(unsafe) var restorationTokenUnderlyingReturnValue: RestorationToken?
    var restorationTokenReturnValue: RestorationToken? {
        get { restorationTokenReturnValueLock.withLock { restorationTokenUnderlyingReturnValue } }
        set { restorationTokenReturnValueLock.withLock { restorationTokenUnderlyingReturnValue = newValue } }
    }
    nonisolated(unsafe) var restorationTokenClosure: (() -> RestorationToken?)?

    func restorationToken() -> RestorationToken? {
        restorationTokenCallsCountLock.withLock { restorationTokenUnderlyingCallsCount += 1 }
        if let restorationTokenClosure = restorationTokenClosure {
            return restorationTokenClosure()
        } else {
            return restorationTokenReturnValue
        }
    }
    //MARK: - save

    private let saveCallsCountLock = NSLock()
    private nonisolated(unsafe) var saveUnderlyingCallsCount = 0
    var saveCallsCount: Int {
        get { saveCallsCountLock.withLock { saveUnderlyingCallsCount } }
        set { saveCallsCountLock.withLock { saveUnderlyingCallsCount = newValue } }
    }
    var saveCalled: Bool {
        return saveCallsCount > 0
    }
    private let saveReceivedTokenLock = NSLock()
    private nonisolated(unsafe) var saveUnderlyingReceivedToken: RestorationToken?
    var saveReceivedToken: RestorationToken? {
        get { saveReceivedTokenLock.withLock { saveUnderlyingReceivedToken } }
        set { saveReceivedTokenLock.withLock { saveUnderlyingReceivedToken = newValue } }
    }
    private let saveReceivedInvocationsLock = NSLock()
    private nonisolated(unsafe) var saveUnderlyingReceivedInvocations: [RestorationToken] = []
    var saveReceivedInvocations: [RestorationToken] {
        get { saveReceivedInvocationsLock.withLock { saveUnderlyingReceivedInvocations } }
        set { saveReceivedInvocationsLock.withLock { saveUnderlyingReceivedInvocations = newValue } }
    }
    nonisolated(unsafe) var saveClosure: ((RestorationToken) -> Void)?

    func save(_ token: RestorationToken) {
        saveCallsCountLock.withLock { saveUnderlyingCallsCount += 1 }
        saveReceivedToken = token
        saveReceivedInvocationsLock.withLock { saveUnderlyingReceivedInvocations.append(token) }
        saveClosure?(token)
    }
    //MARK: - clear

    private let clearCallsCountLock = NSLock()
    private nonisolated(unsafe) var clearUnderlyingCallsCount = 0
    var clearCallsCount: Int {
        get { clearCallsCountLock.withLock { clearUnderlyingCallsCount } }
        set { clearCallsCountLock.withLock { clearUnderlyingCallsCount = newValue } }
    }
    var clearCalled: Bool {
        return clearCallsCount > 0
    }
    nonisolated(unsafe) var clearClosure: (() -> Void)?

    func clear() {
        clearCallsCountLock.withLock { clearUnderlyingCallsCount += 1 }
        clearClosure?()
    }
}
nonisolated class SessionVerificationControllerProxyMock: SessionVerificationControllerProxyProtocol, @unchecked Sendable {
    var actionsPublisher: AnyPublisher<SessionVerificationControllerProxyAction, Never> {
        get { return underlyingActionsPublisher }
        set(value) { underlyingActionsPublisher = value }
    }
    nonisolated(unsafe) var underlyingActionsPublisher: AnyPublisher<SessionVerificationControllerProxyAction, Never>!

    //MARK: - requestDeviceVerification

    private let requestDeviceVerificationCallsCountLock = NSLock()
    private nonisolated(unsafe) var requestDeviceVerificationUnderlyingCallsCount = 0
    var requestDeviceVerificationCallsCount: Int {
        get { requestDeviceVerificationCallsCountLock.withLock { requestDeviceVerificationUnderlyingCallsCount } }
        set { requestDeviceVerificationCallsCountLock.withLock { requestDeviceVerificationUnderlyingCallsCount = newValue } }
    }
    var requestDeviceVerificationCalled: Bool {
        return requestDeviceVerificationCallsCount > 0
    }

    private let requestDeviceVerificationReturnValueLock = NSLock()
    private nonisolated(unsafe) var requestDeviceVerificationUnderlyingReturnValue: Result<Void, SessionVerificationControllerProxyError>!
    var requestDeviceVerificationReturnValue: Result<Void, SessionVerificationControllerProxyError>! {
        get { requestDeviceVerificationReturnValueLock.withLock { requestDeviceVerificationUnderlyingReturnValue } }
        set { requestDeviceVerificationReturnValueLock.withLock { requestDeviceVerificationUnderlyingReturnValue = newValue } }
    }
    nonisolated(unsafe) var requestDeviceVerificationClosure: (() async -> Result<Void, SessionVerificationControllerProxyError>)?

    @concurrent func requestDeviceVerification() async -> Result<Void, SessionVerificationControllerProxyError> {
        requestDeviceVerificationCallsCountLock.withLock { requestDeviceVerificationUnderlyingCallsCount += 1 }
        if let requestDeviceVerificationClosure = requestDeviceVerificationClosure {
            return await requestDeviceVerificationClosure()
        } else {
            return requestDeviceVerificationReturnValue
        }
    }
    //MARK: - startSasVerification

    private let startSasVerificationCallsCountLock = NSLock()
    private nonisolated(unsafe) var startSasVerificationUnderlyingCallsCount = 0
    var startSasVerificationCallsCount: Int {
        get { startSasVerificationCallsCountLock.withLock { startSasVerificationUnderlyingCallsCount } }
        set { startSasVerificationCallsCountLock.withLock { startSasVerificationUnderlyingCallsCount = newValue } }
    }
    var startSasVerificationCalled: Bool {
        return startSasVerificationCallsCount > 0
    }

    private let startSasVerificationReturnValueLock = NSLock()
    private nonisolated(unsafe) var startSasVerificationUnderlyingReturnValue: Result<Void, SessionVerificationControllerProxyError>!
    var startSasVerificationReturnValue: Result<Void, SessionVerificationControllerProxyError>! {
        get { startSasVerificationReturnValueLock.withLock { startSasVerificationUnderlyingReturnValue } }
        set { startSasVerificationReturnValueLock.withLock { startSasVerificationUnderlyingReturnValue = newValue } }
    }
    nonisolated(unsafe) var startSasVerificationClosure: (() async -> Result<Void, SessionVerificationControllerProxyError>)?

    @concurrent func startSasVerification() async -> Result<Void, SessionVerificationControllerProxyError> {
        startSasVerificationCallsCountLock.withLock { startSasVerificationUnderlyingCallsCount += 1 }
        if let startSasVerificationClosure = startSasVerificationClosure {
            return await startSasVerificationClosure()
        } else {
            return startSasVerificationReturnValue
        }
    }
    //MARK: - approveVerification

    private let approveVerificationCallsCountLock = NSLock()
    private nonisolated(unsafe) var approveVerificationUnderlyingCallsCount = 0
    var approveVerificationCallsCount: Int {
        get { approveVerificationCallsCountLock.withLock { approveVerificationUnderlyingCallsCount } }
        set { approveVerificationCallsCountLock.withLock { approveVerificationUnderlyingCallsCount = newValue } }
    }
    var approveVerificationCalled: Bool {
        return approveVerificationCallsCount > 0
    }

    private let approveVerificationReturnValueLock = NSLock()
    private nonisolated(unsafe) var approveVerificationUnderlyingReturnValue: Result<Void, SessionVerificationControllerProxyError>!
    var approveVerificationReturnValue: Result<Void, SessionVerificationControllerProxyError>! {
        get { approveVerificationReturnValueLock.withLock { approveVerificationUnderlyingReturnValue } }
        set { approveVerificationReturnValueLock.withLock { approveVerificationUnderlyingReturnValue = newValue } }
    }
    nonisolated(unsafe) var approveVerificationClosure: (() async -> Result<Void, SessionVerificationControllerProxyError>)?

    @concurrent func approveVerification() async -> Result<Void, SessionVerificationControllerProxyError> {
        approveVerificationCallsCountLock.withLock { approveVerificationUnderlyingCallsCount += 1 }
        if let approveVerificationClosure = approveVerificationClosure {
            return await approveVerificationClosure()
        } else {
            return approveVerificationReturnValue
        }
    }
    //MARK: - declineVerification

    private let declineVerificationCallsCountLock = NSLock()
    private nonisolated(unsafe) var declineVerificationUnderlyingCallsCount = 0
    var declineVerificationCallsCount: Int {
        get { declineVerificationCallsCountLock.withLock { declineVerificationUnderlyingCallsCount } }
        set { declineVerificationCallsCountLock.withLock { declineVerificationUnderlyingCallsCount = newValue } }
    }
    var declineVerificationCalled: Bool {
        return declineVerificationCallsCount > 0
    }

    private let declineVerificationReturnValueLock = NSLock()
    private nonisolated(unsafe) var declineVerificationUnderlyingReturnValue: Result<Void, SessionVerificationControllerProxyError>!
    var declineVerificationReturnValue: Result<Void, SessionVerificationControllerProxyError>! {
        get { declineVerificationReturnValueLock.withLock { declineVerificationUnderlyingReturnValue } }
        set { declineVerificationReturnValueLock.withLock { declineVerificationUnderlyingReturnValue = newValue } }
    }
    nonisolated(unsafe) var declineVerificationClosure: (() async -> Result<Void, SessionVerificationControllerProxyError>)?

    @concurrent func declineVerification() async -> Result<Void, SessionVerificationControllerProxyError> {
        declineVerificationCallsCountLock.withLock { declineVerificationUnderlyingCallsCount += 1 }
        if let declineVerificationClosure = declineVerificationClosure {
            return await declineVerificationClosure()
        } else {
            return declineVerificationReturnValue
        }
    }
    //MARK: - cancelVerification

    private let cancelVerificationCallsCountLock = NSLock()
    private nonisolated(unsafe) var cancelVerificationUnderlyingCallsCount = 0
    var cancelVerificationCallsCount: Int {
        get { cancelVerificationCallsCountLock.withLock { cancelVerificationUnderlyingCallsCount } }
        set { cancelVerificationCallsCountLock.withLock { cancelVerificationUnderlyingCallsCount = newValue } }
    }
    var cancelVerificationCalled: Bool {
        return cancelVerificationCallsCount > 0
    }

    private let cancelVerificationReturnValueLock = NSLock()
    private nonisolated(unsafe) var cancelVerificationUnderlyingReturnValue: Result<Void, SessionVerificationControllerProxyError>!
    var cancelVerificationReturnValue: Result<Void, SessionVerificationControllerProxyError>! {
        get { cancelVerificationReturnValueLock.withLock { cancelVerificationUnderlyingReturnValue } }
        set { cancelVerificationReturnValueLock.withLock { cancelVerificationUnderlyingReturnValue = newValue } }
    }
    nonisolated(unsafe) var cancelVerificationClosure: (() async -> Result<Void, SessionVerificationControllerProxyError>)?

    @concurrent func cancelVerification() async -> Result<Void, SessionVerificationControllerProxyError> {
        cancelVerificationCallsCountLock.withLock { cancelVerificationUnderlyingCallsCount += 1 }
        if let cancelVerificationClosure = cancelVerificationClosure {
            return await cancelVerificationClosure()
        } else {
            return cancelVerificationReturnValue
        }
    }
}
nonisolated class TimelineProxyMock: TimelineProxyProtocol, @unchecked Sendable {
    var itemsPublisher: AnyPublisher<[TimelineItem], Never> {
        get { return underlyingItemsPublisher }
        set(value) { underlyingItemsPublisher = value }
    }
    nonisolated(unsafe) var underlyingItemsPublisher: AnyPublisher<[TimelineItem], Never>!

    //MARK: - subscribe

    private let subscribeCallsCountLock = NSLock()
    private nonisolated(unsafe) var subscribeUnderlyingCallsCount = 0
    var subscribeCallsCount: Int {
        get { subscribeCallsCountLock.withLock { subscribeUnderlyingCallsCount } }
        set { subscribeCallsCountLock.withLock { subscribeUnderlyingCallsCount = newValue } }
    }
    var subscribeCalled: Bool {
        return subscribeCallsCount > 0
    }
    nonisolated(unsafe) var subscribeClosure: (() async -> Void)?

    @concurrent func subscribe() async {
        subscribeCallsCountLock.withLock { subscribeUnderlyingCallsCount += 1 }
        await subscribeClosure?()
    }
    //MARK: - paginateBackwards

    private let paginateBackwardsCallsCountLock = NSLock()
    private nonisolated(unsafe) var paginateBackwardsUnderlyingCallsCount = 0
    var paginateBackwardsCallsCount: Int {
        get { paginateBackwardsCallsCountLock.withLock { paginateBackwardsUnderlyingCallsCount } }
        set { paginateBackwardsCallsCountLock.withLock { paginateBackwardsUnderlyingCallsCount = newValue } }
    }
    var paginateBackwardsCalled: Bool {
        return paginateBackwardsCallsCount > 0
    }

    private let paginateBackwardsReturnValueLock = NSLock()
    private nonisolated(unsafe) var paginateBackwardsUnderlyingReturnValue: Result<Bool, TimelineProxyError>!
    var paginateBackwardsReturnValue: Result<Bool, TimelineProxyError>! {
        get { paginateBackwardsReturnValueLock.withLock { paginateBackwardsUnderlyingReturnValue } }
        set { paginateBackwardsReturnValueLock.withLock { paginateBackwardsUnderlyingReturnValue = newValue } }
    }
    nonisolated(unsafe) var paginateBackwardsClosure: (() async -> Result<Bool, TimelineProxyError>)?

    @concurrent func paginateBackwards() async -> Result<Bool, TimelineProxyError> {
        paginateBackwardsCallsCountLock.withLock { paginateBackwardsUnderlyingCallsCount += 1 }
        if let paginateBackwardsClosure = paginateBackwardsClosure {
            return await paginateBackwardsClosure()
        } else {
            return paginateBackwardsReturnValue
        }
    }
    //MARK: - send

    private let sendMessageInReplyToCallsCountLock = NSLock()
    private nonisolated(unsafe) var sendMessageInReplyToUnderlyingCallsCount = 0
    var sendMessageInReplyToCallsCount: Int {
        get { sendMessageInReplyToCallsCountLock.withLock { sendMessageInReplyToUnderlyingCallsCount } }
        set { sendMessageInReplyToCallsCountLock.withLock { sendMessageInReplyToUnderlyingCallsCount = newValue } }
    }
    var sendMessageInReplyToCalled: Bool {
        return sendMessageInReplyToCallsCount > 0
    }
    private let sendMessageInReplyToReceivedArgumentsLock = NSLock()
    private nonisolated(unsafe) var sendMessageInReplyToUnderlyingReceivedArguments: (message: String, eventID: String?)?
    var sendMessageInReplyToReceivedArguments: (message: String, eventID: String?)? {
        get { sendMessageInReplyToReceivedArgumentsLock.withLock { sendMessageInReplyToUnderlyingReceivedArguments } }
        set { sendMessageInReplyToReceivedArgumentsLock.withLock { sendMessageInReplyToUnderlyingReceivedArguments = newValue } }
    }
    private let sendMessageInReplyToReceivedInvocationsLock = NSLock()
    private nonisolated(unsafe) var sendMessageInReplyToUnderlyingReceivedInvocations: [(message: String, eventID: String?)] = []
    var sendMessageInReplyToReceivedInvocations: [(message: String, eventID: String?)] {
        get { sendMessageInReplyToReceivedInvocationsLock.withLock { sendMessageInReplyToUnderlyingReceivedInvocations } }
        set { sendMessageInReplyToReceivedInvocationsLock.withLock { sendMessageInReplyToUnderlyingReceivedInvocations = newValue } }
    }

    private let sendMessageInReplyToReturnValueLock = NSLock()
    private nonisolated(unsafe) var sendMessageInReplyToUnderlyingReturnValue: Result<Void, TimelineProxyError>!
    var sendMessageInReplyToReturnValue: Result<Void, TimelineProxyError>! {
        get { sendMessageInReplyToReturnValueLock.withLock { sendMessageInReplyToUnderlyingReturnValue } }
        set { sendMessageInReplyToReturnValueLock.withLock { sendMessageInReplyToUnderlyingReturnValue = newValue } }
    }
    nonisolated(unsafe) var sendMessageInReplyToClosure: ((String, String?) async -> Result<Void, TimelineProxyError>)?

    @concurrent func send(message: String, inReplyTo eventID: String?) async -> Result<Void, TimelineProxyError> {
        sendMessageInReplyToCallsCountLock.withLock { sendMessageInReplyToUnderlyingCallsCount += 1 }
        sendMessageInReplyToReceivedArguments = (message: message, eventID: eventID)
        sendMessageInReplyToReceivedInvocationsLock.withLock { sendMessageInReplyToUnderlyingReceivedInvocations.append((message: message, eventID: eventID)) }
        if let sendMessageInReplyToClosure = sendMessageInReplyToClosure {
            return await sendMessageInReplyToClosure(message, eventID)
        } else {
            return sendMessageInReplyToReturnValue
        }
    }
    //MARK: - sendLocation

    private let sendLocationDescriptionCallsCountLock = NSLock()
    private nonisolated(unsafe) var sendLocationDescriptionUnderlyingCallsCount = 0
    var sendLocationDescriptionCallsCount: Int {
        get { sendLocationDescriptionCallsCountLock.withLock { sendLocationDescriptionUnderlyingCallsCount } }
        set { sendLocationDescriptionCallsCountLock.withLock { sendLocationDescriptionUnderlyingCallsCount = newValue } }
    }
    var sendLocationDescriptionCalled: Bool {
        return sendLocationDescriptionCallsCount > 0
    }
    private let sendLocationDescriptionReceivedArgumentsLock = NSLock()
    private nonisolated(unsafe) var sendLocationDescriptionUnderlyingReceivedArguments: (geoURI: GeoURI, description: String?)?
    var sendLocationDescriptionReceivedArguments: (geoURI: GeoURI, description: String?)? {
        get { sendLocationDescriptionReceivedArgumentsLock.withLock { sendLocationDescriptionUnderlyingReceivedArguments } }
        set { sendLocationDescriptionReceivedArgumentsLock.withLock { sendLocationDescriptionUnderlyingReceivedArguments = newValue } }
    }
    private let sendLocationDescriptionReceivedInvocationsLock = NSLock()
    private nonisolated(unsafe) var sendLocationDescriptionUnderlyingReceivedInvocations: [(geoURI: GeoURI, description: String?)] = []
    var sendLocationDescriptionReceivedInvocations: [(geoURI: GeoURI, description: String?)] {
        get { sendLocationDescriptionReceivedInvocationsLock.withLock { sendLocationDescriptionUnderlyingReceivedInvocations } }
        set { sendLocationDescriptionReceivedInvocationsLock.withLock { sendLocationDescriptionUnderlyingReceivedInvocations = newValue } }
    }

    private let sendLocationDescriptionReturnValueLock = NSLock()
    private nonisolated(unsafe) var sendLocationDescriptionUnderlyingReturnValue: Result<Void, TimelineProxyError>!
    var sendLocationDescriptionReturnValue: Result<Void, TimelineProxyError>! {
        get { sendLocationDescriptionReturnValueLock.withLock { sendLocationDescriptionUnderlyingReturnValue } }
        set { sendLocationDescriptionReturnValueLock.withLock { sendLocationDescriptionUnderlyingReturnValue = newValue } }
    }
    nonisolated(unsafe) var sendLocationDescriptionClosure: ((GeoURI, String?) async -> Result<Void, TimelineProxyError>)?

    @concurrent func sendLocation(_ geoURI: GeoURI, description: String?) async -> Result<Void, TimelineProxyError> {
        sendLocationDescriptionCallsCountLock.withLock { sendLocationDescriptionUnderlyingCallsCount += 1 }
        sendLocationDescriptionReceivedArguments = (geoURI: geoURI, description: description)
        sendLocationDescriptionReceivedInvocationsLock.withLock { sendLocationDescriptionUnderlyingReceivedInvocations.append((geoURI: geoURI, description: description)) }
        if let sendLocationDescriptionClosure = sendLocationDescriptionClosure {
            return await sendLocationDescriptionClosure(geoURI, description)
        } else {
            return sendLocationDescriptionReturnValue
        }
    }
    //MARK: - sendVoiceMessage

    private let sendVoiceMessageFileURLDurationWaveformCallsCountLock = NSLock()
    private nonisolated(unsafe) var sendVoiceMessageFileURLDurationWaveformUnderlyingCallsCount = 0
    var sendVoiceMessageFileURLDurationWaveformCallsCount: Int {
        get { sendVoiceMessageFileURLDurationWaveformCallsCountLock.withLock { sendVoiceMessageFileURLDurationWaveformUnderlyingCallsCount } }
        set { sendVoiceMessageFileURLDurationWaveformCallsCountLock.withLock { sendVoiceMessageFileURLDurationWaveformUnderlyingCallsCount = newValue } }
    }
    var sendVoiceMessageFileURLDurationWaveformCalled: Bool {
        return sendVoiceMessageFileURLDurationWaveformCallsCount > 0
    }
    private let sendVoiceMessageFileURLDurationWaveformReceivedArgumentsLock = NSLock()
    private nonisolated(unsafe) var sendVoiceMessageFileURLDurationWaveformUnderlyingReceivedArguments: (fileURL: URL, duration: TimeInterval, waveform: [Float])?
    var sendVoiceMessageFileURLDurationWaveformReceivedArguments: (fileURL: URL, duration: TimeInterval, waveform: [Float])? {
        get { sendVoiceMessageFileURLDurationWaveformReceivedArgumentsLock.withLock { sendVoiceMessageFileURLDurationWaveformUnderlyingReceivedArguments } }
        set { sendVoiceMessageFileURLDurationWaveformReceivedArgumentsLock.withLock { sendVoiceMessageFileURLDurationWaveformUnderlyingReceivedArguments = newValue } }
    }
    private let sendVoiceMessageFileURLDurationWaveformReceivedInvocationsLock = NSLock()
    private nonisolated(unsafe) var sendVoiceMessageFileURLDurationWaveformUnderlyingReceivedInvocations: [(fileURL: URL, duration: TimeInterval, waveform: [Float])] = []
    var sendVoiceMessageFileURLDurationWaveformReceivedInvocations: [(fileURL: URL, duration: TimeInterval, waveform: [Float])] {
        get { sendVoiceMessageFileURLDurationWaveformReceivedInvocationsLock.withLock { sendVoiceMessageFileURLDurationWaveformUnderlyingReceivedInvocations } }
        set { sendVoiceMessageFileURLDurationWaveformReceivedInvocationsLock.withLock { sendVoiceMessageFileURLDurationWaveformUnderlyingReceivedInvocations = newValue } }
    }

    private let sendVoiceMessageFileURLDurationWaveformReturnValueLock = NSLock()
    private nonisolated(unsafe) var sendVoiceMessageFileURLDurationWaveformUnderlyingReturnValue: Result<Void, TimelineProxyError>!
    var sendVoiceMessageFileURLDurationWaveformReturnValue: Result<Void, TimelineProxyError>! {
        get { sendVoiceMessageFileURLDurationWaveformReturnValueLock.withLock { sendVoiceMessageFileURLDurationWaveformUnderlyingReturnValue } }
        set { sendVoiceMessageFileURLDurationWaveformReturnValueLock.withLock { sendVoiceMessageFileURLDurationWaveformUnderlyingReturnValue = newValue } }
    }
    nonisolated(unsafe) var sendVoiceMessageFileURLDurationWaveformClosure: ((URL, TimeInterval, [Float]) async -> Result<Void, TimelineProxyError>)?

    @concurrent func sendVoiceMessage(fileURL: URL, duration: TimeInterval, waveform: [Float]) async -> Result<Void, TimelineProxyError> {
        sendVoiceMessageFileURLDurationWaveformCallsCountLock.withLock { sendVoiceMessageFileURLDurationWaveformUnderlyingCallsCount += 1 }
        sendVoiceMessageFileURLDurationWaveformReceivedArguments = (fileURL: fileURL, duration: duration, waveform: waveform)
        sendVoiceMessageFileURLDurationWaveformReceivedInvocationsLock.withLock { sendVoiceMessageFileURLDurationWaveformUnderlyingReceivedInvocations.append((fileURL: fileURL, duration: duration, waveform: waveform)) }
        if let sendVoiceMessageFileURLDurationWaveformClosure = sendVoiceMessageFileURLDurationWaveformClosure {
            return await sendVoiceMessageFileURLDurationWaveformClosure(fileURL, duration, waveform)
        } else {
            return sendVoiceMessageFileURLDurationWaveformReturnValue
        }
    }
    //MARK: - toggleReaction

    private let toggleReactionToCallsCountLock = NSLock()
    private nonisolated(unsafe) var toggleReactionToUnderlyingCallsCount = 0
    var toggleReactionToCallsCount: Int {
        get { toggleReactionToCallsCountLock.withLock { toggleReactionToUnderlyingCallsCount } }
        set { toggleReactionToCallsCountLock.withLock { toggleReactionToUnderlyingCallsCount = newValue } }
    }
    var toggleReactionToCalled: Bool {
        return toggleReactionToCallsCount > 0
    }
    private let toggleReactionToReceivedArgumentsLock = NSLock()
    private nonisolated(unsafe) var toggleReactionToUnderlyingReceivedArguments: (key: String, itemID: EventOrTransactionId)?
    var toggleReactionToReceivedArguments: (key: String, itemID: EventOrTransactionId)? {
        get { toggleReactionToReceivedArgumentsLock.withLock { toggleReactionToUnderlyingReceivedArguments } }
        set { toggleReactionToReceivedArgumentsLock.withLock { toggleReactionToUnderlyingReceivedArguments = newValue } }
    }
    private let toggleReactionToReceivedInvocationsLock = NSLock()
    private nonisolated(unsafe) var toggleReactionToUnderlyingReceivedInvocations: [(key: String, itemID: EventOrTransactionId)] = []
    var toggleReactionToReceivedInvocations: [(key: String, itemID: EventOrTransactionId)] {
        get { toggleReactionToReceivedInvocationsLock.withLock { toggleReactionToUnderlyingReceivedInvocations } }
        set { toggleReactionToReceivedInvocationsLock.withLock { toggleReactionToUnderlyingReceivedInvocations = newValue } }
    }

    private let toggleReactionToReturnValueLock = NSLock()
    private nonisolated(unsafe) var toggleReactionToUnderlyingReturnValue: Result<Void, TimelineProxyError>!
    var toggleReactionToReturnValue: Result<Void, TimelineProxyError>! {
        get { toggleReactionToReturnValueLock.withLock { toggleReactionToUnderlyingReturnValue } }
        set { toggleReactionToReturnValueLock.withLock { toggleReactionToUnderlyingReturnValue = newValue } }
    }
    nonisolated(unsafe) var toggleReactionToClosure: ((String, EventOrTransactionId) async -> Result<Void, TimelineProxyError>)?

    @concurrent func toggleReaction(_ key: String, to itemID: EventOrTransactionId) async -> Result<Void, TimelineProxyError> {
        toggleReactionToCallsCountLock.withLock { toggleReactionToUnderlyingCallsCount += 1 }
        toggleReactionToReceivedArguments = (key: key, itemID: itemID)
        toggleReactionToReceivedInvocationsLock.withLock { toggleReactionToUnderlyingReceivedInvocations.append((key: key, itemID: itemID)) }
        if let toggleReactionToClosure = toggleReactionToClosure {
            return await toggleReactionToClosure(key, itemID)
        } else {
            return toggleReactionToReturnValue
        }
    }
    //MARK: - retrySend

    private let retrySendCallsCountLock = NSLock()
    private nonisolated(unsafe) var retrySendUnderlyingCallsCount = 0
    var retrySendCallsCount: Int {
        get { retrySendCallsCountLock.withLock { retrySendUnderlyingCallsCount } }
        set { retrySendCallsCountLock.withLock { retrySendUnderlyingCallsCount = newValue } }
    }
    var retrySendCalled: Bool {
        return retrySendCallsCount > 0
    }
    private let retrySendReceivedItemIDLock = NSLock()
    private nonisolated(unsafe) var retrySendUnderlyingReceivedItemID: EventOrTransactionId?
    var retrySendReceivedItemID: EventOrTransactionId? {
        get { retrySendReceivedItemIDLock.withLock { retrySendUnderlyingReceivedItemID } }
        set { retrySendReceivedItemIDLock.withLock { retrySendUnderlyingReceivedItemID = newValue } }
    }
    private let retrySendReceivedInvocationsLock = NSLock()
    private nonisolated(unsafe) var retrySendUnderlyingReceivedInvocations: [EventOrTransactionId] = []
    var retrySendReceivedInvocations: [EventOrTransactionId] {
        get { retrySendReceivedInvocationsLock.withLock { retrySendUnderlyingReceivedInvocations } }
        set { retrySendReceivedInvocationsLock.withLock { retrySendUnderlyingReceivedInvocations = newValue } }
    }

    private let retrySendReturnValueLock = NSLock()
    private nonisolated(unsafe) var retrySendUnderlyingReturnValue: Result<Void, TimelineProxyError>!
    var retrySendReturnValue: Result<Void, TimelineProxyError>! {
        get { retrySendReturnValueLock.withLock { retrySendUnderlyingReturnValue } }
        set { retrySendReturnValueLock.withLock { retrySendUnderlyingReturnValue = newValue } }
    }
    nonisolated(unsafe) var retrySendClosure: ((EventOrTransactionId) async -> Result<Void, TimelineProxyError>)?

    @concurrent func retrySend(_ itemID: EventOrTransactionId) async -> Result<Void, TimelineProxyError> {
        retrySendCallsCountLock.withLock { retrySendUnderlyingCallsCount += 1 }
        retrySendReceivedItemID = itemID
        retrySendReceivedInvocationsLock.withLock { retrySendUnderlyingReceivedInvocations.append(itemID) }
        if let retrySendClosure = retrySendClosure {
            return await retrySendClosure(itemID)
        } else {
            return retrySendReturnValue
        }
    }
    //MARK: - markAsRead

    private let markAsReadCallsCountLock = NSLock()
    private nonisolated(unsafe) var markAsReadUnderlyingCallsCount = 0
    var markAsReadCallsCount: Int {
        get { markAsReadCallsCountLock.withLock { markAsReadUnderlyingCallsCount } }
        set { markAsReadCallsCountLock.withLock { markAsReadUnderlyingCallsCount = newValue } }
    }
    var markAsReadCalled: Bool {
        return markAsReadCallsCount > 0
    }
    nonisolated(unsafe) var markAsReadClosure: (() async -> Void)?

    @concurrent func markAsRead() async {
        markAsReadCallsCountLock.withLock { markAsReadUnderlyingCallsCount += 1 }
        await markAsReadClosure?()
    }
}
nonisolated class UserSessionRestorerMock: UserSessionRestorerProtocol, @unchecked Sendable {

    //MARK: - restore

    private let restoreCallsCountLock = NSLock()
    private nonisolated(unsafe) var restoreUnderlyingCallsCount = 0
    var restoreCallsCount: Int {
        get { restoreCallsCountLock.withLock { restoreUnderlyingCallsCount } }
        set { restoreCallsCountLock.withLock { restoreUnderlyingCallsCount = newValue } }
    }
    var restoreCalled: Bool {
        return restoreCallsCount > 0
    }

    private let restoreReturnValueLock = NSLock()
    private nonisolated(unsafe) var restoreUnderlyingReturnValue: Result<ClientProxyProtocol, UserSessionRestorerError>!
    var restoreReturnValue: Result<ClientProxyProtocol, UserSessionRestorerError>! {
        get { restoreReturnValueLock.withLock { restoreUnderlyingReturnValue } }
        set { restoreReturnValueLock.withLock { restoreUnderlyingReturnValue = newValue } }
    }
    nonisolated(unsafe) var restoreClosure: (() async -> Result<ClientProxyProtocol, UserSessionRestorerError>)?

    @concurrent func restore() async -> Result<ClientProxyProtocol, UserSessionRestorerError> {
        restoreCallsCountLock.withLock { restoreUnderlyingCallsCount += 1 }
        if let restoreClosure = restoreClosure {
            return await restoreClosure()
        } else {
            return restoreReturnValue
        }
    }
}
nonisolated class VoiceMessagePlayerMock: VoiceMessagePlayerProtocol, @unchecked Sendable {
    var statePublisher: AnyPublisher<VoicePlaybackState, Never> {
        get { return underlyingStatePublisher }
        set(value) { underlyingStatePublisher = value }
    }
    nonisolated(unsafe) var underlyingStatePublisher: AnyPublisher<VoicePlaybackState, Never>!
    var state: VoicePlaybackState {
        get { return underlyingState }
        set(value) { underlyingState = value }
    }
    nonisolated(unsafe) var underlyingState: VoicePlaybackState!

    //MARK: - play

    private let playIdSourceCallsCountLock = NSLock()
    private nonisolated(unsafe) var playIdSourceUnderlyingCallsCount = 0
    var playIdSourceCallsCount: Int {
        get { playIdSourceCallsCountLock.withLock { playIdSourceUnderlyingCallsCount } }
        set { playIdSourceCallsCountLock.withLock { playIdSourceUnderlyingCallsCount = newValue } }
    }
    var playIdSourceCalled: Bool {
        return playIdSourceCallsCount > 0
    }
    private let playIdSourceReceivedArgumentsLock = NSLock()
    private nonisolated(unsafe) var playIdSourceUnderlyingReceivedArguments: (id: String, source: MediaSourceProxy)?
    var playIdSourceReceivedArguments: (id: String, source: MediaSourceProxy)? {
        get { playIdSourceReceivedArgumentsLock.withLock { playIdSourceUnderlyingReceivedArguments } }
        set { playIdSourceReceivedArgumentsLock.withLock { playIdSourceUnderlyingReceivedArguments = newValue } }
    }
    private let playIdSourceReceivedInvocationsLock = NSLock()
    private nonisolated(unsafe) var playIdSourceUnderlyingReceivedInvocations: [(id: String, source: MediaSourceProxy)] = []
    var playIdSourceReceivedInvocations: [(id: String, source: MediaSourceProxy)] {
        get { playIdSourceReceivedInvocationsLock.withLock { playIdSourceUnderlyingReceivedInvocations } }
        set { playIdSourceReceivedInvocationsLock.withLock { playIdSourceUnderlyingReceivedInvocations = newValue } }
    }
    nonisolated(unsafe) var playIdSourceClosure: ((String, MediaSourceProxy) async -> Void)?

    @concurrent func play(id: String, source: MediaSourceProxy) async {
        playIdSourceCallsCountLock.withLock { playIdSourceUnderlyingCallsCount += 1 }
        playIdSourceReceivedArguments = (id: id, source: source)
        playIdSourceReceivedInvocationsLock.withLock { playIdSourceUnderlyingReceivedInvocations.append((id: id, source: source)) }
        await playIdSourceClosure?(id, source)
    }
    //MARK: - pause

    private let pauseCallsCountLock = NSLock()
    private nonisolated(unsafe) var pauseUnderlyingCallsCount = 0
    var pauseCallsCount: Int {
        get { pauseCallsCountLock.withLock { pauseUnderlyingCallsCount } }
        set { pauseCallsCountLock.withLock { pauseUnderlyingCallsCount = newValue } }
    }
    var pauseCalled: Bool {
        return pauseCallsCount > 0
    }
    nonisolated(unsafe) var pauseClosure: (() -> Void)?

    func pause() {
        pauseCallsCountLock.withLock { pauseUnderlyingCallsCount += 1 }
        pauseClosure?()
    }
    //MARK: - stop

    private let stopCallsCountLock = NSLock()
    private nonisolated(unsafe) var stopUnderlyingCallsCount = 0
    var stopCallsCount: Int {
        get { stopCallsCountLock.withLock { stopUnderlyingCallsCount } }
        set { stopCallsCountLock.withLock { stopUnderlyingCallsCount = newValue } }
    }
    var stopCalled: Bool {
        return stopCallsCount > 0
    }
    nonisolated(unsafe) var stopClosure: (() -> Void)?

    func stop() {
        stopCallsCountLock.withLock { stopUnderlyingCallsCount += 1 }
        stopClosure?()
    }
}
nonisolated class VoiceMessagePreviewPlayerMock: VoiceMessagePreviewPlayerProtocol, @unchecked Sendable {
    var statePublisher: AnyPublisher<VoiceMessagePreviewPlayerState, Never> {
        get { return underlyingStatePublisher }
        set(value) { underlyingStatePublisher = value }
    }
    nonisolated(unsafe) var underlyingStatePublisher: AnyPublisher<VoiceMessagePreviewPlayerState, Never>!

    //MARK: - play

    private let playFileURLCallsCountLock = NSLock()
    private nonisolated(unsafe) var playFileURLUnderlyingCallsCount = 0
    var playFileURLCallsCount: Int {
        get { playFileURLCallsCountLock.withLock { playFileURLUnderlyingCallsCount } }
        set { playFileURLCallsCountLock.withLock { playFileURLUnderlyingCallsCount = newValue } }
    }
    var playFileURLCalled: Bool {
        return playFileURLCallsCount > 0
    }
    private let playFileURLReceivedFileURLLock = NSLock()
    private nonisolated(unsafe) var playFileURLUnderlyingReceivedFileURL: URL?
    var playFileURLReceivedFileURL: URL? {
        get { playFileURLReceivedFileURLLock.withLock { playFileURLUnderlyingReceivedFileURL } }
        set { playFileURLReceivedFileURLLock.withLock { playFileURLUnderlyingReceivedFileURL = newValue } }
    }
    private let playFileURLReceivedInvocationsLock = NSLock()
    private nonisolated(unsafe) var playFileURLUnderlyingReceivedInvocations: [URL] = []
    var playFileURLReceivedInvocations: [URL] {
        get { playFileURLReceivedInvocationsLock.withLock { playFileURLUnderlyingReceivedInvocations } }
        set { playFileURLReceivedInvocationsLock.withLock { playFileURLUnderlyingReceivedInvocations = newValue } }
    }

    private let playFileURLReturnValueLock = NSLock()
    private nonisolated(unsafe) var playFileURLUnderlyingReturnValue: Result<Void, VoiceMessagePreviewPlayerError>!
    var playFileURLReturnValue: Result<Void, VoiceMessagePreviewPlayerError>! {
        get { playFileURLReturnValueLock.withLock { playFileURLUnderlyingReturnValue } }
        set { playFileURLReturnValueLock.withLock { playFileURLUnderlyingReturnValue = newValue } }
    }
    nonisolated(unsafe) var playFileURLClosure: ((URL) async -> Result<Void, VoiceMessagePreviewPlayerError>)?

    @concurrent func play(fileURL: URL) async -> Result<Void, VoiceMessagePreviewPlayerError> {
        playFileURLCallsCountLock.withLock { playFileURLUnderlyingCallsCount += 1 }
        playFileURLReceivedFileURL = fileURL
        playFileURLReceivedInvocationsLock.withLock { playFileURLUnderlyingReceivedInvocations.append(fileURL) }
        if let playFileURLClosure = playFileURLClosure {
            return await playFileURLClosure(fileURL)
        } else {
            return playFileURLReturnValue
        }
    }
    //MARK: - pause

    private let pauseCallsCountLock = NSLock()
    private nonisolated(unsafe) var pauseUnderlyingCallsCount = 0
    var pauseCallsCount: Int {
        get { pauseCallsCountLock.withLock { pauseUnderlyingCallsCount } }
        set { pauseCallsCountLock.withLock { pauseUnderlyingCallsCount = newValue } }
    }
    var pauseCalled: Bool {
        return pauseCallsCount > 0
    }
    nonisolated(unsafe) var pauseClosure: (() -> Void)?

    func pause() {
        pauseCallsCountLock.withLock { pauseUnderlyingCallsCount += 1 }
        pauseClosure?()
    }
    //MARK: - stop

    private let stopCallsCountLock = NSLock()
    private nonisolated(unsafe) var stopUnderlyingCallsCount = 0
    var stopCallsCount: Int {
        get { stopCallsCountLock.withLock { stopUnderlyingCallsCount } }
        set { stopCallsCountLock.withLock { stopUnderlyingCallsCount = newValue } }
    }
    var stopCalled: Bool {
        return stopCallsCount > 0
    }
    nonisolated(unsafe) var stopClosure: (() -> Void)?

    func stop() {
        stopCallsCountLock.withLock { stopUnderlyingCallsCount += 1 }
        stopClosure?()
    }
}
nonisolated class VoiceMessageRecorderMock: VoiceMessageRecorderProtocol, @unchecked Sendable {
    var statePublisher: AnyPublisher<VoiceRecorderState, Never> {
        get { return underlyingStatePublisher }
        set(value) { underlyingStatePublisher = value }
    }
    nonisolated(unsafe) var underlyingStatePublisher: AnyPublisher<VoiceRecorderState, Never>!
    var state: VoiceRecorderState {
        get { return underlyingState }
        set(value) { underlyingState = value }
    }
    nonisolated(unsafe) var underlyingState: VoiceRecorderState!

    //MARK: - start

    private let startCallsCountLock = NSLock()
    private nonisolated(unsafe) var startUnderlyingCallsCount = 0
    var startCallsCount: Int {
        get { startCallsCountLock.withLock { startUnderlyingCallsCount } }
        set { startCallsCountLock.withLock { startUnderlyingCallsCount = newValue } }
    }
    var startCalled: Bool {
        return startCallsCount > 0
    }

    private let startReturnValueLock = NSLock()
    private nonisolated(unsafe) var startUnderlyingReturnValue: Result<Void, VoiceRecorderError>!
    var startReturnValue: Result<Void, VoiceRecorderError>! {
        get { startReturnValueLock.withLock { startUnderlyingReturnValue } }
        set { startReturnValueLock.withLock { startUnderlyingReturnValue = newValue } }
    }
    nonisolated(unsafe) var startClosure: (() async -> Result<Void, VoiceRecorderError>)?

    @concurrent func start() async -> Result<Void, VoiceRecorderError> {
        startCallsCountLock.withLock { startUnderlyingCallsCount += 1 }
        if let startClosure = startClosure {
            return await startClosure()
        } else {
            return startReturnValue
        }
    }
    //MARK: - stop

    private let stopCallsCountLock = NSLock()
    private nonisolated(unsafe) var stopUnderlyingCallsCount = 0
    var stopCallsCount: Int {
        get { stopCallsCountLock.withLock { stopUnderlyingCallsCount } }
        set { stopCallsCountLock.withLock { stopUnderlyingCallsCount = newValue } }
    }
    var stopCalled: Bool {
        return stopCallsCount > 0
    }
    nonisolated(unsafe) var stopClosure: (() -> Void)?

    func stop() {
        stopCallsCountLock.withLock { stopUnderlyingCallsCount += 1 }
        stopClosure?()
    }
    //MARK: - cancel

    private let cancelCallsCountLock = NSLock()
    private nonisolated(unsafe) var cancelUnderlyingCallsCount = 0
    var cancelCallsCount: Int {
        get { cancelCallsCountLock.withLock { cancelUnderlyingCallsCount } }
        set { cancelCallsCountLock.withLock { cancelUnderlyingCallsCount = newValue } }
    }
    var cancelCalled: Bool {
        return cancelCallsCount > 0
    }
    nonisolated(unsafe) var cancelClosure: (() -> Void)?

    func cancel() {
        cancelCallsCountLock.withLock { cancelUnderlyingCallsCount += 1 }
        cancelClosure?()
    }
}
// swiftlint:enable all
