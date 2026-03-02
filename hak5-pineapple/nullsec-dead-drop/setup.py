from setuptools import setup, find_packages

setup(
    name="nullsec-dead-drop",
    version="1.0.0",
    description="Steganographic Message Hiding — Spy-craft for the terminal",
    long_description=open("README.md").read(),
    long_description_content_type="text/markdown",
    author="bad-antics",
    author_email="nullsec@proton.me",
    url="https://github.com/bad-antics/nullsec-dead-drop",
    packages=find_packages(),
    python_requires=">=3.8",
    install_requires=["click>=8.0", "Pillow>=9.0"],
    entry_points={
        "console_scripts": [
            "dead-drop=dead_drop.cli:entry_point",
        ],
    },
    classifiers=[
        "Development Status :: 4 - Beta",
        "Environment :: Console",
        "Intended Audience :: Developers",
        "Intended Audience :: Information Technology",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Topic :: Security",
        "Topic :: Security :: Cryptography",
    ],
)
