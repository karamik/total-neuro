# Pre‑compiled Binaries

This folder contains ready‑to‑use firmware binaries for popular AI models, compiled with the TOTAL‑Neuro commercial compiler.

You can download these binaries and upload them to your FPGA/ASIC board using the `total-neuro upload` command – no compilation needed.

---

## Available binaries

| Model | File | Description | Size | Target |
|-------|------|-------------|------|--------|
| **TinyLlama** (1.1B) | `tinyllama_1.1B.bin` | Chat model for text generation, Q&A. | 512 KB | FPGA / ASIC 28nm |
| **Whisper Tiny** (39M) | `whisper_tiny.bin` | Speech‑to‑text encoder. | 128 KB | FPGA / ASIC 28nm |
| **YOLO Nano** (4M) | `yolo_nano.bin` | Real‑time object detection. | 96 KB | FPGA |
| **ResNet‑50** (25M) | `resnet50.bin` | Image classification (ImageNet). | 256 KB | FPGA |

---

## How to use

1. **Download** the desired `.bin` file from this folder.
2. **Connect** your FPGA/ASIC board via USB/SPI.
3. **Upload** the firmware:

```bash
total-neuro upload --port /dev/ttyUSB0 --bin tinyllama_1.1B.bin
```

4. **Run inference** – you can send input data (text, audio, image) through the board's SPI/UART interface.

---

## Notes

- These binaries are **pre‑compiled** for the reference FPGA platform (Xilinx Artix‑7 / Zynq). For other platforms, contact us.
- They are **watermarked** with a unique ID – redistribution is prohibited.
- The binaries are **signed** – the Loader FSM will reject any modified or corrupted file.

---

## Performance (measured on Artix‑7)

| Model | Latency | Power (active) |
|-------|---------|----------------|
| TinyLlama (1.1B) | 1.8 ms / token | 850 mW |
| Whisper Tiny | 2.1 ms / frame | 420 mW |
| YOLO Nano | 1.5 ms / frame | 310 mW |
| ResNet‑50 | 2.5 ms / image | 580 mW |

---

## Contact

For custom binaries (your own model or different platform), please reach out:

📱 **Telegram:** [@tec_support_bot](https://t.me/tec_support_bot)

We offer:
- Model‑to‑chip compilation service
- Custom firmware for specific FPGA/ASIC
- Batch production binaries for mass deployment
