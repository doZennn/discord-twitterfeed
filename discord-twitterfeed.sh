#!/usr/bin/env bash

#########################
# License: Unlicense
# This is free and unencumbered software released into the public domain.
# For more information, please refer to <http://unlicense.org/>
#########################

# env vars or default to args
TWITTER_USERNAME="${TWITTER_USERNAME:-$1}"
WEBHOOK_URL="${WEBHOOK_URL:-$2}"
FILTER_SELF_RETWEETS="${FILTER_SELF_RETWEETS:-0}"

if [[ -z "$WEBHOOK_URL" ]] || [[ -z "$TWITTER_USERNAME" ]] ; then
    echo "Usage can be via env vars or args."
    echo "Arguments:"
    echo "$0 <twitter_username> <discord_webhook_url>"
    echo ""
    echo "Environment variables:"
    echo "  TWITTER_USERNAME: Twitter username to fetch tweets from"
    echo "  WEBHOOK_URL: Discord webhook URL to send tweets to"
    echo "  FILTER_SELF_RETWEETS: Do not post self retweets (default: 0)"
    exit 1
fi

cd "$(dirname "$0")" || exit

read_saved_id() {
    if [ -f last_saved_id.txt ]; then
        cat last_saved_id.txt
    else
        echo "0"
    fi
}

# Params: tweet_url, ?username, ?avatar
send_discord_webhook() {
    _tweet_url="$1"
    _username="$2"
    _avatar="$3"
    _json_payload=$(jq -n --arg content "$_tweet_url" '{"content": $content}')
    if [ -n "$_username" ]; then
        _json_payload=$(echo "$_json_payload" | jq --arg username "$_username" '. += {"username": $username}')
    fi
    if [ -n "$_avatar" ]; then
        _json_payload=$(echo "$_json_payload" | jq --arg avatar "$_avatar" '. += {"avatar_url": $avatar}')
    fi
    curl -X POST -H "Content-Type: application/json" -d "$_json_payload" "$WEBHOOK_URL"
}

# Clean URLs to use fxtwitter
# Params: tweet_url
clean_url() {
    _url="$1"
    echo "$_url" | sed -e 's/\/\/twitter\.com/\/\/fixvx.com/g' | sed -e 's/\/\/x\.com/\/\/fixvx.com/g'
}

# Params: _last_id
check_posts() {
    _last_id="$1"

    _response=$(curl -s "https://api.vxtwitter.com/$TWITTER_USERNAME?with_tweets" -H "Accept: application/json") 
    # exit if response is not 200
    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
        echo "Error: Failed to fetch data from the API."
        exit 1
    fi

    _json_output=$(echo "$_response" | jq)
    _avatar=$(echo "$_json_output" | jq -r '.profile_image_url')
    _name=$(echo "$_json_output" | jq -r '.name')

    _post_count=$(echo "$_json_output" | jq '.latest_tweets | length')
    _posts=$(echo "$_json_output" | jq -r '.latest_tweets[]')

    # Get all tweets after last tweet id
    if [ "$_post_count" -gt 0 ]; then
        # Get tweet IDs coming after last tweet
        _posts_filtered=$(echo "$_posts" | jq -r --arg last_id "$_last_id" 'select(.tweetID > $last_id)')

        # filter out self retweets
        if [ "$FILTER_SELF_RETWEETS" -eq 1 ]; then
            echo "Filtering out self retweets..."
            _posts_filtered=$(echo "$_posts_filtered" | jq -r --arg username "$TWITTER_USERNAME" 'select(.text | test("^RT @(?i)\($username)") | not)')
        fi

        _post_ids=$(echo "$_posts_filtered" | jq -r '.tweetID') 
        
        if [ -z "$_post_ids" ]; then
            echo "No new posts found."
            exit 0
        fi

        # Loop over tweet URLs and send them to Discord in reverse
        for _post_id in $(echo "$_post_ids" | tac); do
            # get tweet info
            _post=$(echo "$_posts" | jq -r --arg tweet_id "$_post_id" 'select(.tweetID == $tweet_id)')
            _post_url="$(echo "$_post" | jq -r '.tweetURL')"

            echo "$_post_url"
            send_discord_webhook "$(clean_url "$_post_url")" "$_name" "$_avatar"

            # save the last tweet id to file
            echo "$_post_id" > last_saved_id.txt
        done
    else
        echo "No new posts found."
        exit 0
    fi
}

check_posts "$(read_saved_id)"
