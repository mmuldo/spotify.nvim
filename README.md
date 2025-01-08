# `spotify.nvim`

Control Spotify from Neovim: one step closer to the Neovimux distribution all
Emacs users fear...

## Features
* Make calls to the Spotify Web API with
    ```lua
    local response = require("spotify.api").call(endpoint, method, body)
    ```
* ...I guess that's it

## Quickstart

Let's cut to the chase.

1. Create a [Spotify developer app](https://developer.spotify.com/dashboard) 
with a redirect URI of http://localhost:8888/callback and
copy the Client ID and Client Secret.
2. Add the following somewhere in your Neovim config:
    ```lua
    require("spotify").setup({
        client_id = "CLIENT_ID",
        client_secret = "CLIENT_SECRET",
    })
    ```
3. Create a function you find useful:
    ```lua
    local function new_spotify_playlist()
        local playlists_endpoint = "/me/playlists"
        local method = "post"
        local playlist_body = {
            name = "spotify.nvim",
            description = "omg i created this with spotify.nvim???",
            public = true
        }
        return require("spotify.api").call(playlists_endpoint, method, playlist_body)
    end
    ```
4. Bind your function to a keymap:
    ```lua
    vim.keymap.set("n", "<leader>mnp", function()
        local new_playlist = new_spotify_playlist()
        vim.notify(vim.inspect(new_playlist))
    end)
    ```
5. Repeat steps 3 and 4.

## Installation

### Lazy

```lua
return {
    "mmuldo/spotify.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim"
    },
    config = function()
        -- if you're a security freak.
        -- i'm just spitballing here:
        local client_secret = vim.fn.system("pass spotify.nvim/client-secret")

        require("spotify").setup({
            client_id = "CLIENT_ID",
            client_secret = client_secret
        })
    end
}
```

## Wait, what is this?

This plugin provides a means of interacting with the Spotify Web API in
Neovim. I'd like to see someone make such a thing in VSC\*de!

The idea is as follows. Calling
```lua
require("spotify").setup({
    client_id = "CLIENT_ID",
    client_secret = "CLIENT_SECRET",
})
```
handles all the Spotify auth shenanigans. After running the setup, you can then
run something of the form
```lua
local response = require("spotify.api").call(endpoint, method, body)
```
which will handle any auth token refreshing if necessary and then query the
specified API endpoint.

### FAQs

If you're curious, the answer is yes: I did in fact recently watch the
[Pharell Williams Lego Movie](https://www.imdb.com/title/tt31064841/) and I
did in fact enjoy it. It did in fact remind me what a good producer/musician he
is and it did in fact result in me throwing on a [Spotify playlist of songs he's
produced](https://open.spotify.com/playlist/3gC3qkmGsyEMIfgsiynDPP?si=1fdfc537620a47a0)
while working one day. It was in fact chock-full of bangers which did in fact
require me to hit the three-fingered mac swipe over to my Spotify window, add
the track to my Liked Songs playlist, and three-fingered swipe back to my
Neovim window many, many times during my work session.
This did in fact impede my flow state and did in fact cause me to take more
time than usual to complete my work.
I did in fact come to the conlusion the the solution was in fact to waste
many more hours of time learning about the Spotify Web API's auth workflows
and integrating the API into Neovim all so that I could map
`require("spotify.api").like_current_track()` to a keybinding, enabling
me to add Spotify tracks to my Liked Songs playlist without having to leave
Neovim. That did in fact all happen.

### Where is this plugin going?

I'm sure you already have ideas for features that could be implemented for this plugin.
For one, I think it could beautifully integrate with telescope to
enable searching for and playing things on Spotify from within Neovim.
That said, Spotify is vast in its use cases.
Personally, I tend to listen to albums all the way through; in that case,
creating an album-search picker would suit me.
You, on the other hand, might prefer listening to a song and then subsequently
letting Spotify play the song's radio; in that case,
a track-search picker followed by a track-radio player would be suitable.

Because of these endless possibilities, I think the best future for this plugin
is to be feature-scarce: just a `require("spotify.api").call` function with a
few other functions to serve as examples.
Instead of requesting new features, users are encouraged to define their own
custom Spotify API calls within their configuration--and obviously share
their config to inspire others!

## Actual FAQs

### Where do I get a Client ID and Secret?

Create a Spotify developer account if you haven't already,
goto your [dashboard](https://developer.spotify.com/dashboard), and click
"Create App".

Fill out the form and for "Redirect URIs" add
* http://localhost:8888/callback

You can use another port if you would like, but be sure to specify the
`auth_redirect_uri_port` parameter in the `setup` function.

### Can you provide a full example without being facetious?

```lua
-- /path/to/lazy/plugins/spotify.lua
local function get_device_id()
    local device_id
    local devices = require("spotify.api").call("/me/player/devices").devices
    local active_devices = vim.tbl_filter(function(device) return device.is_active end, devices)

    if #active_devices > 0 then
        device_id = active_devices[1].id
    elseif #devices > 0 then
        device_id = devices[1].id
    else
        vim.notify("no spotify devices found", vim.log.levels.WARN)
        device_id = nil
    end

    return device_id
end

local function play_produced_by_neputunes_playlist()
    local device_id = get_device_id()
    if not device_id then
        vim.notify("open spotify first!", vim.log.levels.ERROR)
        return
    end

    require("spotify.api").call("/me/player/play?device_id=" .. device_id, "put", {
        context_uri = "spotify:playlist:3gC3qkmGsyEMIfgsiynDPP"
    })

    print("playing \"Produced by: The Neptunes\"")
end

return {
    "mmuldo/spotify.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim"
    },
    config = function()
        require("spotify").setup({
            client_id = "CLIENT_ID",
            client_secret = "CLIENT_SECRET"
        })

        vim.keymap.set("n", "<leader>mpn", play_produced_by_neputunes_playlist)
        vim.keymap.set("n", "<leader>mc", require("spotify.api").currently_playing)
        vim.keymap.set("n", "<leader>ml", require("spotify.api").like_current_track)
    end
}
```

## HELP!!!

### Vimdoc

```
:h spotify.nvim
```

### Spotify Web API Documentation

https://developer.spotify.com/documentation/web-api
