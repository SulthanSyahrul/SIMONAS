with open('scripts/inspect_results.txt', 'r', encoding='utf-8') as f:
    lines = f.readlines()

output = []
recording = False
for line in lines:
    if '[Paragraph 406]' in line:
        recording = True
    if '[Paragraph 522]' in line:
        recording = False
        output.append(line)
    if recording:
        output.append(line)

with open('scripts/extracted_bab5_6.txt', 'w', encoding='utf-8') as f:
    f.writelines(output)
print("Done extracting Bab 5 & 6 text.")
