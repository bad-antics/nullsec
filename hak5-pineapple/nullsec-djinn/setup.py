from setuptools import setup, find_packages

setup(
    name="nullsec-djinn",
    version="1.0.0",
    description="Container Escape Surface Analyzer — finds the djinn's way out",
    author="bad-antics",
    author_email="nullsec@proton.me",
    license="MIT",
    packages=find_packages(),
    install_requires=["click>=8.0"],
    entry_points={"console_scripts": ["djinn=djinn.cli:main"]},
    python_requires=">=3.8",
)
