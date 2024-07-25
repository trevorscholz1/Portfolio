import SwiftUI
import ShazamKit

struct MatchedSong: Equatable {
    let title: String
    let artist: String
}

struct WizardView: View {
    @StateObject private var viewModel = WizardViewModel()
    
    private let backgroundColor = Color(red: 4/255, green: 4/255, blue: 62/255)
    private let accentColor = Color(red: 151/255, green: 219/255, blue: 226/255)
    
    var body: some View {
        ZStack {
            backgroundColor.edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                
                if viewModel.isListening {
                    listeningView
                } else {
                    Text("Don't know the name of a song?")
                        .font(.headline)
                        .foregroundColor(accentColor)
                        .multilineTextAlignment(.center)
                    Text("Tap the Microphone, let ClusterJam listen, and find the song your looking for.")
                        .font(.headline)
                        .foregroundColor(accentColor)
                        .multilineTextAlignment(.center)
                        .padding(.bottom)
                    listenButton
                }
                
                Spacer()
                
                if let match = viewModel.matchedSong {
                    matchedSongView(match)
                }
            }
            .padding()
        }
    }
    
    private var listeningView: some View {
        VStack {
            ZStack {
                Circle()
                    .stroke(accentColor.opacity(0.3), lineWidth: 4)
                    .frame(width: 150, height: 150)
                
                Circle()
                    .trim(from: 0, to: 1)
                    .stroke(accentColor, lineWidth: 4)
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(360))
                    .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false), value: viewModel.isListening)
                
                Image(systemName: "waveform")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(accentColor)
                    .frame(width: 60, height: 60)
            }
            
            Text("Listening...")
                .font(.headline)
                .foregroundColor(accentColor)
                .padding(.top)
        }
    }
    
    private var listenButton: some View {
        Button(action: {
            viewModel.startListening()
        }) {
            ZStack {
                Circle()
                    .fill(accentColor)
                    .frame(width: 150, height: 150)
                    .shadow(color: accentColor.opacity(0.3), radius: 10, x: 0, y: 5)
                
                Image(systemName: "mic")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(backgroundColor)
                    .frame(width: 60, height: 60)
            }
        }
    }
    
    private func matchedSongView(_ match: MatchedSong) -> some View {
        VStack(spacing: 16) {
            Text("Matched Song")
                .font(.headline)
                .foregroundColor(accentColor)
            
            VStack(spacing: 8) {
                Text(match.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(match.artist)
                    .font(.title3)
                    .foregroundColor(accentColor)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(backgroundColor)
                .shadow(color: accentColor.opacity(0.3), radius: 10, x: 0, y: 5)
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(), value: viewModel.matchedSong)
    }
}

class WizardViewModel: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var matchedSong: MatchedSong?
    
    private let session = SHSession()
    private let audioEngine = AVAudioEngine()
    
    override init() {
        super.init()
        session.delegate = self
    }
    
    func startListening() {
        guard !isListening else { return }
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .default)
            try audioSession.setActive(true)
            
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.session.matchStreamingBuffer(buffer, at: nil)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            isListening = true
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    func stopListening() {
        guard isListening else { return }
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        isListening = false
    }
}

extension WizardViewModel: SHSessionDelegate {
    func session(_ session: SHSession, didFind match: SHMatch) {
        DispatchQueue.main.async { [weak self] in
            if let mediaItem = match.mediaItems.first {
                self?.matchedSong = MatchedSong(
                    title: mediaItem.title ?? "Unknown",
                    artist: mediaItem.artist ?? "Unknown"
                )
            }
            self?.stopListening()
        }
    }
    
    func session(_ session: SHSession, didNotFindMatchFor signature: SHSignature, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.stopListening()
        }
    }
}
