//
//  WirelessPairView.swift
//  AltStore
//
//  Created by Magesh K on 04/07/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import Minimuxer

struct WirelessPairView: View {
    @State private var statusText = "Ready to pair"
    @State private var subStatusText = "Tap Start to advertise this device on the local network."
    @State private var pinCode: String? = nil
    @State private var isAdvertising = false
    @State private var pairedDevice: WirelessPair.PairedDevice? = nil
    @State private var errorMessage: String? = nil
    @State private var serviceID: String? = nil
    @State private var port: Int? = nil
    
    private let pairing = WirelessPair()
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Pulsing Status Orb
            ZStack {
                // Outer breathing glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: isAdvertising ? [Color.accentColor.opacity(0.25), Color.clear] : [Color.gray.opacity(0.1), Color.clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 100
                        )
                    )
                    .frame(width: 220, height: 220)
                    .scaleEffect(isAdvertising ? 1.2 : 1.0)
                    .opacity(isAdvertising ? 1.0 : 0.5)
                    .animation(isAdvertising ? .easeInOut(duration: 1.8).repeatForever(autoreverses: true) : .default, value: isAdvertising)
                
                // Secondary pulsing ring
                Circle()
                    .stroke(isAdvertising ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 2)
                    .frame(width: 140, height: 140)
                    .scaleEffect(isAdvertising ? 1.15 : 1.0)
                    .opacity(isAdvertising ? 0.8 : 0.0)
                    .animation(isAdvertising ? .easeInOut(duration: 1.8).delay(0.3).repeatForever(autoreverses: true) : .default, value: isAdvertising)

                // Central Orb
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: isAdvertising ? [Color.accentColor, Color.accentColor.opacity(0.8)] : [Color.gray, Color.gray.opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)
                    .shadow(color: isAdvertising ? Color.accentColor.opacity(0.5) : Color.clear, radius: 15)
                
                Image(systemName: isAdvertising ? "antenna.radiowaves.left.and.right" : "wifi.slash")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 20)
            
            // Status Info
            VStack(spacing: 8) {
                Text(statusText)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                if serviceID == nil {
                    Text(subStatusText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .transition(.opacity)
                }
            }
            
            // Connection Details Card
            if let serviceID = serviceID, let port = port {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "network")
                            .foregroundColor(.accentColor)
                        Text("Connection Details")
                            .font(.headline)
                    }
                    .padding(.bottom, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Device ID:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(serviceID)
                                .font(.system(.subheadline, design: .monospaced))
                                .fontWeight(.semibold)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("Port:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(port)")
                                .font(.system(.subheadline, design: .monospaced))
                                .fontWeight(.semibold)
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                    
                    HStack(spacing: 8) {
                        Image(systemName: "wifi")
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                        Text("Ensure both devices are on the same Wi-Fi network.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 32)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            
            // PIN Display
            if let pin = pinCode {
                VStack(spacing: 12) {
                    Text("PAIRING CODE")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .tracking(3)
                    
                    HStack(spacing: 14) {
                        ForEach(Array(pin.enumerated()), id: \.offset) { _, char in
                            Text(String(char))
                                .font(.system(size: 34, weight: .bold, design: .monospaced))
                                .frame(width: 52, height: 68)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
                                .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 3)
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(LinearGradient(gradient: Gradient(colors: [Color.accentColor.opacity(0.5), Color.clear]), startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5))
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                .padding(.vertical, 16)
            }
            
            // Error Display
            if let error = errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .transition(.opacity)
            }
            
            Spacer()
            
            // Main Button
            SwiftUI.Button(action: togglePairing) {
                Text(isAdvertising ? "Stop Advertising" : "Start Pairing")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: isAdvertising ? [Color.red, Color.red.opacity(0.85)] : [Color.accentColor, Color.accentColor.opacity(0.85)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: (isAdvertising ? Color.red : Color.accentColor).opacity(0.3), radius: 10, y: 5)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .navigationTitle("Wireless Pairing")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            pairing.stop()
        }
    }
    
    private func togglePairing() {
        if isAdvertising {
            pairing.stop()
            withAnimation {
                isAdvertising = false
                statusText = "Ready to pair"
                subStatusText = "Tap Start to advertise this device on the local network."
                pinCode = nil
                errorMessage = nil
                serviceID = nil
                port = nil
            }
        } else {
            withAnimation {
                isAdvertising = true
                statusText = "Waiting for connection..."
                subStatusText = "Open Remote Pairing on your Apple TV / Vision Pro / host device to discover this server."
                pinCode = nil
                errorMessage = nil
                serviceID = nil
                port = nil
            }
            
            let pairingFile = pairingFilePath()
            
            pairing.onReadyToPair = { serviceID, port in
                withAnimation {
                    self.serviceID = serviceID
                    self.port = port
                    statusText = "Advertising server..."
                    subStatusText = "Ensure both devices are on the same Wi-Fi."
                }
            }
            
            pairing.onPinReceived = { pin in
                withAnimation {
                    pinCode = pin
                    statusText = "Device Connected"
                    subStatusText = "Enter the pairing code shown below on your other device settings screen."
                }
            }
            
            pairing.start(outPath: pairingFile) { result in
                withAnimation {
                    isAdvertising = false
                    pinCode = nil
                    serviceID = nil
                    port = nil
                    
                    switch result {
                    case .success(let device):
                        pairedDevice = device
                        statusText = "Success!"
                        subStatusText = "Successfully paired with \(device.name) (\(device.model))!\nPairing file saved to documents."
                    case .failure(let error):
                        errorMessage = error.localizedDescription
                        statusText = "Pairing Failed"
                        subStatusText = "An error occurred during pairing."
                    }
                }
            }
        }
    }
    
    private func pairingFilePath() -> String {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("rp_pairing_file.plist").path
    }
}
