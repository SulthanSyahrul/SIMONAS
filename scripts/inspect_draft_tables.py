import docx

doc = docx.Document('Draft Template Naskah TA 2025.docx')
with open('scripts/inspect_draft_tables.txt', 'w', encoding='utf-8') as f:
    for idx, table in enumerate(doc.tables):
        f.write(f"\n--- Table #{idx} ---\n")
        # Try to find what text precedes the table
        # We can find this by iterating through the document element body
        for row in table.rows:
            row_text = [cell.text.strip().replace('\n', ' ') for cell in row.cells]
            f.write(" | ".join(row_text) + "\n")
print("Done inspecting tables.")
