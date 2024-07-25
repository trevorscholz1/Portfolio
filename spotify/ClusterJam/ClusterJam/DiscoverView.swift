import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject var playlistManager: PlaylistManager
    @EnvironmentObject var appData: AppData
    @State private var recommendedSongs: [Song] = []
    @State private var favoriteCluster: (cluster: Cluster, songCount: Int)? = nil
    @State private var featuredArtist: Artist?
    @State private var userAverageStats: [String: Double] = [:]
    @State private var isLoading = true
    
    let darkBlue = Color(red: 4/255, green: 4/255, blue: 62/255)
    let lightBlue = Color(red: 151/255, green: 219/255, blue: 226/255)
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: lightBlue))
                } else {
                    recommendationsSection
                    featuredArtistSection
                    userStatsSection
                    favoriteClusterSection
                        .padding(.bottom, 24)
                }
            }
            .background(darkBlue.edgesIgnoringSafeArea(.all))
            .foregroundColor(lightBlue)
        }
        .onAppear(perform: loadData)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Discover")
                            .toolbarBackground(darkBlue, for: .navigationBar)
                            .toolbarBackground(.visible, for: .navigationBar)
                            .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear(perform: loadData)
    }
    
    private var recommendationsSection: some View {
        VStack {
            if recommendedSongs.isEmpty {
                Text("No recommendations available at the moment.")
                    .foregroundColor(lightBlue)
                    .padding()
            } else {
                CarouselView(items: recommendedSongs) { song in
                    SongCardView(song: song)
                }
            }
        }
    }
    
    private var featuredArtistSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Featured Artist")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.leading, 16)
            
            if let artist = featuredArtist {
                NavigationLink(destination: ClusterListView(artist: artist)) {
                    FeaturedArtistView(artist: artist)
                        .padding(.horizontal, 16)
                }
            } else {
                Text("No featured artist available.")
                    .foregroundColor(lightBlue)
                    .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 24)
        .background(Color.black.opacity(0.3))
    }
    
    private var favoriteClusterSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Favorite Cluster")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.leading, 16)
            
            if let (cluster, songCount) = favoriteCluster {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(cluster.name)
                            .font(.headline)
                            .foregroundColor(lightBlue)
                        Text("\(songCount) songs")
                            .font(.subheadline)
                            .foregroundColor(lightBlue.opacity(0.7))
                    }
                    Spacer()
                }
                .padding()
                .background(Color.black.opacity(0.3))
                .cornerRadius(10)
                .padding(.horizontal, 16)
            } else {
                Text("No favorite cluster found. Add more songs to your playlists!")
                    .foregroundColor(lightBlue)
                    .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 24)
        .background(Color.black.opacity(0.3))
    }
    
    private var userStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Average Stats")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.leading, 16)
            
            ForEach(userAverageStats.sorted(by: { $0.key < $1.key }), id: \.key) { feature, value in
                FeatureBar(label: feature.capitalized, value: value, lightBlue: lightBlue)
                    .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 24)
        .background(Color.black.opacity(0.3))
    }
    
    private func loadData() {
        isLoading = true
        
        loadRecommendations()
        loadFeaturedArtist()
        calculateUserAverageStats()
        calculateFavoriteCluster()
        
        isLoading = false
    }
    
    private func loadRecommendations() {
        let allUserSongs = playlistManager.userPlaylists.flatMap { $0.songs }
        
        if allUserSongs.isEmpty {
            recommendedSongs = getRandomSongs(count: 20)
        } else {
            recommendedSongs = getRecommendedSongs(basedOn: allUserSongs, count: 20)
        }
    }
    
    private func calculateFavoriteCluster() {
        let allUserSongs = playlistManager.userPlaylists.flatMap { $0.songs }
        let clusterCounts = allUserSongs.reduce(into: [:]) { counts, song in
            counts[song.clusterId, default: 0] += 1
        }
        
        if let (clusterId, count) = clusterCounts.max(by: { $0.value < $1.value }) {
            if let cluster = appData.clusters.first(where: { $0.id == clusterId }) {
                favoriteCluster = (cluster: cluster, songCount: count)
            }
        }
    }
    
    private func loadFeaturedArtist() {
        let today = Calendar.current.startOfDay(for: Date())
        let seed = Int(today.timeIntervalSince1970) / 86400
        
        let index = seed % appData.artists.count
        featuredArtist = appData.artists[index]
    }
    
    private func calculateUserAverageStats() {
        let allUserSongs = playlistManager.userPlaylists.flatMap { $0.songs }
        userAverageStats = calculateAverageFeatures(songs: allUserSongs)
    }
    
    private func getRandomSongs(count: Int) -> [Song] {
        let shuffledSongs = appData.songs.shuffled()
        return Array(shuffledSongs.prefix(count))
    }
    
    private func getRecommendedSongs(basedOn userSongs: [Song], count: Int) -> [Song] {
        let avgFeatures = calculateAverageFeatures(songs: userSongs)
        
        let sortedSongs = appData.songs.sorted { (song1, song2) -> Bool in
            let similarity1 = calculateSimilarity(song: song1, avgFeatures: avgFeatures)
            let similarity2 = calculateSimilarity(song: song2, avgFeatures: avgFeatures)
            return similarity1 > similarity2
        }
        
        let userSongIds = Set(userSongs.map { $0.id })
        let recommendedSongs = sortedSongs.filter { !userSongIds.contains($0.id) }
        
        return Array(recommendedSongs.prefix(count))
    }
    
    private func calculateAverageFeatures(songs: [Song]) -> [String: Double] {
        var sumFeatures = [
            "acousticness": 0.0,
            "danceability": 0.0,
            "duration": 0.0,
            "energy": 0.0,
            "instrumentalness": 0.0,
            "key": 0.0,
            "liveness": 0.0,
            "loudness": 0.0,
            "mode": 0.0,
            "speechiness": 0.0,
            "tempo": 0.0,
            "time signature": 0.0,
            "valence": 0.0
        ]
        
        for song in songs {
            sumFeatures["acousticness"]! += song.acousticness
            sumFeatures["danceability"]! += song.danceability
            sumFeatures["duration"]! += song.duration
            sumFeatures["energy"]! += song.energy
            sumFeatures["instrumentalness"]! += song.instrumentalness
            sumFeatures["key"]! += song.key
            sumFeatures["liveness"]! += song.liveness
            sumFeatures["loudness"]! += song.loudness
            sumFeatures["mode"]! += song.mode
            sumFeatures["speechiness"]! += song.speechiness
            sumFeatures["tempo"]! += song.tempo
            sumFeatures["time signature"]! += song.time_signature
            sumFeatures["valence"]! += song.valence
        }
        
        let count = Double(songs.count)
        return sumFeatures.mapValues { $0 / count }
    }
    
    private func calculateSimilarity(song: Song, avgFeatures: [String: Double]) -> Double {
        let features = [
            song.acousticness - avgFeatures["acousticness"]!,
            song.danceability - avgFeatures["danceability"]!,
            song.duration - avgFeatures["duration"]!,
            song.energy - avgFeatures["energy"]!,
            song.instrumentalness - avgFeatures["instrumentalness"]!,
            song.key - avgFeatures["key"]!,
            song.liveness - avgFeatures["liveness"]!,
            song.loudness - avgFeatures["loudness"]!,
            song.mode - avgFeatures["mode"]!,
            song.speechiness - avgFeatures["speechiness"]!,
            song.tempo - avgFeatures["tempo"]!,
            song.time_signature - avgFeatures["time signature"]!,
            song.valence - avgFeatures["valence"]!
        ]
        
        let sumOfSquares = features.reduce(0) { $0 + $1 * $1 }
        return 1 / (1 + sqrt(sumOfSquares))
    }
}

struct FeaturedArtistView: View {
    let artist: Artist
    let lightBlue = Color(red: 151/255, green: 219/255, blue: 226/255)
    
    var body: some View {
        VStack {
            AsyncImage(url: URL(string: artist.imageUrl)) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 200, height: 200)
                        .clipShape(Circle())
                case .failure:
                    Image(systemName: "person.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 200)
                        .background(Color.gray.opacity(0.3))
                        .clipShape(Circle())
                @unknown default:
                    Image(systemName: "person.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 200)
                        .background(Color.gray.opacity(0.3))
                        .clipShape(Circle())
                }
            }
            
            Text(artist.name)
                .font(.title2)
                .foregroundColor(lightBlue)
            Text("Popularity: \(artist.popularity)")
                .font(.subheadline)
                .foregroundColor(lightBlue.opacity(0.7))
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(20)
    }
}

struct FeatureBar: View {
    let label: String
    let value: Double
    let lightBlue: Color
    
    private var normalizedValue: Double {
        return max(0, min(value, 1))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(lightBlue.opacity(0.7))
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(lightBlue.opacity(0.3))
                        .frame(height: 8)
                    
                    Rectangle()
                        .fill(lightBlue)
                        .frame(width: geometry.size.width * CGFloat(normalizedValue), height: 8)
                }
            }
            .cornerRadius(4)
        }
    }
}

struct CarouselView<Content: View, T: Identifiable>: View {
    let items: [T]
    let content: (T) -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recommendations")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.leading, 16)
            
            Text("Based on songs in your playlists")
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.leading, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(items) { item in
                        content(item)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 24)
        .background(Color.black.opacity(0.3))
    }
}

struct SongCardView: View {
    let song: Song
    let darkBlue = Color(red: 4/255, green: 4/255, blue: 62/255)
    let lightBlue = Color(red: 151/255, green: 219/255, blue: 226/255)
    
    var body: some View {
        VStack(spacing: 8) {
            Button(action: {
                openSpotify(song.trackUrl)
            }) {
                AsyncImage(url: URL(string: song.albumImageUrl)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 140, height: 140)
                    case .failure, _:
                        Image(systemName: "music.note")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 140, height: 140)
                            .background(Color.gray.opacity(0.3))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(song.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(lightBlue)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Text(song.albumName)
                    .font(.subheadline)
                    .foregroundColor(lightBlue.opacity(0.7))
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                FeatureBar(label: "Danceability", value: song.danceability, lightBlue: lightBlue)
                FeatureBar(label: "Energy", value: song.energy, lightBlue: lightBlue)
                FeatureBar(label: "Valence", value: song.valence, lightBlue: lightBlue)
            }
        }
        .padding(8)
        .background(darkBlue.opacity(0.8))
        .cornerRadius(20)
        .shadow(color: darkBlue.opacity(0.5), radius: 10, x: 0, y: 5)
        .frame(width: 160, height: 280)
    }
    
    private func openSpotify(_ url: String) {
        if let spotifyURL = URL(string: url), UIApplication.shared.canOpenURL(spotifyURL) {
            UIApplication.shared.open(spotifyURL, options: [:], completionHandler: nil)
        } else {
            print("Unable to open Spotify URL: \(url)")
        }
    }
}
