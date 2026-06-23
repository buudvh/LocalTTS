import csv
import plistlib
import os

def csv_to_plist(csv_path, plist_path, key_col, val_col):
    if not os.path.exists(csv_path):
        print(f"Error: {csv_path} does not exist.")
        return
    
    data = {}
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            if key_col in row and val_col in row:
                key = row[key_col].strip().lower()
                val = row[val_col].strip().lower()
                if key and val:
                    data[key] = val
    
    os.makedirs(os.path.dirname(plist_path), exist_ok=True)
    with open(plist_path, 'wb') as f:
        plistlib.dump(data, f)
    print(f"Compiled {csv_path} to {plist_path} ({len(data)} entries)")

if __name__ == "__main__":
    script_dir = os.path.dirname(os.path.abspath(__file__))
    root_dir = os.path.dirname(script_dir)
    
    csv_words = os.path.join(root_dir, "NghiTTS", "data", "non-vietnamese-words.csv")
    plist_words = os.path.join(root_dir, "LocalTTS", "Resources", "non-vietnamese-words.plist")
    
    csv_acronyms = os.path.join(root_dir, "NghiTTS", "data", "acronyms.csv")
    plist_acronyms = os.path.join(root_dir, "LocalTTS", "Resources", "acronyms.plist")
    
    csv_to_plist(csv_words, plist_words, "original", "transliteration")
    csv_to_plist(csv_acronyms, plist_acronyms, "acronym", "transliteration")
