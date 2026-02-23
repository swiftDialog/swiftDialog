//
//  AudioManager.swift
//  dialog
//
//  Created by Bart Reardon on 17/10/2025.
//

import SwiftUI
import AVFoundation

// MARK: - Audio Manager
class AudioManager: ObservableObject {
    static let shared = AudioManager()
    
    enum LoadingState {
        case idle
        case downloading
        case ready
        case error(String)
    }
    
    @Published var isPlaying = false
    @Published var isMuted = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var loadingState: LoadingState = .idle
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    
    private init() {}
    
    /// Play audio from either a local file path or URL
    func playAudio(from source: String) {
        loadingState = .downloading
        
        // Check if it's a URL
        if source.hasPrefix("http://") || source.hasPrefix("https://") {
            playFromURL(urlString: source)
        } else {
            playFromLocalFile(path: source)
        }
    }
    
    private func playFromURL(urlString: String) {
        guard let url = URL(string: urlString) else {
            loadingState = .error("Invalid URL".localized)
            print("Invalid URL: \(urlString)")
            return
        }
        
        // Download audio data
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.loadingState = .error("Download failed".localized)
                    print("Failed to download audio: \(error.localizedDescription)")
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self.loadingState = .error("No data received".localized)
                }
                return
            }
            
            DispatchQueue.main.async {
                self.playAudioData(data)
            }
        }.resume()
    }
    
    private func playFromLocalFile(path: String) {
        let fileURL: URL
        
        // Handle both absolute and relative paths
        if path.hasPrefix("/") {
            fileURL = URL(fileURLWithPath: path)
        } else if path.hasPrefix("~/") {
            let expandedPath = NSString(string: path).expandingTildeInPath
            fileURL = URL(fileURLWithPath: expandedPath)
        } else {
            // Relative path
            fileURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent(path)
        }
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            loadingState = .error("File not found".localized)
            print("Audio file not found at: \(fileURL.path)")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
            setupPlayer()
        } catch {
            loadingState = .error("Invalid audio file".localized)
            print("Failed to play audio: \(error.localizedDescription)")
        }
    }
    
    private func playAudioData(_ data: Data) {
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            setupPlayer()
        } catch {
            loadingState = .error("Invalid audio format".localized)
            print("Failed to play audio data: \(error.localizedDescription)")
        }
    }
    
    private func setupPlayer() {
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()
        isPlaying = true
        duration = audioPlayer?.duration ?? 0
        loadingState = .ready
        startTimer()
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            self.currentTime = player.currentTime
            
            // Stop timer if playback finished
            if !player.isPlaying && self.currentTime >= self.duration {
                self.stop()
            }
        }
    }
    
    func togglePlayPause() {
        guard let player = audioPlayer else { return }
        
        if isPlaying {
            player.pause()
            isPlaying = false
            timer?.invalidate()
        } else {
            player.play()
            isPlaying = true
            startTimer()
        }
    }
    
    func toggleMute() {
        guard let player = audioPlayer else { return }
        isMuted.toggle()
        player.volume = isMuted ? 0 : 1
    }
    
    func stop() {
        audioPlayer?.stop()
        isPlaying = false
        timer?.invalidate()
        currentTime = 0
    }
    
    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
    }
}
