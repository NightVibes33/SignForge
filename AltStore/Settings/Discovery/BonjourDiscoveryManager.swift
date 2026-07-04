//
//  BonjourDiscoveryManager.swift
//  AltStore
//
//  Created by Magesh K on 4/7/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import Foundation

// MARK: - Data Models

/// Information about a discovered Bonjour service type
struct ServiceTypeInfo: Identifiable, Hashable {
    let id = UUID()
    let rawType: String        // e.g. "_airplay._tcp."
    let friendlyName: String?  // e.g. "AirPlay" (nil if unknown)
    
    var displayName: String {
        friendlyName ?? rawType
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(rawType)
    }
    
    static func == (lhs: ServiceTypeInfo, rhs: ServiceTypeInfo) -> Bool {
        lhs.rawType == rhs.rawType
    }
}

/// A discovered service instance (before resolution)
struct DiscoveredService: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let type: String
    let domain: String
    
    // The underlying NetService reference for resolution
    let netService: NetService
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(type)
        hasher.combine(domain)
    }
    
    static func == (lhs: DiscoveredService, rhs: DiscoveredService) -> Bool {
        lhs.name == rhs.name && lhs.type == rhs.type && lhs.domain == rhs.domain
    }
}

/// Fully resolved service details
struct ResolvedServiceInfo: Identifiable {
    let id = UUID()
    let name: String
    let type: String
    let domain: String
    let hostname: String
    let port: Int
    let addresses: [String]      // Formatted IP address strings
    let txtRecords: [(key: String, value: String)]
}


// MARK: - Known Service Types

/// Dictionary mapping raw Bonjour type strings to human-readable names
private let knownServiceTypes: [String: String] = [
    "_airplay._tcp.":       "Protocol for streaming of audio/video content",
    "_raop._tcp.":          "Remote Audio Output Protocol (AirTunes)",
    "_sftp-ssh._tcp.":      "Secure File Transfer Protocol over SSH",
    "_sleep-proxy._udp.":   "Sleep Proxy Server",
    "_ssh._tcp.":           "SSH Remote Login Protocol",
    "_http._tcp.":          "World Wide Web (HTTP)",
    "_https._tcp.":         "World Wide Web (HTTPS)",
    "_smb._tcp.":           "SMB File Sharing",
    "_afpovertcp._tcp.":    "Apple Filing Protocol (AFP)",
    "_printer._tcp.":       "Printer",
    "_ipp._tcp.":           "Internet Printing Protocol",
    "_scanner._tcp.":       "Scanner",
    "_ftp._tcp.":           "File Transfer Protocol",
    "_nfs._tcp.":           "Network File System",
    "_daap._tcp.":          "Digital Audio Access Protocol (iTunes)",
    "_dpap._tcp.":          "Digital Photo Access Protocol (iPhoto)",
    "_airport._tcp.":       "AirPort Base Station",
    "_homekit._tcp.":       "HomeKit Accessory",
    "_hap._tcp.":           "HomeKit Accessory Protocol",
    "_companion-link._tcp.": "Companion Link (Apple Watch)",
    "_apple-mobdev2._tcp.":  "Apple Mobile Device v2",
    "_remotepairing._tcp.":  "Remote Pairing",
    "_remotepairing-pairable-host._tcp.": "Remote Pairing (Pairable Host)",
    "_rdlink._tcp.":        "Remote Debug Link",
    "_net-assistant._udp.": "Apple Remote Desktop",
    "_rfb._tcp.":           "Remote Frame Buffer (VNC)",
    "_spotify-connect._tcp.": "Spotify Connect",
    "_googlecast._tcp.":    "Google Cast (Chromecast)",
    "_meshcop._udp.":       "Thread Mesh Commissioning",
    "_asquic._udp.":        "Apple QUIC Service",
    "_rp-tunnel._tcp.":     "Remote Pairing Tunnel",
    "_altserver._tcp.":     "AltServer",
    "_workstation._tcp.":   "Workstation",
    "_device-info._tcp.":   "Device Info",
    "_touch-able._tcp.":    "Remote App (Apple TV Remote)",
]


// MARK: - BonjourDiscoveryManager

/// Manages Bonjour/DNS-SD discovery of domains, service types, instances, and resolution
final class BonjourDiscoveryManager: NSObject, ObservableObject {
    
    // MARK: Published State
    
    @Published var domains: [String] = []
    @Published var serviceTypes: [ServiceTypeInfo] = []
    @Published var instances: [DiscoveredService] = []
    @Published var resolvedService: ResolvedServiceInfo? = nil
    @Published var isSearching = false
    @Published var resolveError: String? = nil
    
    // MARK: Private
    
    private var domainBrowser: NetServiceBrowser?
    private var typeBrowser: NetServiceBrowser?
    private var instanceBrowser: NetServiceBrowser?
    private var resolvingService: NetService?
    
    private var fallbackBrowsers: [NetServiceBrowser] = []
    private var fallbackTimer: Timer?
    
    private var discoveredDomains = Set<String>()
    private var discoveredTypes = Set<String>()
    private var discoveredInstances: [String: DiscoveredService] = [:]
    
    override init() {
        super.init()
    }
    
    deinit {
        stopAll()
    }
    
    // MARK: - Domain Discovery
    
    /// Discover browsable Bonjour domains (typically just "local.")
    func discoverDomains() {
        print("[BonjourDiscovery] Starting domain discovery...")
        stopDomainSearch()
        discoveredDomains.removeAll()
        domains.removeAll()
        isSearching = true
        
        let browser = NetServiceBrowser()
        browser.delegate = self
        browser.searchForBrowsableDomains()
        domainBrowser = browser
    }
    
    func stopDomainSearch() {
        print("[BonjourDiscovery] Stopping domain discovery.")
        domainBrowser?.stop()
        domainBrowser = nil
    }
    
    // MARK: - Service Type Discovery
    
    /// Discover all service types registered in a given domain
    func discoverServiceTypes(in domain: String) {
        let domainWithDot = domain.hasSuffix(".") ? domain : domain + "."
        print("[BonjourDiscovery] Starting service type discovery in domain '\(domainWithDot)'...")
        stopTypeSearch()
        discoveredTypes.removeAll()
        serviceTypes.removeAll()
        isSearching = true
        
        let browser = NetServiceBrowser()
        browser.delegate = self
        browser.searchForServices(ofType: "_services._dns-sd._udp.", inDomain: domainWithDot)
        typeBrowser = browser
        
        // Start fallback parallel searches after 1.5 seconds if we haven't found anything
        fallbackTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            print("[BonjourDiscovery] Fallback timer fired. Current service types count: \(self.serviceTypes.count)")
            if self.serviceTypes.isEmpty {
                print("[BonjourDiscovery] Falling back to searching declared service types in parallel...")
                self.startFallbackSearches(in: domainWithDot)
            }
        }
    }
    
    private func startFallbackSearches(in domain: String) {
        let typesToBrowse = [
            "_altserver._tcp.",
            "_remotepairing-pairable-host._tcp.",
            "_airplay._tcp.",
            "_raop._tcp.",
            "_sftp-ssh._tcp.",
            "_sleep-proxy._udp.",
            "_ssh._tcp.",
            "_apple-mobdev2._tcp.",
            "_asquic._udp.",
            "_companion-link._tcp.",
            "_meshcop._udp.",
            "_remotepairing._tcp.",
            "_rp-tunnel._tcp."
        ]
        
        for t in typesToBrowse {
            let browser = NetServiceBrowser()
            browser.delegate = self
            browser.searchForServices(ofType: t, inDomain: domain)
            fallbackBrowsers.append(browser)
            print("[BonjourDiscovery] Fallback: Started browsing for service type '\(t)' in domain '\(domain)'")
        }
    }
    
    func stopTypeSearch() {
        print("[BonjourDiscovery] Stopping service type discovery.")
        typeBrowser?.stop()
        typeBrowser = nil
        fallbackTimer?.invalidate()
        fallbackTimer = nil
        for b in fallbackBrowsers {
            b.stop()
        }
        fallbackBrowsers.removeAll()
    }
    
    // MARK: - Instance Discovery
    
    /// Discover all instances of a specific service type in a domain
    func discoverInstances(ofType type: String, inDomain domain: String) {
        let domainWithDot = domain.hasSuffix(".") ? domain : domain + "."
        let typeWithDot = type.hasSuffix(".") ? type : type + "."
        print("[BonjourDiscovery] Starting instance discovery for type '\(typeWithDot)' in domain '\(domainWithDot)'...")
        stopInstanceSearch()
        discoveredInstances.removeAll()
        instances.removeAll()
        isSearching = true
        
        let browser = NetServiceBrowser()
        browser.delegate = self
        browser.searchForServices(ofType: typeWithDot, inDomain: domainWithDot)
        instanceBrowser = browser
    }
    
    func stopInstanceSearch() {
        print("[BonjourDiscovery] Stopping instance discovery.")
        instanceBrowser?.stop()
        instanceBrowser = nil
    }
    
    // MARK: - Service Resolution
    
    /// Resolve a service to get its hostname, addresses, port, and TXT records
    func resolveService(_ service: DiscoveredService) {
        print("[BonjourDiscovery] Starting resolution for service '\(service.name)' (\(service.type))...")
        stopResolving()
        resolvedService = nil
        resolveError = nil
        isSearching = true
        
        let netService = service.netService
        netService.delegate = self
        netService.resolve(withTimeout: 10.0)
        resolvingService = netService
    }
    
    func stopResolving() {
        print("[BonjourDiscovery] Stopping service resolution.")
        resolvingService?.stop()
        resolvingService = nil
    }
    
    // MARK: - Stop All
    
    func stopAll() {
        print("[BonjourDiscovery] Stopping all discovery activities.")
        stopDomainSearch()
        stopTypeSearch()
        stopInstanceSearch()
        stopResolving()
        isSearching = false
    }
    
    // MARK: - Helpers
    
    /// Look up the friendly name for a raw service type string
    static func friendlyName(for rawType: String) -> String? {
        let normalized = rawType.hasSuffix(".") ? rawType : rawType + "."
        return knownServiceTypes[normalized]
    }
    
    /// Format socket address data into a readable string
    private static func formatAddress(_ data: Data) -> String? {
        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        
        let result = data.withUnsafeBytes { rawBufferPointer -> Int32 in
            guard let baseAddress = rawBufferPointer.baseAddress else { return -1 }
            let sockAddr = baseAddress.assumingMemoryBound(to: sockaddr.self)
            return getnameinfo(
                sockAddr,
                socklen_t(data.count),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )
        }
        
        guard result == 0 else { return nil }
        
        let addressString = String(cString: hostname)
        guard !addressString.isEmpty else { return nil }
        
        return addressString
    }
    
    /// Parse TXT record data into key-value pairs
    private static func parseTXTRecord(_ data: Data) -> [(key: String, value: String)] {
        let dict = NetService.dictionary(fromTXTRecord: data)
        return dict.map { key, value in
            let valueStr = String(data: value, encoding: .utf8) ?? value.map { String(format: "%02x", $0) }.joined()
            return (key: key, value: valueStr)
        }.sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
    }
}


// MARK: - NetServiceBrowserDelegate

extension BonjourDiscoveryManager: NetServiceBrowserDelegate {
    
    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        print("[BonjourDiscovery] netServiceBrowserWillSearch: Browser search started successfully.")
    }
    
    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        print("[BonjourDiscovery] netServiceBrowserDidStopSearch: Browser search stopped.")
        DispatchQueue.main.async { [weak self] in
            self?.isSearching = false
        }
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        print("[BonjourDiscovery] netServiceBrowser didNotSearch: Error dictionary: \(errorDict)")
        DispatchQueue.main.async { [weak self] in
            self?.isSearching = false
        }
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didFindDomain domainString: String, moreComing: Bool) {
        print("[BonjourDiscovery] didFindDomain: Found domain '\(domainString)' (moreComing: \(moreComing))")
        let trimmed = domainString.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard !trimmed.isEmpty else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.discoveredDomains.insert(trimmed).inserted {
                self.domains.append(trimmed)
                self.domains.sort()
            }
            if !moreComing {
                self.isSearching = false
            }
        }
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didRemoveDomain domainString: String, moreComing: Bool) {
        print("[BonjourDiscovery] didRemoveDomain: Removed domain '\(domainString)' (moreComing: \(moreComing))")
        let trimmed = domainString.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.discoveredDomains.remove(trimmed)
            self.domains.removeAll { $0 == trimmed }
        }
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        let isTypeSearch = (browser === self.typeBrowser)
        print("[BonjourDiscovery] didFind: Found service name='\(service.name)', type='\(service.type)', domain='\(service.domain)' (isTypeSearch: \(isTypeSearch), moreComing: \(moreComing))")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if isTypeSearch {
                let fullType = "\(service.name).\(service.type)"
                    .replacingOccurrences(of: "..", with: ".")
                
                print("[BonjourDiscovery] Found service type reconstructed: '\(fullType)'")
                if self.discoveredTypes.insert(fullType).inserted {
                    let info = ServiceTypeInfo(
                        rawType: fullType,
                        friendlyName: BonjourDiscoveryManager.friendlyName(for: fullType)
                    )
                    self.serviceTypes.append(info)
                    self.serviceTypes.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
                }
            } else if browser === self.instanceBrowser {
                let key = "\(service.name)|\(service.type)|\(service.domain)"
                print("[BonjourDiscovery] Found instance key: '\(key)'")
                if self.discoveredInstances[key] == nil {
                    let discovered = DiscoveredService(
                        name: service.name,
                        type: service.type,
                        domain: service.domain,
                        netService: service
                    )
                    self.discoveredInstances[key] = discovered
                    self.instances.append(discovered)
                }
            }
            
            if !moreComing {
                self.isSearching = false
            }
        }
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if browser === self.typeBrowser {
                let fullType = "\(service.name).\(service.type)"
                    .replacingOccurrences(of: "..", with: ".")
                self.discoveredTypes.remove(fullType)
                self.serviceTypes.removeAll { $0.rawType == fullType }
            } else if browser === self.instanceBrowser {
                let key = "\(service.name)|\(service.type)|\(service.domain)"
                self.discoveredInstances.removeValue(forKey: key)
                self.instances.removeAll { $0.name == service.name && $0.type == service.type }
            }
        }
    }
}


// MARK: - NetServiceDelegate (for resolution)

extension BonjourDiscoveryManager: NetServiceDelegate {
    
    func netServiceDidResolveAddress(_ sender: NetService) {
        print("[BonjourDiscovery] netServiceDidResolveAddress: Successfully resolved '\(sender.name)' to host: \(sender.hostName ?? "nil"), port: \(sender.port)")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            var addresses: [String] = []
            if let addressData = sender.addresses {
                for data in addressData {
                    if let addr = BonjourDiscoveryManager.formatAddress(data) {
                        addresses.append(addr)
                    }
                }
            }
            print("[BonjourDiscovery] Resolved addresses: \(addresses)")
            
            var txtRecords: [(key: String, value: String)] = []
            if let txtData = sender.txtRecordData() {
                txtRecords = BonjourDiscoveryManager.parseTXTRecord(txtData)
            }
            print("[BonjourDiscovery] Resolved TXT record count: \(txtRecords.count)")
            
            let resolved = ResolvedServiceInfo(
                name: sender.name,
                type: sender.type,
                domain: sender.domain,
                hostname: sender.hostName ?? "Unknown",
                port: sender.port,
                addresses: addresses,
                txtRecords: txtRecords
            )
            
            self.resolvedService = resolved
            self.isSearching = false
        }
    }
    
    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        print("[BonjourDiscovery] netService didNotResolve: Resolution failed for '\(sender.name)'. Errors: \(errorDict)")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let errorCode = errorDict[NetService.errorCode] ?? -1
            self.resolveError = "Failed to resolve service (error \(errorCode))"
            self.isSearching = false
        }
    }
}
