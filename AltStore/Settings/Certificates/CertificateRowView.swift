//
//  CertificateRowView.swift
//  AltStore
//
//  Created by Magesh K on 2026-07-03.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import AltSign

struct CertificateRowView: View {
    let cert: ALTCertificate
    @ObservedObject var viewModel: CertificatesViewModel
    
    var onRevoke:     () -> Void
    var onExportP12:  () -> Void
    var onClearKey:   () -> Void
    var onAddKeyBin:  () -> Void
    var onAddKeyText: () -> Void
    var onDelete:     () -> Void
    
    private var hasPrivateKey: Bool { cert.privateKey != nil }
    private var isActive:      Bool { cert.serialNumber == viewModel.activeSerialNumber }
    private var isRemote:      Bool { viewModel.remoteSerials.contains(cert.serialNumber) }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text((cert.machineName ?? cert.name) + (isRemote ? " (R)" : ""))
                    .font(.headline)
                
                let displaySerial = viewModel.displaySerial(for: cert, hasPrivateKey: hasPrivateKey)
                (
                    Text("Serial: ").font(.system(size: 11))
                    + Text(displaySerial).font(.system(size: 11, design: .monospaced))
                )
                .foregroundColor(.secondary)
                .onTapGesture { toggleReveal() }
                
                if let displayIdent = viewModel.displayIdentifier(for: cert, hasPrivateKey: hasPrivateKey) {
                    (
                        Text("ID: ").font(.system(size: 10))
                        + Text(displayIdent).font(.system(size: 10, design: .monospaced))
                    )
                    .foregroundColor(.gray)
                }
                
                if let brief = getBriefInfo(for: cert.data) {
                    CertBriefInfoView(brief: brief, cert: cert, viewModel: viewModel)
                }
                
                if let displayReq = viewModel.displayRequester(for: cert, hasPrivateKey: hasPrivateKey) {
                    let isHidden = displayReq.contains("•")
                    (
                        Text("Requester: ").font(.system(size: 10))
                        + Text(displayReq).font(isHidden ? .system(size: 10, design: .monospaced) : .system(size: 10))
                    )
                    .foregroundColor(.secondary)
                }
                
                (
                    Text("Keys: ").font(.system(size: 10))
                    + Text(hasPrivateKey ? "public + private" : "public").font(.system(size: 10))
                )
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            CertTrailingIcons(isActive: isActive, isRemote: isRemote, onRevoke: onRevoke)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu {
            SwiftUI.Button { toggleReveal() } label: {
                Label(viewModel.revealedSerials.contains(cert.serialNumber) ? "Hide Details" : "Reveal Details",
                      systemImage: viewModel.revealedSerials.contains(cert.serialNumber) ? "eye.slash" : "eye")
            }
            if hasPrivateKey && !isActive {
                SwiftUI.Button { viewModel.makeCertificateActive(cert) } label: {
                    Label("Activate", systemImage: "key.fill")
                }
            }
            SwiftUI.Button { UIPasteboard.general.string = cert.serialNumber } label: {
                Label("Copy S/N", systemImage: "doc.on.doc")
            }
            if hasPrivateKey {
                CertPrivateKeyMenuItems(cert: cert, viewModel: viewModel, onExportP12: onExportP12, onClearKey: onClearKey)
            } else {
                CertPublicKeyMenuItems(cert: cert, viewModel: viewModel, onAddKeyBin: onAddKeyBin, onAddKeyText: onAddKeyText, onExportP12: onExportP12)
            }
            if viewModel.isCertificateLocallyCached(cert) {
                SwiftUI.Button(role: .destructive) { onDelete() } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
    
    private func toggleReveal() {
        if viewModel.revealedSerials.contains(cert.serialNumber) { viewModel.revealedSerials.remove(cert.serialNumber) }
        else { viewModel.revealedSerials.insert(cert.serialNumber) }
    }
}

private struct CertBriefInfoView: View {
    let brief: CertificateBriefInfo
    let cert: ALTCertificate
    @ObservedObject var viewModel: CertificatesViewModel
    
    var body: some View {
        let displayType      = viewModel.displayBriefType(for: brief, cert: cert)
        let displayValidity  = viewModel.displayBriefValidity(for: brief, cert: cert)
        let isTypeHidden     = displayType.contains("•")
        let isValidityHidden = displayValidity.contains("•")
        Group {
            (
                Text("Type: ").font(.system(size: 10))
                + Text(displayType).font(isTypeHidden ? .system(size: 10, design: .monospaced) : .system(size: 10))
            )
            .foregroundColor(.secondary)
            (
                Text("Validity: ").font(.system(size: 10))
                + Text(displayValidity).font(isValidityHidden ? .system(size: 10, design: .monospaced) : .system(size: 10))
            )
            .foregroundColor(.secondary)
        }
    }
}

private struct CertTrailingIcons: View {
    let isActive: Bool
    let isRemote: Bool
    var onRevoke: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            if isActive {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.title3)
            } else if isRemote {
                SwiftUI.Button { onRevoke() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.red).font(.title3)
                }
                .buttonStyle(.plain)
            }
            Image(systemName: "chevron.right").foregroundColor(Color(.tertiaryLabel)).font(.footnote)
        }
    }
}

private struct CertPrivateKeyMenuItems: View {
    let cert: ALTCertificate
    @ObservedObject var viewModel: CertificatesViewModel
    var onExportP12: () -> Void
    var onClearKey:  () -> Void
    
    var body: some View {
        Group {
            SwiftUI.Button { onExportP12() } label: { Label("Export (.p12)", systemImage: "square.and.arrow.up") }
            SwiftUI.Button { CertificateExporter.sharePublicCertAsPEM(cert) { viewModel.errorMessage = $0 } } label: { Label("Export (.pem)", systemImage: "square.and.arrow.up") }
            SwiftUI.Button { CertificateExporter.sharePublicCertAsDER(cert) { viewModel.errorMessage = $0 } } label: { Label("Export (.der)", systemImage: "square.and.arrow.up") }
            SwiftUI.Button { CertificateExporter.copyPublicCertAsPEM(cert) { viewModel.errorMessage = $0 } } label: { Label("Copy (.pem)", systemImage: "doc.on.doc") }
            SwiftUI.Button { CertificateExporter.copyPrivateKey(cert) } label: { Label("Copy Private Key", systemImage: "doc.on.doc") }
            SwiftUI.Button { CertificateExporter.sharePrivateKeyAsPEM(cert) { viewModel.errorMessage = $0 } } label: { Label("Export Key (.pem)", systemImage: "key") }
            SwiftUI.Button { CertificateExporter.sharePrivateKeyAsDER(cert) { viewModel.errorMessage = $0 } } label: { Label("Export Key (.der)", systemImage: "key") }
            SwiftUI.Button(role: .destructive) { onClearKey() } label: { Label("Clear pKey", systemImage: "key.slash") }
        }
    }
}

private struct CertPublicKeyMenuItems: View {
    let cert: ALTCertificate
    @ObservedObject var viewModel: CertificatesViewModel
    var onAddKeyBin:  () -> Void
    var onAddKeyText: () -> Void
    var onExportP12:  () -> Void
    
    var body: some View {
        Group {
            SwiftUI.Button { onAddKeyText() } label: { Label("Add pKey (text)", systemImage: "square.and.pencil") }
            SwiftUI.Button { onAddKeyBin() } label: { Label("Add pKey (bin)", systemImage: "doc.badge.plus") }
            SwiftUI.Button { onExportP12() } label: { Label("Export (.p12)", systemImage: "square.and.arrow.up") }
            SwiftUI.Button { CertificateExporter.sharePublicCertAsPEM(cert) { viewModel.errorMessage = $0 } } label: { Label("Export (.pem)", systemImage: "square.and.arrow.up") }
            SwiftUI.Button { CertificateExporter.sharePublicCertAsDER(cert) { viewModel.errorMessage = $0 } } label: { Label("Export (.der)", systemImage: "square.and.arrow.up") }
            SwiftUI.Button { CertificateExporter.copyPublicCertAsPEM(cert) { viewModel.errorMessage = $0 } } label: { Label("Copy (.pem)", systemImage: "doc.on.doc") }
        }
    }
}
