# ED‑IR Specification (Public)

**Event‑Driven Intermediate Representation** – JSON format for describing spiking neural networks and their hardware mapping.

---

## Overview

ED‑IR is the intermediate format used by TOTAL‑Neuro to represent a neural network as a graph of **spiking layers** with temporal encoding, threshold parameters, and virtual channel assignments. It is the bridge between high‑level frameworks (PyTorch, ONNX) and the hardware compiler (ScheduleGenerator + Loader FSM).

This public specification covers the structure and fields; the actual generation of ED‑IR from trained models is part of the commercial core.

---

## Top‑level structure

```json
{
  "protocol_version": "9.2",
  "model_name": "string",
  "architecture": "TOTAL‑Neuro Event‑Driven",
  "layers": [ ... ]
}
```

| Field | Type | Description |
|-------|------|-------------|
| `protocol_version` | string | Version of the ED‑IR format (currently `"9.2"`). |
| `model_name` | string | Human‑readable name of the compiled model. |
| `architecture` | string | Fixed value: `"TOTAL‑Neuro Event‑Driven"`. |
| `layers` | array | List of layer specifications (see below). |

---

## Layer object

Each layer in the `layers` array describes one computational block of the spiking network.

```json
{
  "layer_id": "string",
  "type": "SpikingDense | SpikingConv | MultiHeadAttention | LayerNorm | ...",
  "threshold": float,
  "time_windows": int,
  "weights_shape": [int],
  "virtual_channel": int,
  "weight_data": [float]   // optional – may be omitted in public spec
}
```

| Field | Type | Description |
|-------|------|-------------|
| `layer_id` | string | Unique identifier (e.g., `"fc1"`, `"attn_out"`). |
| `type` | string | Layer type – determines how spikes are processed. Common types: `SpikingDense`, `SpikingConv`, `MultiHeadAttention`, `LayerNorm`, `SpikingLIF`. |
| `threshold` | float | Firing threshold for neurons in this layer (after BTR calibration). |
| `time_windows` | int | Number of discrete time bins used for Phase‑Trellis encoding (typically 8–32). |
| `weights_shape` | [int] | Dimensions of the weight matrix (e.g., `[256, 128]` for a dense layer). |
| `virtual_channel` | int | Hardware virtual channel (0–3) assigned to this layer. 0 = best‑effort, 1–3 = prioritised/isolated. |
| `weight_data` | [float] | (Optional) Flattened weight values. In the public spec, this field is usually omitted to keep the JSON compact. |

---

## Layer types

| Type | Description |
|------|-------------|
| `SpikingDense` | Fully‑connected layer with spike‑based activations. |
| `SpikingConv` | Convolutional layer (2D or 1D). |
| `MultiHeadAttention` | Transformer attention block (Q, K, V, O projections). |
| `LayerNorm` | Normalisation layer (scale + shift). |
| `SpikingLIF` | Leaky‑integrate‑and‑fire neuron layer (for custom models). |

---

## Example ED‑IR

```json
{
  "protocol_version": "9.2",
  "model_name": "mnist_mlp",
  "architecture": "TOTAL‑Neuro Event‑Driven",
  "layers": [
    {
      "layer_id": "fc1",
      "type": "SpikingDense",
      "threshold": 0.125,
      "time_windows": 16,
      "weights_shape": [256, 784],
      "virtual_channel": 1
    },
    {
      "layer_id": "fc2",
      "type": "SpikingDense",
      "threshold": 0.25,
      "time_windows": 16,
      "weights_shape": [10, 256],
      "virtual_channel": 1
    }
  ]
}
```

---

## Virtual channels

| Channel | Purpose |
|---------|---------|
| `0` | Best‑effort traffic – background, non‑critical connections. |
| `1` | Standard priority – normal synaptic paths. |
| `2` | High priority – important connections (weight > 0.7). |
| `3` | Critical – highest priority, isolated from interference (weight > 0.9). |

The compiler uses these channels during static TDM scheduling to guarantee latency bounds for critical paths.

---

## Time windows and Phase‑Trellis

Each layer's `time_windows` defines the temporal resolution of spike encoding. A higher value gives finer granularity but increases memory and latency. Typical values:
- 8 – for high‑speed, low‑precision applications.
- 16 – balanced (default for most models).
- 32 – for tasks requiring high temporal resolution (e.g., audio).

---

## Notes

- The public specification omits internal fields such as `bias`, `activation_stats`, and `phase_anchor` – these are used by the commercial compiler for calibration and routing.
- Full ED‑IR generation from arbitrary PyTorch/ONNX models is part of the **commercial core** and is not available in the open‑source demo.

For the complete ED‑IR generator, RTL source, and ASIC packages, please contact us:

📱 **Telegram:** [@tec_support_bot](https://t.me/tec_support_bot)

---

© 2026 TOTAL‑Neuro. All rights reserved.
