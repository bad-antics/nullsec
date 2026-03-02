from setuptools import setup, find_packages

setup(
    name="nullsec-mothman",
    version="1.0.0",
    description="Network Interface Promiscuity & ARP Anomaly Detector — something watches from the dark",
    author="bad-antics",
    author_email="nullsec@proton.me",
    license="MIT",
    packages=find_packages(),
    install_requires=["click>=8.0"],
    entry_points={"console_scripts": ["mothman=mothman.cli:main"]},
    python_requires=">=3.8",
)
