using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace WhisperWin
{
    /// AI text correction — mirrors TextCorrectionService.swift (same system prompt).
    public static class LlmClient
    {
        /// Returns corrected text, or null on any failure (caller falls back to the raw text).
        public static async Task<string> CorrectAsync(AppConfig cfg, string text, string language)
        {
            if (string.IsNullOrWhiteSpace(text)) return null;

            var p = LlmRegistry.Get(cfg.LlmProvider);
            var key = cfg.LlmKey(p);
            if (string.IsNullOrEmpty(key))
            {
                Log.Error("No key for " + p.Name + " (set in Settings or env " + p.EnvKey + ")");
                return null;
            }
            var endpoint = cfg.LlmEndpoint(p);
            if (string.IsNullOrEmpty(endpoint)) return null;
            var model = cfg.LlmModel(p);
            if (string.IsNullOrEmpty(model)) return null;

            string langHint;
            if (language == "th") langHint = "The text is in Thai";
            else if (language == "en") langHint = "The text is in English";
            else langHint = "The text may be in Thai or English — keep the original language";

            var systemPrompt =
                "You are a text correction assistant for speech-to-text output, which often contains\n" +
                "misheard words and missing punctuation.\n" +
                "Your tasks:\n" +
                "- Fix misheard/garbled words based on context\n" +
                "- Add punctuation and spacing to improve readability\n" +
                "- Do NOT add new content, summarize, translate, or change word endings/speaker gender\n" +
                "- Return ONLY the corrected text — no explanations, no quotation marks\n" +
                langHint;

            Dictionary<string, object> body;
            if (p.Style == LlmStyle.OpenAI)
            {
                body = new Dictionary<string, object>
                {
                    { "model", model },
                    { "messages", new object[]
                        {
                            new Dictionary<string, object> { { "role", "system" }, { "content", systemPrompt } },
                            new Dictionary<string, object> { { "role", "user" }, { "content", text } },
                        }
                    },
                };
            }
            else if (p.Style == LlmStyle.Responses)
            {
                body = new Dictionary<string, object>
                {
                    { "model", model },
                    { "input", new object[]
                        {
                            new Dictionary<string, object> { { "role", "system" }, { "content", systemPrompt } },
                            new Dictionary<string, object> { { "role", "user" }, { "content", text } },
                        }
                    },
                    { "store", false },
                };
            }
            else
            {
                body = new Dictionary<string, object>
                {
                    { "model", model },
                    { "max_tokens", 8192 },
                    { "system", systemPrompt },
                    { "messages", new object[]
                        {
                            new Dictionary<string, object> { { "role", "user" }, { "content", text } },
                        }
                    },
                };
            }

            if (p.SupportsTemperature)
                body["temperature"] = 0.2;

            if (p.DisableThinking)
                body["thinking"] = new Dictionary<string, object> { { "type", "disabled" } };

            try
            {
                using (var req = new HttpRequestMessage(HttpMethod.Post, endpoint))
                {
                    if (p.Style == LlmStyle.Anthropic)
                    {
                        req.Headers.TryAddWithoutValidation("x-api-key", key);
                        req.Headers.TryAddWithoutValidation("anthropic-version", "2023-06-01");
                    }
                    else
                    {
                        req.Headers.TryAddWithoutValidation("Authorization", "Bearer " + key);
                    }
                    req.Content = new StringContent(Json.Serializer().Serialize(body), Encoding.UTF8, "application/json");

                    using (var cts = new CancellationTokenSource(TimeSpan.FromSeconds(60)))
                    using (var resp = await SttClient.Http.SendAsync(req, cts.Token).ConfigureAwait(false))
                    {
                        var respBody = await resp.Content.ReadAsStringAsync().ConfigureAwait(false);
                        if (!resp.IsSuccessStatusCode)
                        {
                            Log.Error(p.Name + " HTTP " + (int)resp.StatusCode + ": " + SttClient.Truncate(respBody, 500));
                            return null;
                        }

                        var json = Json.ParseObject(respBody);
                        var content = ExtractText(json, p.Style);
                        if (content == null)
                        {
                            Log.Error(p.Name + " unexpected response: " + SttClient.Truncate(respBody, 500));
                            return null;
                        }
                        var cleaned = content.Trim().Trim('"', '\'');
                        return string.IsNullOrEmpty(cleaned) ? null : cleaned;
                    }
                }
            }
            catch (Exception ex)
            {
                Log.Error("Correction (" + p.Name + "): " + ex.Message);
                return null;
            }
        }

        private static string ExtractText(Dictionary<string, object> json, LlmStyle style)
        {
            if (json == null) return null;
            if (style == LlmStyle.OpenAI)
            {
                var choice = Json.AsObject(Json.AsArray(Json.Get(json, "choices")).FirstOrDefault());
                var message = Json.AsObject(Json.Get(choice, "message"));
                return Json.AsString(Json.Get(message, "content"));
            }
            if (style == LlmStyle.Responses)
            {
                var convenience = Json.AsString(Json.Get(json, "output_text"));
                if (!string.IsNullOrEmpty(convenience)) return convenience;

                var texts = new List<string>();
                foreach (var rawItem in Json.AsArray(Json.Get(json, "output")))
                {
                    var item = Json.AsObject(rawItem);
                    if (Json.AsString(Json.Get(item, "type")) != "message") continue;
                    foreach (var rawPart in Json.AsArray(Json.Get(item, "content")))
                    {
                        var part = Json.AsObject(rawPart);
                        if (Json.AsString(Json.Get(part, "type")) != "output_text") continue;
                        var text = Json.AsString(Json.Get(part, "text"));
                        if (!string.IsNullOrEmpty(text)) texts.Add(text);
                    }
                }
                return texts.Count == 0 ? null : string.Concat(texts);
            }

            var parts = Json.AsArray(Json.Get(json, "content"))
                .Select(x => Json.AsString(Json.Get(Json.AsObject(x), "text")))
                .Where(t => t != null);
            var joined = string.Concat(parts);
            return joined.Length > 0 ? joined : null;
        }
    }
}
