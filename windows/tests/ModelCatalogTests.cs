using System;
using System.Collections.Generic;
using WhisperWin;

namespace WhisperWinTests
{
    public static class ModelCatalogTests
    {
        public static int Main()
        {
            try
            {
                TestParsePreservesOrderAndDeduplicates();
                TestProviderCatalogEndpoints();
                Console.WriteLine("WindowsModelCatalogTests: PASS");
                return 0;
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine("WindowsModelCatalogTests: FAIL — " + ex.Message);
                return 1;
            }
        }

        private static void Expect(bool condition, string message)
        {
            if (!condition) throw new Exception(message);
        }

        private static void TestParsePreservesOrderAndDeduplicates()
        {
            var json = new Dictionary<string, object>
            {
                { "data", new object[]
                    {
                        new Dictionary<string, object> { { "id", "model-b" } },
                        new Dictionary<string, object> { { "id", "model-a" } },
                        new Dictionary<string, object> { { "name", "ignored" } },
                        new Dictionary<string, object> { { "id", "model-a" } },
                    }
                }
            };

            var ids = ModelCatalog.ParseModelIds(json);
            Expect(ids.Count == 2, "catalog should ignore invalid/duplicate items");
            Expect(ids[0] == "model-b" && ids[1] == "model-a", "catalog order mismatch");
        }

        private static void TestProviderCatalogEndpoints()
        {
            Expect(LlmRegistry.Get("openai").ModelsEndpoint == "https://api.openai.com/v1/models",
                   "OpenAI models endpoint missing");
            Expect(LlmRegistry.Get("anthropic").ModelsEndpoint == "https://api.anthropic.com/v1/models",
                   "Anthropic models endpoint missing");
            Expect(LlmRegistry.Get("moonshot").ModelsEndpoint == "https://api.moonshot.ai/v1/models",
                   "Moonshot models endpoint missing");
            Expect(LlmRegistry.Get("qwen").ModelsEndpoint == null,
                   "workspace-specific Qwen model catalog should remain unset");
        }
    }
}
