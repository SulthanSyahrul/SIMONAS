import os

for root, dirs, files in os.walk('.'):
    for file in files:
        if file.endswith('.docx') or file.endswith('.pdf'):
            print(os.path.join(root, file))
