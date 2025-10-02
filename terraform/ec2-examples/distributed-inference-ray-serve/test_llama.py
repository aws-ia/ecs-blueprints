from urllib.parse import urljoin
from openai import OpenAI
import sys

if len(sys.argv) != 2:
    print("Usage: python test_llama.py '<message>'")
    sys.exit(1)

api_key = "FAKE_KEY"
base_url = "http://localhost:8000"

client = OpenAI(base_url=urljoin(base_url, "v1"), api_key=api_key)

response = client.chat.completions.create(
    model="my-llama-3.1-8b",
    messages=[{"role": "user", "content": sys.argv[1]}],
    stream=True
)

for chunk in response:
    content = chunk.choices[0].delta.content
    if content:
        print(content, end="", flush=True)
print("")