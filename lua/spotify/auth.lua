local M = {}

local SPOTIFY_ACCOUNTS_URL = "https://accounts.spotify.com"
local AUTH_URL_FORMAT = SPOTIFY_ACCOUNTS_URL .. "/authorize?response_type=code&client_id=%s&scope=%s&redirect_uri=%s"
local REDIRECT_URI_FORMAT = "http://localhost:%d/callback"
local REDIRECT_SUCCESS_MESSAGE = "success"
local SPACE_URL_CHAR = "%20"
local LOCALHOST = "127.0.0.1"
local HTTP_CALLBACK_CODE_REQUEST_REGEX = "code=([%w_-]+)"
local TOKEN_URL = SPOTIFY_ACCOUNTS_URL .. "/api/token"
local TOKEN_REQUEST_HEADERS = {
    ["Content-Type"] = "application/x-www-form-urlencoded",
}
local TOKEN_REQUEST_BODY_FORMAT = "grant_type=%s&%s=%s&client_id=%s&client_secret=%s"
local TOKEN_PATH = vim.fn.stdpath("config") .. "/.spotify_tokens.json"
local REFRESH_TOKENS_WAIT_TIME_MS = 10
local SUCCESS_RESPONSE_STATUS_CODE = 200

---@class spotify.auth.State
---@field scopes string[]
---@field redirect_uri_port integer
---@field refreshing_tokens boolean

---@class spotify.auth.Tokens
---@field access_token string
---@field refresh_token string
---@field expires_at integer
---@type spotify.auth.State
local state = {
    scopes = {},
    redirect_uri_port = -1,
    refreshing_tokens = false
}

local function await_tokens_refresh()
    while state.refreshing_tokens do
        vim.wait(REFRESH_TOKENS_WAIT_TIME_MS)
    end
end

--- Executes a shell command 'safely' and validates its success.
---
---@param cmd string: The shell command to be executed.
---@throws error if the command execution fails.
local function safe_execute(cmd)
    local success, reason, code = os.execute(cmd)
    if not success then
        error(string.format("Command failed: %s (Reason: %s, Code: %s)", cmd, reason, code))
    end
end

local function open_in_browser(url)
    local cmd
    if vim.fn.has("mac") == 1 then
        cmd = string.format("open '%s'", url)
    elseif vim.fn.has("unix") == 1 then
        cmd = string.format("xdg-open '%s'", url)
    elseif vim.fn.has("win32") == 1 then
        cmd = string.format("start '%s'", url)
    else
        error("Spotify Auth: Unsupported OS")
    end

    safe_execute(cmd)
end

---@param client_id string
---@param scopes string[]
---@param redirect_uri_port integer
---@return string
local function get_auth_url(client_id, scopes, redirect_uri_port)
    local redirect_uri = string.format(
        REDIRECT_URI_FORMAT,
        redirect_uri_port
    )

    return string.format(
        AUTH_URL_FORMAT,
        client_id,
        table.concat(scopes, SPACE_URL_CHAR),
        redirect_uri
    )
end

---@param port integer
---@param with_auth_code_callback fun(code: string)
local function start_redirect_server(
    port,
    with_auth_code_callback
)
    local server = vim.uv.new_tcp()
    server:bind(LOCALHOST, port)

    server:listen(1, function(err)
        assert(not err, err)

        local client = vim.uv.new_tcp()
        server:accept(client)
        client:read_start(function(read_err, chunk)
            assert(not read_err, read_err)
            if chunk then
                -- Parse the code from the URL
                local code = chunk:match(HTTP_CALLBACK_CODE_REQUEST_REGEX)
                if code then
                    client:write(REDIRECT_SUCCESS_MESSAGE)
                    client:shutdown()
                    client:close()
                    server:close()
                    with_auth_code_callback(code)
                end
            end
        end)
    end)
end

---@param filepath string
local function set_secure_file_permissions(filepath)
    local cmd
    if vim.fn.has("mac") == 1 or vim.fn.has("unix") == 1 then
        cmd = "chmod 600 " .. filepath
    elseif vim.fn.has("win32") == 1 then
        cmd = string.format('icacls "%s" /grant:r "%s:(R,W)"', filepath, os.getenv("USERNAME"))
    else
        error("Spotify Auth: Unsupported OS")
    end
    os.execute(cmd)
end

---@param tokens spotify.auth.Tokens
local function save_tokens(tokens)
    local file = io.open(TOKEN_PATH, "w")
    if file then
        file:write(vim.fn.json_encode(tokens))
        file:close()

        set_secure_file_permissions(TOKEN_PATH)
    else
        error("Spotify Auth: Failed to open token file for writing.")
    end
end

---@return spotify.auth.Tokens | nil
local function load_tokens()
    local file, err = io.open(TOKEN_PATH, "r")
    if not file then
        vim.notify(
            "Failed to open token file: " .. (err or "unknown error"),
            vim.log.levels.ERROR
        )
        return nil
    end

    local content = file:read("*a")
    file:close()

    local ok, tokens = pcall(vim.fn.json_decode, content)
    if not ok then
        vim.notify(
            "Failed to decode token file: " .. tokens, -- error message is from `pcall`.
            vim.log.levels.ERROR
        )
        return nil
    end

    return tokens
end

---@param grant_type string
---@param credential_key string
---@param credential_value string
---@param client_id string
---@param client_secret string
---@param redirect_uri_port? integer
local function save_auth_tokens(
    client_id,
    client_secret,
    grant_type,
    credential_key,
    credential_value,
    redirect_uri_port
)
    local http = require("plenary.curl")
    local redirect_uri_param = redirect_uri_port and
        "&redirect_uri=" .. string.format(REDIRECT_URI_FORMAT, redirect_uri_port) or ""
    local body = string.format(
        TOKEN_REQUEST_BODY_FORMAT,
        grant_type,
        credential_key,
        credential_value,
        client_id,
        client_secret
    ) .. redirect_uri_param
    http.post({
        url = TOKEN_URL,
        headers = TOKEN_REQUEST_HEADERS,
        body = body,
        callback = function(response)
            state.refreshing_tokens = true
            vim.schedule(function()
                if response.status == SUCCESS_RESPONSE_STATUS_CODE then
                    local data = vim.fn.json_decode(response.body)
                    local tokens = {
                        access_token = data.access_token,
                        refresh_token = data.refresh_token and data.refresh_token or credential_value,
                        expires_at = os.time() + data.expires_in
                    }
                    save_tokens(tokens)
                else
                    error("Spotify Auth: error exchanging code: response.body")
                end
                state.refreshing_tokens = false
            end)
        end
    })
end

---@param client_id string
---@param client_secret string
---@param auth_code string
---@param redirect_uri_port integer
local function exchange_code_for_token(
    client_id,
    client_secret,
    auth_code,
    redirect_uri_port
)
    save_auth_tokens(
        client_id,
        client_secret,
        "authorization_code",
        "code",
        auth_code,
        redirect_uri_port
    )
end

---@param client_id string
---@param client_secret string
---@param refresh_token string
local function refresh_tokens(
    client_id,
    client_secret,
    refresh_token
)
    save_auth_tokens(
        client_id,
        client_secret,
        "refresh_token",
        "refresh_token",
        refresh_token
    )
end

---@param client_id string
---@param client_secret string
---@param scopes string[]
---@param redirect_uri_port integer
local function authenticate(
    client_id,
    client_secret,
    scopes,
    redirect_uri_port
)
    start_redirect_server(redirect_uri_port, function(auth_code)
        exchange_code_for_token(client_id, client_secret, auth_code, redirect_uri_port)
    end)

    local auth_url = get_auth_url(client_id, scopes, redirect_uri_port)
    open_in_browser(auth_url)
end

---refreshes tokens if expired;
---if tokens have not yet been retrieved, authenticates with spotify
---@param client_id string
---@param client_secret string
---@param scopes? string[]: required unless previously called with this paramter
---@param redirect_uri_port? integer: required unless previously called with this paramter
---@return spotify.auth.Tokens
M.authenticate = function(
    client_id,
    client_secret,
    scopes,
    redirect_uri_port
)
    local tokens = load_tokens();
    local tokens_valid = tokens and tokens.expires_at >= os.time()
    if tokens_valid then
        ---@diagnostic disable-next-line return-type-mismatch
        return tokens
    elseif tokens then
        refresh_tokens(client_id, client_secret, tokens.refresh_token)
        await_tokens_refresh()
        ---@diagnostic disable-next-line return-type-mismatch
        return load_tokens()
    end

    if scopes then
        state.scopes = scopes
    elseif #state.scopes == 0 then
        error("scopes not specified")
    end
    if redirect_uri_port then
        state.redirect_uri_port = redirect_uri_port
    elseif redirect_uri_port == -1 then
        error("redirect_uri_port not specified")
    end

    authenticate(
        client_id,
        client_secret,
        state.scopes,
        state.redirect_uri_port
    )
    await_tokens_refresh()
    ---@diagnostic disable-next-line return-type-mismatch
    return load_tokens()
end

return M
