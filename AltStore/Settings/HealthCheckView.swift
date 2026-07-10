//
//  HealthCheckView.swift
//  AltStore
//
//  Created by Magesh K on 11/07/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import Minimuxer
import Darwin

struct LocalInterfaceInfo: Hashable, Identifiable {
    var id: String { name + "-" + ip }
    let name: String
    let ip: String
    let subnet: String
    let type: String
}

@MainActor
final class HealthCheckViewModel: ObservableObject {
    @Published var isWifiSatisfied = false
    @Published var isWiredSatisfied = false
    @Published var isBridgeSatisfied = false
    @Published var isUTunAvailable = false
    @Published var isIKEv2IPSecAvailable = false
    
    @Published var deviceIP: String? = nil
    @Published var subnetMask: String? = nil
    @Published var fakeIP: String? = nil
    @Published var overrideFakeIP: String = ""
    @Published var overrideEffective = false
    
    @Published var activeProtocol = ""
    @Published var isPingSuccessful = false
    
    @Published var isDDIMounted = false
    @Published var isPairingFileVerified = false
    
    @Published var minimuxerReadyResult: Result<Bool, MinimuxerError>? = nil
    @Published var availableInterfaces: [LocalInterfaceInfo] = []
    @Published var isPolling = false
    
    private var pollingTask: Task<Void, Never>? = nil
    
    func startPolling() {
        guard !isPolling else { return }
        isPolling = true
        
        pollingTask = Task {
            while !Task.isCancelled {
                let wifi = Minimuxer.network.isWifiSatisfied
                let wired = Minimuxer.network.isWiredSatisfied
                let bridge = Minimuxer.network.isBridgeSatisfied
                let utun = Minimuxer.network.isUTunAvailable
                let ipsec = Minimuxer.network.isIKEv2IPSecAvailable
                
                let devIP = TunnelConfig.shared.deviceIP
                let subMask = TunnelConfig.shared.subnetMask
                let fkIP = TunnelConfig.shared.fakeIP
                let ovFakeIP = TunnelConfig.shared.overrideFakeIP
                let ovEffective = TunnelConfig.shared.overrideEffective
                
                let isRp = Minimuxer.shared.isrppairing
                let protocolStr = isRp ? "Remote Pairing (iOS 17+)" : "Lockdown (pre-iOS 17)"
                
                let pingSuccess = Minimuxer.shared.testDeviceConnection(ifaddr: devIP)
                
                let ddi = (try? await Minimuxer.shared.isDDIMounted()) ?? false
                let pairingVerified = (try? await Minimuxer.shared.fetchUDID() != nil) ?? false
                let readyResult = await Minimuxer.shared.isReady
                
                let scanned = scanLocalInterfaces()
                
                await MainActor.run {
                    self.isWifiSatisfied = wifi
                    self.isWiredSatisfied = wired
                    self.isBridgeSatisfied = bridge
                    self.isUTunAvailable = utun
                    self.isIKEv2IPSecAvailable = ipsec
                    
                    self.deviceIP = devIP
                    self.subnetMask = subMask
                    self.fakeIP = fkIP
                    self.overrideFakeIP = ovFakeIP
                    self.overrideEffective = ovEffective
                    
                    self.activeProtocol = protocolStr
                    self.isPingSuccessful = pingSuccess
                    
                    self.isDDIMounted = ddi
                    self.isPairingFileVerified = pairingVerified
                    
                    self.minimuxerReadyResult = readyResult
                    self.availableInterfaces = scanned
                }
                
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }
    
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        isPolling = false
    }
    
    private func scanLocalInterfaces() -> [LocalInterfaceInfo] {
        var interfaces = [LocalInterfaceInfo]()
        var head: UnsafeMutablePointer<ifaddrs>? = nil
        guard getifaddrs(&head) == 0, let first = head else { return [] }
        defer { freeifaddrs(head) }
        
        var cur: UnsafeMutablePointer<ifaddrs>? = first
        while let p = cur {
            let e = p.pointee
            let flags = Int32(e.ifa_flags)
            
            let ipv4 = e.ifa_addr?.pointee.sa_family == UInt8(AF_INET)
            let active = (flags & (IFF_UP | IFF_RUNNING | IFF_LOOPBACK)) == (IFF_UP | IFF_RUNNING)
            
            if ipv4 && active {
                if let name = String(utf8String: e.ifa_name),
                   let addr = e.ifa_addr,
                   let mask = e.ifa_netmask {
                    
                    var hostBuf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    var maskBuf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    
                    if getnameinfo(addr, socklen_t(addr.pointee.sa_len), &hostBuf, socklen_t(hostBuf.count), nil, 0, NI_NUMERICHOST) == 0,
                       getnameinfo(mask, socklen_t(mask.pointee.sa_len), &maskBuf, socklen_t(maskBuf.count), nil, 0, NI_NUMERICHOST) == 0 {
                        
                        let ipStr = String(cString: hostBuf)
                        let maskStr = String(cString: maskBuf)
                        
                        let type: String
                        if name.hasPrefix("utun") {
                            type = "VPN (uTun)"
                        } else if name.hasPrefix("ipsec") {
                            type = "VPN (IPSec)"
                        } else if name.hasPrefix("en") {
                            type = "Wi-Fi / Ethernet"
                        } else if name.hasPrefix("lo") {
                            type = "Loopback"
                        } else if name.hasPrefix("bridge") || name.hasPrefix("ap") {
                            type = "Bridge"
                        } else {
                            type = "Other"
                        }
                        
                        interfaces.append(LocalInterfaceInfo(name: name, ip: ipStr, subnet: maskStr, type: type))
                    }
                }
            }
            cur = e.ifa_next
        }
        
        return interfaces.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
}

struct HealthCheckView: View {
    @StateObject private var viewModel = HealthCheckViewModel()
    
    var body: some View {
        List {
            // Section 1: Overall Health Status Card
            Section {
                VStack(spacing: 12) {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            if case .success = viewModel.minimuxerReadyResult {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.green)
                                Text("System Healthy")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("SideStore is fully configured and ready.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            } else if case .failure(let error) = viewModel.minimuxerReadyResult {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.orange)
                                Text("Action Required")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text(Minimuxer.shared.describeError(error))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            } else {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(1.5)
                                    .padding(.vertical, 10)
                                Text("Checking status...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 12)
                }
            }
            
            // Section 2: Core Dependencies
            Section(header: Text("Core Requirements")) {
                DependencyRow(
                    title: "Network Connectivity",
                    subtitle: viewModel.isWifiSatisfied ? "Wi-Fi Active" : (viewModel.isWiredSatisfied ? "Ethernet Active" : (viewModel.isBridgeSatisfied ? "Bridge Active" : "No Connection")),
                    isSatisfied: viewModel.isWifiSatisfied || viewModel.isWiredSatisfied || viewModel.isBridgeSatisfied
                )
                
                DependencyRow(
                    title: "VPN Tunnel (utun)",
                    subtitle: viewModel.isUTunAvailable ? "Connected" : "Disconnected",
                    isSatisfied: viewModel.isUTunAvailable
                )
                
                if !Minimuxer.shared.isrppairing {
                    DependencyRow(
                        title: "IPSec/IKEv2 Tunnel",
                        subtitle: viewModel.isIKEv2IPSecAvailable ? "Connected" : "Disconnected (Required for 26.4+)",
                        isSatisfied: viewModel.isIKEv2IPSecAvailable
                    )
                }
                
                DependencyRow(
                    title: "Device Reachability (Ping)",
                    subtitle: viewModel.isPingSuccessful ? "Reachable" : "Unreachable",
                    isSatisfied: viewModel.isPingSuccessful
                )
                
                DependencyRow(
                    title: "Pairing file",
                    subtitle: viewModel.isPairingFileVerified ? "Verified" : "Unverified / Missing",
                    isSatisfied: viewModel.isPairingFileVerified
                )
                
                DependencyRow(
                    title: "Developer Disk Image (DDI)",
                    subtitle: viewModel.isDDIMounted ? "Mounted" : "Not Mounted",
                    isSatisfied: viewModel.isDDIMounted
                )
            }
            
            // Section 3: Discovered Configs
            Section(header: Text("Device IP Configuration")) {
                ConfigRow(label: "Assigned Device IP", value: viewModel.deviceIP)
                ConfigRow(label: "Subnet Mask", value: viewModel.subnetMask)
                ConfigRow(label: "Fake IP", value: viewModel.fakeIP)
                ConfigRow(label: "Override IP", value: viewModel.overrideFakeIP.isEmpty ? nil : viewModel.overrideFakeIP)
                HStack {
                    Text("Override Status")
                    Spacer()
                    Text(viewModel.overrideEffective ? "Active" : "Inactive")
                        .foregroundColor(viewModel.overrideEffective ? .green : .secondary)
                }
                HStack {
                    Text("Active Protocol")
                    Spacer()
                    Text(viewModel.activeProtocol)
                        .foregroundColor(.secondary)
                }
            }
            
            // Section 4: All Active Interfaces
            Section(header: Text("Active Network Interfaces")) {
                if viewModel.availableInterfaces.isEmpty {
                    Text("No active interfaces scanned.")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    let vpnInterfaces = viewModel.availableInterfaces.filter { $0.type.contains("VPN") }
                    let localInterfaces = viewModel.availableInterfaces.filter { !$0.type.contains("VPN") }
                    
                    if !vpnInterfaces.isEmpty {
                        ForEach(vpnInterfaces) { iface in
                            InterfaceRow(iface: iface)
                        }
                    }
                    
                    if !localInterfaces.isEmpty {
                        ForEach(localInterfaces) { iface in
                            InterfaceRow(iface: iface)
                        }
                    }
                }
            }
        }
        .navigationTitle("Health Check")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.startPolling()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
    }
}

struct DependencyRow: View {
    let title: String
    let subtitle: String
    let isSatisfied: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: isSatisfied ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isSatisfied ? .green : .red)
                .font(.title3)
        }
    }
}

struct ConfigRow: View {
    let label: String
    let value: String?
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value ?? "None")
                .foregroundColor(.secondary)
        }
    }
}

struct InterfaceRow: View {
    let iface: LocalInterfaceInfo
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(iface.name)
                        .fontWeight(.semibold)
                    Text(iface.type)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(iface.type.contains("VPN") ? Color.blue.opacity(0.15) : Color.gray.opacity(0.15))
                        .foregroundColor(iface.type.contains("VPN") ? .blue : .primary)
                        .cornerRadius(4)
                }
                Text("Subnet: \(iface.subnet)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(iface.ip)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }
}
