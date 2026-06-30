# ImageManager

A lightweight asset caching library for Roblox executors. Downloads images/assets once, caches them locally with `writefile`, and serves them back through `getcustomasset` so you never re-download the same asset twice.

Thư viện cache asset nhẹ dành cho Roblox executor. Tải asset về một lần, cache lại bằng `writefile`, và trả về thông qua `getcustomasset` để không bao giờ phải tải lại cùng một asset hai lần.

---

## 📖 Table of Contents / Mục Lục

1. [Installation / Cài Đặt](#installation--cài-đặt)
2. [Configuration / Cấu Hình](#configuration--cấu-hình)
3. [API Reference / Tài Liệu Hàm](#api-reference--tài-liệu-hàm)
4. [How It Works / Cách Hoạt Động](#how-it-works--cách-hoạt-động)
5. [Full Example / Ví Dụ Đầy Đủ](#full-example--ví-dụ-đầy-đủ)
6. [Notes & Requirements / Lưu Ý & Yêu Cầu](#notes--requirements--lưu-ý--yêu-cầu)

---

## Installation / Cài Đặt

**EN** — Load the library via `loadstring` from your raw script link:

**VI** — Load thư viện bằng `loadstring` từ link raw script của bạn:

```lua
local ImageManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/tanhoangviet/Random-Oss/refs/heads/main/ImageManager.lua"))()
```

---

## Configuration / Cấu Hình

**EN** — Set `ImageManager.Config` right after loading the library, before calling `AddAsset`.

**VI** — Set `ImageManager.Config` ngay sau khi load thư viện, trước khi gọi `AddAsset`.

```lua
ImageManager.Config = {
    Folder = "Hub Name",
    APIType = "Direct",
    UseFuncAdv = true,
    TypeAssetDownload = ""
}
```

| Field | Type | EN — Description | VI — Mô tả |
|---|---|---|---|
| `Folder` | string | Folder name used to store cached files on disk (created automatically). | Tên folder dùng để lưu file cache trên máy (tự tạo nếu chưa có). |
| `APIType` | string | `"Roblox"` resolves the asset through `assetdelivery.roblox.com` using the `id`. `"Direct"` or `"Discord"` (or anything else) uses the raw `link` as-is. | `"Roblox"` sẽ lấy asset qua `assetdelivery.roblox.com` dựa vào `id`. `"Direct"` hoặc `"Discord"` (hoặc bất kỳ giá trị nào khác) sẽ dùng thẳng `link` đã truyền vào. |
| `UseFuncAdv` | bool | `true` makes the library try `request` / `syn.request` / `http_request` first (works on high-level UNC/UNCs executors, returns raw binary data more reliably). Falls back to `HttpService:GetAsync` / `game.HttpGet` if unavailable or it fails. | `true` sẽ ưu tiên dùng `request` / `syn.request` / `http_request` (executor UNC/UNCs cao mới có, trả về dữ liệu nhị phân chuẩn hơn). Nếu không có hàm này hoặc lỗi thì tự fallback về `HttpService:GetAsync` / `game.HttpGet`. |
| `TypeAssetDownload` | string | Force a file extension for cached files (e.g. `"png"`, `"jpg"`). Leave as `""` to auto-detect the extension from the asset link. | Ép định dạng file khi cache (vd `"png"`, `"jpg"`). Để `""` thì thư viện tự đoán đuôi file từ link asset. |

---

## API Reference / Tài Liệu Hàm

### `ImageManager.AddAsset(name, id, link)`

**EN**
- `name` *(string)* — unique key to identify this asset later.
- `id` *(number/string, optional)* — Roblox asset id, only used when `APIType == "Roblox"`.
- `link` *(string)* — direct URL to the asset, used when `APIType` is anything other than `"Roblox"`, and also used to guess the file extension.
- Downloads the asset (if not already cached), saves it with `writefile`, verifies the write with `readfile`, and stores the local path in memory.
- Returns the local file path, or `nil` if the download failed.

**VI**
- `name` *(string)* — key dùng để định danh asset này, dùng lại khi `GetAsset`.
- `id` *(number/string, optional)* — id asset Roblox, chỉ dùng khi `APIType == "Roblox"`.
- `link` *(string)* — link trực tiếp tới asset, dùng khi `APIType` khác `"Roblox"`, và cũng dùng để đoán đuôi file.
- Tải asset về (nếu chưa cache), lưu bằng `writefile`, verify lại bằng `readfile`, và lưu đường dẫn local vào bộ nhớ.
- Trả về đường dẫn file local, hoặc `nil` nếu tải thất bại.

```lua
ImageManager.AddAsset("Logo", nil, "https://example.com/logo.png")
ImageManager.AddAsset("PlayerIcon", 123456789, "")
```

### `ImageManager.GetAsset(name)`

**EN** — Returns a content id you can set directly into an `Image` / `ImageColor3` property (via `getcustomasset` when `UseFuncAdv` is on, otherwise falls back to `"rbxasset://"..path`). Returns `""` and warns if the asset was never added or the cached file is missing.

**VI** — Trả về content id để set thẳng vào property `Image` / `ImageColor3` (qua `getcustomasset` nếu `UseFuncAdv` bật, nếu không thì fallback `"rbxasset://"..path`). Trả về `""` và cảnh báo nếu asset chưa từng được add hoặc file cache bị mất.

```lua
local AssetName = ImageManager.GetAsset("Logo")
imageLabel.Image = AssetName
```

### `ImageManager.GetAssetRaw(name)`

**EN** — Returns the raw file bytes via `readfile`, useful if you need to process the asset further (e.g. convert to base64) instead of just displaying it. Returns `nil` if not cached.

**VI** — Trả về raw bytes của file bằng `readfile`, hữu ích khi cần xử lý thêm asset (vd convert base64) thay vì chỉ hiển thị. Trả về `nil` nếu chưa được cache.

```lua
local raw = ImageManager.GetAssetRaw("Logo")
```

### `ImageManager.ClearCache()`

**EN** — Deletes the entire cache folder (`delfolder`) and clears the in-memory cache table. Use this when you want to force a fresh re-download of everything.

**VI** — Xoá toàn bộ folder cache (`delfolder`) và clear luôn bảng cache trong bộ nhớ. Dùng khi muốn ép tải lại toàn bộ asset từ đầu.

```lua
ImageManager.ClearCache()
```

---

## How It Works / Cách Hoạt Động

**EN**
1. `AddAsset` checks `isfile(path)` first — if the file already exists on disk, it skips downloading entirely and just registers the path in memory.
2. If not cached, it resolves the correct URL based on `APIType`, then downloads using the advanced HTTP method first (if `UseFuncAdv` is `true`), falling back to the basic method otherwise.
3. The downloaded data is saved with `writefile`, then immediately re-read with `readfile` to confirm the write succeeded.
4. `GetAsset` converts the cached file into a usable content id with `getcustomasset`, so executors that support it never need to re-upload/re-stream the asset to Roblox's CDN.

**VI**
1. `AddAsset` check `isfile(path)` trước — nếu file đã tồn tại trên máy, bỏ qua bước tải luôn và chỉ đăng ký lại path vào bộ nhớ.
2. Nếu chưa cache, hàm sẽ resolve URL đúng dựa theo `APIType`, sau đó tải bằng phương thức HTTP nâng cao trước (nếu `UseFuncAdv` là `true`), fallback về phương thức cơ bản nếu không có/lỗi.
3. Dữ liệu tải về được lưu bằng `writefile`, sau đó đọc lại ngay bằng `readfile` để xác nhận ghi file thành công.
4. `GetAsset` chuyển file đã cache thành content id dùng được ngay bằng `getcustomasset`, nên các executor hỗ trợ hàm này sẽ không cần upload/stream lại asset lên CDN Roblox.

---

## Full Example / Ví Dụ Đầy Đủ

```lua
local ImageManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/tanhoangviet/Random-Oss/refs/heads/main/ImageManager.lua"))()

ImageManager.Config = {
    Folder = "MyHub",
    APIType = "Direct",
    UseFuncAdv = true,
    TypeAssetDownload = ""
}

ImageManager.AddAsset("Logo", nil, "https://example.com/logo.png")
ImageManager.AddAsset("CloseIcon", nil, "https://example.com/close.png")

local logoImage = ImageManager.GetAsset("Logo")
local closeIconImage = ImageManager.GetAsset("CloseIcon")

print(logoImage, closeIconImage)
```

---

## Notes & Requirements / Lưu Ý & Yêu Cầu

**EN**
- Requires executor file functions: `writefile`, `readfile`, `isfile`, `isfolder`, `makefolder`, `delfolder`.
- `getcustomasset` is required for `UseFuncAdv` to give a clean content id; without it, `GetAsset` falls back to `"rbxasset://"..path`, which still works on most executors.
- `UseFuncAdv`'s advanced HTTP request (`request` / `syn.request` / `http_request`) requires a UNC/UNCs-compliant executor; if unavailable, it automatically falls back without erroring.
- Set `ImageManager.Config` before calling `AddAsset` — changing config after assets are added does not re-trigger downloads.

**VI**
- Cần executor hỗ trợ các hàm file: `writefile`, `readfile`, `isfile`, `isfolder`, `makefolder`, `delfolder`.
- Cần `getcustomasset` để `UseFuncAdv` trả về content id sạch; nếu không có, `GetAsset` sẽ fallback về `"rbxasset://"..path`, vẫn hoạt động trên hầu hết executor.
- HTTP request nâng cao của `UseFuncAdv` (`request` / `syn.request` / `http_request`) cần executor chuẩn UNC/UNCs; nếu không có sẽ tự fallback, không báo lỗi.
- Set `ImageManager.Config` trước khi gọi `AddAsset` — đổi config sau khi đã add asset sẽ không khiến asset tải lại.
