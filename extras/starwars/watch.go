package main

import (
	"context"
	"encoding/json"
	"fmt"
	"html/template"
	"log"
	"math/rand"
	"net/http"
	"os"
	"regexp"
	"strconv"
	"time"

	"google.golang.org/api/option"
	"google.golang.org/api/youtube/v3"
)

var (
	youtubeService *youtube.Service
	config         *Config
	templates      *template.Template
)

type Config struct {
	APIKey string `json:"api_key"`
}

type SearchResult struct {
	ChannelTitle string
	ChannelID    string
}

type VideoData struct {
	Title      string
	VideoID    string
	Error      string
	ChannelID  string
	ChannelLen int
	Interval   string
}

type SelectedChannels struct {
	Channels []SearchResult
}

var selectedChannels SelectedChannels

func main() {
	var err error
	config, err = loadConfig("config.json")
	if err != nil {
		log.Fatal(err)
	}

	ctx := context.Background()
	youtubeService, err = youtube.NewService(ctx, option.WithAPIKey(config.APIKey))
	if err != nil {
		log.Fatal(err)
	}

	templates, err = template.ParseFiles("index.html", "results.html")
	if err != nil {
		log.Fatal(err)
	}

	http.HandleFunc("/", handleHome)
	http.HandleFunc("/search", handleSearch)
	http.HandleFunc("/add-channel", handleAddChannel)
	http.HandleFunc("/remove-channel", handleRemoveChannel)
	http.HandleFunc("/random-global", handleRandomGlobalVideo)

	log.Println("Server starting on http://localhost:8080")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		log.Fatal(err)
	}
}

func handleHome(w http.ResponseWriter, r *http.Request) {
	templates.ExecuteTemplate(w, "index.html", selectedChannels)
}

func handleSearch(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Redirect(w, r, "/", http.StatusSeeOther)
		return
	}

	query := r.FormValue("query")
	if query == "" {
		templates.ExecuteTemplate(w, "index.html", map[string]interface{}{
			"Error":    "Please enter a search query",
			"Channels": selectedChannels.Channels,
		})
		return
	}

	results, err := searchChannels(youtubeService, query)
	if err != nil {
		templates.ExecuteTemplate(w, "index.html", map[string]interface{}{
			"Error":    "Error searching for channels: " + err.Error(),
			"Channels": selectedChannels.Channels,
		})
		return
	}

	templates.ExecuteTemplate(w, "results.html", map[string]interface{}{
		"Results":  results,
		"Channels": selectedChannels.Channels,
	})
}

func handleAddChannel(w http.ResponseWriter, r *http.Request) {
	channelTitle := r.FormValue("channel_title")
	channelID := r.FormValue("channel_id")

	for _, ch := range selectedChannels.Channels {
		if ch.ChannelID == channelID {
			http.Redirect(w, r, "/", http.StatusSeeOther)
			return
		}
	}

	selectedChannels.Channels = append(selectedChannels.Channels, SearchResult{
		ChannelTitle: channelTitle,
		ChannelID:    channelID,
	})

	http.Redirect(w, r, "/", http.StatusSeeOther)
}

func handleRemoveChannel(w http.ResponseWriter, r *http.Request) {
	channelID := r.FormValue("channel_id")

	for i, ch := range selectedChannels.Channels {
		if ch.ChannelID == channelID {
			selectedChannels.Channels = append(selectedChannels.Channels[:i], selectedChannels.Channels[i+1:]...)
			break
		}
	}

	http.Redirect(w, r, "/", http.StatusSeeOther)
}

func handleRandomGlobalVideo(w http.ResponseWriter, r *http.Request) {
	if len(selectedChannels.Channels) == 0 {
		templates.ExecuteTemplate(w, "index.html", map[string]interface{}{
			"Error":    "No channels selected",
			"Channels": selectedChannels.Channels,
		})
		return
	}

	var allVideos []*youtube.PlaylistItem
	for _, channel := range selectedChannels.Channels {
		videos, err := getAllVideos(youtubeService, channel.ChannelID)
		if err != nil {
			log.Printf("Error fetching videos for channel %s: %v", channel.ChannelTitle, err)
			continue
		}
		allVideos = append(allVideos, videos...)
	}

	if len(allVideos) == 0 {
		templates.ExecuteTemplate(w, "index.html", map[string]interface{}{
			"Error":    "No videos found across selected channels",
			"Channels": selectedChannels.Channels,
		})
		return
	}

	index := rand.Intn(len(allVideos))
	video := allVideos[index]

	duration, err := getVideoDuration(youtubeService, video.Snippet.ResourceId.VideoId)
	if err != nil {
		templates.ExecuteTemplate(w, "index.html", map[string]interface{}{
			"Error":    "Error fetching video duration: " + err.Error(),
			"Channels": selectedChannels.Channels,
		})
		return
	}

	start, end := getRandomInterval(duration)
	data := VideoData{
		Title:      video.Snippet.Title,
		VideoID:    video.Snippet.ResourceId.VideoId,
		ChannelID:  video.Snippet.ChannelId,
		ChannelLen: len(allVideos) - 1,
		Interval:   fmt.Sprintf("%s - %s", start, end),
	}

	templates.ExecuteTemplate(w, "index.html", map[string]interface{}{
		"VideoData": data,
		"Channels":  selectedChannels.Channels,
	})
}

func searchChannels(service *youtube.Service, query string) ([]SearchResult, error) {
	call := service.Search.List([]string{"snippet"}).Q(query).Type("channel").MaxResults(10)
	response, err := call.Do()
	if err != nil {
		return nil, err
	}

	var results []SearchResult
	for _, item := range response.Items {
		results = append(results, SearchResult{
			ChannelTitle: item.Snippet.ChannelTitle,
			ChannelID:    item.Snippet.ChannelId,
		})
	}

	return results, nil
}

func getAllVideos(service *youtube.Service, channelID string) ([]*youtube.PlaylistItem, error) {
	channelsResponse, err := service.Channels.List([]string{"contentDetails"}).Id(channelID).Do()
	if err != nil {
		return nil, err
	}
	if len(channelsResponse.Items) == 0 {
		return nil, fmt.Errorf("channel not found")
	}
	uploadsPlaylistID := channelsResponse.Items[0].ContentDetails.RelatedPlaylists.Uploads

	var videos []*youtube.PlaylistItem
	playlistItemsRequest := service.PlaylistItems.List([]string{"snippet", "contentDetails"}).PlaylistId(uploadsPlaylistID)
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

// func handleRandomVideo(w http.ResponseWriter, r *http.Request) {
// 	channelID := r.URL.Query().Get("channel_id")
// 	if channelID == "" {
// 		http.Redirect(w, r, "/", http.StatusSeeOther)
// 		return
// 	}

// 	videos, err := getAllVideos(youtubeService, channelID)
// 	if err != nil {
// 		templates.ExecuteTemplate(w, "index.html", map[string]string{"Error": "Error fetching videos: " + err.Error()})
// 		return
// 	}

// 	if len(videos) == 0 {
// 		templates.ExecuteTemplate(w, "index.html", map[string]string{"Error": "No videos found for this channel"})
// 		return
// 	}

// 	index := rand.Intn(len(videos))
// 	video := videos[index]

// 	duration, err := getVideoDuration(youtubeService, video.Snippet.ResourceId.VideoId)
// 	if err != nil {
// 		templates.ExecuteTemplate(w, "index.html", map[string]string{"Error": "Error fetching video duration: " + err.Error()})
// 		return
// 	}

// 	start, end := getRandomInterval(duration)
// 	data := VideoData{
// 		Title:     video.Snippet.Title,
// 		VideoID:   video.Snippet.ResourceId.VideoId,
// 		ChannelID: channelID,
// 		Interval:  fmt.Sprintf("%s - %s", start, end),
// 	}

// 	templates.ExecuteTemplate(w, "index.html", data)
// }

func getVideoDuration(service *youtube.Service, videoID string) (time.Duration, error) {
	call := service.Videos.List([]string{"contentDetails"}).Id(videoID)
	response, err := call.Do()
	if err != nil {
		return 0, err
	}
	if len(response.Items) == 0 {
		return 0, fmt.Errorf("video not found")
	}
	duration, err := parseDuration(response.Items[0].ContentDetails.Duration)
	if err != nil {
		return 0, err
	}
	return duration, nil
}

func parseDuration(duration string) (time.Duration, error) {
	re := regexp.MustCompile(`PT(\d+H)?(\d+M)?(\d+S)?`)
	matches := re.FindStringSubmatch(duration)
	var hours, minutes, seconds int64
	if matches[1] != "" {
		hours, _ = strconv.ParseInt(matches[1][:len(matches[1])-1], 10, 64)
	}
	if matches[2] != "" {
		minutes, _ = strconv.ParseInt(matches[2][:len(matches[2])-1], 10, 64)
	}
	if matches[3] != "" {
		seconds, _ = strconv.ParseInt(matches[3][:len(matches[3])-1], 10, 64)
	}
	return time.Duration(hours)*time.Hour + time.Duration(minutes)*time.Minute + time.Duration(seconds)*time.Second, nil
}

func getRandomInterval(duration time.Duration) (string, string) {
	if duration <= 30*time.Minute {
		return "", ""
	}
	maxStart := duration - 30*time.Minute
	start := time.Duration(rand.Int63n(int64(maxStart)))
	end := start + 30*time.Minute
	return fmt.Sprintf("%02d:%02d", int(start.Minutes()), int(start.Seconds())%60),
		fmt.Sprintf("%02d:%02d", int(end.Minutes()), int(end.Seconds())%60)
}

func loadConfig(filename string) (*Config, error) {
	data, err := os.ReadFile(filename)
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
