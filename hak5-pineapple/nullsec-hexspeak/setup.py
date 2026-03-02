from setuptools import setup, find_packages

setup(
    name="nullsec-hexspeak",
    version="1.0.0",
    description="Hexadecimal Word Encoder — Speak in machine code",
    long_description=open("README.md").read(),
    long_description_content_type="text/markdown",
    author="bad-antics",
    author_email="nullsec@proton.me",
    url="https://github.com/bad-antics/nullsec-hexspeak",
    packages=find_packages(),
    python_requires=">=3.8",
    install_requires=["click>=8.0"],
    entry_points={
        "console_scripts": [
            "hexspeak=hexspeak.cli:entry_point",
        ],
    },
    classifiers=[
        "Development Status :: 4 - Beta",
        "Environment :: Console",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Topic :: Security",
        "Topic :: Software Development",
    ],
)
