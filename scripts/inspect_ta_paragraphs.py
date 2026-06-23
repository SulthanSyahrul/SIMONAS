import docx

doc = docx.Document('Naskah_TA_SinarBelajar_SMPN1Jenar_v3_cited.docx')
with open('scripts/inspect_results_ta.txt', 'w', encoding='utf-8') as f:
    for idx, p in enumerate(doc.paragraphs):
        f.write(f"[{idx}]: runs={len(p.runs)} text='{p.text}'\n")
print("Done writing to scripts/inspect_results_ta.txt")
