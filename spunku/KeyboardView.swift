import SwiftUI
import Cocoa
import AVFoundation
import UniformTypeIdentifiers

struct KeyboardView: View {
    // Mappings live in KeyboardSoundboardManager (shared with the
    // background key monitor in KeyboardSoundboard.swift).
    @ObservedObject private var manager = KeyboardSoundboardManager.shared

    // A simplified layout of Mac Key Codes
    let keyRows = [
        [50, 18, 19, 20, 21, 23, 22, 26, 28, 25, 29, 27, 24, 51], // Num row
        [48, 12, 13, 14, 15, 17, 16, 32, 34, 31, 35, 33, 30, 42], // QWERTY
        [53, 0, 1, 2, 3, 5, 4, 38, 40, 37, 41, 39, 36],           // ASDF
        [57, 6, 7, 8, 9, 11, 45, 46, 43, 47, 44]                  // ZXCV
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Global Keyboard Soundboard")
                .font(.headline)
            Text("Click a key to assign a sound. Keep the app running to hear sounds on keypress.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 6) {
                ForEach(0..<keyRows.count, id: \.self) { rowIndex in
                    HStack(spacing: 6) {
                        ForEach(keyRows[rowIndex], id: \.self) { keyCode in
                            KeyButton(
                                keyCode: keyCode,
                                isMapped: manager.mappedKeys[keyCode] != nil,
                                isPressed: manager.lastPressedKey == keyCode
                            ) {
                                selectAudioFile(for: keyCode)
                            }
                        }
                    }
                }
                
                // Spacebar row
                HStack {
                    KeyButton(keyCode: 49, isMapped: manager.mappedKeys[49] != nil, isPressed: manager.lastPressedKey == 49, width: 250) {
                        selectAudioFile(for: 49)
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            
            Button("Clear All Sounds") {
                manager.clearAll()
            }
            .buttonStyle(.link)
            .font(.caption)
            .foregroundColor(.red)
            
            Spacer()
        }
        .padding()
        .frame(width: 600, height: 400)
    }
    
    private func selectAudioFile(for keyCode: Int) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.mp3]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK, let url = panel.url {
            manager.setMapping(keyCode: keyCode, path: url.path)
        }
    }
}

struct KeyButton: View {
    let keyCode: Int
    let isMapped: Bool
    let isPressed: Bool
    var width: CGFloat = 36
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isPressed ? Color.blue.opacity(0.8) : (isMapped ? Color.green.opacity(0.3) : Color(NSColor.controlBackgroundColor)))
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isMapped ? Color.green.opacity(0.6) : Color.gray.opacity(0.3), lineWidth: 1)
                
                Text("\(keyCode)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(isPressed ? .white : .primary)
            }
            .frame(width: width, height: 36)
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeOut(duration: 0.1), value: isPressed)
    }
}
