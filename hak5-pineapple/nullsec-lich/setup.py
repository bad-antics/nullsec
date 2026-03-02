from setuptools import setup, find_packages
setup(
    name="nullsec-lich",
    version="1.0.0",
    description="💀 Kernel Module & Rootkit Surface Scanner — command the undead kernel",
    author="bad-antics",
    author_email="nullsec@proton.me",
    license="MIT",
    packages=find_packages(),
    install_requires=["click>=8.0"],
    entry_points={"console_scripts": ["lich=lich.cli:entry_point"]},
    python_requires=">=3.8",
)
