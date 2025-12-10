import asyncio
import time
from openai import AsyncOpenAI

# ---------------------------
# Configuration
# ---------------------------
VLLM_BASE_URL = "http://localhost:32156/v1"
MODEL_NAME = "meta-llama/Llama-3.1-8B-Instruct"

MAX_CONCURRENCY = 32
MAX_TOKENS = 1028

# ---------------------------
# OpenAI client (vLLM)
# ---------------------------
client = AsyncOpenAI(
    base_url=VLLM_BASE_URL,
    api_key="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0ZWFtX2lkIjoidGVuc3RvcnJlbnQiLCJ0b2tlbl9pZCI6ImRlYnVnLXRlc3QifQ.kkqzJ-xEhQFWh4TD6cJFmNd_gkkxn9jwdDg3V0BkEK8"
)

# ---------------------------
# ORIGINAL PROMPTS ONLY
# ---------------------------
PROMPTS = (
    [f"Define AI concept #{i}" for i in range(10)] +
    [f"Explain systems concept #{i} with an example" for i in range(10)] +
    [f"Write a Python function #{i}" for i in range(10)]
)

TOTAL_REQUESTS = len(PROMPTS)
semaphore = asyncio.Semaphore(MAX_CONCURRENCY)

# ---------------------------
# LLM call with token stats
# ---------------------------
async def call_llm(i: int, prompt: str):
    async with semaphore:
        start = time.perf_counter()

        response = await client.chat.completions.create(
            model=MODEL_NAME,
            messages=[{"role": "user", "content": prompt}],
            max_tokens=MAX_TOKENS,
            temperature=0.7,
        )

        latency = time.perf_counter() - start

        usage = response.usage
        prompt_tokens = usage.prompt_tokens
        completion_tokens = usage.completion_tokens
        total_tokens = usage.total_tokens

        tokens_per_second = (
            completion_tokens / latency if latency > 0 else 0.0
        )

        return {
            "id": i,
            "latency": latency,
            "prompt_tokens": prompt_tokens,
            "completion_tokens": completion_tokens,
            "total_tokens": total_tokens,
            "tokens_per_second": tokens_per_second,
            "output": response.choices[0].message.content.strip(),
        }

# ---------------------------
# Main
# ---------------------------
async def main():
    print(f"Sending {TOTAL_REQUESTS} requests")
    print(f"Max concurrency: {MAX_CONCURRENCY}\n")

    wall_start = time.perf_counter()

    tasks = [call_llm(i, p) for i, p in enumerate(PROMPTS)]
    results = await asyncio.gather(*tasks)

    wall_time = time.perf_counter() - wall_start

    # Per-request dump
    for r in sorted(results, key=lambda x: x["id"]):
        print("=" * 80)
        print(f"Request #{r['id']}")
        print(f"Latency: {r['latency']:.2f}s")
        print(f"Prompt tokens: {r['prompt_tokens']}")
        print(f"Completion tokens: {r['completion_tokens']}")
        print(f"Tokens/sec: {r['tokens_per_second']:.2f}")
        print("Output (first 150 chars):")
        print(r["output"][:150], "...")

    # Aggregate metrics
    total_prompt_tokens = sum(r["prompt_tokens"] for r in results)
    total_completion_tokens = sum(r["completion_tokens"] for r in results)
    total_latency = sum(r["latency"] for r in results)

    avg_latency = total_latency / len(results)
    avg_tokens_per_sec_per_request = (
        sum(r["tokens_per_second"] for r in results) / len(results)
    )
    global_tokens_per_sec = (
        total_completion_tokens / total_latency if total_latency > 0 else 0.0
    )

    print("\n" + "=" * 80)
    print("AGGREGATE STATS")
    print(f"Wall time: {wall_time:.2f}s")
    print(f"Average latency per request: {avg_latency:.2f}s")
    print(f"Total prompt tokens: {total_prompt_tokens}")
    print(f"Total completion tokens: {total_completion_tokens}")
    print(f"Avg tokens/sec (per-request mean): {avg_tokens_per_sec_per_request:.2f}")
    print(f"Avg tokens/sec (global): {global_tokens_per_sec:.2f}")

if __name__ == "__main__":
    asyncio.run(main())

