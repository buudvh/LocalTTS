import csv
import plistlib
import os
import re

# Bộ ký tự có dấu tiếng Việt
VN_ACCENT_RE = re.compile(r"[àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ]", re.IGNORECASE)

def load_unsigned_words_from_swift(swift_path):
    unsigned_set = set()
    if not os.path.exists(swift_path):
        print(f"Warning: Swift file {swift_path} not found.")
        return unsigned_set
        
    with open(swift_path, 'r', encoding='utf-8') as f:
        content = f.read()
        
    # Tìm đoạn định nghĩa vnUnsignedWords trong Swift
    match = re.search(r"private static let vnUnsignedWords:\s*(?:Set<String>|\[String\])\s*=\s*\[(.*?)\]", content, re.DOTALL)
    if match:
        words_block = match.group(1)
        # Trích xuất tất cả các từ nằm trong dấu ngoặc kép
        words = re.findall(r'"([^"]+)"', words_block)
        for w in words:
            unsigned_set.add(w.strip().lower())
    else:
        print(f"Warning: Could not find definitions for vnUnsignedWords in Swift file: {swift_path}")
    return unsigned_set

def is_vietnamese_word(word, unsigned_set):
    w = word.strip().lower()
    if not w:
        return False
    if VN_ACCENT_RE.search(w):
        return True
    return w in unsigned_set

def csv_to_plist(csv_path, plist_path, key_col, val_col, swift_path=None, backup_plist_path=None):
    if not os.path.exists(csv_path):
        raise FileNotFoundError(f"Error: CSV file '{csv_path}' does not exist.")
    
    unsigned_set = set()
    if swift_path:
        unsigned_set = load_unsigned_words_from_swift(swift_path)
        print(f"Loaded {len(unsigned_set)} unsigned Vietnamese words from Swift file.")
    
    data = {}
    backup_data = {}
    
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        
        # Kiểm tra tiêu đề để tránh lỗi silent failure
        if not reader.fieldnames:
            raise ValueError(f"Error: CSV file '{csv_path}' is empty or has no header.")
        if key_col not in reader.fieldnames:
            raise KeyError(f"Error: Key column '{key_col}' not found in {csv_path}. Available columns: {reader.fieldnames}")
        if val_col not in reader.fieldnames:
            raise KeyError(f"Error: Value column '{val_col}' not found in {csv_path}. Available columns: {reader.fieldnames}")
            
        seen_keys = {}
        for row in reader:
            if key_col in row and val_col in row:
                key = row[key_col].strip().lower()
                val = row[val_col].strip().lower()
                if key and val:
                    # Kiểm tra trùng lặp khóa và in ra cảnh báo nếu giá trị dịch khác nhau
                    if key in seen_keys:
                        if seen_keys[key] != val:
                            print(f"Warning: Duplicate key '{key}' in '{os.path.basename(csv_path)}' with different values: '{seen_keys[key]}' vs '{val}'. Using latest.")
                    seen_keys[key] = val
                    
                    # Lọc các từ đơn (không chứa khoảng trắng) là từ tiếng Việt hợp lệ
                    if swift_path and (" " not in key) and is_vietnamese_word(key, unsigned_set):
                        backup_data[key] = val
                        if key in data:
                            del data[key]
                    else:
                        data[key] = val
                        if key in backup_data:
                            del backup_data[key]
    
    os.makedirs(os.path.dirname(plist_path), exist_ok=True)
    with open(plist_path, 'wb') as f:
        plistlib.dump(data, f)
    print(f"Compiled {csv_path} to {plist_path} ({len(data)} entries)")
    
    if backup_plist_path and backup_data:
        os.makedirs(os.path.dirname(backup_plist_path), exist_ok=True)
        with open(backup_plist_path, 'wb') as f:
            plistlib.dump(backup_data, f)
        print(f"Saved {len(backup_data)} filtered Vietnamese homographs to backup: {backup_plist_path}")

if __name__ == "__main__":
    script_dir = os.path.dirname(os.path.abspath(__file__))
    root_dir = os.path.dirname(script_dir)
    
    csv_words = os.path.join(root_dir, "NghiTTS", "data", "non-vietnamese-words.csv")
    plist_words = os.path.join(root_dir, "LocalTTS", "Resources", "non-vietnamese-words.plist")
    backup_words = os.path.join(root_dir, "LocalTTS", "Resources", "non-vietnamese-words-homographs-backup.plist")
    swift_path = os.path.join(root_dir, "LocalTTS", "Services", "TextPreprocessor.swift")
    
    csv_acronyms = os.path.join(root_dir, "NghiTTS", "data", "acronyms.csv")
    plist_acronyms = os.path.join(root_dir, "LocalTTS", "Resources", "acronyms.plist")
    
    csv_to_plist(csv_words, plist_words, "original", "transliteration", swift_path, backup_words)
    csv_to_plist(csv_acronyms, plist_acronyms, "acronym", "transliteration")
