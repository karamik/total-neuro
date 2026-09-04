# Quick Start

## Installation

```bash
pip install total-neuro
```

## Convert a model

Use the command‑line interface to compile a Hugging Face model into a hardware binary:

```bash
total-neuro convert \
  --model TinyLlama/TinyLlama-1.1B-Chat-v1.0 \
  --target fpga \
  --time-windows 16 \
  --output my_model.bin
```

**Parameters:**
- `--model` – Hugging Face model ID or path to a `.pt` / `.onnx` file.
- `--target` – `fpga` (for prototyping) or `asic` (for production tape‑out).
- `--time-windows` – number of temporal windows for Phase‑Trellis encoding (default: 16).
- `--output` – output binary file name.
- `--input-shape` – (optional) input tensor shape, e.g. `1 3 224 224`.

The command generates a binary firmware ready to be loaded into your board.

---

## Upload firmware to your board

If you have a compatible FPGA/ASIC board connected via USB/SPI:

```bash
total-neuro upload --port /dev/ttyUSB0 --bin my_model.bin
```

This sends the binary to the hardware bootloader (Loader FSM) and initialises the chip.

---

## Use the Python API

You can also integrate the compiler into your own Python scripts:

```python
from total_neuro import compile_model

# Generate ED‑IR JSON (public API – demo mode)
edir_json = compile_model('TinyLlama/TinyLlama-1.1B-Chat-v1.0', time_windows=16)
print(edir_json)
```

For full control (custom weights, batch processing, etc.), refer to the [API documentation](docs/api.md).

---

## What’s next?

- Explore the [examples](examples/) folder for MNIST, Whisper, and YOLO demos.
- Read the [ED‑IR specification](docs/edir_spec.md) to understand the intermediate format.
- Check the [roadmap](README.md#-roadmap) for upcoming features.

---

## ⚠️ Important note

This public version is a **demo** – it includes the CLI, Python API, and ED‑IR generation, but the actual hardware compilation (BTR, Phase‑Trellis, Network Calculus, RTL generation) is part of the **commercial core**.

To access the full compiler, RTL source, ASIC‑ready packages, and enterprise support, please contact us:

📱 **Telegram:** [@tec_support_bot](https://t.me/tec_support_bot)

We offer:
- Model‑to‑chip services (turnkey)
- RTL IP licensing (Loader FSM, NoC)
- Custom ASIC/FPGA development
- On‑premise deployment for sensitive projects

---

© 2026 TOTAL‑Neuro. All rights reserved.
