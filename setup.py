from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setup(
    name="total-neuro",
    version="0.1.0",
    author="TOTAL‑Neuro Team",
    author_email="total@neuro.dev",
    description="AI‑to‑Chip Compiler – Turn models into microwatt chips",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/karamik/total-neuro",
    packages=find_packages(where="src"),
    package_dir={"": "src"},
    classifiers=[
        "Programming Language :: Python :: 3",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
        "Topic :: Scientific/Engineering :: Artificial Intelligence",
        "Topic :: Hardware :: Embedded Systems",
    ],
    python_requires=">=3.8",
    install_requires=[
        "torch>=2.0.0",
        "numpy>=1.24.0",
        "transformers>=4.30.0",
        "onnx>=1.14.0",
        "onnxruntime>=1.15.0",
        "click>=8.1.0",
        "pyyaml>=6.0",
        "tqdm>=4.65.0",
    ],
    entry_points={
        "console_scripts": [
            "total-neuro = total_neuro.cli:main",
        ],
    },
)
