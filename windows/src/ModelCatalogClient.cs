using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;

namespace WhisperWin
{
    public static class ModelCatalogClient
    {
        public static async Task<List<string>> FetchAsync(LlmProvider provider, string apiKey)
        {
            if (provider == null || string.IsNullOrWhiteSpace(provider.ModelsEndpoint))
                throw new InvalidOperationException("ผู้ให้บริการนี้ไม่มี model catalog endpoint");
            if (provider.RequiresApiKey && string.IsNullOrWhiteSpace(apiKey))
                throw new InvalidOperationException("ต้องใส่ API key ก่อนโหลดโมเดล");

            using (var req = new HttpRequestMessage(HttpMethod.Get, provider.ModelsEndpoint))
            {
                if (provider.RequiresApiKey)
                {
                    if (provider.Style == LlmStyle.Anthropic)
                    {
                        req.Headers.TryAddWithoutValidation("x-api-key", apiKey.Trim());
                        req.Headers.TryAddWithoutValidation("anthropic-version", "2023-06-01");
                    }
                    else
                    {
                        req.Headers.TryAddWithoutValidation("Authorization", "Bearer " + apiKey.Trim());
                    }
                }

                using (var cts = new CancellationTokenSource(TimeSpan.FromSeconds(30)))
                using (var resp = await SttClient.Http.SendAsync(req, cts.Token).ConfigureAwait(false))
                {
                    var body = await resp.Content.ReadAsStringAsync().ConfigureAwait(false);
                    if (!resp.IsSuccessStatusCode)
                        throw new InvalidOperationException(
                            provider.Name + " model catalog HTTP " + (int)resp.StatusCode
                        );

                    var json = Json.ParseObject(body);
                    var ids = new List<string>();
                    foreach (var raw in Json.AsArray(Json.Get(json, "data")))
                    {
                        var item = Json.AsObject(raw);
                        var id = Json.AsString(Json.Get(item, "id"));
                        if (!string.IsNullOrWhiteSpace(id)) ids.Add(id.Trim());
                    }

                    var distinct = ids
                        .Distinct(StringComparer.OrdinalIgnoreCase)
                        .OrderBy(x => x, StringComparer.OrdinalIgnoreCase)
                        .ToList();

                    if (distinct.Count == 0)
                        throw new InvalidOperationException("อ่านรายการโมเดลจาก " + provider.Name + " ไม่ได้");
                    return distinct;
                }
            }
        }
    }
}
