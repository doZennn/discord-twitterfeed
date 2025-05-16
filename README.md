# discord-twitterfeed
Simple Discord script that gets latest tweets then sends it to a Discord channel using a webhook.  
All the existing Discord bots are either paid, overengineered, or for some reason use the official Twitter API.  

Run this using a cron job or something:
```
*/5 * * * * /var/discord-twitterfeed/discord-twitterfeed.sh "zoomplatform" "https://discord.com/api/webhooks/[...]"
```