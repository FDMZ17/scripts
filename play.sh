#!/bin/bash

DL=$1

# Function to download a file from the given URL
download() {
    clear
    printf "\033[2K\r\033[1;32mDownloading from $3 >>\033[0m\n%s\n"
    if [ "$DL" = "-d" ]; then
        axel -a -k -n 10 --header=Referer:"$1" "$2" -o "$url.mp4"
    fi
    ch=$(printf "play\ndownload" | fzf)
    [ -z "$ch" ] && exit 0
    printf "\033[2K\r\033[1;32m${ch}ing ($3) video link>>\n\033[0m"
    if [ "$ch" = "play" ]; then
        mpv "$2"
        exit 0
    fi
    if [ "$ch" = "download" ]; then
        axel -a -k -n 10 --header=Referer:"$1" "$2" -o "$url.mp4"
    fi
    if [ "$ch" = "skip" ]; then
        return
    fi
    exit 0
}

# Base URL of the website
base_url="https://gogohd.net"

# Search URL of the website
search_url="https://gogohd.net/search.html?keyword="

# User agent string to use when making requests
agent="Mozilla/5.0 (X11; Linux x86_64; rv:99.0) Gecko/20100101 Firefox/100.0"

# Trap signals to exit cleanly
trap "exit 0" INT HUP

# Read the name of the anime to search for
read -p "Enter the name of the anime you want to search for: " anime_name
anime_name_clean=$(echo "$anime_name" | cut -d ' ' -f1)

# Exit if no anime name was entered
[ -z "$anime_name" ] && exit 0

# Display the search term
printf "\033[1;35mSearching for: $anime_name\n\033[1;36mLoading search results.."

# Search for the anime and select the URL
urlo=$(curl -A "$agent" -s "${search_url}${anime_name_clean}" | sed -nE 's_.*<a href="/videos/([^"]*)">_\1_p' | fzf)

# Exit if no URL was selected
[ -z "$urlo" ] && exit 0

# Display the selected URL
printf "\033[1;35mSelected $url\n\033[1;36mLoading Episode.."

# Get the embed URL from the selected anime page
refr=$(curl -A "$agent" -s "$base_url/videos/$urlo" | sed -nE 's/.*iframe src="(.*)" al.*/\1/p')

# Display a message while fetching embed links
printf "\33[2K\r\033[1;34mFetching Embed links"

# Parse the episode number from the URL
episode_num=$(echo "$urlo" | grep -o -E 'episode-[0-9]+' | sed -E 's/episode-([0-9]+)/\1/')

# Iterate over the specified number of episodes
for ((i = 1; i <= $episode_num; i++)); do
    # Update the URL to the current episode
    url="${urlo%[0-9]}2"

    # Get the embed URL for the current episode
    refr=$(curl -A "$agent" -s "$base_url/videos/$url" | sed -nE 's/.*iframe src="(.*)" al.*/\1/p')

    # Display a message while fetching embed links
    printf "\33[2K\r\033[1;34mFetching Embed links for episode $i"

    # Get the list of embed links for the current episode
    resp="$(curl -A "$agent" -s "https:$refr" | sed -nE 's/.*class="container-(.*)">/\1/p ; s/.*class="video-item-title" title="(.*)">.*/\1/p')"

    fb_link=$(printf "$resp" | sed -n "s_.*fembed.*/v/__p")
    printf "\n\033[1;34mFetching xstreamcdn links <\033[0m $fb_link"
    [ -z "$fb_link" ] || fb_video=$(curl -A "$agent" -s -X POST "https://fembed-hd.com/api/source/$fb_link" -H "x-requested-with:XMLHttpRequest" | sed -e 's/\\//g' -e 's/.*data"://' | tr "}" "\n" | sed -nE 's/.*file":"(.*)","label.*/\1/p' | tail -1)
    [ -z "$fb_video" ] && printf "\33[2K\r\033[1;31m unable to fetch xstreamcdn link\033[0m" || download "https://fembed-hd.com/v/$fb_link" "$fb_video" "Xstreamcdn"

done
