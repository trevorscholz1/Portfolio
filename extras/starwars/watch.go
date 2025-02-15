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
	Title            string
	VideoID          string
	Error            string
	SelectedChannels []SearchResult
	Interval         string
}

type SearchData struct {
	Results          []SearchResult
	SelectedChannels []SearchResult
	Error            string
}

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
	http.HandleFunc("/random", handleRandomVideo)

	log.Println("Server starting on http://localhost:8080")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		log.Fatal(err)
	}
}

func handleHome(w http.ResponseWriter, r *http.Request) {
	// Parse selected channels from query parameters if they exist
	selectedChannelIDs := r.URL.Query()["selected_channels"]
	var selectedChannels []SearchResult

	if len(selectedChannelIDs) > 0 {
		for _, id := range selectedChannelIDs {
			if channel, err := getChannelDetails(youtubeService, id); err == nil {
				selectedChannels = append(selectedChannels, channel)
			}
		}
	}

	data := struct {
		SelectedChannels []SearchResult
	}{
		SelectedChannels: selectedChannels,
	}

	templates.ExecuteTemplate(w, "index.html", data)
}

func handleSearch(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Redirect(w, r, "/", http.StatusSeeOther)
		return
	}

	query := r.FormValue("query")
	if query == "" {
		templates.ExecuteTemplate(w, "index.html", map[string]string{"Error": "Please enter a search query"})
		return
	}

	// Get selected channels from the form
	selectedChannelIDs := r.Form["selected_channels"]
	var selectedChannels []SearchResult

	if len(selectedChannelIDs) > 0 {
		for _, id := range selectedChannelIDs {
			if channel, err := getChannelDetails(youtubeService, id); err == nil {
				selectedChannels = append(selectedChannels, channel)
			}
		}
	}

	results, err := searchChannels(youtubeService, query)
	if err != nil {
		data := SearchData{
			Error:            "Error searching for channels: " + err.Error(),
			SelectedChannels: selectedChannels,
		}
		templates.ExecuteTemplate(w, "results.html", data)
		return
	}

	data := SearchData{
		Results:          results,
		SelectedChannels: selectedChannels,
	}
	templates.ExecuteTemplate(w, "results.html", data)
}

func handleRandomVideo(w http.ResponseWriter, r *http.Request) {
	channelIDs := r.URL.Query()["channel_ids"]
	if len(channelIDs) == 0 {
		http.Redirect(w, r, "/", http.StatusSeeOther)
		return
	}

	// Randomly select a channel from the list
	selectedChannelID := channelIDs[rand.Intn(len(channelIDs))]

	videos, err := getAllVideos(youtubeService, selectedChannelID)
	if err != nil {
		templates.ExecuteTemplate(w, "index.html", map[string]string{"Error": "Error fetching videos: " + err.Error()})
		return
	}

	if len(videos) == 0 {
		templates.ExecuteTemplate(w, "index.html", map[string]string{"Error": "No videos found for this channel"})
		return
	}

	index := rand.Intn(len(videos))
	video := videos[index]

	duration, err := getVideoDuration(youtubeService, video.Snippet.ResourceId.VideoId)
	if err != nil {
		templates.ExecuteTemplate(w, "index.html", map[string]string{"Error": "Error fetching video duration: " + err.Error()})
		return
	}

	start, end := getRandomInterval(duration)

	// Get channel details for all selected channels
	var selectedChannels []SearchResult
	for _, id := range channelIDs {
		channel, err := getChannelDetails(youtubeService, id)
		if err == nil {
			selectedChannels = append(selectedChannels, channel)
		}
	}

	data := VideoData{
		Title:            video.Snippet.Title,
		VideoID:          video.Snippet.ResourceId.VideoId,
		SelectedChannels: selectedChannels,
		Interval:         fmt.Sprintf("%s - %s", start, end),
	}

	templates.ExecuteTemplate(w, "index.html", data)
}

func getChannelDetails(service *youtube.Service, channelID string) (SearchResult, error) {
	call := service.Channels.List([]string{"snippet"}).Id(channelID)
	response, err := call.Do()
	if err != nil {
		return SearchResult{}, err
	}
	if len(response.Items) == 0 {
		return SearchResult{}, fmt.Errorf("channel not found")
	}

	return SearchResult{
		ChannelTitle: response.Items[0].Snippet.Title,
		ChannelID:    channelID,
	}, nil
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
