import pathlib
import plistlib
import re
from typing import Dict, Set


ROOT = pathlib.Path(__file__).resolve().parents[1]
SWIFT = ROOT / "LocalTTS" / "Services" / "TextPreprocessor.swift"
PLIST = ROOT / "LocalTTS" / "Resources" / "non-vietnamese-words.plist"
APP = ROOT / "LocalTTS" / "LocalTTSApp.swift"
VIEW = ROOT / "LocalTTS" / "ContentView.swift"

EXPECTED_SETTING_KEYS = {
    "numericNormalizationEnabled": "preprocessorNumericNormalizationEnabled",
    "dictionaryReplacementEnabled": "preprocessorDictionaryReplacementEnabled",
    "transliterationEnabled": "preprocessorTransliterationEnabled",
    "debugLoggingEnabled": "preprocessorDebugLoggingEnabled",
}


def load_vn_unsigned_words() -> Set[str]:
    content = SWIFT.read_text(encoding="utf-8")
    match = re.search(
        r"private static let vnUnsignedWords:\s*Set<String>\s*=\s*\[(.*?)\]",
        content,
        re.S,
    )
    if not match:
        raise SystemExit("vnUnsignedWords not found in TextPreprocessor.swift")

    return {word.strip().lower() for word in re.findall(r'"([^"]+)"', match.group(1))}


def load_plist() -> Dict[str, str]:
    with PLIST.open("rb") as fh:
        return plistlib.load(fh)


def ensure_overlap_is_empty() -> None:
    if not PLIST.exists():
        return
    words = load_vn_unsigned_words()
    data = load_plist()
    overlap = sorted(set(key.lower() for key in data.keys()) & words)
    if overlap:
        sample = ", ".join(overlap[:20])
        raise SystemExit(
            f"non-vietnamese-words.plist still overlaps vnUnsignedWords: {len(overlap)} keys ({sample})"
        )


def ensure_setting_constants_exist() -> None:
    content = SWIFT.read_text(encoding="utf-8")
    for name, plist_key in EXPECTED_SETTING_KEYS.items():
        needle = f'static let {name} = "{plist_key}"'
        if needle not in content:
            raise SystemExit(f"{name} constant is missing from TextPreprocessor.swift")

    required_wiring = [
        "private struct PreprocessorRuntimeConfig",
        "private static func processVietnameseText(_ text: String, config: PreprocessorRuntimeConfig",
        "private func replaceDictionaryWords(in text: String, type: DictionaryType, config: PreprocessorRuntimeConfig)",
        "private func transliterateToken(_ token: String, config: PreprocessorRuntimeConfig)",
        "let runtimeConfig = PreprocessorRuntimeConfig.load()",
        "let shouldProcessTokens = runtimeConfig.dictionaryReplacementEnabled || runtimeConfig.transliterationEnabled",
    ]
    for needle in required_wiring:
        if needle not in content:
            raise SystemExit(f"{needle} wiring is missing from TextPreprocessor.swift")


def ensure_debug_and_perf_configs_are_wired() -> None:
    app_text = APP.read_text(encoding="utf-8")
    view_text = VIEW.read_text(encoding="utf-8")

    expected_app_defaults = {
        "PreprocessorSettingKey.numericNormalizationEnabled: true": "numericNormalizationEnabled default is missing from LocalTTSApp.swift",
        "PreprocessorSettingKey.dictionaryReplacementEnabled: true": "dictionaryReplacementEnabled default is missing from LocalTTSApp.swift",
        "PreprocessorSettingKey.transliterationEnabled: true": "transliterationEnabled default is missing from LocalTTSApp.swift",
        "PreprocessorSettingKey.debugLoggingEnabled: false": "debugLoggingEnabled default is missing from LocalTTSApp.swift",
    }
    for needle, message in expected_app_defaults.items():
        if needle not in app_text:
            raise SystemExit(message)

    expected_view_bindings = {
        '@AppStorage(PreprocessorSettingKey.numericNormalizationEnabled) private var preprocessorNumericNormalizationEnabled = true': "numericNormalizationEnabled AppStorage binding is missing from ContentView.swift",
        '@AppStorage(PreprocessorSettingKey.dictionaryReplacementEnabled) private var preprocessorDictionaryReplacementEnabled = true': "dictionaryReplacementEnabled AppStorage binding is missing from ContentView.swift",
        '@AppStorage(PreprocessorSettingKey.transliterationEnabled) private var preprocessorTransliterationEnabled = true': "transliterationEnabled AppStorage binding is missing from ContentView.swift",
        '@AppStorage(PreprocessorSettingKey.debugLoggingEnabled) private var preprocessorDebugLoggingEnabled = false': "debugLoggingEnabled AppStorage binding is missing from ContentView.swift",
    }
    for needle, message in expected_view_bindings.items():
        if needle not in view_text:
            raise SystemExit(message)

    expected_toggles = [
        'Section("Preprocess")',
        'Toggle("Normalize numbers"',
        'Toggle("Replace dictionary words"',
        'Toggle("Transliterate EN/JP"',
        'Toggle("Debug preprocess logs"',
    ]
    for needle in expected_toggles:
        if needle not in view_text:
            raise SystemExit(f"{needle} is missing from ContentView.swift")


def main() -> int:
    ensure_overlap_is_empty()
    ensure_setting_constants_exist()
    ensure_debug_and_perf_configs_are_wired()
    print("Text preprocessor validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
