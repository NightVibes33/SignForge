//
//  MinimuxerWrapper.swift
//
//  Created by Magesh K on 22/02/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import Foundation
import Minimuxer

let useIdevice: Bool = {
    if #available(iOS 17.0, *) {
        return true
    }
    return false
}()

func bindTunnelConfig() {
    defer { print("[SideStore] bindTunnelConfig() completed") }

    #if targetEnvironment(simulator)
    print("[SideStore] bindTunnelConfig() is no-op on simulator")
    #else
    print("[SideStore] bindTunnelConfig() invoked")

    Task { @MainActor in
        let config = TunnelConfig.shared
        if useIdevice {
            // Set the device IP on the gateway
            if let ip = config.deviceIP {
                IdeviceGateway.shared.setDeviceIP(ip)
            }
        } else {
            Minimuxer.shared.bindTunnelConfig(
                TunnelConfigBinding(
                    setDeviceIP: { value in Task { @MainActor in config.deviceIP = value } },
                    setFakeIP: { value in Task { @MainActor in config.fakeIP = value } },
                    setSubnetMask: { value in Task { @MainActor in config.subnetMask = value } },
                    getOverrideFakeIP: { config.overrideFakeIP },
                    setOverrideEffective: { value in Task { @MainActor in config.overrideEffective = value } }
                )
            )
        }
    }
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
    return .ready
    #else
    if useIdevice {
        // Direct gateway approach doesn't require a persistent listener status.
        // If setup successfully, we are ready to communicate.
        return .ready
    } else {
        if AppManager.needsMuxerServicesRestart && (AppManager.muxerRestartError as? MinimuxerError) == .PairingFile {
            return .invalidPairingFile
        }
        
        let result = Minimuxer.shared.ready()
        switch result {
        case .success(let isReady):
            print("[SideStore] minimuxerStatus = \(isReady)")
            return isReady ? .ready : .noConnection
        case .failure(let error):
            print("[SideStore] minimuxerStatus = false, error: \(error)")
            if error == .NoConnection {
                return .noConnection
            } else if error == .NoVPN {
                return .noVPN
            } else {
                return .invalidPairingFile
            }
        }
    }
    #endif
}


func retargetUsbmuxdAddr() {
    defer { print("[SideStore] retargetUsbmuxdAddr() completed") }
    #if targetEnvironment(simulator)
    print("[SideStore] retargetUsbmuxdAddr() is no-op on simulator")
    #else
    print("[SideStore] retargetUsbmuxdAddr() invoked")
    if !useIdevice {
        Minimuxer.shared.retargetUsbmuxdAddr()
    }
    #endif
}

func markMuxerServicesNeedsRestart(error: Error) {
    AppManager.markMuxerServicesNeedsRestart(error: error)
}

func reinitializePairingData(_ pairingFile: String) throws {
    defer { print("[SideStore] reinitializePairingData(pairingFile) completed") }
    #if targetEnvironment(simulator)
    print("[SideStore] reinitializePairingData(pairingFile) is no-op on simulator")
    #else
    print("[SideStore] reinitializePairingData(pairingFile) invoked")
    if useIdevice {
        try IdeviceGateway.shared.start(pairingFileContent: pairingFile)
    } else {
        try Minimuxer.shared.reinitializePairingData(pairingFile: pairingFile)
    }
    #endif
}

func startNetworkMonitoring() {
    #if !targetEnvironment(simulator)
    if useIdevice {
        // Direct connection monitors connection internally or via URLSession
    } else {
        bindTunnelConfig()
        Minimuxer.network.start()
    }
    #endif
}

func minimuxerStart(_ pairingFile: String) throws {
    defer { print("[SideStore] minimuxerStart(pairingFile) completed") }
    #if targetEnvironment(simulator)
    print("[SideStore] minimuxerStart(pairingFile) is no-op on simulator")
    #else
    if useIdevice {
        bindTunnelConfig()
        print("[SideStore] minimuxerStart(pairingFile) invoked")
        try IdeviceGateway.shared.start(pairingFileContent: pairingFile)
    } else {
        // refresh config if any
        bindTunnelConfig()
        
        // observe background errors
        Minimuxer.shared.onBackgroundError = { error in
            guard let bgError = error as? MinimuxerServiceError else { return }
            if bgError.component == .mounter {
                print("[SideStore] Minimuxer background error (\(bgError.component)): \(bgError.error), scheduling restart/pairing prompt...")
                markMuxerServicesNeedsRestart(error: bgError.error)
            }
        }
        
        // observe network route changes (and update device endpoint from vpn(utun))
        Minimuxer.network.start()
        
        print("[SideStore] minimuxerStart(pairingFile) invoked")
        try Minimuxer.shared.start(pairingFile: pairingFile)
    }
    #endif
}

func installProvisioningProfiles(_ profileData: Data) throws {
    defer { print("[SideStore] installProvisioningProfiles(profileData) completed") }
    #if targetEnvironment(simulator)
    print("[SideStore] installProvisioningProfiles(profileData) is no-op on simulator")
    #else
    print("[SideStore] installProvisioningProfiles(profileData) invoked")
    if useIdevice {
        try IdeviceGateway.shared.installProvisioningProfile(profile: profileData)
    } else {
        try Minimuxer.shared.installProvisioningProfile(profile: profileData)
    }
    #endif
}

func removeProvisioningProfile(_ id: String) throws {
    defer { print("[SideStore] removeProvisioningProfile(id) completed") }
    #if targetEnvironment(simulator)
    print("[SideStore] removeProvisioningProfile(id) is no-op on simulator")
    #else
    print("[SideStore] removeProvisioningProfile(id) invoked")
    if useIdevice {
        try IdeviceGateway.shared.removeProvisioningProfile(id: id)
    } else {
        try Minimuxer.shared.removeProvisioningProfile(id: id)
    }
    #endif
}

func removeApp(_ bundleId: String) throws {
    defer { print("[SideStore] removeApp(bundleId) completed") }
    #if targetEnvironment(simulator)
    print("[SideStore] removeApp(bundleId) is no-op on simulator")
    #else
    print("[SideStore] removeApp(bundleId) invoked")
    if useIdevice {
        try IdeviceGateway.shared.removeApp(bundleId: bundleId)
    } else {
        try Minimuxer.shared.removeApp(bundleId: bundleId)
    }
    #endif
}

func yeetAppAFC(_ bundleId: String, _ rawBytes: Data) throws {
    defer { print("[SideStore] yeetAppAFC(bundleId, rawBytes) completed") }
    #if targetEnvironment(simulator)
    print("[SideStore] yeetAppAFC(bundleId, rawBytes) is no-op on simulator")
    #else
    print("[SideStore] yeetAppAFC(bundleId, rawBytes) invoked")
    if useIdevice {
        try IdeviceGateway.shared.yeetAppAfc(bundleId: bundleId, ipaBytes: rawBytes)
    } else {
        try Minimuxer.shared.yeetAppAfc(bundleId: bundleId, ipaBytes: rawBytes)
    }
    #endif
}

func installIPA(_ bundleId: String) throws {
    defer { print("[SideStore] installIPA(bundleId) completed") }
    #if targetEnvironment(simulator)
    print("[SideStore] installIPA(bundleId) is no-op on simulator")
    #else
    print("[SideStore] installIPA(bundleId) invoked")
    if useIdevice {
        try IdeviceGateway.shared.installIpa(bundleId: bundleId)
    } else {
        try Minimuxer.shared.installIpa(bundleId: bundleId)
    }
    #endif
}

func fetchUDID() -> String? {
    defer { print("[SideStore] fetchUDID() completed") }
    #if targetEnvironment(simulator)
    print("[SideStore] fetchUDID() is no-op on simulator")
    return "XXXXX-XXXX-XXXXX-XXXX"
    #else
    print("[SideStore] fetchUDID() invoked")
    if useIdevice {
        return IdeviceGateway.shared.fetchUDID()
    } else {
        return Minimuxer.shared.fetchUDID()
    }
    #endif
}

func debugApp(_ appId: String) throws {
    defer { print("[SideStore] debugApp(appId) completed") }
    #if targetEnvironment(simulator)
    print("[SideStore] debugApp(appId) is no-op on simulator")
    #else
    print("[SideStore] debugApp(appId) invoked")
    if useIdevice {
        try IdeviceGateway.shared.debugApp(appId: appId)
    } else {
        try Minimuxer.shared.debugApp(appId: appId)
    }
    #endif
}

func attachDebugger(_ pid: UInt32) throws {
    defer { print("[SideStore] attachDebugger(pid) completed") }
    #if targetEnvironment(simulator)
    print("[SideStore] attachDebugger(pid) is no-op on simulator")
    #else
    print("[SideStore] attachDebugger(pid) invoked")
    if useIdevice {
        try IdeviceGateway.shared.debugProcess(pid: pid)
    } else {
        try Minimuxer.shared.attachDebugger(pid: pid)
    }
    #endif
}

func startAutoMounter(_ docsPath: String) {
    defer { print("[SideStore] startAutoMounter(docsPath) completed") }
    #if targetEnvironment(simulator)
    print("[SideStore] startAutoMounter(docsPath) is no-op on simulator")
    #else
    print("[SideStore] startAutoMounter(docsPath) invoked")
    if useIdevice {
        // Mounter can be run explicitly if needed
    } else {
        Task {
            await Minimuxer.shared.startAutoMounter(docsPath: docsPath)
        }
    }
    #endif
}

func dumpProfiles(_ docsPath: String) throws -> String {
    defer { print("[SideStore] dumpProfiles(docsPath) completed") }
    #if targetEnvironment(simulator)
    print("[SideStore] dumpProfiles(docsPath) is no-op on simulator")
    return ""
    #else
    print("[SideStore] dumpProfiles(docsPath) invoked")
    if useIdevice {
        return try IdeviceGateway.shared.dumpProfiles(docsPath: docsPath)
    } else {
        return try Minimuxer.shared.dumpProfiles(docsPath: docsPath)
    }
    #endif
}

func minimuxerSetLogging(_ enabled: Bool) {
    defer { print("[SideStore] minimuxerSetLogging(enabled) completed") }
    print("[SideStore] minimuxerSetLogging(enabled) invoked")
    #if !targetEnvironment(simulator)
    if useIdevice {
        IdeviceGateway.shared.setLogging(enabled)
    } else {
        Minimuxer.shared.setLogging(enabled)
    }
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
        case .InvalidPairing:
            return NSLocalizedString("Invalid pairing configuration", comment: "")
//        case .bridgeError(let err):
//            return err.localizedDescription
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
}

extension Error {
    public var isMinimuxerNoConnection: Bool {
        return (self as? MinimuxerError) == .NoConnection
    }
    public var isMinimuxerNoVPN: Bool {
        return (self as? MinimuxerError) == .NoVPN
    }
    public var isMinimuxerProfileInstall: Bool {
        return (self as? MinimuxerError) == .ProfileInstall || (self as? MinimuxerWrapperError) == .profileInstall
    }
    public var isMinimuxerPairingFile: Bool {
        return (self as? MinimuxerError) == .PairingFile || (self as? MinimuxerWrapperError) == .pairingFile
    }
    public var isMinimuxerRestartInProgress: Bool {
        return (self as? MinimuxerError) == .RestartAlreadyInProgressError || (self as? MinimuxerWrapperError) == .restartAlreadyInProgress
    }
}

func minimuxerRestart() async throws {
    #if !targetEnvironment(simulator)
    if useIdevice {
        return
    } else {
        try await Minimuxer.shared.restart()
    }
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

