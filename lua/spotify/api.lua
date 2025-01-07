local M = {}

local SPOTIFY_API_BASE_URL = "https://api.spotify.com/v1"

---@class spotify.api.Track
---@field artists string[]
---@field album string
---@field name string
---@field release_date string
---@field progress? string
---@field is_playing? boolean

---@class spotify.api.Client
---@field client_id string
---@field client_secret string
---
---@type spotify.api.Client
local client = {
    client_id = "",
    client_secret = "",
}

---@return boolean
local client_initialized = function()
    return #client.client_id > 0 and #client.client_secret > 0
end

---@param client_id string
---@param client_secret string
M.set_client = function(
    client_id,
    client_secret
)
    client.client_id = client_id
    client.client_secret = client_secret
end

local function get_headers(access_token)
    return {
        Authorization = "Bearer " .. access_token,
        ["Content-Type"] = "application/json",
    }
end

---@param endpoint string
---@param method? string
---@param body? any
---@return any
M.call = function(
    endpoint,
    method,
    body
)
    if not client_initialized() then
        error("Spotify Init: client not yet initialized, please specify client_id and client_secret")
    end

    local http = require("plenary.curl")
    local url = SPOTIFY_API_BASE_URL .. endpoint
    local access_token = require("spotify.auth").authenticate(
        client.client_id,
        client.client_secret
    ).access_token
    local headers = get_headers(access_token)

    method = method or "get"
    local response = http[method]({
        url = url,
        headers = headers,
        body = body and vim.fn.json_encode(body) or nil,
    })

    if response.status >= 200 and response.status < 300 then
        return #response.body > 0 and vim.fn.json_decode(response.body) or nil
    else
        error("Spotify API: " .. response.body)
    end
end

local function milliseconds_to_display_time(ms)
    local total_seconds = math.floor(ms / 1000)
    local hours = math.floor(total_seconds / 3600)
    local minutes = math.floor((total_seconds % 3600) / 60)
    local seconds = total_seconds % 60

    local formatted_time = ""
    if hours > 0 then
        formatted_time = string.format("%02d:%02d:%02d", hours, minutes, seconds)
    elseif minutes > 0 then
        formatted_time = string.format("%02d:%02d", minutes, seconds)
    else
        formatted_time = string.format("%02d", seconds)
    end

    return formatted_time
end

---@return any
local function currently_playing()
    return M.call("/me/player/currently-playing")
end

M.currently_playing = function()
    local response = currently_playing()
    if not response then
        vim.notify("Spotify API: nothing currently playing", vim.log.levels.WARN)
        return
    end

    if response.currently_playing_type == "track" then
        ---@type spotify.api.Track
        local track = {
            artists = vim.tbl_map(function(artist)
                return artist.name
            end, response.item.artists),
            album = response.item.album.name,
            name = response.item.name,
            release_date = response.item.album.release_date,
            progress = string.format(
                "%s/%s",
                milliseconds_to_display_time(response.progress_ms),
                milliseconds_to_display_time(response.item.duration_ms)
            ),
            is_playing = response.is_playing
        }

        vim.notify(vim.inspect(track))
    else
        vim.notify(vim.inspect(response))
    end
end

M.like_current_track = function ()
    local response = currently_playing()
    if response.currently_playing_type ~= "track" then
        vim.notify("Spotify API: current playback is not a track", vim.log.levels.WARN)
        return
    end

    local track = response.item
    M.call("/me/tracks?ids=" .. track.id, "put")
    vim.notify(string.format(
        "liked %s by %s off %s",
        track.name,
        track.artists[1].name,
        track.album.name
    ))
end

return M
