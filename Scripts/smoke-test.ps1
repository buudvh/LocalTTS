param(
    [string]$BaseUrl = "http://127.0.0.1:17771"
)

Write-Host "Health"
curl.exe -s "$BaseUrl/health"

Write-Host "`nVoices"
curl.exe -s "$BaseUrl/v1/voices"

Write-Host "`nPrefetch default voice"
curl.exe -s -X POST "$BaseUrl/v1/models/prefetch" `
    -H "Content-Type: application/json" `
    --data '{"voices":["Ngọc Huyền (mới)"]}'

Write-Host "`nTTS"
curl.exe -s -X POST "$BaseUrl/v1/tts" `
    -H "Content-Type: application/json" `
    --data '{"text":"Xin chào, đây là thử giọng tiếng Việt.","voice":"Ngọc Huyền (mới)","speed":1.0}' `
    -o sample.wav -D -
