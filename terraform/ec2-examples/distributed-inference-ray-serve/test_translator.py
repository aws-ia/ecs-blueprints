import requests
import sys

if len(sys.argv) != 2:
    print("Usage: python test_translator.py '<english_text>'")
    sys.exit(1)

english_text = sys.argv[1]

response = requests.post("http://127.0.0.1:8000/", json=english_text)
french_text = response.text

print(french_text)
