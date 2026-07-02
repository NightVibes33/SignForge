//
//  InfoPlistContainerView.swift
//  AltStore
//
//  Created by Magesh K on 2026-07-02.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import AltSign

// MARK: - Tree Node Model
struct PlistNode: Identifiable {
    let id = UUID()
    let key: String
    let value: String?
    let typeInfo: String
    let children: [PlistNode]?
    
    static func parse(key: String, value: Any) -> PlistNode {
        if let dict = value as? [String: Any] {
            let sortedChildren = dict.keys.sorted().map { parse(key: $0, value: dict[$0]!) }
            return PlistNode(key: key, value: nil, typeInfo: "Dictionary (\(dict.count) keys)", children: sortedChildren)
        } else if let array = value as? [Any] {
            let children = array.enumerated().map { parse(key: "Index \($0)", value: $1) }
            return PlistNode(key: key, value: nil, typeInfo: "Array (\(array.count) items)", children: children)
        } else {
            let typeStr: String
            if value is Bool {
                typeStr = "Boolean"
            } else if value is NSNumber {
                typeStr = "Number"
            } else {
                typeStr = "String"
            }
            return PlistNode(key: key, value: "\(value)", typeInfo: typeStr, children: nil)
        }
    }
}

// MARK: - InfoPlist Mode Enum
enum InfoPlistMode: String, CaseIterable, Identifiable {
    case tree = "Tree"
    case rawXML = "Raw XML"
    case rawJSON = "Raw JSON"
    case semantic = "Semantic"
    
    var id: String { self.rawValue }
}

// MARK: - Container View
struct InfoPlistContainerView: View {
    let plist: [String: Any]
    
    @State private var selectedMode: InfoPlistMode = .tree
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("Visualization Mode", selection: $selectedMode) {
                ForEach(InfoPlistMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            .background(Color(.systemGroupedBackground))
            
            Divider()
            
            Group {
                switch selectedMode {
                case .tree:
                    InfoPlistTreeView(plist: plist)
                case .rawXML:
                    InfoPlistRawXMLView(plist: plist)
                case .rawJSON:
                    InfoPlistRawView(plist: plist)
                case .semantic:
                    InfoPlistSemanticView(plist: plist)
                }
            }
        }
        .navigationTitle("Info.plist")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Mode 1: Tree View
struct InfoPlistTreeView: View {
    let plist: [String: Any]
    
    @State private var searchQuery = ""
    
    var rootNodes: [PlistNode] {
        let nodes = plist.keys.sorted().map { PlistNode.parse(key: $0, value: plist[$0]!) }
        if searchQuery.isEmpty {
            return nodes
        }
        return filterNodes(nodes, query: searchQuery)
    }
    
    var body: some View {
        List {
            ForEach(rootNodes) { node in
                PlistNodeRow(node: node)
            }
        }
        .listStyle(InsetGroupedListStyle())
        .searchable(text: $searchQuery, prompt: "Search keys")
    }
    
    private func filterNodes(_ nodes: [PlistNode], query: String) -> [PlistNode] {
        return nodes.compactMap { node in
            if node.key.localizedCaseInsensitiveContains(query) {
                return node
            }
            if let children = node.children {
                let filteredChildren = filterNodes(children, query: query)
                if !filteredChildren.isEmpty {
                    return PlistNode(key: node.key, value: node.value, typeInfo: node.typeInfo, children: filteredChildren)
                }
            }
            return nil
        }
    }
}

struct PlistNodeRow: View {
    let node: PlistNode
    
    @State private var isCopied = false
    
    var body: some View {
        if let children = node.children {
            DisclosureGroup {
                ForEach(children) { child in
                    PlistNodeRow(node: child)
                }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(node.key)
                        .font(.footnote)
                        .foregroundColor(.primary)
                        .bold()
                    Text(node.typeInfo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .contextMenu {
                    SwiftUI.Button {
                        UIPasteboard.general.string = node.key
                    } label: {
                        Label("Copy Key", systemImage: "doc.on.doc")
                    }
                }
            }
        } else {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(node.key)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .bold()
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(node.value ?? "N/A")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer()
                
                SwiftUI.Button {
                    let textToCopy = node.value ?? ""
                    UIPasteboard.general.string = textToCopy
                    withAnimation {
                        isCopied = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation {
                            isCopied = false
                        }
                    }
                } label: {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.footnote)
                        .foregroundColor(isCopied ? .green : .accentColor)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                let textToCopy = node.value ?? ""
                UIPasteboard.general.string = textToCopy
                withAnimation {
                    isCopied = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation {
                        isCopied = false
                    }
                }
            }
        }
    }
}

// MARK: - Mode 1.5: Raw XML View
struct InfoPlistRawXMLView: View {
    let plist: [String: Any]
    
    @State private var isCopied = false
    
    var xmlString: String {
        guard let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }
    
    var highlightedXML: AttributedString {
        let xml = xmlString
        let nsMutable = NSMutableAttributedString(string: xml)
        nsMutable.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular), range: NSRange(location: 0, length: xml.count))
        nsMutable.addAttribute(.foregroundColor, value: UIColor.label, range: NSRange(location: 0, length: xml.count))
        
        // Highlight XML Tags: <tag> and </tag>
        if let tagRegex = try? NSRegularExpression(pattern: "</?[a-zA-Z0-9:-]+( [^>]+)*/?>", options: []) {
            let matches = tagRegex.matches(in: xml, options: [], range: NSRange(location: 0, length: xml.count))
            for match in matches {
                nsMutable.addAttribute(.foregroundColor, value: UIColor.systemPurple, range: match.range)
            }
        }
        
        // Highlight <key> text
        if let keyRegex = try? NSRegularExpression(pattern: "<key>([^<]+)</key>", options: []) {
            let matches = keyRegex.matches(in: xml, options: [], range: NSRange(location: 0, length: xml.count))
            for match in matches {
                if match.numberOfRanges > 1 {
                    let textRange = match.range(at: 1)
                    nsMutable.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: textRange)
                }
            }
        }
        
        // Highlight <string> text
        if let stringRegex = try? NSRegularExpression(pattern: "<string>([^<]*)</string>", options: []) {
            let matches = stringRegex.matches(in: xml, options: [], range: NSRange(location: 0, length: xml.count))
            for match in matches {
                if match.numberOfRanges > 1 {
                    let textRange = match.range(at: 1)
                    nsMutable.addAttribute(.foregroundColor, value: UIColor.systemGreen, range: textRange)
                }
            }
        }
        
        return AttributedString(nsMutable)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Spacer()
                    SwiftUI.Button {
                        UIPasteboard.general.string = xmlString
                        withAnimation {
                            isCopied = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation {
                                isCopied = false
                            }
                        }
                    } label: {
                        Label(isCopied ? "Copied!" : "Copy XML", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.footnote)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isCopied ? .green : .accentColor)
                }
                .padding(.horizontal)
                .padding(.top)
                
                Text(highlightedXML)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                    .padding(.horizontal)
            }
        }
    }
}

// MARK: - Mode 2: Raw JSON View
struct InfoPlistRawView: View {
    let plist: [String: Any]
    
    @State private var isCopied = false
    
    var jsonString: String {
        guard let data = try? JSONSerialization.data(withJSONObject: plist, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
    
    var highlightedJSON: AttributedString {
        let json = jsonString
        let nsMutable = NSMutableAttributedString(string: json)
        nsMutable.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular), range: NSRange(location: 0, length: json.count))
        nsMutable.addAttribute(.foregroundColor, value: UIColor.label, range: NSRange(location: 0, length: json.count))
        
        // Highlight Keys
        if let keyRegex = try? NSRegularExpression(pattern: "\"([^\"]+)\"\\s*:", options: []) {
            let matches = keyRegex.matches(in: json, options: [], range: NSRange(location: 0, length: json.count))
            for match in matches {
                if match.numberOfRanges > 1 {
                    let keyRange = match.range(at: 1)
                    nsMutable.addAttribute(.foregroundColor, value: UIColor.systemPurple, range: keyRange)
                }
            }
        }
        
        // Highlight String Values
        if let valRegex = try? NSRegularExpression(pattern: ":\\s*\"([^\"]*)\"", options: []) {
            let matches = valRegex.matches(in: json, options: [], range: NSRange(location: 0, length: json.count))
            for match in matches {
                if match.numberOfRanges > 1 {
                    let valRange = match.range(at: 1)
                    nsMutable.addAttribute(.foregroundColor, value: UIColor.systemGreen, range: valRange)
                }
            }
        }
        
        // Highlight Booleans & Numbers
        if let numRegex = try? NSRegularExpression(pattern: "\\b(true|false|null|-?\\d+(\\.\\d+)?)\\b", options: []) {
            let matches = numRegex.matches(in: json, options: [], range: NSRange(location: 0, length: json.count))
            for match in matches {
                nsMutable.addAttribute(.foregroundColor, value: UIColor.systemOrange, range: match.range)
            }
        }
        
        return AttributedString(nsMutable)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Spacer()
                    SwiftUI.Button {
                        UIPasteboard.general.string = jsonString
                        withAnimation {
                            isCopied = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation {
                                isCopied = false
                            }
                        }
                    } label: {
                        Label(isCopied ? "Copied!" : "Copy JSON", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.footnote)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isCopied ? .green : .accentColor)
                }
                .padding(.horizontal)
                .padding(.top)
                
                Text(highlightedJSON)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                    .padding(.horizontal)
            }
        }
    }
}

// MARK: - Mode 3: Semantic View
struct InfoPlistSemanticView: View {
    let plist: [String: Any]
    
    @State private var searchQuery = ""
    
    // Core App Metadata
    var appName: String {
        return (plist["CFBundleDisplayName"] as? String) ?? (plist["CFBundleName"] as? String) ?? "N/A"
    }
    var bundleID: String {
        return (plist["CFBundleIdentifier"] as? String) ?? "N/A"
    }
    var version: String {
        let short = plist["CFBundleShortVersionString"] as? String
        let build = plist["CFBundleVersion"] as? String
        if let short = short, let build = build {
            return "\(short) (\(build))"
        }
        return short ?? build ?? "N/A"
    }
    var minOS: String {
        return (plist["MinimumOSVersion"] as? String) ?? "N/A"
    }
    
    // Categorized Groups
    var privacyPermissions: [String: String] {
        var dict = [String: String]()
        for key in plist.keys where key.hasPrefix("NS") && key.hasSuffix("UsageDescription") {
            if let val = plist[key] as? String {
                dict[key] = val
            }
        }
        return dict
    }
    
    var customURLSchemes: [String] {
        var schemes = [String]()
        if let urlTypes = plist["CFBundleURLTypes"] as? [[String: Any]] {
            for type in urlTypes {
                if let typeSchemes = type["CFBundleURLSchemes"] as? [String] {
                    schemes.append(contentsOf: typeSchemes)
                }
            }
        }
        return schemes
    }
    
    var backgroundModes: [String] {
        return (plist["UIBackgroundModes"] as? [String]) ?? []
    }
    
    var queriedSchemes: [String] {
        return (plist["LSApplicationQueriesSchemes"] as? [String]) ?? []
    }
    
    // Custom/Uncategorized keys
    var customKeys: [String: Any] {
        let categorized: Set<String> = [
            "CFBundleDisplayName", "CFBundleName", "CFBundleIdentifier",
            "CFBundleShortVersionString", "CFBundleVersion", "MinimumOSVersion",
            "CFBundleURLTypes", "UIBackgroundModes", "LSApplicationQueriesSchemes"
        ]
        
        var dict = [String: Any]()
        for key in plist.keys {
            if categorized.contains(key) { continue }
            if key.hasPrefix("NS") && key.hasSuffix("UsageDescription") { continue }
            dict[key] = plist[key]
        }
        return dict
    }
    
    var filteredCustomKeys: [String] {
        let keys = customKeys.keys.sorted()
        if searchQuery.isEmpty {
            return keys
        }
        return keys.filter { $0.localizedCaseInsensitiveContains(searchQuery) }
    }
    
    var body: some View {
        List {
            // General Info Card
            Section(header: Text("General Info")) {
                VStack(alignment: .leading, spacing: 8) {
                    SemanticValueRow(label: "App Name", value: appName)
                    SemanticValueRow(label: "Bundle Identifier", value: bundleID)
                    SemanticValueRow(label: "Version", value: version)
                    SemanticValueRow(label: "Minimum OS", value: minOS)
                }
                .padding(.vertical, 4)
            }
            
            // Privacy Permissions Card
            if !privacyPermissions.isEmpty {
                Section(header: Text("Privacy Permissions (\(privacyPermissions.count))")) {
                    ForEach(privacyPermissions.keys.sorted(), id: \.self) { key in
                        LocalCopyableDescriptionRow(key: key, value: privacyPermissions[key] ?? "")
                    }
                }
            }
            
            // Custom URL Schemes Card
            if !customURLSchemes.isEmpty {
                Section(header: Text("Custom URL Schemes")) {
                    ForEach(customURLSchemes, id: \.self) { scheme in
                        LocalCopyableValueOnlyRow(value: scheme)
                    }
                }
            }
            
            // Background Modes Card
            if !backgroundModes.isEmpty {
                Section(header: Text("Background Modes")) {
                    ForEach(backgroundModes, id: \.self) { mode in
                        HStack {
                            Image(systemName: getBackgroundModeIcon(mode))
                                .foregroundColor(.accentColor)
                                .frame(width: 24)
                            Text(mode)
                                .font(.footnote)
                            Spacer()
                        }
                    }
                }
            }
            
            // Queried URL Schemes Card
            if !queriedSchemes.isEmpty {
                Section(header: Text("Queries Schemes")) {
                    ForEach(queriedSchemes, id: \.self) { scheme in
                        HStack {
                            Text(scheme)
                                .font(.system(size: 11, design: .monospaced))
                            Spacer()
                        }
                    }
                }
            }
            
            // Other Custom/Advanced Keys
            Section(header: Text("Advanced / Custom Keys")) {
                SearchBarView(text: $searchQuery)
                    .listRowInsets(EdgeInsets())
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                
                ForEach(filteredCustomKeys, id: \.self) { key in
                    let val = customKeys[key] ?? ""
                    CopyableValueRow(key: key, value: val)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    private func getBackgroundModeIcon(_ mode: String) -> String {
        switch mode {
        case "audio": return "music.note"
        case "location": return "location.fill"
        case "voip": return "phone.fill"
        case "newsstand-content": return "newspaper"
        case "external-accessory": return "cable.connector"
        case "bluetooth-central": return "wave.3.left"
        case "bluetooth-peripheral": return "wave.3.right"
        case "fetch": return "arrow.down.to.line"
        case "remote-notification": return "bell.badge.fill"
        case "processing": return "cpu"
        default: return "ellipsis.bubble.fill"
        }
    }
}

// MARK: - Localized Semantic Value Row
struct SemanticValueRow: View {
    let label: String
    let value: String
    
    @State private var isCopied = false
    
    var body: some View {
        HStack {
            Text(label)
                .font(.footnote)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
            
            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                .font(.caption2)
                .foregroundColor(isCopied ? .green : .accentColor.opacity(0.7))
                .frame(width: 16, height: 16)
                .padding(.leading, 4)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            UIPasteboard.general.string = value
            withAnimation {
                isCopied = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    isCopied = false
                }
            }
        }
    }
}

// MARK: - Localized Description Row
struct LocalCopyableDescriptionRow: View {
    let key: String
    let value: String
    
    @State private var isCopied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(key)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .bold()
                Spacer()
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.caption)
                    .foregroundColor(isCopied ? .green : .accentColor)
            }
            Text(value)
                .font(.footnote)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            UIPasteboard.general.string = value
            withAnimation {
                isCopied = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    isCopied = false
                }
            }
        }
    }
}

// MARK: - Localized Value Only Row
struct LocalCopyableValueOnlyRow: View {
    let value: String
    
    @State private var isCopied = false
    
    var body: some View {
        HStack {
            Text(value)
                .font(.system(size: 11, design: .monospaced))
            Spacer()
            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                .font(.caption)
                .foregroundColor(isCopied ? .green : .accentColor)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            UIPasteboard.general.string = value
            withAnimation {
                isCopied = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    isCopied = false
                }
            }
        }
    }
}

// MARK: - Localized Copyable Value Row
struct CopyableValueRow: View {
    let key: String
    let value: Any
    
    @State private var isCopied = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(key)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .bold()
                
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(formatValue(value))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                }
            }
            Spacer()
            
            SwiftUI.Button {
                UIPasteboard.general.string = formatValue(value)
                withAnimation {
                    isCopied = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation {
                        isCopied = false
                    }
                }
            } label: {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.footnote)
                    .foregroundColor(isCopied ? .green : .accentColor)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            UIPasteboard.general.string = formatValue(value)
            withAnimation {
                isCopied = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    isCopied = false
                }
            }
        }
    }
    
    private func formatValue(_ val: Any) -> String {
        if JSONSerialization.isValidJSONObject(val) {
            if let data = try? JSONSerialization.data(withJSONObject: val, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) {
                return String(data: data, encoding: .utf8) ?? "\(val)"
            }
        }
        if let array = val as? [Any] {
            return "[" + array.map { formatValue($0) }.joined(separator: ", ") + "]"
        }
        if let dict = val as? [String: Any] {
            return "{" + dict.map { "\($0.key): \(formatValue($0.value))" }.sorted().joined(separator: ", ") + "}"
        }
        return "\(val)"
    }
}

// MARK: - Search Bar Helper View
struct SearchBarView: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search keys", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                
            if !text.isEmpty {
                SwiftUI.Button(action: {
                    self.text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}
