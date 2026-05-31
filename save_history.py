import sqlite3
import re
import os
import sys
import glob
from datetime import datetime

# Reconfigure stdout to use UTF-8 in case it's run in console
if sys.version_info >= (3, 7):
    sys.stdout.reconfigure(encoding='utf-8')

def extract_chat_text(payload):
    if not payload:
        return None
    # UTF-8 text strings regex (supports Russian and English characters)
    text_re = re.compile(rb'(?:[\x09\x0a\x0d\x20-\x7e]|\xd0[\x80-\xbf]|\xd1[\x80-\xbf])+')
    
    candidates = []
    for match in text_re.findall(payload):
        try:
            text = match.decode('utf-8').strip()
            # Basic validation: must contain letters and be reasonably long
            if len(text) > 8 and any(c.isalpha() for c in text):
                # Filter out internal UUID keys or system values
                if not any(x in text for x in ['sessionID', 'query_engine', 'node_modules', 'System.Object', 'b$', 't1zuc3pf', 'ku4f2t3n']):
                    # Filter out JSON tool calls
                    if not (text.startswith('{') and any(key in text for key in ['CommandLine', 'CodeContent', 'TargetFile', 'AbsolutePath', 'toolAction', 'toolSummary'])):
                        candidates.append(text)
        except Exception:
            pass
            
    if not candidates:
        return None
    # Return the longest candidate (usually the actual prompt or markdown response)
    candidates.sort(key=len, reverse=True)
    return candidates[0]

def main():
    conversations_dir = "C:/Users/HP/.gemini/antigravity-ide/conversations"
    output_path = "d:/skycheck/chat_history.md"
    
    if not os.path.exists(conversations_dir):
        print(f"Directory not found: {conversations_dir}")
        return
        
    db_files = glob.glob(os.path.join(conversations_dir, "*.db"))
    # Sort DB files by modification time (ascending, so oldest is first)
    db_files.sort(key=os.path.getmtime)
    
    markdown_content = []
    markdown_content.append("# История чатов SkyCheck (ИИ-ассистент)\n")
    markdown_content.append(f"Экспортировано: {datetime.now().strftime('%d.%m.%Y %H:%M:%S')}\n")
    markdown_content.append("Этот файл содержит восстановленную историю диалогов с ИИ-ассистентом.\n")
    
    for db_path in db_files:
        db_name = os.path.basename(db_path)
        conv_id = db_name.replace(".db", "")
        mtime = os.path.getmtime(db_path)
        conv_date = datetime.fromtimestamp(mtime).strftime('%d.%m.%Y %H:%M:%S')
        
        print(f"Processing conversation {conv_id} ({conv_date})...")
        
        try:
            conn = sqlite3.connect(db_path)
            cur = conn.cursor()
            
            # Fetch steps in order
            cur.execute("SELECT idx, step_type, step_payload FROM steps WHERE step_type IN (14, 15) ORDER BY idx;")
            rows = cur.fetchall()
            
            chat_entries = []
            for idx, step_type, payload in rows:
                extracted = extract_chat_text(payload)
                if extracted:
                    role = "Пользователь" if step_type == 14 else "Ассистент"
                    chat_entries.append((idx, role, extracted))
            
            conn.close()
            
            if chat_entries:
                markdown_content.append(f"\n## 💬 Сессия: {conv_id} ({conv_date})\n")
                
                # Deduplicate consecutive identical messages from the same role if any
                last_role = None
                last_text = None
                
                for idx, role, text in chat_entries:
                    # Clean up markdown line endings and formatting
                    text_formatted = text.replace('\\n', '\n').replace('\\t', '\t').replace('\\"', '"')
                    
                    if role == last_role and text_formatted == last_text:
                        continue # Skip duplicate logs
                        
                    markdown_content.append(f"### 👤 {role}:\n{text_formatted}\n\n---\n")
                    last_role = role
                    last_text = text_formatted
                    
        except Exception as e:
            print(f"Error reading {db_name}: {e}")
            
    with open(output_path, "w", encoding="utf-8") as f:
        f.write("\n".join(markdown_content))
        
    print(f"Successfully generated history markdown at: {output_path}")

if __name__ == "__main__":
    main()
