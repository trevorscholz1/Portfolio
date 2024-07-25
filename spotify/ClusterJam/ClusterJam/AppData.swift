import SwiftUI

class AppData: ObservableObject {
    @Published var artists: [Artist] = []
    @Published var clusters: [Cluster] = []
    @Published var songs: [Song] = []
    @Published var isLoading: Bool = true
    
    init() {
        loadData()
    }
    
    private func loadData() {
        DispatchQueue.global(qos: .userInitiated).async {
            let (loadedArtists, loadedClusters, loadedSongs) = loadCSVData()
            DispatchQueue.main.async {
                self.artists = loadedArtists.sorted { $0.name < $1.name }
                self.clusters = loadedClusters
                self.songs = loadedSongs
                self.isLoading = false
            }
        }
    }
}
