import SwiftUI
import FirebaseAuth

struct PlaylistView: View {
    @EnvironmentObject var playlistManager: PlaylistManager
    @EnvironmentObject var spotifyAuthManager: SpotifyAuthManager
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isUserLoggedIn = false
    @State private var showingAddPlaylistView = false
    
    let darkBlue = Color(red: 4/255, green: 4/255, blue: 62/255)
    let lightBlue = Color(red: 151/255, green: 219/255, blue: 226/255)
    
    var body: some View {
        ZStack {
            darkBlue.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                HStack {
                    Text("Your Playlists")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(lightBlue)
                    Spacer()
                    Button(action: {
                        showingAddPlaylistView = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundColor(lightBlue)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 30)
                
                if isUserLoggedIn {
                    if playlistManager.userPlaylists.isEmpty {
                        emptyStateView
                    } else {
                        playlistGridView
                    }
                } else {
                    loginPromptView
                }
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .sheet(isPresented: $showingAddPlaylistView) {
            AddPlaylistView(isPresented: $showingAddPlaylistView, addNewPlaylist: addNewPlaylist)
        }
        .onAppear(perform: checkUserLoginStatus)
    }
    
    private var emptyStateView: some View {
        VStack {
            Image(systemName: "music.note.list")
                .font(.system(size: 80))
                .foregroundColor(lightBlue.opacity(0.5))
            Text("Tap the '+' to create your first playlist!")
                .font(.headline)
                .foregroundColor(lightBlue)
                .multilineTextAlignment(.center)
                .padding()
        }
    }
    
    private var playlistGridView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                ForEach(playlistManager.userPlaylists) { playlist in
                    PlaylistCard(playlist: playlist, deleteAction: { deletePlaylist(playlist) })
                }
            }
            .padding()
        }
    }
    
    private var loginPromptView: some View {
        VStack {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 80))
                .foregroundColor(lightBlue.opacity(0.5))
            Text("Please log in to view your playlists")
                .font(.headline)
                .foregroundColor(lightBlue)
                .multilineTextAlignment(.center)
                .padding()
        }
    }
    
    private func checkUserLoginStatus() {
        isUserLoggedIn = Auth.auth().currentUser != nil
    }
    
    private func addNewPlaylist(name: String) {
        guard !name.isEmpty else {
            alertMessage = "Playlist name cannot be empty."
            showAlert = true
            return
        }
        playlistManager.addNewPlaylist(with: name)
    }
    
    private func deletePlaylist(_ playlist: Playlist) {
        playlistManager.removePlaylist(playlist)
    }
}

struct PlaylistCard: View {
    let playlist: Playlist
    let deleteAction: () -> Void
    
    let darkBlue = Color(red: 4/255, green: 4/255, blue: 62/255)
    let lightBlue = Color(red: 151/255, green: 219/255, blue: 226/255)
    
    var body: some View {
        NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
            VStack {
                Image(systemName: "music.note.list")
                    .font(.system(size: 50))
                    .foregroundColor(lightBlue)
                    .padding()
                    .background(darkBlue.opacity(0.3))
                    .clipShape(Circle())
                
                Text(playlist.name)
                    .font(.headline)
                    .foregroundColor(lightBlue)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                Text("\(playlist.songs.count) songs")
                    .font(.subheadline)
                    .foregroundColor(lightBlue.opacity(0.7))
            }
            .frame(height: 180)
            .padding()
            .background(lightBlue.opacity(0.1))
            .cornerRadius(15)
            .overlay(
                Button(action: deleteAction) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .padding(8)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
                    .padding(8),
                alignment: .topTrailing
            )
        }
    }
}

struct AddPlaylistView: View {
    @Binding var isPresented: Bool
    @State private var newPlaylistName = ""
    var addNewPlaylist: (String) -> Void
    
    let darkBlue = Color(red: 4/255, green: 4/255, blue: 62/255)
    let lightBlue = Color(red: 151/255, green: 219/255, blue: 226/255)
    
    var body: some View {
        ZStack {
            darkBlue.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                Text("Create New Playlist")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(lightBlue)
                
                TextField("Playlist Name", text: $newPlaylistName)
                    .padding()
                    .background(lightBlue.opacity(0.1))
                    .cornerRadius(10)
                    .foregroundColor(lightBlue)
                
                Button(action: {
                    addNewPlaylist(newPlaylistName)
                    isPresented = false
                }) {
                    Text("Create")
                        .font(.headline)
                        .foregroundColor(darkBlue)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(lightBlue)
                        .cornerRadius(10)
                }
                
                Button("Cancel") {
                    isPresented = false
                }
                .font(.headline)
                .foregroundColor(lightBlue)
            }
            .padding()
        }
    }
}

struct PlaylistDetailView: View {
    @EnvironmentObject var playlistManager: PlaylistManager
    @EnvironmentObject var spotifyAuthManager: SpotifyAuthManager
    let playlist: Playlist
    @State private var songs: [Song]
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isAddingToSpotify = false
    
    let darkBlue = Color(red: 4/255, green: 4/255, blue: 62/255)
    let lightBlue = Color(red: 151/255, green: 219/255, blue: 226/255)
    
    init(playlist: Playlist) {
        self.playlist = playlist
        _songs = State(initialValue: playlist.songs)
    }
    
    var body: some View {
        ZStack {
            darkBlue.edgesIgnoringSafeArea(.all)
            
            VStack {
                HStack {
                    Text(playlist.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(lightBlue)
                        .padding()
                    
                    Spacer()
                    
                    Button(action: {
                        addAsSpotifyPlaylist()
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundColor(.green)
                    }
                    .disabled(isAddingToSpotify)
                }
                .padding(.horizontal)
                
                if songs.isEmpty {
                    emptyPlaylistView
                } else {
                    songListView
                }
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Notification"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    private var emptyPlaylistView: some View {
        VStack {
            Image(systemName: "music.note")
                .font(.system(size: 80))
                .foregroundColor(lightBlue.opacity(0.5))
            Text("This playlist is empty")
                .font(.headline)
                .foregroundColor(lightBlue)
                .multilineTextAlignment(.center)
                .padding()
        }
    }
    
    private var songListView: some View {
        ScrollView {
            LazyVStack(spacing: 15) {
                ForEach(songs) { song in
                    SongRow(song: song, removeSong: { removeSong(song) })
                }
            }
            .padding()
        }
    }
    
    private func removeSong(_ song: Song) {
        playlistManager.removeSongFromPlaylist(song: song, playlist: playlist) { result in
            switch result {
            case .success():
                if let index = songs.firstIndex(where: { $0.id == song.id }) {
                    songs.remove(at: index)
                }
            case .failure(let error):
                alertMessage = "Failed to remove song: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    private func addAsSpotifyPlaylist() {
        isAddingToSpotify = true
        spotifyAuthManager.createSpotifyPlaylist(name: playlist.name, tracks: songs) { result in
            DispatchQueue.main.async {
                isAddingToSpotify = false
                switch result {
                case .success:
                    alertMessage = "Playlist added to Spotify!"
                case .failure(let error):
                    alertMessage = "Failed to add playlist to Spotify: \(error.localizedDescription)"
                }
                showAlert = true
            }
        }
    }
}

struct SongRow: View {
    let song: Song
    let removeSong: () -> Void
    
    let darkBlue = Color(red: 4/255, green: 4/255, blue: 62/255)
    let lightBlue = Color(red: 151/255, green: 219/255, blue: 226/255)
    
    var body: some View {
        HStack {
            AsyncImage(url: URL(string: song.albumImageUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
            } placeholder: {
                Image(systemName: "music.note")
                    .font(.system(size: 30))
                    .frame(width: 60, height: 60)
                    .background(lightBlue.opacity(0.3))
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 5) {
                Text(song.name)
                    .font(.headline)
                    .foregroundColor(lightBlue)
                Text(song.albumName)
                    .font(.subheadline)
                    .foregroundColor(lightBlue.opacity(0.7))
            }
            
            Spacer()
            
            Button(action: {
                if let url = URL(string: song.trackUrl) {
                    UIApplication.shared.open(url)
                }
            }) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(lightBlue)
            }
            
            Button(action: removeSong) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(lightBlue.opacity(0.1))
        .cornerRadius(15)
    }
}
