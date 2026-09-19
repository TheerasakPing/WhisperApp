using System;
using System.Collections.Generic;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Web.Script.Serialization;

namespace WhisperWin
{
    /// API-key storage protected with Windows DPAPI (CurrentUser).
    /// The JSON file contains only Base64 DPAPI ciphertext, never plaintext API keys.
    public static class CredentialStore
    {
        private static readonly object Gate = new object();

        public static string FilePath
        {
            get { return Path.Combine(AppConfig.Dir, "credentials.json"); }
        }

        public static string Read(string account)
        {
            if (string.IsNullOrWhiteSpace(account)) return null;
            lock (Gate)
            {
                try
                {
                    var map = LoadEncrypted();
                    string cipherText;
                    if (!map.TryGetValue(account, out cipherText) || string.IsNullOrWhiteSpace(cipherText))
                        return null;

                    var cipher = Convert.FromBase64String(cipherText);
                    var plain = ProtectedData.Unprotect(
                        cipher,
                        OptionalEntropy(),
                        DataProtectionScope.CurrentUser
                    );
                    var value = Encoding.UTF8.GetString(plain).Trim();
                    return value.Length == 0 ? null : value;
                }
                catch (Exception ex)
                {
                    Log.Error("Credential read (" + account + "): " + ex.Message);
                    return null;
                }
            }
        }

        public static bool Write(string account, string value)
        {
            if (string.IsNullOrWhiteSpace(account)) return false;
            var trimmed = (value ?? "").Trim();
            if (trimmed.Length == 0) return Delete(account);

            lock (Gate)
            {
                try
                {
                    Directory.CreateDirectory(AppConfig.Dir);
                    var plain = Encoding.UTF8.GetBytes(trimmed);
                    var cipher = ProtectedData.Protect(
                        plain,
                        OptionalEntropy(),
                        DataProtectionScope.CurrentUser
                    );
                    var map = LoadEncrypted();
                    map[account] = Convert.ToBase64String(cipher);
                    SaveEncrypted(map);

                    // Verify before reporting success; callers can safely clear plaintext only then.
                    return String.Equals(ReadUnlocked(map, account), trimmed, StringComparison.Ordinal);
                }
                catch (Exception ex)
                {
                    Log.Error("Credential write (" + account + "): " + ex.Message);
                    return false;
                }
            }
        }

        public static bool Delete(string account)
        {
            if (string.IsNullOrWhiteSpace(account)) return true;
            lock (Gate)
            {
                try
                {
                    var map = LoadEncrypted();
                    if (!map.Remove(account)) return true;
                    SaveEncrypted(map);
                    return true;
                }
                catch (Exception ex)
                {
                    Log.Error("Credential delete (" + account + "): " + ex.Message);
                    return false;
                }
            }
        }

        /// Migrates legacy plaintext dictionaries. Values are cleared only after
        /// a DPAPI write has succeeded and verified.
        public static bool MigratePlaintextKeys(AppConfig cfg)
        {
            if (cfg == null) return false;
            bool changed = false;
            changed |= MigrateDictionary("stt:", cfg.SttKeys);
            changed |= MigrateDictionary("llm:", cfg.LlmKeys);
            return changed;
        }

        public static Dictionary<string, string> LoadProviderKeys(string prefix, IEnumerable<string> providerIds)
        {
            var result = new Dictionary<string, string>();
            if (providerIds == null) return result;

            foreach (var id in providerIds)
            {
                var value = Read(prefix + id);
                if (!string.IsNullOrEmpty(value)) result[id] = value;
            }
            return result;
        }

        public static bool SaveProviderKeys(string prefix, Dictionary<string, string> values, IEnumerable<string> providerIds)
        {
            if (providerIds == null) return true;
            bool ok = true;
            foreach (var id in providerIds)
            {
                string value = null;
                if (values != null) values.TryGetValue(id, out value);
                if (string.IsNullOrWhiteSpace(value))
                    ok = Delete(prefix + id) && ok;
                else
                    ok = Write(prefix + id, value.Trim()) && ok;
            }
            return ok;
        }

        private static bool MigrateDictionary(string prefix, Dictionary<string, string> values)
        {
            if (values == null || values.Count == 0) return false;
            bool changed = false;
            var keys = new List<string>(values.Keys);
            foreach (var id in keys)
            {
                var value = values[id];
                if (string.IsNullOrWhiteSpace(value))
                {
                    values.Remove(id);
                    changed = true;
                    continue;
                }

                var account = prefix + id;
                var existing = Read(account);
                if (!string.IsNullOrEmpty(existing))
                {
                    values.Remove(id);
                    changed = true;
                    continue;
                }

                if (Write(account, value))
                {
                    values.Remove(id);
                    changed = true;
                }
            }
            return changed;
        }

        private static Dictionary<string, string> LoadEncrypted()
        {
            try
            {
                if (!File.Exists(FilePath)) return new Dictionary<string, string>();
                var json = File.ReadAllText(FilePath);
                var value = new JavaScriptSerializer().Deserialize<Dictionary<string, string>>(json);
                return value ?? new Dictionary<string, string>();
            }
            catch
            {
                return new Dictionary<string, string>();
            }
        }

        private static void SaveEncrypted(Dictionary<string, string> map)
        {
            Directory.CreateDirectory(AppConfig.Dir);
            var json = new JavaScriptSerializer().Serialize(map);
            var temp = FilePath + ".tmp";
            File.WriteAllText(temp, json, Encoding.UTF8);

            if (File.Exists(FilePath))
            {
                try
                {
                    File.Replace(temp, FilePath, null);
                    return;
                }
                catch { File.Delete(FilePath); }
            }
            File.Move(temp, FilePath);
        }

        private static string ReadUnlocked(Dictionary<string, string> map, string account)
        {
            string cipherText;
            if (!map.TryGetValue(account, out cipherText)) return null;
            var cipher = Convert.FromBase64String(cipherText);
            var plain = ProtectedData.Unprotect(
                cipher,
                OptionalEntropy(),
                DataProtectionScope.CurrentUser
            );
            return Encoding.UTF8.GetString(plain).Trim();
        }

        private static byte[] OptionalEntropy()
        {
            return Encoding.UTF8.GetBytes("WhisperApp.Credentials.v1");
        }
    }
}
