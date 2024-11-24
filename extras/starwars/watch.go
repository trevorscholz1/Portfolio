package main

import (
	"context"
	"encoding/json"
	"fmt"
	"html/template"
	"io/ioutil"
	"log"
	"math/rand"
	"net/http"
	"time"

	"google.golang.org/api/option"
	"google.golang.org/api/youtube/v3"
)

// Config holds the configuration for the YouTube API
type Config struct {
    APIKey string `json:"api_key"`
}

// VideoData holds the data to be passed to the template
type VideoData struct {
    Title     string
    VideoID   string
    Error     string
    ChannelID string
}

var (
    youtubeService *youtube.Service
    config         *Config
    templates      *template.Template
)

func main() {
    // Load configuration from file
    var err error
    config, err = loadConfig("config.json")
    if err != nil {
        log.Fatal(err)
    }

    // Create a new YouTube API client
    ctx := context.Background()
    youtubeService, err = youtube.NewService(ctx, option.WithAPIKey(config.APIKey))
    if err != nil {
        log.Fatal(err)
    }

    // Parse templates
    templates, err = template.ParseFiles("index.html")
    if err != nil {
        log.Fatal(err)
    }

    // Initialize random seed
    rand.Seed(time.Now().UnixNano())

    // Set up HTTP routes
    http.HandleFunc("/", handleHome)
    http.HandleFunc("/random", handleRandomVideo)
    
    // Start the server
    log.Println("Server starting on http://localhost:8080")
    if err := http.ListenAndServe(":8080", nil); err != nil {
        log.Fatal(err)
    }
}

func handleHome(w http.ResponseWriter, r *http.Request) {
    data := VideoData{}
    templates.Execute(w, data)
}

func handleRandomVideo(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodPost {
        http.Redirect(w, r, "/", http.StatusSeeOther)
        return
    }

    channelID := r.FormValue("channel_id")
    if channelID == "" {
        data := VideoData{Error: "Please enter a channel ID"}
        templates.Execute(w, data)
        return
    }

    // Get all videos from the specified channel
    videos, err := getAllVideos(youtubeService, channelID)
    if err != nil {
        data := VideoData{Error: "Error fetching videos: " + err.Error(), ChannelID: channelID}
        templates.Execute(w, data)
        return
    }

    if len(videos) == 0 {
        data := VideoData{Error: "No videos found for this channel", ChannelID: channelID}
        templates.Execute(w, data)
        return
    }

    // Get a random video from the list
    index := rand.Intn(len(videos))
    video := videos[index]

    // Prepare data for template
    data := VideoData{
        Title:     video.Snippet.Title,
        VideoID:   video.Snippet.ResourceId.VideoId,
        ChannelID: channelID,
    }

    // Render template
    if err := templates.Execute(w, data); err != nil {
        http.Error(w, "Error rendering template: "+err.Error(), http.StatusInternalServerError)
        return
    }
}

// loadConfig loads the configuration from a JSON file
func loadConfig(filename string) (*Config, error) {
    data, err := ioutil.ReadFile(filename)
    if err != nil {
        return nil, err
    }
    var config Config
    err = json.Unmarshal(data, &config)
    if err != nil {
        return nil, err
    }
    return &config, nil
}

// getAllVideos fetches all videos from the specified channel
func getAllVideos(service *youtube.Service, channelID string) ([]*youtube.PlaylistItem, error) {
    // Get the uploads playlist ID
    channelsResponse, err := service.Channels.List([]string{"contentDetails"}).Id(channelID).Do()
    if err != nil {
        return nil, err
    }
    if len(channelsResponse.Items) == 0 {
        return nil, fmt.Errorf("channel not found")
    }
    uploadsPlaylistID := channelsResponse.Items[0].ContentDetails.RelatedPlaylists.Uploads

    // Get all videos from the uploads playlist
    var videos []*youtube.PlaylistItem
    playlistItemsRequest := service.PlaylistItems.List([]string{"snippet"}).PlaylistId(uploadsPlaylistID)
    for {
        playlistItemsResponse, err := playlistItemsRequest.Do()
        if err != nil {
            return nil, err
        }
        videos = append(videos, playlistItemsResponse.Items...)
        if playlistItemsResponse.NextPageToken == "" {
            break
        }
        playlistItemsRequest = playlistItemsRequest.PageToken(playlistItemsResponse.NextPageToken)
    }
    return videos, nil
}
