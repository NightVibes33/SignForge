//
//  MinimuxerWrapper.swift
//
//  Created by Magesh K on 22/02/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import Foundation
import Minimuxer

func bindTunnelConfig() {
    defer { print("[SideStore] bindTunnelConfig() completed") }

    #if targetEnvironment(simulator)
    print("[SideStore] bindTunnelConfig() is no-op on simulator")
    #else
    print("[SideStore] bindTunnelConfig() invoked")
    let config = TunnelConfig.shared
    let configBinding = TunnelConfigBinding(
        setDeviceIP: { value in Task { @MainActor in config.deviceIP = value } },
        setFakeIP: { value in Task { @MainActor in config.fakeIP = value } },
        setSubnetMask: { value in Task { @MainActor in config.subnetMask = value } },
        getOverrideFakeIP: { config.overrideFakeIP },
        setOverrideEffective: { value in Task { @MainActor in config.overrideEffective = value } }
    )
    Task { await Minimuxer.shared.bindTunnelConfig(configBinding) }
    #endif
}


enum MinimuxerStatus {
    case ready
    case noConnection
    case noVPN
    case invalidPairingFile
}

extension MinimuxerStatus {
    var operationError: OperationError? {
        switch self {
        case .ready:
            return nil
        case .noConnection:
            return .noConnection
        case .noVPN:
            return .noVPN
        case .invalidPairingFile:
            return .invalidPairingFile
        }
    }
}

var minimuxerStatus: MinimuxerStatus {
    #if targetEnvironment(simulator)
    print("[SideStore] minimuxerStatus = true on simulator")
    #endif

    // if AppManager.needsMuxerServicesRestart && (AppManager.muxerRestartError as? MinimuxerError) == .PairingFile {
    //     return .invalidPairingFile
    // }
    let semaphore = DispatchSemaphore(value: 0)
    var status: MinimuxerStatus = .noVPN
    
    Task {
        do {
            _ = try await Minimuxer.shared.ready()
            status = .ready
        } catch {
            if let minErr = error as? MinimuxerError {
                switch minErr {
                case .NoVPN, .InvalidVPN:
                    status = .noVPN
                case .PairingFile, .InvalidPairing:
                    status = .invalidPairingFile
                default:
                    status = .noConnection
                }
            } else {
                status = .noConnection
            }
        }
        semaphore.signal()
    }
    _ = semaphore.wait(timeout: .now() + 5.0)
    return status
}


func markMuxerServicesNeedsRestart(error: Error) {
    AppManager.markMuxerServicesNeedsRestart(error: error)
}

func reinitializePairingData(_ pairingFile: String) async throws {
    defer { print("[SideStore] reinitializePairingData(pairingFile) completed") }
    #if targetEnvironment(simulator)
    print("[SideStore] reinitializePairingData(pairingFile) is no-op on simulator")
    #else
    print("[SideStore] reinitializePairingData(pairingFile) invoked")
    try await Minimuxer.shared.reinitializePairingData(pairingFile: pairingFile)
    #endif
}

func startNetworkMonitoring() {
    bindTunnelConfig()
    #if !targetEnvironment(simulator)
    Minimuxer.network.start()
    #endif
}

func minimuxerStart(_ pairingFile: String, mountPath: String) async throws {
    defer { print("[SideStore] minimuxerStart(pairingFile) completed") }
    #if targetEnvironment(simulator)
    print("[SideStore] minimuxerStart(pairingFile) is no-op on simulator")
    #else
    bindTunnelConfig()
    Minimuxer.network.start()
    print("[SideStore] minimuxerStart(pairingFile) invoked")
    try await Minimuxer.shared.start(pairingFile: pairingFile, mountPath: mountPath)
    #endif
}


func reinitializePairingData(pairingFile: String) async throws {
    defer { print("[SideStore] reinitializePairingData(pairingFile) completed") }
    #if targetEnvironment(simulator)
    print("[SideStore] reinitializePairingData(pairingFile) is no-op on simulator")
    #else
    print("[SideStore] reinitializePairingData(pairingFile) invoked")
    try await Minimuxer.shared.reinitializePairingData(pairingFile: pairingFile)
    #endif
}

func installProvisioningProfiles(_ profileData: Data) async throws {
    defer { print("[SideStore] installProvisioningProfiles(profileData) completed") }
    #if targetEnvironment(simulator)
    print("[SideStore] installProvisioningProfiles(profileData) is no-op on simulator")
    #else
    print("[SideStore] installProvisioningProfiles(profileData) invoked")
    try await Minimuxer.shared.installProvisioningProfile(profile: profileData)
    #endif
}

func removeProvisioningProfile(_ id: String) async throws {
    defer { print("[SideStore] removeProvisioningProfile(id) completed") }
    #if targetEnvironment(simulator)
    print("[SideStore] removeProvisioningProfile(id) is no-op on simulator")
    #else
    print("[SideStore] removeProvisioningProfile(id) invoked")
    try await Minimuxer.shared.removeProvisioningProfile(id: id)
    #endif
}

func removeApp(_ bundleId: String) async throws {
    defer { print("[SideStore] removeApp(bundleId) completed") }
    #if targetEnvironment(simulator)
    print("[SideStore] removeApp(bundleId) is no-op on simulator")
    #else
    print("[SideStore] removeApp(bundleId) invoked")
    try await Minimuxer.shared.removeApp(bundleId: bundleId)
    #endif
}

func yeetAppAFC(_ bundleId: String, _ rawBytes: Data) async throws {
    defer { print("[SideStore] yeetAppAFC(bundleId, rawBytes) completed") }
    #if targetEnvironment(simulator)
    print("[SideStore] yeetAppAFC(bundleId, rawBytes) is no-op on simulator")
    #else
    print("[SideStore] yeetAppAFC(bundleId, rawBytes) invoked")
    try await Minimuxer.shared.yeetAppAfc(bundleId: bundleId, ipaBytes: rawBytes)
    #endif
}

func installIPA(_ bundleId: String) async throws {
    defer { print("[SideStore] installIPA(bundleId) completed") }
    #if targetEnvironment(simulator)
    print("[SideStore] installIPA(bundleId) is no-op on simulator")
    #else
    print("[SideStore] installIPA(bundleId) invoked")
    try await Minimuxer.shared.installIpa(bundleId: bundleId)
    #endif
}

@discardableResult
func fetchUDID() async throws -> String? {
    defer { print("[SideStore] fetchUDID() completed") }
    #if targetEnvironment(simulator)
    print("[SideStore] fetchUDID() is no-op on simulator")
    return "XXXXX-XXXX-XXXXX-XXXX"
    #else
    print("[SideStore] fetchUDID() invoked")
    return try await Minimuxer.shared.fetchUDID()
    #endif
}

func debugApp(_ appId: String) async throws {
    defer { print("[SideStore] debugApp(appId) completed") }
    #if targetEnvironment(simulator)
    print("[SideStore] debugApp(appId) is no-op on simulator")
    #else
    print("[SideStore] debugApp(appId) invoked")
    try await Minimuxer.shared.debugApp(appId: appId)
    #endif
}

func attachDebugger(_ pid: UInt32) async throws {
    defer { print("[SideStore] attachDebugger(pid) completed") }
    #if targetEnvironment(simulator)
    print("[SideStore] attachDebugger(pid) is no-op on simulator")
    #else
    print("[SideStore] attachDebugger(pid) invoked")
    try await Minimuxer.shared.attachDebugger(pid: pid)
    #endif
}


func dumpProfiles(_ docsPath: String) async throws -> String {
    defer { print("[SideStore] dumpProfiles(docsPath) completed") }
    #if targetEnvironment(simulator)
    print("[SideStore] dumpProfiles(docsPath) is no-op on simulator")
    return ""
    #else
    print("[SideStore] dumpProfiles(docsPath) invoked")
    return try await Minimuxer.shared.dumpProfiles(docsPath: docsPath)
    #endif
}

func minimuxerSetLogging(_ enabled: Bool) {
    defer { print("[SideStore] minimuxerSetLogging(enabled) completed") }
    print("[SideStore] minimuxerSetLogging(enabled) invoked")
    #if !targetEnvironment(simulator)
    Minimuxer.shared.setLogging(enabled)
    #endif
}

extension Result {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}

extension MinimuxerError: @retroactive LocalizedError {
    public var failureReason: String? {
        switch self {
        case .NoDevice:
            return NSLocalizedString("Cannot fetch the device from the muxer", comment: "")
        case .NoConnection:
            return NSLocalizedString("You do not appear to be connected to Wi-Fi or a wired network connection! Please connect to a Wi-Fi or wired connection.", comment: "")
        case .NoVPN:
            return NSLocalizedString("Unable to connect to the device. Please make sure LocalDevVPN is enabled and running! If it is connected, replace your pairing with iloader.", comment: "")
        case .PairingFile:
            return NSLocalizedString("Invalid pairing file. Your pairing file either didn't have a UDID, or it wasn't a valid plist. Please use iloader to replace it.", comment: "")
        case .CreateDebug:
            return createService(name: "debug")
        case .LookupApps:
            return getFromDevice(name: "installed apps")
        case .FindApp:
            return getFromDevice(name: "path to the app")
        case .BundlePath:
            return getFromDevice(name: "bundle path")
        case .MaxPacket:
            return setArgument(name: "max packet")
        case .WorkingDirectory:
            return setArgument(name: "working directory")
        case .Argv:
            return setArgument(name: "argv")
        case .LaunchSuccess:
            return getFromDevice(name: "launch success")
        case .Detach:
            return NSLocalizedString("Unable to detach from the app's process", comment: "")
        case .Attach:
            return NSLocalizedString("Unable to attach to the app's process", comment: "")
        case .CreateInstproxy:
            return createService(name: "instproxy")
        case .CreateAfc:
            return createService(name: "AFC")
        case .RwAfc:
            return NSLocalizedString("AFC was unable to manage files on the device.", comment: "")
        case .InstallApp(let message):
            return NSLocalizedString("Unable to install the app: \(message)", comment: "")
        case .UninstallApp:
            return NSLocalizedString("Unable to uninstall the app", comment: "")
        case .CreateMisagent:
            return createService(name: "misagent")
        case .ProfileInstall:
            return NSLocalizedString("Unable to manage profiles on the device", comment: "")
        case .ProfileRemove:
            return NSLocalizedString("Unable to manage profiles on the device", comment: "")
        case .CreateLockdown:
            return NSLocalizedString("Unable to connect to lockdown", comment: "")
        case .CreateCoreDevice:
            return NSLocalizedString("Unable to connect to core device proxy", comment: "")
        case .CreateSoftwareTunnel:
            return NSLocalizedString("Unable to create software tunnel", comment: "")
        case .CreateRemoteServer:
            return NSLocalizedString("Unable to connect to remote server", comment: "")
        case .CreateProcessControl:
            return NSLocalizedString("Unable to connect to process control", comment: "")
        case .GetLockdownValue:
            return NSLocalizedString("Unable to get value from lockdown", comment: "")
        case .Connect:
            return NSLocalizedString("Unable to connect to TCP port", comment: "")
        case .Close:
            return NSLocalizedString("Unable to close TCP port", comment: "")
        case .XpcHandshake:
            return NSLocalizedString("Unable to get services from XPC", comment: "")
        case .NoService:
            return NSLocalizedString("Device did not contain service", comment: "")
        case .InvalidProductVersion:
            return NSLocalizedString("Service version was in an unexpected format", comment: "")
        case .CreateFolder:
            return NSLocalizedString("Unable to create DDI folder", comment: "")
        case .DownloadImage:
            return NSLocalizedString("Unable to download DDI", comment: "")
        case .ImageLookup:
            return NSLocalizedString("Unable to lookup DDI images", comment: "")
        case .ImageRead:
            return NSLocalizedString("Unable to read images to memory", comment: "")
        case .Mount:
            return NSLocalizedString("Mount failed", comment: "")
        case .RestartAlreadyInProgressError:
            return NSLocalizedString("Restart already in progress", comment: "")
        case .InvalidVPN:
            return NSLocalizedString("Invalid VPN configuration", comment: "")
        case .InvalidPairing(let type):
            return NSLocalizedString("Invalid pairing configuration: \(type)", comment: "")
        case .MuxerNotListening:
            return NSLocalizedString("Usbmuxd server is not listening on the device", comment: "")
        }
    }

    fileprivate func createService(name: String) -> String {
        String(format: NSLocalizedString("Cannot start a %@ server on the device.", comment: ""), name)
    }

    fileprivate func getFromDevice(name: String) -> String {
        String(format: NSLocalizedString("Cannot fetch %@ from the device.", comment: ""), name)
    }

    fileprivate func setArgument(name: String) -> String {
        String(format: NSLocalizedString("Cannot set %@ on the device.", comment: ""), name)
    }
}

public enum MinimuxerWrapperError: Error, LocalizedError {
    case profileInstall
    case restartAlreadyInProgress
    case pairingFile
    
    public var errorDescription: String? {
        switch self {
        case .profileInstall:
            return NSLocalizedString("Unable to manage profiles on the device", comment: "")
        case .restartAlreadyInProgress:
            return NSLocalizedString("Restart already in progress", comment: "")
        case .pairingFile:
            return NSLocalizedString("Invalid pairing file. Your pairing file either didn't have a UDID, or it wasn't a valid plist. Please use iloader to replace it.", comment: "")
        }
    }

    public var failureReason: String? {
        return errorDescription
    }
}

extension Error {
    public var isMinimuxerNoConnection: Bool {
        if let gatewayErr = self as? IdeviceGatewayError {
            if case .noConnection = gatewayErr {
                return true
            }
        }
        return (self as? MinimuxerError) == .NoConnection
    }
    public var isMinimuxerNoVPN: Bool {
        return (self as? MinimuxerError) == .NoVPN
    }
    public var isMinimuxerProfileInstall: Bool {
        return (self as? MinimuxerError) == .ProfileInstall || (self as? MinimuxerWrapperError) == .profileInstall
    }
    public var isMinimuxerPairingFile: Bool {
        if let gatewayErr = self as? IdeviceGatewayError {
            if case .invalidPairingFile = gatewayErr {
                return true
            }
        }
        return (self as? MinimuxerError) == .PairingFile || (self as? MinimuxerWrapperError) == .pairingFile
    }
    public var isMinimuxerRestartInProgress: Bool {
        return (self as? MinimuxerError) == .RestartAlreadyInProgressError || (self as? MinimuxerWrapperError) == .restartAlreadyInProgress
    }
}

func minimuxerRestart() async throws {
    #if !targetEnvironment(simulator)
    try await Minimuxer.shared.restart()
    #endif
}

public struct MinimuxerPairedDevice: Codable, Sendable {
    public let name: String
    public let model: String
    public let udid: String
    public let pairingFilePath: String
    
    public init(name: String, model: String, udid: String, pairingFilePath: String) {
        self.name = name
        self.model = model
        self.udid = udid
        self.pairingFilePath = pairingFilePath
    }
}

@MainActor
public final class WirelessPairWrapper {
    public static let shared = WirelessPairWrapper()
    
    private init() {}
    
    public var onPinReceived: ((String) -> Void)? {
        get {
            #if !targetEnvironment(simulator)
            return Minimuxer.wirelessPair.onPinReceived
            #else
            return nil
            #endif
        }
        set {
            #if !targetEnvironment(simulator)
            Minimuxer.wirelessPair.onPinReceived = newValue
            #endif
        }
    }
    
    public var onReadyToPair: ((String, Int) -> Void)? {
        get {
            #if !targetEnvironment(simulator)
            return Minimuxer.wirelessPair.onReadyToPair
            #else
            return nil
            #endif
        }
        set {
            #if !targetEnvironment(simulator)
            Minimuxer.wirelessPair.onReadyToPair = newValue
            #endif
        }
    }
    
    public func start(
        outPath: String,
        completion: @escaping (Result<MinimuxerPairedDevice, Error>) -> Void
    ) {
        #if !targetEnvironment(simulator)
        Minimuxer.wirelessPair.start(outPath: outPath) { result in
            switch result {
            case .success(let device):
                completion(.success(MinimuxerPairedDevice(
                    name: device.name,
                    model: device.model,
                    udid: device.udid,
                    pairingFilePath: device.pairingFilePath
                )))
            case .failure(let error):
                completion(.failure(error))
            }
        }
        #else
        completion(.failure(MinimuxerWrapperError.pairingFile))
        #endif
    }
    
    public func stop() {
        #if !targetEnvironment(simulator)
        Minimuxer.wirelessPair.stop()
        #endif
    }
}

@MainActor
let wirelessPairing = WirelessPairWrapper.shared
