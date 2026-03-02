from setuptools import setup, find_packages
setup(
    name="nullsec-chimera",
    version="1.0.0",
    description="🐉 Binary Polyglot Structure Validator — detect files with multiple faces",
    author="bad-antics",
    author_email="nullsec@proton.me",
    license="MIT",
    packages=find_packages(),
    install_requires=["click>=8.0"],
    entry_points={"console_scripts": ["chimera=chimera.cli:entry_point"]},
    python_requires=">=3.8",
)
