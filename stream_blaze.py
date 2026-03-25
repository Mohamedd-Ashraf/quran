from openai import OpenAI

client = OpenAI(
    base_url="https://blazeai.boxu.dev/api/v1",
    api_key="sk-blaze-OxwlQJtbCjqHzfOuBT8vbq1GJPKhqma6kIIkPI7Qf3VXuuZN"
)

response = client.chat.completions.create(
    model="anthropic/claude-sonnet-4-6",
    messages=[
        {"role": "user", "content": "Hello!"}
    ]
)

print(response.choices[0].message.content)