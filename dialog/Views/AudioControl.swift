//
//  AudioControl.swift
//  dialog
//
//  Created by Bart Reardon on 17/10/2025.
//

import SwiftUI


// MARK: - Audio Control View
struct AudioControl: View {
    @ObservedObject private var audioManager = AudioManager.shared
    
    var body: some View {
        VStack(spacing: 12) {
            // Animated waveform / status icon
            Group {
                switch audioManager.loadingState {
                case .idle:
                    Image(systemName: "waveform")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.5))
                    
                case .downloading:
                    if #available(macOS 15.0, *) {
                        Image(systemName: "hourglass.circle")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                            .symbolEffect(.rotate.byLayer, options: .repeat(.periodic(delay: 1.0)))
                    } else {
                        // Fallback on earlier versions
                        Image(systemName: "hourglass.circle")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    }
                    
                case .ready:
                    Image(systemName: "waveform")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                        .symbolEffect(.variableColor.iterative, isActive: audioManager.isPlaying)
                    
                case .error:
                    Image(systemName: "play.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                }
            }
            
            // Play/Pause and Mute buttons
            HStack(spacing: 20) {
                Button(action: {
                    audioManager.togglePlayPause()
                }) {
                    Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .help(audioManager.isPlaying ? "Pause" : "Play")
                
                Button(action: {
                    audioManager.toggleMute()
                }) {
                    Image(systemName: audioManager.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .help(audioManager.isMuted ? "Unmute" : "Mute")
            }
            
            // Progress bar and time remaining / error message
            VStack(spacing: 4) {
                if case .error(let message) = audioManager.loadingState {
                    // Show error message instead of progress bar
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                } else if case .downloading = audioManager.loadingState {
                    // Show downloading message
                    Text("Downloading".localized+"...")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.8))
                } else {
                    // Normal progress bar and time
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background track
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.3))
                                .frame(height: 4)
                            
                            // Progress
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white)
                                .frame(width: progress(in: geometry.size.width), height: 4)
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let newTime = (value.location.x / geometry.size.width) * audioManager.duration
                                    audioManager.seek(to: max(0, min(newTime, audioManager.duration)))
                                }
                        )
                    }
                    .frame(height: 4)
                    
                    // Time remaining
                    Text(timeRemainingString)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.8))
        )
        .frame(width: .infinity)
    }
    
    private func progress(in width: CGFloat) -> CGFloat {
        guard audioManager.duration > 0 else { return 0 }
        return width * CGFloat(audioManager.currentTime / audioManager.duration)
    }
    
    private var timeRemainingString: String {
        let remaining = max(0, audioManager.duration - audioManager.currentTime)
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return String(format: "-%d:%02d", minutes, seconds)
    }
}
