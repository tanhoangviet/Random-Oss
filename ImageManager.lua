local function SafeService(name)
    local ok, service = pcall(game.GetService, game, name)
    if not ok or not service then return nil end

    if type(cloneref) == "function" then
        local cloneOk, cloned = pcall(cloneref, service)
        if cloneOk and cloned then
            return cloned
        end
    end

    return service
end

local HttpService = SafeService("HttpService")

local ImageManager = {}
ImageManager.Cache = {}

ImageManager.Config = {
    Folder = "ImageManagerCache",
    APIType = "Direct",
    UseFuncAdv = true,
    TypeAssetDownload = "",
    AutoConvertVideo = false,
    ConvertProvider = "CloudConvert",
    ConvertAPIKey = ""
}

local VideoFormats = {
    mp4 = true, mov = true, avi = true, mkv = true, flv = true,
    wmv = true, m4v = true, mpg = true, mpeg = true, ["3gp"] = true,
    ts = true, ogv = true, vob = true, m2ts = true
}

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then return false, nil end
    local ok, result = pcall(fn, ...)
    if ok then return true, result end
    return false, nil
end

local function HasFileSupport()
    return type(writefile) == "function"
        and type(readfile) == "function"
        and type(isfile) == "function"
        and type(isfolder) == "function"
        and type(makefolder) == "function"
end

local function EnsureFolder()
    if not HasFileSupport() then return end
    local folder = ImageManager.Config.Folder
    local ok, exists = SafeCall(isfolder, folder)
    if ok and not exists then
        SafeCall(makefolder, folder)
    end
end

local function GuessExtension(link)
    if ImageManager.Config.TypeAssetDownload ~= "" then
        return ImageManager.Config.TypeAssetDownload:lower()
    end
    local clean = (link or ""):gsub("%?.*", "")
    local ext = clean:match("%.([%a%d]+)$")
    return ext and ext:lower() or "png"
end

local function IsVideoFormat(ext)
    return VideoFormats[ext] == true
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

local function GetAdvancedRequest()
    local candidates = {
        request,
        http_request,
        (syn and syn.request),
        (http and http.request),
        (fluxus and fluxus.request),
        (krnl and krnl.request)
    }

    for _, fn in ipairs(candidates) do
        if type(fn) == "function" then
            return fn
        end
    end

    return nil
end

local function DownloadAdvanced(url)
    local req = GetAdvancedRequest()
    if not req then return nil end

    local ok, res = pcall(req, { Url = url, Method = "GET" })
    if ok and res and res.Body then
        return res.Body
    end

    return nil
end

local function DownloadBasic(url)
    if HttpService then
        local ok, res = pcall(function()
            return HttpService:GetAsync(url)
        end)
        if ok then return res end
    end

    local ok, res = pcall(game.HttpGet, game, url)
    if ok then return res end

    return nil
end

local function JSONEncode(data)
    if HttpService then
        local ok, res = pcall(function()
            return HttpService:JSONEncode(data)
        end)
        if ok then return res end
    end
    return nil
end

local function JSONDecode(text)
    if HttpService then
        local ok, res = pcall(function()
            return HttpService:JSONDecode(text)
        end)
        if ok then return res end
    end
    return nil
end

local ConvertProviders = {}

ConvertProviders.CloudConvert = function(req, sourceUrl, apiKey)
    local headers = {
        ["Authorization"] = "Bearer "..apiKey,
        ["Content-Type"] = "application/json"
    }

    local jobBody = JSONEncode({
        tasks = {
            ["import-1"] = { operation = "import/url", url = sourceUrl },
            ["convert-1"] = { operation = "convert", input = "import-1", output_format = "webm" },
            ["export-1"] = { operation = "export/url", input = "convert-1" }
        }
    })

    if not jobBody then return nil end

    local ok, jobRes = pcall(req, {
        Url = "https://api.cloudconvert.com/v2/jobs",
        Method = "POST",
        Headers = headers,
        Body = jobBody
    })

    if not ok or not jobRes or not jobRes.Body then return nil end

    local jobData = JSONDecode(jobRes.Body)
    if not jobData or not jobData.data then return nil end

    local jobId = jobData.data.id

    for _ = 1, 30 do
        task.wait(2)

        local pollOk, pollRes = pcall(req, {
            Url = "https://api.cloudconvert.com/v2/jobs/"..jobId,
            Method = "GET",
            Headers = headers
        })

        if pollOk and pollRes and pollRes.Body then
            local pollData = JSONDecode(pollRes.Body)

            if pollData and pollData.data then
                local status = pollData.data.status

                if status == "finished" then
                    for _, t in ipairs(pollData.data.tasks or {}) do
                        if t.name == "export-1" and t.result and t.result.files then
                            return t.result.files[1].url
                        end
                    end
                    return nil
                elseif status == "error" then
                    return nil
                end
            end
        end
    end

    return nil
end

local function ConvertToWebm(sourceUrl)
    if not ImageManager.Config.AutoConvertVideo then
        return nil
    end

    local req = GetAdvancedRequest()
    if not req then
        warn("[ImageManager] No advanced request function found, caching original video instead")
        return nil
    end

    if ImageManager.Config.ConvertAPIKey == "" then
        warn("[ImageManager] No ConvertAPIKey set, caching original video instead")
        return nil
    end

    local provider = ConvertProviders[ImageManager.Config.ConvertProvider]
    if not provider then
        warn("[ImageManager] Unknown ConvertProvider: "..tostring(ImageManager.Config.ConvertProvider))
        return nil
    end

    return provider(req, sourceUrl, ImageManager.Config.ConvertAPIKey)
end

function ImageManager.AddAsset(name, id, link)
    if not HasFileSupport() then
        warn("[ImageManager] Executor missing file functions, cannot cache assets")
        return nil
    end

    EnsureFolder()

    local ext = GuessExtension(link or "")
    local url = ResolveUrl(id, link)

    if IsVideoFormat(ext) then
        local converted = ConvertToWebm(url)
        if converted then
            url = converted
            ext = "webm"
        end
    end

    local path = ImageManager.Config.Folder.."/"..name.."."..ext

    local fileOk, exists = SafeCall(isfile, path)
    if fileOk and exists then
        ImageManager.Cache[name] = path
        return path
    end

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

    local writeOk = SafeCall(writefile, path, data)
    if not writeOk then
        warn("[ImageManager] Failed to write file: "..tostring(name))
        return nil
    end

    local verifyOk, verify = SafeCall(readfile, path)
    if not verifyOk or not verify or #verify == 0 then
        warn("[ImageManager] Write verification failed: "..tostring(name))
    end

    ImageManager.Cache[name] = path
    return path
end

function ImageManager.GetAsset(name)
    local path = ImageManager.Cache[name]

    if not path then
        warn("[ImageManager] Asset not cached: "..tostring(name))
        return ""
    end

    local fileOk, exists = SafeCall(isfile, path)
    if not fileOk or not exists then
        warn("[ImageManager] Cached file missing on disk: "..tostring(name))
        return ""
    end

    if ImageManager.Config.UseFuncAdv and type(getcustomasset) == "function" then
        local ok, contentId = SafeCall(getcustomasset, path)
        if ok and contentId then
            return contentId
        end
    end

    return "rbxasset://"..path
end

function ImageManager.GetAssetRaw(name)
    local path = ImageManager.Cache[name]

    if not path then
        warn("[ImageManager] Asset not cached: "..tostring(name))
        return nil
    end

    local fileOk, exists = SafeCall(isfile, path)
    if not fileOk or not exists then
        warn("[ImageManager] Cached file missing on disk: "..tostring(name))
        return nil
    end

    local ok, data = SafeCall(readfile, path)
    if ok then return data end
    return nil
end

function ImageManager.ClearCache()
    if type(isfolder) == "function" and type(delfolder) == "function" then
        local ok, exists = SafeCall(isfolder, ImageManager.Config.Folder)
        if ok and exists then
            SafeCall(delfolder, ImageManager.Config.Folder)
        end
    end
    ImageManager.Cache = {}
end

if type(getgenv) == "function" then
    getgenv().ImageManager = ImageManager
end

return ImageManager
