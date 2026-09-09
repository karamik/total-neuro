#!/usr/bin/env python3
"""
TOTAL‑Neuro Demo: TinyLlama inference on simulated chip
+ Generation of Proof Package (hardware + inspection manifests)
Run without FPGA – just to see how it works and produce auditable proofs.
"""

import os
import time
import json
import uuid
import hashlib
from datetime import datetime
from total_neuro.simulator import NeuroSimulator  # открытая заглушка


def generate_hardware_manifest(chip_id, firmware_version, inference_id,
                               latency_us, power_mw, spike_times,
                               input_data, output_text):
    """
    Формирует hardware_manifest из данных симуляции или реального чипа.
    """
    input_hash = hashlib.sha256(input_data.encode()).hexdigest()
    output_hash = hashlib.sha256(output_text.encode()).hexdigest()

    return {
        "chip_id": chip_id,
        "firmware_version": firmware_version,
        "inference_id": inference_id,
        "latency_us": latency_us,
        "power_consumption_mw": power_mw,
        "spike_times": spike_times[:10],  # первые 10 для компактности
        "stdp_window_violations": 0,
        "router_stats": {
            "vc_usage": [1, 2, 0, 1],
            "collisions": 0
        },
        "input_hash": input_hash,
        "output_hash": output_hash
    }


def generate_inspection_manifest(inference_id, model_id, decision, confidence,
                                 spectral_entropy, drift_score, inspector_version="2.1.0"):
    """
    Формирует inspection_manifest (эмулирует работу TurboLLM G‑Space Inspector).
    В реальной системе здесь будет вызов API TurboLLM.
    """
    return {
        "inspector_version": inspector_version,
        "model_id": model_id,
        "inference_id": inference_id,
        "gs_metrics": {
            "spectral_entropy": spectral_entropy,
            "drift_score": drift_score,
            "anomaly_detected": drift_score > 0.1,
            "layer_activations": [
                {"layer": "layer_0", "mean": 0.45, "std": 0.12},
                {"layer": "layer_1", "mean": 0.32, "std": 0.09}
            ]
        },
        "decision": decision,
        "confidence": confidence,
        "reflection_triggered": False,
        "proof_of_inspection": "simulated_signature_" + hashlib.sha256(
            f"{inference_id}{spectral_entropy}".encode()
        ).hexdigest()[:16],
        "inspector_log": "ipfs://QmSimulatedLogHash"
    }


def sign_package(package):
    """
    Заглушка подписания пакета (аппаратно или через QRAP SDK).
    В реальности здесь будет вызов криптографической подписи.
    """
    package["signature"] = {
        "algorithm": "ECDSA_SECP256K1",
        "public_key": "0xSimulatedPublicKey",
        "signature": "simulated_signature_" + hashlib.sha256(
            json.dumps(package, sort_keys=True).encode()
        ).hexdigest()[:32],
        "signed_by": "both",
        "timestamp": datetime.utcnow().isoformat() + "Z"
    }
    return package


def save_proof_package(package, filename="proof_package.json"):
    with open(filename, "w") as f:
        json.dump(package, f, indent=2)
    print(f"📄 Proof package saved to {filename}")


def main():
    print("🧠 TOTAL‑Neuro Demo: TinyLlama on simulated chip")
    print("=" * 60)

    # 1. Загружаем / компилируем бинарник
    bin_path = "tinyllama.bin"
    if not os.path.exists(bin_path):
        print("⚙️ Compiling TinyLlama (this may take 2–3 minutes)...")
        os.system(
            "total-neuro convert --model TinyLlama/TinyLlama-1.1B-Chat-v1.0 "
            "--target sim --output tinyllama.bin"
        )

    # 2. Создаём симулятор
    sim = NeuroSimulator(bin_path)

    # 3. Вводим промпт
    prompt = input("\n📝 Enter your prompt: ")

    # 4. Запускаем инференс
    print("\n⏳ Processing on simulated chip...")
    start = time.perf_counter()
    response = sim.infer(prompt, max_tokens=50)
    elapsed_us = int((time.perf_counter() - start) * 1_000_000)

    # 5. Вывод результата
    print("\n🤖 Response:")
    print("-" * 50)
    print(response)
    print("-" * 50)
    print(f"⚡ Simulated latency: {elapsed_us/1000:.1f} ms (on CPU, would be <2 ms on FPGA)")

    # 6. Генерация Proof‑пакета
    inference_id = str(uuid.uuid4())
    hardware_manifest = generate_hardware_manifest(
        chip_id="TOTAL-NEURO-SIM-001",
        firmware_version="v1.2.0-demo",
        inference_id=inference_id,
        latency_us=elapsed_us,
        power_mw=850,  # пример
        spike_times=[12, 45, 78, 102, 134],  # пример
        input_data=prompt,
        output_text=response
    )

    # Эмуляция вызова TurboLLM G‑Space Inspector
    # В реальной системе здесь будет: inspect_result = turbollm.verify(hardware_manifest, prompt)
    inspection_manifest = generate_inspection_manifest(
        inference_id=inference_id,
        model_id="TinyLlama-1.1B-Chat-v1.0",
        decision="APPROVED",
        confidence=0.997,
        spectral_entropy=0.782,
        drift_score=0.023
    )

    # Сборка полного пакета
    proof_package = {
        "package_id": "pkg-" + datetime.utcnow().strftime("%Y%m%d-%H%M%S") + "-" + inference_id[:8],
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "hardware_manifest": hardware_manifest,
        "inspection_manifest": inspection_manifest
    }

    # Подписание (заглушка)
    proof_package = sign_package(proof_package)

    # Сохранение
    save_proof_package(proof_package)

    print("\n✅ Demo finished. Proof package generated.")


if __name__ == "__main__":
    main()
