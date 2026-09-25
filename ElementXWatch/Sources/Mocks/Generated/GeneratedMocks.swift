// Generated using Sourcery 2.3.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

// swiftlint:disable all
@preconcurrency import Combine
@preconcurrency import SwiftUI

@preconcurrency import MatrixRustSDK

import Foundation

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
// swiftlint:enable all
