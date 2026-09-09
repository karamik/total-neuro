import json
import numpy as np
from typing import Union, Optional, List

def compile_model(
    model: Union[str, object],
    sample_input: Optional[np.ndarray] = None,
    time_windows: int = 16,
    target: str = 'fpga'
) -> str:
    """
    Compile a model to ED‑IR JSON format.
    This is a public API placeholder – full compilation requires a commercial license.
    """
    # В реальности здесь вызывается BTR, Phase‑Trellis, ED‑IR сериализатор
    # Сейчас просто возвращаем заглушку
    return json.dumps({
        "protocol_version": "9.2",
        "model_name": str(model),
        "architecture": "TOTAL‑Neuro Event‑Driven",
        "layers": [],
        "note": "This is a demo ED‑IR. Full compilation requires commercial license."
    }, indent=2)

def upload_firmware(port: str, bin_file: str) -> bool:
    """
    Upload firmware to a connected board.
    """
    # Здесь будет логика загрузки через драйвер
    return True
# ... (существующий код)

from .proof_package import HardwareManifest, ProofPackage

def get_hardware_manifest(chip_id: str, firmware: str, inference_result: dict) -> HardwareManifest:
    """
    Собирает манифест из данных, полученных с чипа.
    """
    manifest = HardwareManifest(chip_id, firmware)
    manifest.set_latency(inference_result.get("latency_us", 0))
    manifest.set_power(inference_result.get("power_mw", 0))
    manifest.set_spike_times(inference_result.get("spike_times", []))
    manifest.set_violations(inference_result.get("violations", 0))
    manifest.set_router_stats(
        inference_result.get("vc_usage", [0,0,0,0]),
        inference_result.get("collisions", 0)
    )
    manifest.set_input_hash(inference_result.get("input_data", b""))
    manifest.set_output_hash(inference_result.get("output_data", b""))
    return manifest

def create_proof_package(chip_id: str, firmware: str, inference_result: dict, inspection_manifest: dict = None) -> str:
    """
    Создаёт полный Proof-пакет на основе данных чипа и результатов инспекции.
    """
    manifest = get_hardware_manifest(chip_id, firmware, inference_result)
    package = ProofPackage(manifest, inspection_manifest)
    # Подпись будет добавлена позже (интеграция с QRAP)
    return package.to_json()
