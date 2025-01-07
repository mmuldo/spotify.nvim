local M = {}

local DEFAULT_SCOPES = {
    "ugc-image-upload",
    "user-read-playback-state",
    "user-modify-playback-state",
    "user-read-currently-playing",
    "app-remote-control",
    "streaming",
    "playlist-read-private",
    "playlist-read-collaborative",
    "playlist-modify-private",
    "playlist-modify-public",
    "user-follow-modify",
    "user-follow-read",
    "user-read-playback-position",
    "user-top-read",
    "user-read-recently-played",
    "user-library-modify",
    "user-library-read",
    "user-read-email",
    "user-read-private",
}
local DEFAULT_REDIRECT_URI_PORT = 8888

---@class spotify.Opts
---@field client_id string
---@field client_secret string
---@field scopes? string[]: https://developer.spotify.com/documentation/web-api/concepts/scopes; default is all scopes
---@field auth_redirect_uri_port? integer: after authenticating, redirects to http://localhost:{auth_redirect_uri_port}/callback with auth code; default is 8888

---@param opts spotify.Opts
M.setup = function(opts)
    if not opts.client_id then
        error("Spotify Init: client_id not specified")
    end

    if not opts.client_secret then
        error("Spotify Init: client_secret not specified")
    end

    local scopes = opts.scopes or DEFAULT_SCOPES
    local redirect_uri_port = opts.auth_redirect_uri_port or DEFAULT_REDIRECT_URI_PORT

    require("spotify.auth").authenticate(
        opts.client_id,
        opts.client_secret,
        scopes,
        redirect_uri_port
    )

    require("spotify.api").set_client(opts.client_id, opts.client_secret)
end

return M
