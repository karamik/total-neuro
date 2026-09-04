# ====================================================================
# Dockerfile for TOTAL‑Neuro public environment
# ====================================================================
# This container provides a ready‑to‑use environment for:
#   - Running the open‑source CLI and Python API
#   - Generating ED‑IR for demo models
#   - Experimenting with examples
#
# For the full commercial compiler (RTL, synthesis scripts, etc.),
# please contact us.
# ====================================================================

FROM ubuntu:22.04

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3 python3-pip git cmake build-essential \
    iverilog gtkwave \
    && rm -rf /var/lib/apt/lists/*

# Set up Python environment
COPY requirements.txt /tmp/
RUN pip3 install --no-cache-dir -r /tmp/requirements.txt

# Copy the source code
WORKDIR /app
COPY . .

# Install the open‑source package
RUN pip3 install -e .

# Set entry point
CMD ["bash"]
