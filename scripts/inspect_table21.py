import docx

doc = docx.Document('Draft Template Naskah TA 2025.docx')
# Table #21 is the table we want
table = doc.tables[21]
print("Table 21 rows count:", len(table.rows))
for r_idx, r in enumerate(table.rows):
    row_text = []
    for c_idx, cell in enumerate(r.cells):
        row_text.append(f"C{c_idx}: {cell.text.strip().replace('\n', ' ')}")
    print(f"Row {r_idx}:", " | ".join(row_text))
