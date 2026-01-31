#!/usr/bin/env python3
"""
AI Entropy Mapper - Setup Script
================================

Install with: pip install -e .
"""

from setuptools import setup, find_packages
from pathlib import Path

# Read README
readme_path = Path(__file__).parent / "README.md"
long_description = readme_path.read_text() if readme_path.exists() else ""

# Read requirements
req_path = Path(__file__).parent / "requirements.txt"
requirements = []
if req_path.exists():
    requirements = [
        line.strip() 
        for line in req_path.read_text().splitlines()
        if line.strip() and not line.startswith('#') and not line.startswith('-')
    ]

setup(
    name="ai-entropy-mapper",
    version="1.0.0",
    author="NullSec Team",
    author_email="nullsec@example.com",
    description="AI System Detection and Mapping Framework",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/nullsec/ai-entropy-mapper",
    project_urls={
        "Bug Tracker": "https://github.com/nullsec/ai-entropy-mapper/issues",
        "Documentation": "https://github.com/nullsec/ai-entropy-mapper/wiki",
    },
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "Intended Audience :: Information Technology",
        "Intended Audience :: Science/Research",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Topic :: Security",
        "Topic :: Scientific/Engineering :: Artificial Intelligence",
    ],
    package_dir={"": "."},
    packages=find_packages(where="."),
    python_requires=">=3.9",
    install_requires=[
        "numpy>=1.24.0",
        "scipy>=1.10.0",
        "torch>=2.0.0",
        "transformers>=4.30.0",
        "networkx>=3.1",
        "matplotlib>=3.7.0",
        "rich>=13.0.0",
        "aiohttp>=3.8.0",
        "pyyaml>=6.0",
    ],
    extras_require={
        "dev": [
            "pytest>=7.3.0",
            "pytest-asyncio>=0.21.0",
            "pytest-cov>=4.1.0",
            "black>=23.0.0",
            "isort>=5.12.0",
            "mypy>=1.3.0",
        ],
        "gpu": [
            "torch[cuda]>=2.0.0",
        ],
    },
    entry_points={
        "console_scripts": [
            "aiem=src.cli:main",
            "ai-entropy-mapper=src.cli:main",
        ],
    },
    include_package_data=True,
    package_data={
        "": ["configs/*.yaml", "configs/*.json"],
    },
)
