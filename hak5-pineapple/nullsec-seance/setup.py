from setuptools import setup, find_packages
setup(
    name="nullsec-seance", version="1.0.0",
    description="Network Necromancy — Resurrect Dead Connections",
    long_description=open("README.md").read(), long_description_content_type="text/markdown",
    author="bad-antics", author_email="nullsec@proton.me",
    packages=find_packages(), python_requires=">=3.8",
    install_requires=["click>=8.0"],
    entry_points={"console_scripts": ["seance=seance.cli:entry_point"]},
)
