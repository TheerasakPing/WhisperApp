using System;
using System.Collections.Generic;
using System.IO;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace WhisperWin
{
    /// Cloud speech-to-text — multipart upload, mirrors CloudTranscriptionService.swift.
    /// OpenAI style: Bearer auth, fields model/language (ISO 639-1)
    /// ElevenLabs style: xi-api-key header, fields model_id/language_code (ISO 639-3)
    public static class SttClient
    {
        public static readonly HttpClient Http = CreateClient();

        private static HttpClient CreateClient()
        {
            var c = new HttpClient();
            c.Timeout = Timeout.InfiniteTimeSpan; // per-request timeouts via CancellationToken
            return c;
        }

        private static string LangCode(string language, SttStyle style)
        {
            if (language == "th") return style == SttStyle.ElevenLabs ? "tha" : "th";
            if (language == "en") return style == SttStyle.ElevenLabs ? "eng" : "en";
            return null; // auto → let the provider detect
        }

        /// Returns transcribed text, or throws with a readable message.
        public static async Task<string> TranscribeAsync(AppConfig cfg, string wavPath, string language)
        {
            var p = SttRegistry.Get(cfg.SttProvider);
            var key = cfg.SttKey(p);
            if (string.IsNullOrEmpty(key))
                throw new InvalidOperationException("ยังไม่ได้ตั้งค่า API key ของ " + p.Name);
            var endpoint = cfg.SttEndpoint(p);
            if (string.IsNullOrEmpty(endpoint))
                throw new InvalidOperationException("ยังไม่ได้ตั้งค่า endpoint ของ " + p.Name);

            byte[] audio = File.ReadAllBytes(wavPath);

            if (p.Style == SttStyle.QwenAudioChat)
                return await TranscribeQwenAudioChatAsync(cfg, p, key, endpoint, audio).ConfigureAwait(false);

            using (var form = new MultipartFormDataContent("Boundary-" + Guid.NewGuid().ToString("N")))
            using (var req = new HttpRequestMessage(HttpMethod.Post, endpoint))
            {
                string modelField = p.Style == SttStyle.ElevenLabs ? "model_id" : "model";
                string langField = p.Style == SttStyle.ElevenLabs ? "language_code" : "language";

                var model = cfg.SttModel(p);
                if (!string.IsNullOrEmpty(model))
                    form.Add(new StringContent(model), modelField);

                var lang = LangCode(language, p.Style);
                if (lang != null)
                    form.Add(new StringContent(lang), langField);

                var fileContent = new ByteArrayContent(audio);
                fileContent.Headers.ContentType = MediaTypeHeaderValue.Parse("audio/wav");
                form.Add(fileContent, "file", "audio.wav");

                if (p.Style == SttStyle.ElevenLabs)
                    req.Headers.TryAddWithoutValidation("xi-api-key", key);
                else
                    req.Headers.TryAddWithoutValidation("Authorization", "Bearer " + key);

                req.Content = form;

                using (var cts = new CancellationTokenSource(TimeSpan.FromSeconds(120)))
                using (var resp = await Http.SendAsync(req, cts.Token).ConfigureAwait(false))
                {
                    var body = await resp.Content.ReadAsStringAsync().ConfigureAwait(false);
                    if (!resp.IsSuccessStatusCode)
                    {
                        Log.Error(p.Name + " HTTP " + (int)resp.StatusCode + ": " + Truncate(body, 500));
                        throw new InvalidOperationException(p.Name + " ตอบกลับ HTTP " + (int)resp.StatusCode);
                    }

                    var json = Json.ParseObject(body);
                    var text = Json.AsString(Json.Get(json, "text"));
                    if (text == null)
                    {
                        Log.Error(p.Name + " unexpected response: " + Truncate(body, 500));
                        throw new InvalidOperationException("อ่านผลลัพธ์จาก " + p.Name + " ไม่ได้");
                    }
                    return text.Trim();
                }
            }
        }

        private static async Task<string> TranscribeQwenAudioChatAsync(
            AppConfig cfg,
            SttProvider p,
            string key,
            string endpoint,
            byte[] audio)
        {
            const int maxAudioBytes = 10 * 1024 * 1024;
            if (audio == null || audio.Length == 0)
                throw new InvalidOperationException("ไฟล์เสียงว่าง");
            if (audio.Length > maxAudioBytes)
                throw new InvalidOperationException("Qwen3 ASR รองรับไฟล์เสียงสูงสุด 10 MB ต่อคำขอ");

            var dataUri = "data:audio/wav;base64," + Convert.ToBase64String(audio);
            var body = new Dictionary<string, object>
            {
                { "model", cfg.SttModel(p) },
                { "messages", new object[]
                    {
                        new Dictionary<string, object>
                        {
                            { "role", "user" },
                            { "content", new object[]
                                {
                                    new Dictionary<string, object>
                                    {
                                        { "type", "input_audio" },
                                        { "input_audio", new Dictionary<string, object>
                                            {
                                                { "data", dataUri }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                },
                { "stream", false },
            };

            using (var req = new HttpRequestMessage(HttpMethod.Post, endpoint))
            {
                req.Headers.TryAddWithoutValidation("Authorization", "Bearer " + key);
                req.Content = new StringContent(
                    Json.Serializer().Serialize(body),
                    Encoding.UTF8,
                    "application/json"
                );

                using (var cts = new CancellationTokenSource(TimeSpan.FromSeconds(120)))
                using (var resp = await Http.SendAsync(req, cts.Token).ConfigureAwait(false))
                {
                    var responseBody = await resp.Content.ReadAsStringAsync().ConfigureAwait(false);
                    if (!resp.IsSuccessStatusCode)
                    {
                        Log.Error(p.Name + " HTTP " + (int)resp.StatusCode + ": " + Truncate(responseBody, 500));
                        throw new InvalidOperationException(p.Name + " ตอบกลับ HTTP " + (int)resp.StatusCode);
                    }

                    var json = Json.ParseObject(responseBody);
                    var choice = Json.AsObject(Json.AsArray(Json.Get(json, "choices")).FirstOrDefault());
                    var message = Json.AsObject(Json.Get(choice, "message"));
                    var text = Json.AsString(Json.Get(message, "content"));
                    if (string.IsNullOrWhiteSpace(text))
                    {
                        Log.Error(p.Name + " unexpected response: " + Truncate(responseBody, 500));
                        throw new InvalidOperationException("อ่านผลลัพธ์จาก " + p.Name + " ไม่ได้");
                    }
                    return text.Trim();
                }
            }
        }

        public static string Truncate(string s, int n)
        {
            if (s == null) return "";
            return s.Length <= n ? s : s.Substring(0, n) + "…";
        }
    }
}
