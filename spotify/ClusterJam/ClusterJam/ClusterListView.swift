import SwiftUI

struct ClusterListView: View {
    @EnvironmentObject var appData: AppData
    let artist: Artist
    @State private var searchText: String = ""
    
    let darkBlue = Color(red: 4/255, green: 4/255, blue: 62/255)
    let lightBlue = Color(red: 151/255, green: 219/255, blue: 226/255)
    
    let clusterEmojis: [String: String] = [
        "Mixed Emotions (Anger/Sadness)": "😖",
        "Party": "🥳",
        "Happy/Confident": "😎",
        "Euphoric": "🤩",
        "Gym Songs": "🫨",
        "Spring": "🌷",
        "Summer": "☀️",
        "Fall": "🍂",
        "Winter": "❄️"
    ]
    
    var body: some View {
        ZStack {
            darkBlue.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        if !standardClusters.isEmpty {
                            ClusterSection(title: "Standard Clusters", clusters: filteredStandardClusters, lightBlue: lightBlue, clusterEmojis: clusterEmojis)
                        }
                        
                        if !seasonClusters.isEmpty {
                            ClusterSection(title: "Season Clusters", clusters: filteredSeasonClusters, lightBlue: lightBlue, clusterEmojis: clusterEmojis)
                        }
                        
                        NavigationLink(destination: AllSongsView(artist: artist, songs: artistSongs)) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("View All Songs")
                                        .font(.headline)
                                    Text("All songs by \(artist.name)")
                                        .font(.subheadline)
                                }
                                Spacer()
                                Image(systemName: "music.note.list")
                            }
                            .foregroundColor(lightBlue)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(artist.name)
                .toolbarBackground(darkBlue, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
    }
    
    private var standardClusters: [Cluster] {
        appData.clusters.filter { $0.type == .standard && $0.artistId == artist.id }
    }
    
    private var seasonClusters: [Cluster] {
        appData.clusters.filter { $0.type == .season && $0.artistId == artist.id }
    }
    
    private var artistSongs: [Song] {
        appData.songs.filter { $0.artistImageUrl == artist.imageUrl }
    }
    
    private var filteredStandardClusters: [Cluster] {
        if searchText.isEmpty {
            return standardClusters
        } else {
            return standardClusters.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }
    }
    
    private var filteredSeasonClusters: [Cluster] {
        if searchText.isEmpty {
            return seasonClusters
        } else {
            return seasonClusters.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }
    }
}

struct ClusterSection: View {
    let title: String
    let clusters: [Cluster]
    let lightBlue: Color
    let clusterEmojis: [String: String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title2)
                .foregroundColor(lightBlue)
                .padding(.leading)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                ForEach(clusters) { cluster in
                    NavigationLink(destination: SongListView(cluster: cluster)) {
                        ClusterCard(cluster: cluster, lightBlue: lightBlue, clusterEmojis: clusterEmojis)
                    }
                }
            }
        }
    }
}

struct ClusterCard: View {
    let cluster: Cluster
    let lightBlue: Color
    let clusterEmojis: [String: String]
    
    var body: some View {
        VStack {
            if let emoji = clusterEmojis[cluster.name] {
                Text(emoji)
                    .font(.largeTitle)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            
            Text(cluster.name)
                .font(.headline)
                .foregroundColor(lightBlue)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 50)
        }
        .frame(width: 150, height: 150)
        .background(Color.white.opacity(0.1))
        .cornerRadius(15)
    }
}
