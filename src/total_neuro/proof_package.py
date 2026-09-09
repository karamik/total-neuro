# total-neuro/src/total_neuro/proof_package.py

import json
import hashlib
import uuid
from datetime import datetime
from typing import Dict, Any, Optional, List

class HardwareManifest:
    """Сбор данных о работе чипа."""
    def __init__(self, chip_id: str, firmware_version: str):
        self.chip_id = chip_id
        self.firmware_version = firmware_version
        self.inference_id = str(uuid.uuid4())
        self.timestamp = datetime.utcnow().isoformat() + "Z"
        self.latency_us = None
        self.power_consumption_mw = None
        self.spike_times = []
        self.stdp_window_violations = 0
        self.router_stats = {"vc_usage": [0,0,0,0], "collisions": 0}
        self.input_hash = None
        self.output_hash = None

    def set_latency(self, us: int):
        self.latency_us = us

    def set_power(self, mw: int):
        self.power_consumption_mw = mw

    def set_spike_times(self, times: List[int]):
        self.spike_times = times

    def set_violations(self, count: int):
        self.stdp_window_violations = count

    def set_router_stats(self, vc_usage: List[int], collisions: int):
        self.router_stats["vc_usage"] = vc_usage
        self.router_stats["collisions"] = collisions

    def set_input_hash(self, data: bytes):
        self.input_hash = hashlib.sha256(data).hexdigest()

    def set_output_hash(self, data: bytes):
        self.output_hash = hashlib.sha256(data).hexdigest()

    def to_dict(self) -> Dict[str, Any]:
        return {
            "chip_id": self.chip_id,
            "firmware_version": self.firmware_version,
            "inference_id": self.inference_id,
            "timestamp": self.timestamp,
            "latency_us": self.latency_us,
            "power_consumption_mw": self.power_consumption_mw,
            "spike_times": self.spike_times,
            "stdp_window_violations": self.stdp_window_violations,
            "router_stats": self.router_stats,
            "input_hash": self.input_hash,
            "output_hash": self.output_hash
        }


class ProofPackage:
    """Основной контейнер для доказательств."""
    def __init__(self, hardware: HardwareManifest, inspection_manifest: Optional[Dict] = None):
        self.hardware = hardware
        self.inspection_manifest = inspection_manifest or {}
        self.package_id = hashlib.sha256(
            f"{hardware.chip_id}{hardware.inference_id}".encode()
        ).hexdigest()[:16]
        self.timestamp = datetime.utcnow().isoformat() + "Z"
        self.signature = None

    def set_inspection_manifest(self, manifest: Dict):
        self.inspection_manifest = manifest

    def sign(self, private_key, algorithm="ECDSA_SECP256K1"):
        # Здесь должна быть реальная подпись, например, через библиотеку ec
        # Пока заглушка
        self.signature = {
            "algorithm": algorithm,
            "public_key": private_key.public_key().to_hex() if hasattr(private_key, 'public_key') else "0x...",
            "signature": "base64_encoded_signature",
            "signed_by": "both",
            "timestamp": datetime.utcnow().isoformat() + "Z"
        }

    def to_dict(self) -> Dict[str, Any]:
        return {
            "package_id": self.package_id,
            "timestamp": self.timestamp,
            "hardware_manifest": self.hardware.to_dict(),
            "inspection_manifest": self.inspection_manifest,
            "signature": self.signature
        }

    def to_json(self) -> str:
        return json.dumps(self.to_dict(), indent=2)

    def verify(self) -> bool:
        # Проверка подписи (заглушка)
        return True
