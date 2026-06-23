import docx

def main():
    doc = docx.Document('Naskah TA Sulthan Syahrul BAB I-IV.docx')
    print("=== Searching all tables for Table 3.1 contents ===")
    for idx, table in enumerate(doc.tables):
        found = False
        for r_idx, row in enumerate(table.rows):
            for c_idx, cell in enumerate(row.cells):
                text = cell.text.lower()
                if "filter filter" in text or "relasi composite" in text or "roles & user_roles" in text:
                    found = True
                    break
            if found:
                break
        if found:
            print(f"Found Table 3.1 at index {idx}! Rows={len(table.rows)}, Cols={len(table.columns)}")
            for r in range(len(table.rows)):
                row_texts = [f"C{c}: '{cell.text.strip().replace('\n', ' [NL] ')}'" for c, cell in enumerate(table.rows[r].cells)]
                print(f"Row {r:02d}: {' | '.join(row_texts)}")

if __name__ == '__main__':
    main()
