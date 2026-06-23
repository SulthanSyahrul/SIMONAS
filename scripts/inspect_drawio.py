import xml.etree.ElementTree as ET

try:
    tree = ET.parse('../pengawasan_kelas_smp_negeri_1_jenar/TA.drawio.xml')
    root = tree.getroot()
    diagrams = root.findall('.//diagram')
    print(f"Found {len(diagrams)} diagrams in drawio.xml:")
    for idx, d in enumerate(diagrams):
        print(f"  Diagram {idx}: id={d.get('id')}, name={d.get('name')}")
except Exception as e:
    print("Error:", e)
