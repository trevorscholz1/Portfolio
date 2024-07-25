import SwiftUI
import FirebaseFirestore
import FirebaseAuth

let darkBlue = Color(red: 4/255, green: 4/255, blue: 62/255)

class PlaylistManager: ObservableObject {
    @Published var userPlaylists: [Playlist] = []
    private var db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    
    init() {
        setupAuthListener()
    }
    
    deinit {
        listenerRegistration?.remove()
    }
    
    private func setupAuthListener() {
        Auth.auth().addStateDidChangeListener { [weak self] (auth, user) in
            if let user = user {
                self?.fetchUserPlaylists(for: user.uid)
            } else {
                self?.userPlaylists = []
                self?.listenerRegistration?.remove()
            }
        }
    }
    
    func fetchUserPlaylists(for userId: String) {
        listenerRegistration?.remove()
        
        listenerRegistration = db.collection("users").document(userId).collection("playlists")
            .addSnapshotListener { [weak self] (querySnapshot, error) in
                guard let documents = querySnapshot?.documents else {
                    print("Error fetching playlists: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                DispatchQueue.main.async {
                    self?.userPlaylists = documents.compactMap { document -> Playlist? in
                        do {
                            return try document.data(as: Playlist.self)
                        } catch {
                            print("Error decoding playlist: \(error)")
                            return nil
                        }
                    }
                }
            }
    }
    
    func addNewPlaylist(with name: String) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let newPlaylist = Playlist(id: UUID(), name: name, songs: [])
        
        db.collection("users").document(userId).collection("playlists").document(newPlaylist.id.uuidString).setData(newPlaylist.dictionary) { error in
            if let error = error {
                print("Error adding playlist: \(error)")
            }
        }
    }
    
    func removeSongFromPlaylist(song: Song, playlist: Playlist, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "PlaylistManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not signed in"])))
            return
        }
        
        var updatedPlaylist = playlist
        updatedPlaylist.songs.removeAll { $0.id == song.id }
        
        db.collection("users").document(userId).collection("playlists").document(playlist.id.uuidString).setData(updatedPlaylist.dictionary) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                DispatchQueue.main.async {
                    if let index = self.userPlaylists.firstIndex(where: { $0.id == playlist.id }) {
                        self.userPlaylists[index] = updatedPlaylist
                    }
                    completion(.success(()))
                }
            }
        }
    }
    
    func removePlaylist(_ playlist: Playlist) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users").document(userId).collection("playlists").document(playlist.id.uuidString).delete { error in
            if let error = error {
                print("Error removing playlist: \(error)")
            } else {
                DispatchQueue.main.async {
                    self.userPlaylists.removeAll { $0.id == playlist.id }
                }
            }
        }
    }
    
    func addSongToPlaylist(song: Song, playlist: Playlist) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        var updatedPlaylist = playlist
        updatedPlaylist.songs.append(song)
        
        db.collection("users").document(userId).collection("playlists").document(playlist.id.uuidString).setData(updatedPlaylist.dictionary) { error in
            if let error = error {
                print("Error adding song to playlist: \(error)")
            } else {
                DispatchQueue.main.async {
                    if let index = self.userPlaylists.firstIndex(where: { $0.id == playlist.id }) {
                        self.userPlaylists[index] = updatedPlaylist
                    }
                }
            }
        }
    }
}

