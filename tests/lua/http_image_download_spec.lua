local downloads = {}
g_http = {
	download = function(url, file)
		downloads[#downloads + 1] = { url = url, file = file }
		return #downloads
	end,
	setUserAgent = function() end,
	setEnableTimeOutOnReadWrite = function() end,
}
connect = function() end

dofile("modules/corelib/http.lua")

local received = {}
local function record(path, err)
	received[#received + 1] = { path = path, err = err }
end
local url = "https://example.test/store/bag.png"
assert(HTTP.downloadImage(url, record) == 1)
assert(HTTP.downloadImage(url, record) == 1)
assert(#downloads == 1, "duplicate in-flight HTTP request")
HTTP.onDownload(1, url, "", "bag.png", "")
assert(#received == 2 and received[1].path == "/downloads/bag.png" and received[2].path == "/downloads/bag.png")
assert(HTTP.imageRequests[url] == nil and HTTP.operations[1] == nil)
HTTP.downloadImage(url, record)
assert(#downloads == 1 and #received == 3, "completed image was not reused")

local failedUrl = "https://example.test/store/missing.png"
HTTP.downloadImage(failedUrl, record)
HTTP.onDownload(2, failedUrl, "404", nil, "")
assert(received[4].err == "404" and HTTP.imageRequests[failedUrl] == nil)
HTTP.downloadImage(failedUrl, record)
assert(#downloads == 3, "failed image should be retried")
print("HTTP image requests share downloads and cache completed images")