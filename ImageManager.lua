local HttpService = cloneref(game:GetService("HttpService"))

local ImageManager = {}
ImageManager.Cache = {}

ImageManager.Config = {
    Folder = "ImageManagerCache",
    APIType = "Direct",
    UseFuncAdv = true,
    TypeAssetDownload = ""
}

local function EnsureFolder()
    local folder = ImageManager.Config.Folder
    if not isfolder(folder) then
        makefolder(folder)
    end
end

local function GuessExtension(link)
    if ImageManager.Config.TypeAssetDownload ~= "" then
        return ImageManager.Config.TypeAssetDownload
    end
    local ext = link:match("%.(%a+)$")
    return ext or "png"
end

local function ResolveUrl(id, link)
    local APIType = ImageManager.Config.APIType

    if APIType == "Roblox" and id and tostring(id) ~= "" then
        return "https://assetdelivery.roblox.com/v1/asset/?id="..tostring(id)
    elseif APIType == "Discord" then
        return link
    end

    return link
end

local function DownloadAdvanced(url)
    local req = (syn and syn.request) or (http and http.request) or request or http_request
    if not req then return nil end
    local ok, res = pcall(req, { Url = url, Method = "GET" })
    if ok and res and res.Body then
        return res.Body
    end
    return nil
end

local function DownloadBasic(url)
    local ok, res = pcall(function()
        return HttpService:GetAsync(url)
    end)
    if ok then return res end

    ok, res = pcall(game.HttpGet, game, url)
    if ok then return res end

    return nil
end

function ImageManager.AddAsset(name, id, link)
    EnsureFolder()
    local ext = GuessExtension(link or "")
    local path = ImageManager.Config.Folder.."/"..name.."."..ext

    if isfile(path) then
        ImageManager.Cache[name] = path
        return path
    end

    local url = ResolveUrl(id, link)
    local data

    if ImageManager.Config.UseFuncAdv then
        data = DownloadAdvanced(url)
    end

    if not data then
        data = DownloadBasic(url)
    end

    if not data then
        warn("[ImageManager] Failed to download: "..tostring(name))
        return nil
    end

    writefile(path, data)

    local verify = readfile(path)
    if not verify or #verify == 0 then
        warn("[ImageManager] Write verification failed: "..tostring(name))
    end

    ImageManager.Cache[name] = path
    return path
end

function ImageManager.GetAsset(name)
    local path = ImageManager.Cache[name]

    if not path or not isfile(path) then
        warn("[ImageManager] Asset not cached: "..tostring(name))
        return ""
    end

    if ImageManager.Config.UseFuncAdv and getcustomasset then
        local ok, contentId = pcall(getcustomasset, path)
        if ok and contentId then
            return contentId
        end
    end

    return "rbxasset://"..path
end

function ImageManager.GetAssetRaw(name)
    local path = ImageManager.Cache[name]

    if not path or not isfile(path) then
        warn("[ImageManager] Asset not cached: "..tostring(name))
        return nil
    end

    return readfile(path)
end

function ImageManager.ClearCache()
    if isfolder(ImageManager.Config.Folder) then
        delfolder(ImageManager.Config.Folder)
    end
    ImageManager.Cache = {}
end

getgenv().ImageManager = ImageManager

return ImageManager
