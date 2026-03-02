from setuptools import setup, find_packages
setup(
    name="nullsec-basilisk",
    version="1.0.0",
    description="🐍 DNS Resolver Security Audit — petrify insecure DNS configs",
    author="bad-antics",
    author_email="nullsec@proton.me",
    license="MIT",
    packages=find_packages(),
    install_requires=["click>=8.0"],
    entry_points={"console_scripts": ["basilisk=basilisk.cli:entry_point"]},
    python_requires=">=3.8",
)
