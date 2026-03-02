from setuptools import setup, find_packages
setup(
    name="nullsec-manticore",
    version="1.0.0",
    description="🦂 TLS/SSL Certificate Chain Analyzer — sting your weakest TLS link",
    author="bad-antics",
    author_email="nullsec@proton.me",
    license="MIT",
    packages=find_packages(),
    install_requires=["click>=8.0"],
    entry_points={"console_scripts": ["manticore=manticore.cli:entry_point"]},
    python_requires=">=3.8",
)
