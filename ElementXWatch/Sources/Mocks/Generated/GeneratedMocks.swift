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
// swiftlint:enable all
