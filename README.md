# `spotify.nvim`

Let's cut to the chase.

```lua
require("spotify").setup({
    client_id = "CLIENT_ID",
    client_secret = "CONSIDER_GETTING_THIS_FROM_SOMETHING_SECURE_LIKE_PASS",
})

new_playlist = require("spotify.api").call(
    "/me/playlists",
    "post",
    {
        name = "spotify.nvm",
        description = "omg i created this with spotify.nvim???",
        public = true
    }
)

vim.notify(vim.inspect(new_playlist))

vim.keymap.set("n", "<leader>ml", require("spotify.api").like_current_track)
```

## Where do I get a Client ID and Secret?

Create a Spotify developer account if you haven't already,
goto your [dashboard](https://developer.spotify.com/dashboard), and click
"Create App".

Fill out the form and for "Redirect URIs", add
* http://localhost:8888/callback

You can use another port if you would like, but be sure to specify the
`auth_redirect_uri_port` parameter in the `setup` function.

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

## HELP!!!

```
:h spotify
```
