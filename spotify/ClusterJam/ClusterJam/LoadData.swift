import Foundation
import SwiftCSV

enum ClusterType {
    case standard
    case season
}

struct User {
    let id: String
    var playlists: [Playlist] = []
}

struct Playlist: Identifiable, Codable {
    var id: UUID
    var name: String
    var songs: [Song]
    var spotifyId: String?
}

extension Playlist {
    var dictionary: [String: Any] {
        return [
            "id": id.uuidString,
            "name": name,
            "songs": songs.map { $0.dictionary }
        ]
    }
}

struct Song: Identifiable, Codable {
    var id: String
    var name: String
    var albumName: String
    var albumImageUrl: String
    var artistImageUrl: String
    var trackUrl: String
    var trackUri: String
    var acousticness: Double
    var danceability: Double
    var duration: Double
    var energy: Double
    var instrumentalness: Double
    var key: Double
    var liveness: Double
    var loudness: Double
    var mode: Double
    var speechiness: Double
    var tempo: Double
    var time_signature: Double
    var valence: Double
    var clusterId: String
}

extension Song {
    var dictionary: [String: Any] {
        return [
            "id": id,
            "name": name,
            "albumName": albumName,
            "albumImageUrl": albumImageUrl,
            "artistImageUrl": artistImageUrl,
            "trackUrl": trackUrl,
            "trackUri": trackUri,
            "acousticness": acousticness,
            "danceability": danceability,
            "duration": duration,
            "energy": energy,
            "instrumentalness": instrumentalness,
            "key": key,
            "liveness": liveness,
            "loudness": loudness,
            "mode": mode,
            "speechiness": speechiness,
            "tempo": tempo,
            "time_signature": time_signature,
            "valence": valence,
            "clusterId": clusterId,
        ]
    }
}

struct Artist: Identifiable {
    let id: String
    let name: String
    let imageUrl: String
    var popularity: Int
    let isDailyArtist: Bool
}

struct Cluster: Identifiable {
    let id: String
    let name: String
    let description: String
    let artistId: String
    let type: ClusterType
}

func loadCSVData() -> ([Artist], [Cluster], [Song]) {
    var artists: [Artist] = []
    var clusters: [Cluster] = []
    var songs: [Song] = []
    var songIDs: Set<String> = []
    
    do {
        if let csvFileURL = Bundle.main.url(forResource: "clusters", withExtension: "csv") {
            let csvFile = try CSV<Named>(url: csvFileURL)
            let rows = csvFile.rows
            
            var artistDict = [String: Artist]()
            var clusterDict = [String: Cluster]()
            var seasonClusterDict = [String: Cluster]()
            
            for row in rows {
                let artistId = row["artist_image_url"] ?? ""
                if artistDict[artistId] == nil {
                    let artist = Artist(
                        id: artistId,
                        name: row["artist_name"] ?? "",
                        imageUrl: artistId,
                        popularity: Int(row["artist_popularity"] ?? "0") ?? 0,
                        isDailyArtist: (row["is_daily_artist"] ?? "False").lowercased() == "true"
                    )
                    artistDict[artistId] = artist
                    artists.append(artist)
                }
                
                let clusterIdString = "\(artistId)_\(row["cluster"] ?? "0")"
                if let clusterName = row["cluster_name"], !clusterName.isEmpty, clusterDict[clusterIdString] == nil {
                    let cluster = Cluster(id: clusterIdString, name: clusterName, description: "", artistId: artistId, type: .standard)
                    clusterDict[clusterIdString] = cluster
                    clusters.append(cluster)
                }
                
                let seasonClusterIdString = "\(artistId)_\(row["season_cluster"] ?? "0")"
                if let seasonName = row["season_name"], !seasonName.isEmpty, seasonClusterDict[seasonClusterIdString] == nil {
                    let seasonCluster = Cluster(id: seasonClusterIdString, name: seasonName, description: "", artistId: artistId, type: .season)
                    seasonClusterDict[seasonClusterIdString] = seasonCluster
                    clusters.append(seasonCluster)
                }
                
                func processSong(for clusterId: String) {
                    let songID = row["track_url"] ?? UUID().uuidString
                    if !songIDs.contains(songID) {
                        let song = Song(
                            id: songID,
                            name: row["track_name"] ?? "",
                            albumName: row["album_name"] ?? "",
                            albumImageUrl: row["album_image_url"] ?? "",
                            artistImageUrl: row["artist_image_url"] ?? "",
                            trackUrl: row["track_url"] ?? "",
                            trackUri: row["track_uri"] ?? "",
                            acousticness: Double(row["acousticness"] ?? "0") ?? 0,
                            danceability: Double(row["danceability"] ?? "0") ?? 0,
                            duration: Double(row["duration_ms"] ?? "0") ?? 0,
                            energy: Double(row["energy"] ?? "0") ?? 0,
                            instrumentalness: Double(row["instrumentalness"] ?? "0") ?? 0,
                            key: Double(Double(row["key"] ?? "0") ?? 0),
                            liveness: Double(row["liveness"] ?? "0") ?? 0,
                            loudness: Double(row["loudness"] ?? "0") ?? 0,
                            mode: Double(row["mode"] ?? "0") ?? 0,
                            speechiness: Double(row["speechiness"] ?? "0") ?? 0,
                            tempo: Double(row["tempo"] ?? "0") ?? 0,
                            time_signature: Double(row["time_signature"] ?? "0") ?? 0,
                            valence: Double(row["valence"] ?? "0") ?? 0,
                            clusterId: clusterId
                        )
                        songs.append(song)
                        songIDs.insert(songID)
                    }
                }
                if let clusterName = row["cluster_name"], !clusterName.isEmpty {
                    processSong(for: clusterIdString)
                }
                
                if let seasonName = row["season_name"], !seasonName.isEmpty {
                    processSong(for: seasonClusterIdString)
                }
            }
        }
    } catch {
        print("Failed to load CSV file: \(error)")
    }
    
    return (artists, clusters, songs)
}
