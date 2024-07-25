import SwiftUI
import FirebaseAuth

struct SongListView: View {
    @EnvironmentObject var appData: AppData
    @EnvironmentObject var playlistManager: PlaylistManager
    @State private var addToPlaylistPresentation: AddToPlaylistPresentation?
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isUserLoggedIn = false
    @State private var searchText = ""
    
    let cluster: Cluster
    let darkBlue = Color(red: 4/255, green: 4/255, blue: 62/255)
    let lightBlue = Color(red: 151/255, green: 219/255, blue: 226/255)
    
    var clusterSongs: [Song] {
        appData.songs.filter { $0.clusterId == cluster.id }
    }
    
    var filteredSongs: [Song] {
        if searchText.isEmpty {
            return clusterSongs
        } else {
            return clusterSongs.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }
    }
    
    var body: some View {
        ZStack {
            darkBlue.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                SearchSongBar(text: $searchText, backgroundColor: darkBlue, textColor: lightBlue)
                    .padding()
                
                ScrollView {
                    LazyVStack(spacing: 15) {
                        ForEach(filteredSongs) { song in
                            SongListRow(song: song, lightBlue: lightBlue, onAddToPlaylist: {
                                addToPlaylist(song)
                            })
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(cluster.name)
                .toolbarBackground(darkBlue, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .fullScreenCover(item: $addToPlaylistPresentation) { presentation in
            AddToPlaylistView(song: presentation.song, onPlaylistSelected: { playlist in
                playlistManager.addSongToPlaylist(song: presentation.song, playlist: playlist)
            })
            .environmentObject(playlistManager)
        }
        .onAppear {
            checkUserLoginStatus()
        }
    }
    
    private func addToPlaylist(_ song: Song) {
        if isUserLoggedIn {
            addToPlaylistPresentation = AddToPlaylistPresentation(song: song)
        } else {
            alertMessage = "Please log in to add songs to playlists."
            showAlert = true
        }
    }
    
    private func checkUserLoginStatus() {
        if Auth.auth().currentUser != nil {
            isUserLoggedIn = true
        } else {
            isUserLoggedIn = false
        }
    }
}

struct SongListRow: View {
    let song: Song
    let lightBlue: Color
    let onAddToPlaylist: () -> Void
    
    var body: some View {
        HStack {
            AsyncImage(url: URL(string: song.albumImageUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
            } placeholder: {
                Image(systemName: "music.note")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .foregroundColor(lightBlue)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(song.name)
                    .font(.headline)
                    .foregroundColor(lightBlue)
                Text(song.albumName)
                    .font(.subheadline)
                    .foregroundColor(lightBlue.opacity(0.7))
            }
            
            Spacer()
            
            Button(action: onAddToPlaylist) {
                Image(systemName: "plus.circle.fill")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .foregroundColor(lightBlue)
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(15)
    }
}

struct SearchSongBar: View {
    @Binding var text: String
    var backgroundColor: Color
    var textColor: Color
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(textColor.opacity(0.7))
            
            TextField("Search songs", text: $text)
                .foregroundColor(.white)
            
            if !text.isEmpty {
                Button(action: {
                    self.text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(textColor.opacity(0.7))
                }
            }
        }
        .padding(12)
        .background(backgroundColor.opacity(0.3))
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(textColor.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(15)
    }
}

struct AddToPlaylistView: View {
    let song: Song
    let onPlaylistSelected: (Playlist) -> Void
    @EnvironmentObject var playlistManager: PlaylistManager
    @Environment(\.presentationMode) var presentationMode
    @State private var isLoading = true
    @State private var showingPlaylistView = false
    
    let darkBlue = Color(red: 4/255, green: 4/255, blue: 62/255)
    let lightBlue = Color(red: 151/255, green: 219/255, blue: 226/255)
    
    var body: some View {
        NavigationView {
            ZStack {
                darkBlue.edgesIgnoringSafeArea(.all)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .foregroundColor(lightBlue)
                } else if playlistManager.userPlaylists.isEmpty {
                    VStack {
                        Text("Create a playlist to get started!")
                            .font(.headline)
                            .foregroundColor(lightBlue)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        Button(action: {
                            showingPlaylistView = true
                        }) {
                            Text("Create Playlist")
                                .foregroundColor(darkBlue)
                                .padding()
                                .background(lightBlue)
                                .cornerRadius(10)
                        }
                    }
                } else {
                    List(playlistManager.userPlaylists) { playlist in
                        Button(action: {
                            onPlaylistSelected(playlist)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text(playlist.name)
                                .foregroundColor(lightBlue)
                        }
                        .listRowBackground(darkBlue)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Add to Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
                        .toolbarBackground(darkBlue, for: .navigationBar)
                        .toolbarBackground(.visible, for: .navigationBar)
                        .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onAppear {
            loadPlaylists()
        }
        .sheet(isPresented: $showingPlaylistView) {
            PlaylistView()
                .background(darkBlue)
        }
    }
    
    private func loadPlaylists() {
        isLoading = true
        if let userId = Auth.auth().currentUser?.uid {
            playlistManager.fetchUserPlaylists(for: userId)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLoading = false
        }
    }
}

struct AddToPlaylistPresentation: Identifiable {
    let id = UUID()
    let song: Song
}

struct AllSongsView: View {
    let artist: Artist
    let songs: [Song]
    @State private var sortFeature: SortFeature = .name
    @State private var sortOrder: SortOrder = .ascending
    
    enum SortFeature: String, CaseIterable, Identifiable {
        case name = "Name"
        case acousticness = "Acousticness"
        case danceability = "Danceability"
        case duration = "Duration"
        case energy = "Energy"
        case instrumentalness = "Instrumentalness"
        case key = "Key"
        case liveness = "Liveness"
        case loudness = "Loudness"
        case mode = "Mode"
        case speechiness = "Speechiness"
        case tempo = "Tempo"
        case time_signature = "Time Signature"
        case valence = "Valence"
        
        var id: SortFeature { self }
    }
    
    enum SortOrder: String, CaseIterable, Identifiable {
        case ascending = "Ascending"
        case descending = "Descending"
        
        var id: SortOrder { self }
    }
    
    var sortedSongs: [Song] {
        let sortedSongs = songs.sorted { song1, song2 in
            switch sortFeature {
            case .name:
                return song1.name.localizedCompare(song2.name) == .orderedAscending
            case .danceability:
                return song1.danceability > song2.danceability
            case .energy:
                return song1.energy > song2.energy
            case .key:
                return song1.key > song2.key
            case .loudness:
                return song1.loudness > song2.loudness
            case .mode:
                return song1.mode > song2.mode
            case .speechiness:
                return song1.speechiness > song2.speechiness
            case .acousticness:
                return song1.acousticness > song2.acousticness
            case .instrumentalness:
                return song1.instrumentalness > song2.instrumentalness
            case .liveness:
                return song1.liveness > song2.liveness
            case .valence:
                return song1.valence > song2.valence
            case .tempo:
                return song1.tempo > song2.tempo
            case .duration:
                return song1.duration > song2.duration
            case .time_signature:
                return song1.time_signature > song2.time_signature
            }
        }
        
        return sortOrder == .ascending ? sortedSongs : sortedSongs.reversed()
    }
    
    var body: some View {
        VStack {
            HStack {
                Picker("Sort Feature", selection: $sortFeature) {
                    ForEach(SortFeature.allCases) { feature in
                        Text(feature.rawValue)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .foregroundColor(.gray)
                .padding()
                
                Picker("Sort Order", selection: $sortOrder) {
                    ForEach(SortOrder.allCases) { order in
                        Text(order.rawValue)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .foregroundColor(.gray)
                .padding()
            }
            
            List(sortedSongs) { song in
                HStack {
                    AsyncImage(url: URL(string: song.albumImageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                    } placeholder: {
                        ProgressView()
                            .frame(width: 50, height: 50)
                    }
                    
                    VStack(alignment: .leading) {
                        Text(song.name)
                            .foregroundColor(.white)
                        Text("\(sortFeature.rawValue): \(sortFeatureValue(for: song))")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    Button(action: {
                        if let url = URL(string: song.trackUrl) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Image(systemName: "play.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 30, height: 30)
                            .foregroundColor(.blue)
                    }
                }
                .listRowBackground(Color(red: 4/255, green: 4/255, blue: 62/255))
            }
        }
        .background(Color(red: 4/255, green: 4/255, blue: 62/255))
    }
    
    func sortFeatureValue(for song: Song) -> String {
        switch sortFeature {
        case .name:
            return song.name
        case .danceability:
            return String(format: "%.2f", song.danceability)
        case .energy:
            return String(format: "%.2f", song.energy)
        case .key:
            return String(format: "%.2f", song.key)
        case .loudness:
            return String(format: "%.2f", song.loudness)
        case .mode:
            return String(format: "%.2f", song.mode)
        case .speechiness:
            return String(format: "%.2f", song.speechiness)
        case .acousticness:
            return String(format: "%.2f", song.acousticness)
        case .instrumentalness:
            return String(format: "%.2f", song.instrumentalness)
        case .liveness:
            return String(format: "%.2f", song.liveness)
        case .valence:
            return String(format: "%.2f", song.valence)
        case .tempo:
            return String(format: "%.2f", song.tempo)
        case .duration:
            return String(format: "%.2f", song.duration)
        case .time_signature:
            return String(format: "%.2f", song.time_signature)
        }
    }
}

