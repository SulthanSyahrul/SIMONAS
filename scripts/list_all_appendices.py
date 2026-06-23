import os, docx

def list_appendices(filename):
    if not os.path.exists(filename):
        return
    print(f"\n=== Appendices in {filename} ===")
    doc = docx.Document(filename)
    for idx, p in enumerate(doc.paragraphs):
        text = p.text.strip()
        if text.upper().startswith("LAMPIRAN"):
            # print surrounding 5 paragraphs
            for j in range(max(0, idx - 1), min(len(doc.paragraphs), idx + 8)):
                print(f"[{j}]: {doc.paragraphs[j].text}")

if __name__ == '__main__':
    for file in os.listdir('.'):
        if file.endswith('.docx') and not file.startswith('~$'):
            list_appendices(file)
