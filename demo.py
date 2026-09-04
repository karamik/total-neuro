#!/usr/bin/env python3
"""
TOTAL‑Neuro Demo: TinyLlama inference on simulated chip
Run without FPGA – just to see how it works.
"""

import os
import time
from total_neuro.simulator import NeuroSimulator  # это мы создадим в открытой части

def main():
    print("🧠 TOTAL‑Neuro Demo: TinyLlama on simulated chip")
    print("=" * 50)
    
    # 1. Загружаем готовый бинарник (или компилируем)
    bin_path = "tinyllama.bin"
    if not os.path.exists(bin_path):
        print("⚙️ Compiling TinyLlama (this may take 2–3 minutes)...")
        os.system("total-neuro convert --model TinyLlama/TinyLlama-1.1B-Chat-v1.0 --target sim --output tinyllama.bin")
    
    # 2. Создаём симулятор
    sim = NeuroSimulator(bin_path)
    
    # 3. Вводим промпт
    prompt = input("\n📝 Enter your prompt: ")
    
    # 4. Запускаем инференс (с симуляцией временных окон)
    print("\n⏳ Processing on simulated chip...")
    start = time.time()
    response = sim.infer(prompt, max_tokens=50)
    elapsed = (time.time() - start) * 1000  # ms
    
    # 5. Вывод результата
    print("\n🤖 Response:")
    print("-" * 50)
    print(response)
    print("-" * 50)
    print(f"⚡ Simulated latency: {elapsed:.1f} ms (on CPU, would be <2 ms on FPGA)")

if __name__ == "__main__":
    main()
