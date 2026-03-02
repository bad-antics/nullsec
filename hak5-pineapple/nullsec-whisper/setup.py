from setuptools import setup, find_packages
setup(
    name="nullsec-whisper", version="1.0.0",
    description="Spectral Audio Steganography — Voices From The Static",
    long_description=open("README.md").read(), long_description_content_type="text/markdown",
    author="bad-antics", author_email="nullsec@proton.me",
    url="https://github.com/bad-antics/nullsec-whisper",
    packages=find_packages(), python_requires=">=3.8",
    install_requires=["click>=8.0"],
    entry_points={"console_scripts": ["whisper=whisper.cli:entry_point"]},
)
